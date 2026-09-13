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
  /** 批量姿势任务依赖信息；单任务为空 */
  batch?: {
    metaJson: string;
    extraPrompt?: string | null;
    dependencyTaskId?: string;
    dependents?: string[];
  };
  /** 仅 done 时存在 */
  result?: { image: string; mimeType: string };
  /** 仅 error 时存在 */
  error?: string;
}

/** 已完成/错误任务的保留时长（超过即清理，防 base64 结果占用内存） */
const RESULT_TTL_MS = 15 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;
const DEPENDENT_CONCURRENCY = 5;
const GENERATE_RETRY_LIMIT = 4;

@Injectable()
export class AiImageTaskService implements OnModuleDestroy {
  private readonly tasks = new Map<string, ImageTask>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiConfigService: AiConfigService,
  ) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    // unref：不因清理定时器阻止进程退出（测试友好）
    this.sweeper.unref?.();
  }

  /** 惰性清理过期任务（含 done/error 结果） */
  private sweep(): void {
    const now = Date.now();
    for (const [id, task] of this.tasks) {
      if (now - task.createdAt > RESULT_TTL_MS) this.tasks.delete(id);
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
  ): Promise<{ taskId: string }> {
    await this.aiConfigService.getActiveConfig();
    const id = `img_${nanoid(16)}`;
    this.tasks.set(id, { id, status: 'pending', createdAt: Date.now() });
    void this.run(id, reference, metaJson, extraPrompt);
    return { taskId: id };
  }

  /**
   * 批量姿势任务：先提交首张锚点，锚点完成后由后端用内存中的锚点图启动剩余任务，
   * 避免浏览器把已生成图片经 Server Action 回传造成的中断。
   */
  async submitBatch(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
  ): Promise<{ tasks: Array<{ index: number; taskId: string }> }> {
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

    if (targets.length <= 1) {
      const taskMeta = targets[0] === undefined
        ? metaJson
        : JSON.stringify({ ...draft, pose: targets[0], singlePose: true, consistency: { mode: 'strict' } });
      const { taskId } = await this.submit(reference, taskMeta, extraPrompt);
      return { tasks: [{ index: 0, taskId }] };
    }

    const taskIds: string[] = [];
    targets.forEach((_, index) => {
      const id = `img_${nanoid(16)}`;
      this.tasks.set(id, { id, status: 'pending', createdAt: Date.now() });
      taskIds.push(id);
    });

    targets.forEach((pose, index) => {
      const task = this.tasks.get(taskIds[index]!);
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
        dependencyTaskId: index === 0 ? undefined : taskIds[0],
        dependents: index === 0 ? taskIds.slice(1) : undefined,
      };
    });

    const anchor = this.tasks.get(taskIds[0]!);
    if (!anchor?.batch) throw new Error('批量姿势任务初始化失败');
    void this.run(taskIds[0]!, reference, anchor.batch.metaJson, anchor.batch.extraPrompt);

    return {
      tasks: taskIds.map((taskId, index) => ({ index, taskId })),
    };
  }

  /** 后台执行（复用 AiGenerateImageService.generate，内部已有各类超时兜底，不会无限挂起） */
  private async run(
    id: string,
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
  ): Promise<void> {
    const task = this.tasks.get(id);
    if (!task) return;
    task.status = 'running';
    try {
      const r = await this.generateWithRetry(reference, metaJson, extraPrompt);
      task.status = 'done';
      task.result = { image: r.base64, mimeType: r.mimeType };
      void this.startDependents(id);
    } catch (err) {
      task.status = 'error';
      task.error = (err as Error)?.message || '生图失败，请重试';
      this.failDependents(id, task.error);
    }
  }

  private async generateWithRetry(
    reference: UploadFile | undefined,
    metaJson: string | null,
    extraPrompt?: string | null,
  ): Promise<{ base64: string; mimeType: string }> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= GENERATE_RETRY_LIMIT; attempt += 1) {
      try {
        return await this.aiGenerateImageService.generate(reference, metaJson, extraPrompt);
      } catch (err) {
        lastError = err;
        const message = (err as Error)?.message || '';
        const retryable = /HTTP 429|HTTP 5\d\d|超时|无法连接/.test(message);
        if (!retryable || attempt >= GENERATE_RETRY_LIMIT) break;
        await new Promise((resolve) => setTimeout(resolve, attempt * attempt * 1000));
      }
    }
    throw lastError instanceof Error ? lastError : new Error('生图失败，请重试');
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

    const queue = [...dependents];
    const workers = Array.from(
      { length: Math.min(DEPENDENT_CONCURRENCY, queue.length) },
      async () => {
        for (;;) {
          const dependentId = queue.shift();
          if (!dependentId) return;
          const dependent = this.tasks.get(dependentId);
          const batch = dependent?.batch;
          if (!dependent || !batch) continue;
          const reference: UploadFile = {
            buffer: Buffer.from(anchor.result!.image, 'base64'),
            filename: 'anchor.png',
            mimetype: anchor.result!.mimeType,
          };
          await this.run(dependentId, reference, batch.metaJson, batch.extraPrompt);
        }
      },
    );
    void Promise.all(workers).catch(() => undefined);
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

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}
