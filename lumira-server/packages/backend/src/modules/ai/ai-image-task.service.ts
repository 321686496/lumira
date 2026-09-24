// lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts
// 封面生图异步任务化（修复 Vercel serverless 同步长请求被掐断）：提交 → 立即返回 taskId，
// 后台执行生图；前端轮询状态。任务存在内存 Map（单容器、结果瞬态；重启丢失由前端针对
// "任务不存在" 给出可重试提示）。仅生图改异步，识别/剪影保持同步。

import { BadRequestException, Injectable, OnModuleDestroy } from '@nestjs/common';
import { nanoid } from 'nanoid';
import { UploadFile } from '../templates/admin-templates.service';
import { AiConfigService } from './ai-config.service';
import { AiGenerateImageService } from './ai-generate-image.service';

export type ImageTaskStatus = 'pending' | 'running' | 'done' | 'error';

export interface ImageTask {
  id: string;
  status: ImageTaskStatus;
  createdAt: number;
  /** 所属批次（批量姿势任务）；单任务为空 */
  batchId?: string;
  /** 批量姿势任务依赖信息；单任务为空 */
  batch?: {
    metaJson: string;
    extraPrompt?: string | null;
    /** 识别阶段研究结果 JSON（ResearchItem[]；透传给生图提示词组织器） */
    research?: string | null;
    dependencyTaskId?: string;
    dependents?: string[];
  };
  /** 仅 done 时存在 */
  result?: { image: string; mimeType: string };
  /** 仅 error 时存在 */
  error?: string;
  startedAt?: number;
  finishedAt?: number;
  prompt?: string;
  model?: string;
}

/** 批次中单张姿势图的结果项 */
export interface AiBatchResultItem {
  index: number;
  /** 内部任务 id（查询用；前端无需关心） */
  taskId?: string;
  status: ImageTaskStatus;
  image?: string;
  mimeType?: string;
  error?: string;
  startedAt?: number;
  finishedAt?: number;
  prompt?: string;
  model?: string;
}

/** 批量姿势图的单条实时 trace 事件（仿 analyze 的 seq 增量机制） */
export interface AiBatchImageTraceEvent {
  seq: number;
  ts: number;
  /** 对应姿势图 index（0-based） */
  index: number;
  title: string;
  status: ImageTaskStatus;
  prompt?: string;
  model?: string;
  error?: string;
  durationMs?: number;
}

/**
 * 单批次进度（前端只轮询这一个接口即可拿到全量进度）：
 * - total：本批张数
 * - completed：已结束（done 或 error）的张数
 * - current：正在处理的第几张（1-based；全部完成后等于 total）
 * - status：'pending' 启动前 / 'running' 处理中 / 'done' 全部处理完毕（含 error）
 * - results：按 index 排序的逐张明细（done 带 image/mimeType，error 带 error）
 */
export interface AiBatchProgress {
  batchId: string;
  total: number;
  completed: number;
  current: number;
  status: ImageTaskStatus;
  results: AiBatchResultItem[];
  createdAt: number;
  /** 实时事件日志（按 seq 递增；前端按 lastSeq 增量拉取） */
  events: AiBatchImageTraceEvent[];
  lastSeq: number;
}

/** 批次 trace 事件上限（超出静默丢弃，防空涨内存） */
const MAX_TRACE_EVENTS = 1000;

/** 已完成/错误任务的保留时长（超过即清理，防 base64 结果占用内存） */
const RESULT_TTL_MS = 15 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;
const GENERATE_RETRY_LIMIT = 4;

@Injectable()
export class AiImageTaskService implements OnModuleDestroy {
  private readonly tasks = new Map<string, ImageTask>();
  /** 批次进度：batchId → 进度快照 */
  private readonly batches = new Map<string, AiBatchProgress>();
  /** 批次内部索引注册表：batchId → [{ index, taskId }]（按 index 顺序） */
  private readonly batchEntries = new Map<string, Array<{ index: number; taskId: string }>>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiConfigService: AiConfigService,
  ) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    // unref：不因清理定时器阻止进程退出（测试友好）
    this.sweeper.unref?.();
  }

  /** 惰性清理过期任务（含 done/error 结果）及对应批次 */
  private sweep(): void {
    const now = Date.now();
    for (const [id, task] of this.tasks) {
      if (now - task.createdAt > RESULT_TTL_MS) this.tasks.delete(id);
    }
    for (const [batchId, batch] of this.batches) {
      if (now - batch.createdAt > RESULT_TTL_MS) {
        this.batches.delete(batchId);
        this.batchEntries.delete(batchId);
      }
    }
  }

  /**
   * 提交生图任务：先快速失败（未配置/未启用时 getActiveConfig 抛 503，避免用户空等），
   * 创建 pending 任务后后台执行并立即返回 taskId。
   */
  async submit(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    research?: string | null,
  ): Promise<{ taskId: string }> {
    await this.aiConfigService.getActiveConfig();
    const id = `img_${nanoid(16)}`;
    this.tasks.set(id, { id, status: 'pending', createdAt: Date.now() });
    void this.run(id, reference, metaJson, extraPrompt, research);
    return { taskId: id };
  }

  /**
   * 批量姿势任务：一次提交返回单个 batchId（前端只需轮询 GET batch/:batchId 一个接口）。
   * 后端先生成首张锚点，锚点完成后用内存中的锚点图启动剩余任务（并发受 DEPENDENT_CONCURRENCY 限制），
   * 逐张完成时实时刷新批次进度；前端据 completed/total 展示「第 X/Y 张」。
   */
  async submitBatch(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    research?: string | null,
  ): Promise<{ batchId: string }> {
    await this.aiConfigService.getActiveConfig();

    let draft: Record<string, unknown> = {};
    if (metaJson) {
      try {
        draft = JSON.parse(metaJson);
      } catch {
        throw new BadRequestException('meta 不是合法的 JSON，请检查草稿数据');
      }
    }
    if (!draft || typeof draft !== 'object' || Array.isArray(draft)) {
      throw new BadRequestException('meta 不是合法的模板草稿');
    }

    const rawPose = draft.pose;
    const poses = Array.isArray(rawPose)
      ? rawPose.filter((pose): pose is Record<string, unknown> => (
          typeof pose === 'object' && pose !== null && !Array.isArray(pose)
        ))
      : rawPose && typeof rawPose === 'object' && !Array.isArray(rawPose)
        ? [rawPose]
        : [];
    const targets = poses.length > 0 ? poses : [undefined];

    const batchId = `bimg_${nanoid(16)}`;
    const entries = targets.map((_, index) => {
      const id = `img_${nanoid(16)}`;
      const task: ImageTask = { id, status: 'pending', createdAt: Date.now(), batchId };
      this.tasks.set(id, task);
      return { index, taskId: id };
    });

    targets.forEach((pose, index) => {
      const task = this.tasks.get(entries[index]!.taskId);
      if (!task) return;
      task.batch = {
        metaJson: JSON.stringify({
          ...draft,
          pose,
          singlePose: true,
          consistency: index === 0
            ? { mode: 'strict' }
            : { mode: 'strict', anchor: 'first' },
        }),
        extraPrompt,
        research,
        dependencyTaskId: index === 0 ? undefined : entries[0].taskId,
        dependents: index === 0 ? entries.slice(1).map((e) => e.taskId) : undefined,
      };
    });

    const firstTaskId = entries[0]!.taskId;
    const anchor = this.tasks.get(firstTaskId);
    this.batchEntries.set(batchId, entries);
    this.batches.set(batchId, {
      batchId,
      total: entries.length,
      completed: 0,
      current: 1,
      status: 'pending',
      results: entries.map(({ index }) => ({ index, status: 'pending' })),
      createdAt: Date.now(),
      events: [],
      lastSeq: 0,
    });

    entries.forEach(({ index }) => {
      this.emitBatchEvent(batchId, { index, title: `姿势图 #${index + 1} 排队中`, status: 'pending' });
    });

    if (!anchor?.batch) throw new BadRequestException('批量姿势任务初始化失败');
    void this.run(
      firstTaskId,
      reference,
      anchor.batch.metaJson,
      anchor.batch.extraPrompt,
      anchor.batch.research,
    );
    this.refreshBatch(batchId);

    return { batchId };
  }

  /** 后台执行（复用 AiGenerateImageService.generate，内部已有各类超时兜底，不会无限挂起） */
  private async run(
    id: string,
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    research?: string | null,
  ): Promise<void> {
    const task = this.tasks.get(id);
    if (!task) return;
    task.status = 'running';
    task.startedAt = Date.now();
    const index = this.indexOfTask(id);
    this.emitBatchEvent(task.batchId, { index, title: `姿势图 #${index + 1} 生成中`, status: 'running' });
    this.refreshBatch(task.batchId);
    try {
      const r = await this.generateWithRetry(reference, metaJson, extraPrompt, research);
      task.status = 'done';
      task.result = { image: r.base64, mimeType: r.mimeType };
      task.prompt = r.prompt;
      task.model = r.model;
      task.finishedAt = Date.now();
      this.emitBatchEvent(task.batchId, {
        index,
        title: `姿势图 #${index + 1} 完成`,
        status: 'done',
        durationMs: task.startedAt ? Date.now() - task.startedAt : undefined,
        prompt: task.prompt,
        model: task.model,
      });
      void this.startDependents(id);
    } catch (err) {
      task.status = 'error';
      task.error = (err as Error)?.message || '生图失败，请重试';
      task.finishedAt = Date.now();
      this.emitBatchEvent(task.batchId, {
        index,
        title: `姿势图 #${index + 1} 失败`,
        status: 'error',
        error: task.error,
        durationMs: task.startedAt ? Date.now() - task.startedAt : undefined,
      });
      this.failDependents(id, task.error);
    }
    this.refreshBatch(task.batchId);
  }

  private async generateWithRetry(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
    research?: string | null,
  ): Promise<{ base64: string; mimeType: string; prompt: string; model: string }> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= GENERATE_RETRY_LIMIT; attempt += 1) {
      try {
        return await this.aiGenerateImageService.generate(reference, metaJson, extraPrompt, research);
      } catch (err) {
        lastError = err;
        const message = (err as Error)?.message || '';
        // 「生图服务返回内容为空」多为上游瞬时空响应，重试大概率成功，纳入可重试集合
        const retryable = /HTTP 429|HTTP 5\d\d|超时|无法连接|返回内容为空/.test(message);
        if (!retryable || attempt >= GENERATE_RETRY_LIMIT) break;
        await new Promise((resolve) => setTimeout(resolve, attempt * attempt * 1000));
      }
    }
    throw lastError instanceof Error ? lastError : new Error('生图失败，请重试');
  }

  /** 向批次追加一条 trace 事件（带 seq/ts；达上限静默丢弃） */
  private emitBatchEvent(
    batchId: string | undefined,
    ev: Omit<AiBatchImageTraceEvent, 'seq' | 'ts'>,
  ): void {
    if (!batchId) return;
    const batch = this.batches.get(batchId);
    if (!batch || batch.events.length >= MAX_TRACE_EVENTS) return;
    batch.lastSeq += 1;
    batch.events.push({ ...ev, seq: batch.lastSeq, ts: Date.now() });
  }

  /** 由 taskId 反查其在批次内的 index（-1 表示未归属任何批次） */
  private indexOfTask(taskId: string): number {
    let found = -1;
    for (const [, entries] of this.batchEntries) {
      const hit = entries.find((e) => e.taskId === taskId);
      if (hit) {
        found = hit.index;
        break;
      }
    }
    return found;
  }

  /** 依据该批次各 task 最新状态重新计算进度快照（任一张结束即调用） */
  private refreshBatch(batchId?: string): void {
    if (!batchId) return;
    const entries = this.batchEntries.get(batchId);
    const progress = this.batches.get(batchId);
    if (!entries || !progress) return;
    const results: AiBatchResultItem[] = [];
    let completed = 0;
    let running = false;
    let pending = false;
    for (const { index, taskId } of entries) {
      const t = this.tasks.get(taskId);
      const status = t?.status ?? 'pending';
      results.push({
        index,
        taskId: t?.id,
        status,
        image: t?.result?.image,
        mimeType: t?.result?.mimeType,
        error: t?.error,
        startedAt: t?.startedAt,
        finishedAt: t?.finishedAt,
        prompt: t?.prompt,
        model: t?.model,
      });
      if (status === 'done' || status === 'error') completed += 1;
      else if (status === 'running') running = true;
      else pending = true;
    }
    const status: ImageTaskStatus =
      completed === entries.length ? 'done' : running || completed > 0 ? 'running' : 'pending';
    progress.results = results;
    progress.completed = completed;
    progress.status = status;
    progress.current = completed < entries.length ? completed + 1 : entries.length;
  }

  private startDependents(taskId: string): void {
    const anchor = this.tasks.get(taskId);
    const dependents = anchor?.batch?.dependents ?? [];
    if (!anchor?.result) {
      for (const dependentId of dependents) {
        const dependent = this.tasks.get(dependentId);
        if (!dependent) continue;
        dependent.status = 'error';
        dependent.error = '首张锚点姿势图生成失败';
      }
      return;
    }

    // 锚点完成后，剩余依赖图一次性全量并发（不设并发上限）——
    // 所有 run 同步内即置 running 并触发 generate，真正的多路上游并行调用，互不阻塞。
    const reference: UploadFile = {
      buffer: Buffer.from(anchor.result.image, 'base64'),
      filename: 'anchor.png',
      mimetype: anchor.result.mimeType,
    };
    const started = dependents.map((dependentId) => {
      const dependent = this.tasks.get(dependentId);
      const batch = dependent?.batch;
      if (!dependent || !batch) return null;
      return this.run(dependentId, reference, batch.metaJson, batch.extraPrompt, batch.research);
    });
    void Promise.all(started.filter((p): p is Promise<void> => p !== null)).catch(() => undefined);
  }

  private failDependents(taskId: string, error: string): void {
    const anchor = this.tasks.get(taskId);
    const dependents = anchor?.batch?.dependents ?? [];
    for (const dependentId of dependents) {
      const dependent = this.tasks.get(dependentId);
      if (!dependent || dependent.status === 'done') continue;
      dependent.status = 'error';
      dependent.error = '首张锚点姿势图生成失败，已停止后续生成';
    }
  }

  /** 查询任务；不存在返回 null（前端据此提示可重试） */
  get(taskId: string): ImageTask | null {
    return this.tasks.get(taskId) ?? null;
  }

  /** 查询批次进度；support since 增量（返回 seq > since 的事件副本）。不存在返回 null */
  getBatch(batchId: string, since?: number): AiBatchProgress | null {
    const batch = this.batches.get(batchId);
    if (!batch) return null;
    if (typeof since === 'number' && since > 0) {
      return { ...batch, events: batch.events.filter((e) => e.seq > since) };
    }
    return batch;
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}
