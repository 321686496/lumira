// lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts
// AI 一键建模流水线 job（识别 → 批量姿势图 → 剪影）：
// 把三阶段的输入与产物收在一个内存 job 里，前端只持 jobId；
// 任意阶段中断时保留已完成阶段的产物与统一事件流，支持「继续」（重连 / 重跑失败阶段）。
// 直接复用 AiAnalyzeService / AiGenerateImageService / AiSilhouetteService，
// 不经过既有 3 个 task service（避免任务嵌套与跨服务状态同步）。

import { BadRequestException, Injectable, OnModuleDestroy } from '@nestjs/common';
import { nanoid } from 'nanoid';
import type { UploadFile } from '../templates/admin-templates.service';
import { AiAnalyzeService } from './ai-analyze.service';
import type { AiAnalyzeResult } from './ai-analyze.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { AiUpstreamError, classifyUpstreamError, isRetryableUpstream } from './ai-upstream-error';
import { runWithTrace, traceNote } from './llm-trace';
import type { AiTraceEvent, TraceSink } from './llm-trace';

export type PipelineStage = 'analyze' | 'image' | 'silhouette';
export type StageStatus = 'pending' | 'running' | 'done' | 'error';
export type JobStatus = 'running' | 'done' | 'error';
export type JobMode = 'auto' | 'analyze-only';

/** 中断分类错误码（前端据此选文案与建议，不再靠中文正则猜） */
export type InterruptionCode =
  | 'job_missing'
  | 'upstream_timeout'
  | 'upstream_http'
  | 'upstream_empty'
  | 'poll_timeout'
  | 'network'
  | 'payload_too_large'
  | 'aborted'
  | 'invalid_input'
  | 'internal';

/** 一次中断的分层详情：错误码 + 阶段 + 上游原文 + 耗时 + 失败下标 + 处置建议 */
export interface InterruptionInfo {
  code: InterruptionCode;
  stage: PipelineStage;
  /** 运营可读的粗粒度原因（保留上游原文中的关键信息） */
  message: string;
  /** 上游原始响应/异常文案（截断后） */
  upstream?: string;
  /** 上游 HTTP 状态码 */
  status?: number;
  /** 该阶段已耗时（ms） */
  elapsedMs?: number;
  /** 失败下标（示例图/姿势图/剪影，0-based） */
  failedIndexes?: number[];
  /** 处置建议 */
  hint?: string;
  at: number;
}

export interface StageState {
  status: StageStatus;
  startedAt?: number;
  finishedAt?: number;
  error?: InterruptionInfo;
}

/** 统一事件流事件：在既有 AiTraceEvent 之上补 stage / index / prompt（前端据此分流到两个 Tab） */
export interface AiPipelineEvent extends AiTraceEvent {
  stage: PipelineStage;
  /** 姿势图 / 剪影下标（0-based） */
  index?: number;
  /** 姿势图完成后的最终生图提示词 */
  prompt?: string;
}

export interface PipelinePoseFile {
  index: number;
  base64: string;
  mimeType: string;
}

export interface PipelineStageFailure {
  index: number;
  error: string;
}

export interface AiPipelineJob {
  id: string;
  createdAt: number;
  status: JobStatus;
  mode: JobMode;
  inputs: {
    images?: UploadFile[];
    text?: string;
    extra: {
      textDesc?: string | null;
      creationReq?: string | null;
      poseCount?: string | null;
      subjectCount?: string | null;
    };
    references?: UploadFile[];
    extraPrompt?: string | null;
    silhouette: { mode: 'sketch' | 'solid'; crop: boolean; engine: 'ai' | 'local' };
  };
  stages: Record<PipelineStage, StageState>;
  events: AiPipelineEvent[];
  error?: InterruptionInfo;
  artifacts: {
    analyze?: AiAnalyzeResult;
    poseFiles: PipelinePoseFile[];
    poseErrors: PipelineStageFailure[];
    silFiles: PipelinePoseFile[];
    silErrors: PipelineStageFailure[];
  };
}

export interface PipelineCreateInput {
  images?: UploadFile[];
  text?: string;
  extra?: {
    textDesc?: string | null;
    creationReq?: string | null;
    poseCount?: string | null;
    subjectCount?: string | null;
  };
  references?: UploadFile[];
  extraPrompt?: string | null;
  mode: JobMode;
  silhouette?: { mode: 'sketch' | 'solid'; crop: boolean; engine: 'ai' | 'local' };
}

/** 已完成/错误 job 保留时长（对齐既有 task service：60 分钟，覆盖前端 60 分钟轮询预算） */
const RESULT_TTL_MS = 60 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;
/** 单 job 事件上限（超出静默丢弃，兜住异常长流程的内存占用） */
const MAX_JOB_EVENTS = 1200;
/** running 态序列化时单个文本字段上限（终态 / verbose 沿用 llm-trace 的 50k 上限） */
const COMPACT_TEXT_CAP = 2000;
/** 单张姿势图生图重试上限（与既有 AiImageTaskService 一致） */
const GENERATE_RETRY_LIMIT = 4;

const STAGE_TITLES: Record<PipelineStage, string> = {
  analyze: '示例图识别',
  image: '封面姿势图生成',
  silhouette: '剪影生成',
};

const HINTS: Record<InterruptionCode, string> = {
  job_missing: '任务已失效（后端重启或超过 1 小时保留期被清理），请重新开始',
  upstream_timeout: '上游模型响应超时；可在「AI 设置 → 识别稳定性」调大单次 LLM 超时后点「继续」重试',
  upstream_http: '上游返回错误状态；请检查「AI 设置」中的模型与 apiKey（含权限/额度）',
  upstream_empty: '上游返回空内容（多为瞬时故障）；点「继续」重试该阶段',
  poll_timeout: '前端等待超时但后端可能仍在运行；点「继续」重连接着等',
  network: '网络中断或后端不可达；恢复后点「继续」重连',
  payload_too_large: '上传内容过大被网关拒绝；请压缩示例图（建议 ≤3MB/张）后重新开始',
  aborted: '已手动中止；点「继续」可从当前阶段续跑',
  invalid_input: '输入不合法；请按提示修正后重新开始',
  internal: '未归类异常；详情见上方事件流，可点「继续」重试该阶段',
};

/** running 态事件收敛：长文本截断 + 丢弃原始响应体（终态会重新全量返回） */
function capEvent(e: AiPipelineEvent): AiPipelineEvent {
  const cut = (s?: string): string | undefined =>
    typeof s === 'string' && s.length > COMPACT_TEXT_CAP
      ? `${s.slice(0, COMPACT_TEXT_CAP)}…（已截断，原长 ${s.length} 字）`
      : s;
  return {
    ...e,
    systemPrompt: cut(e.systemPrompt),
    userPrompt: cut(e.userPrompt),
    response: cut(e.response),
    rawResponse: undefined,
  };
}

@Injectable()
export class AiPipelineJobService implements OnModuleDestroy {
  private readonly jobs = new Map<string, AiPipelineJob>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(
    private readonly aiAnalyzeService: AiAnalyzeService,
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiSilhouetteService: AiSilhouetteService,
  ) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    // unref：不因清理定时器阻止进程退出（测试友好）
    this.sweeper.unref?.();
  }

  /** 惰性清理过期 job（含产物，防 base64 占用内存） */
  private sweep(): void {
    const now = Date.now();
    for (const [id, job] of this.jobs) {
      if (now - job.createdAt > RESULT_TTL_MS) this.jobs.delete(id);
    }
  }

  private emptyStages(): Record<PipelineStage, StageState> {
    return {
      analyze: { status: 'pending' },
      image: { status: 'pending' },
      silhouette: { status: 'pending' },
    };
  }

  /** 追加一条事件（分配 seq/ts；达上限静默丢弃） */
  private append(job: AiPipelineJob, ev: Omit<AiPipelineEvent, 'seq' | 'ts'>): void {
    if (job.events.length >= MAX_JOB_EVENTS) return;
    job.events.push({ ...ev, seq: job.events.length + 1, ts: Date.now() });
  }

  /**
   * 创建 job：先快速失败（示例图与文字都缺 → 400），登记 job 后后台跑流水线并立即返回 jobId。
   * 其余输入合法性（图片格式/大小、poseCount 范围、文字长度）在识别阶段由 AiAnalyzeService 校验，
   * 失败会以 invalid_input 中断详情的形式暴露，不会让前端空等。
   */
  async create(input: PipelineCreateInput): Promise<{ jobId: string }> {
    const text = (input.text ?? '').trim();
    if (!input.images?.length && !text) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    const mode: JobMode = input.mode === 'analyze-only' ? 'analyze-only' : 'auto';
    const job: AiPipelineJob = {
      id: `job_${nanoid(16)}`,
      createdAt: Date.now(),
      status: 'running',
      mode,
      inputs: {
        images: input.images,
        text: text || undefined,
        extra: input.extra ?? {},
        references: input.references,
        extraPrompt: input.extraPrompt ?? null,
        silhouette: input.silhouette ?? { mode: 'sketch', crop: true, engine: 'local' },
      },
      stages: this.emptyStages(),
      events: [],
      artifacts: { poseFiles: [], poseErrors: [], silFiles: [], silErrors: [] },
    };
    this.jobs.set(job.id, job);
    void this.runPipeline(job, {
      stages: mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'],
    });
    return { jobId: job.id };
  }

  /**
   * 顺序执行指定阶段；任一阶段失败即写入分层中断详情并停在 error（已完成阶段与产物保留，供续跑）。
   * 已处于 done 的阶段跳过（续跑时复用上游成果）。
   */
  private async runPipeline(
    job: AiPipelineJob,
    opts: { stages: PipelineStage[]; onlyIndexes?: Partial<Record<PipelineStage, number[]>> },
  ): Promise<void> {
    job.status = 'running';
    for (const stage of opts.stages) {
      const state = job.stages[stage];
      if (state.status === 'done') continue;
      state.status = 'running';
      state.startedAt = Date.now();
      state.error = undefined;
      try {
        const onlyIndexes = opts.onlyIndexes?.[stage];
        if (stage === 'analyze') await this.runAnalyzeStage(job);
        else if (stage === 'image') await this.runImageStage(job, onlyIndexes);
        else await this.runSilhouetteStage(job, onlyIndexes);
        state.status = 'done';
        state.finishedAt = Date.now();
      } catch (err) {
        const info = this.buildInterruption(job, stage, err);
        state.status = 'error';
        state.finishedAt = Date.now();
        state.error = info;
        job.status = 'error';
        job.error = info;
        this.append(job, {
          stage,
          type: 'note',
          step: stage,
          title: `${STAGE_TITLES[stage]}中断`,
          status: 'fail',
          error: info.message,
          resultBrief: info.hint,
        });
        return;
      }
    }
    job.status = 'done';
    job.error = undefined;
    const lastStage = opts.stages[opts.stages.length - 1] ?? 'analyze';
    this.append(job, {
      stage: lastStage,
      type: 'note',
      step: 'pipeline',
      title: '流水线完成',
      status: 'done',
      resultBrief: '产物已就绪，可进入下一步',
    });
  }

  /** 把任意异常归一化为分层中断详情（BadRequestException → invalid_input） */
  private buildInterruption(job: AiPipelineJob, stage: PipelineStage, err: unknown): InterruptionInfo {
    const startedAt = job.stages[stage].startedAt;
    if (err instanceof BadRequestException) {
      return {
        code: 'invalid_input',
        stage,
        message: err.message,
        hint: HINTS.invalid_input,
        at: Date.now(),
      };
    }
    const c = classifyUpstreamError(err);
    const code: InterruptionCode =
      c.code === 'upstream_timeout' || c.code === 'upstream_http' || c.code === 'upstream_empty' || c.code === 'network'
        ? c.code
        : 'internal';
    return {
      code,
      stage,
      message: c.message,
      upstream: c.upstream,
      status: c.status,
      failedIndexes: c.failedIndexes,
      elapsedMs: startedAt ? Date.now() - startedAt : undefined,
      hint: HINTS[code],
      at: Date.now(),
    };
  }

  // ===== 阶段执行 =====

  /** ① 识别：跑在 trace 采集上下文内，事件统一落 stage='analyze' */
  private async runAnalyzeStage(job: AiPipelineJob): Promise<void> {
    const sink: TraceSink = (ev) => this.append(job, { ...ev, stage: 'analyze' });
    const result = await runWithTrace(sink, async () => {
      traceNote(
        'task',
        '任务已提交',
        `输入：${job.inputs.images?.length ? `${job.inputs.images.length} 张示例图` : '无图'}${
          job.inputs.text ? ' + 文字描述' : ''
        }`,
      );
      return this.aiAnalyzeService.analyze(job.inputs.images, job.inputs.text, job.inputs.extra);
    });
    job.artifacts.analyze = result;
    this.append(job, {
      stage: 'analyze',
      type: 'note',
      step: 'task',
      title: '识别完成',
      status: 'done',
      resultBrief: '草稿已生成，可进入下一步',
    });
  }

  /** 草稿 → 姿势目标列表（与 AiImageTaskService.submitBatch 同口径） */
  private targetsFor(draft: Record<string, unknown> | undefined): Array<Record<string, unknown> | undefined> {
    const rawPose = draft?.pose;
    const poses = Array.isArray(rawPose)
      ? rawPose.filter(
          (pose): pose is Record<string, unknown> => typeof pose === 'object' && pose !== null && !Array.isArray(pose),
        )
      : rawPose && typeof rawPose === 'object' && !Array.isArray(rawPose)
        ? [rawPose as Record<string, unknown>]
        : [];
    return poses.length > 0 ? poses : [undefined];
  }

  /** 识别阶段研究结果 → 生图阶段 research JSON（与既有前端口径一致：{ items, brief, vision }） */
  private buildResearchJson(job: AiPipelineJob): string | null {
    const a = job.artifacts.analyze;
    if (!a) return null;
    const items = a.research ?? [];
    const brief = a.brief ?? null;
    const vision = a.researchVision ?? null;
    if (!items.length && !brief && !vision) return null;
    return JSON.stringify({ items, brief, vision });
  }

  /** 生图有界重试：仅对可重试分类重试（超时/空响应/网络/5xx/429） */
  private async generateWithRetry(
    references: UploadFile[] | undefined,
    metaJson: string,
    extraPrompt: string | null,
    research: string | null,
  ): Promise<{ base64: string; mimeType: string; prompt: string; model: string }> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= GENERATE_RETRY_LIMIT; attempt += 1) {
      try {
        return await this.aiGenerateImageService.generate(references, metaJson, extraPrompt, research);
      } catch (err) {
        lastError = err;
        const c = classifyUpstreamError(err);
        if (!isRetryableUpstream(c.code, c.status) || attempt >= GENERATE_RETRY_LIMIT) break;
        await new Promise((resolve) => setTimeout(resolve, attempt * attempt * 1000));
      }
    }
    throw lastError instanceof Error ? lastError : new Error('生图失败，请重试');
  }

  /**
   * ② 批量姿势图：首张锚点先生成，其余张以锚点成片为参考并发生成（并发上限由生图服务信号量控制）。
   * onlyIndexes 给定时只补这些下标（续跑「仅补失败/缺失张」）；未给定的下标视为已完成、直接复用产物。
   */
  private async runImageStage(job: AiPipelineJob, onlyIndexes?: number[]): Promise<void> {
    const draft = job.artifacts.analyze?.draft;
    if (!draft) throw new BadRequestException('缺少识别草稿，无法生成姿势图');
    const targets = this.targetsFor(draft);
    const total = targets.length;

    const byIndex = new Map<number, PipelinePoseFile>();
    for (const f of job.artifacts.poseFiles) byIndex.set(f.index, f);

    const todo = (onlyIndexes ?? Array.from({ length: total }, (_, i) => i)).filter(
      (i) => Number.isInteger(i) && i >= 0 && i < total,
    );
    if (!todo.length) return;

    const references = job.inputs.references;
    const research = this.buildResearchJson(job);
    const failed: number[] = [];
    let firstError: unknown;

    for (const index of todo) {
      this.append(job, {
        stage: 'image',
        type: 'note',
        step: 'pose',
        index,
        title: `姿势图 #${index + 1} 排队中`,
        status: 'running',
        resultBrief: '等待生图额度',
      });
    }

    const runOne = async (index: number, refs: UploadFile[] | undefined): Promise<void> => {
      const startedAt = Date.now();
      const queuedMs = await this.aiGenerateImageService.acquireImageSlot();
      try {
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 生成中`,
          status: 'running',
          durationMs: queuedMs > 0 ? queuedMs : undefined,
        });
        const sink: TraceSink = (ev) => this.append(job, { ...ev, stage: 'image', index });
        const meta = JSON.stringify({
          ...draft,
          pose: targets[index],
          singlePose: true,
          consistency: index === 0 ? { mode: 'strict' } : { mode: 'strict', anchor: 'first' },
        });
        const r = await runWithTrace(sink, () =>
          this.generateWithRetry(refs, meta, job.inputs.extraPrompt ?? null, research),
        );
        byIndex.set(index, { index, base64: r.base64, mimeType: r.mimeType });
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 完成`,
          status: 'done',
          prompt: r.prompt,
          model: r.model,
          durationMs: Date.now() - startedAt,
        });
      } catch (err) {
        if (firstError === undefined) firstError = err;
        failed.push(index);
        byIndex.delete(index);
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 失败`,
          status: 'fail',
          error: (err as Error)?.message || '生图失败，请重试',
          durationMs: Date.now() - startedAt,
        });
      } finally {
        this.aiGenerateImageService.releaseImageSlot();
      }
    };

    if (todo.includes(0)) await runOne(0, references);

    const anchor = byIndex.get(0);
    const rest = todo.filter((i) => i !== 0);
    if (!anchor) {
      // 锚点不可用：依赖张全部标记失败（与既有批次语义一致），阶段整体失败
      for (const index of rest) {
        failed.push(index);
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 失败`,
          status: 'fail',
          error: '首张锚点姿势图不可用，已停止后续生成',
        });
      }
    } else {
      const anchorRef: UploadFile = {
        buffer: Buffer.from(anchor.base64, 'base64'),
        filename: 'anchor.png',
        mimetype: anchor.mimeType,
      };
      // 依赖张并发提交（真正的多路上游并行由生图服务内部并发额度控制）
      await Promise.all(rest.map((index) => runOne(index, [anchorRef])));
    }

    job.artifacts.poseFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
    job.artifacts.poseErrors = failed.map((index) => ({ index, error: '姿势图生成失败' }));

    if (failed.length) {
      // 透传真实上游分类（超时/网络/空响应/HTTP），不用固定 upstream_http 掩盖原因；
      // 仅在没有逐张异常（如续跑时锚点本就缺失）时回退到 upstream_http。
      const c = firstError === undefined ? null : classifyUpstreamError(firstError);
      throw new AiUpstreamError(
        c?.code ?? 'upstream_http',
        `共 ${failed.length}/${total} 张姿势图生成失败（#${failed.map((i) => i + 1).join('、')}）`,
        { status: c?.status, upstream: c?.upstream, failedIndexes: failed },
      );
    }
  }

  /**
   * ③ 剪影：源 = 已生成的姿势图（base64），mode/crop/engine 取 job 创建时的选项。
   * onlyIndexes 给定时只补这些下标；未给定的下标复用既有产物。
   */
  private async runSilhouetteStage(job: AiPipelineJob, onlyIndexes?: number[]): Promise<void> {
    const sources = job.artifacts.poseFiles;
    if (!sources.length) throw new BadRequestException('缺少姿势图，无法生成剪影');
    const { mode, crop, engine } = job.inputs.silhouette;

    const byIndex = new Map<number, PipelinePoseFile>();
    for (const f of job.artifacts.silFiles) byIndex.set(f.index, f);

    const todo = (onlyIndexes ?? sources.map((s) => s.index)).filter((i) => sources.some((s) => s.index === i));
    if (!todo.length) return;

    const failed: number[] = [];
    let firstError: unknown;

    await Promise.all(
      todo.map(async (index) => {
        const src = sources.find((s) => s.index === index)!;
        const startedAt = Date.now();
        try {
          this.append(job, {
            stage: 'silhouette',
            type: 'note',
            step: 'silhouette',
            index,
            title: `剪影 #${index + 1} 生成中`,
            status: 'running',
          });
          const file: UploadFile = {
            buffer: Buffer.from(src.base64, 'base64'),
            filename: `pose-${index}.png`,
            mimetype: src.mimeType,
          };
          const sink: TraceSink = (ev) => this.append(job, { ...ev, stage: 'silhouette', index });
          const r = await runWithTrace(sink, () =>
            this.aiSilhouetteService.generate(file, JSON.stringify({ mode, crop, engine })),
          );
          byIndex.set(index, { index, base64: r.image, mimeType: r.mimeType });
          this.append(job, {
            stage: 'silhouette',
            type: 'note',
            step: 'silhouette',
            index,
            title: `剪影 #${index + 1} 完成`,
            status: 'done',
            durationMs: Date.now() - startedAt,
          });
        } catch (err) {
          if (firstError === undefined) firstError = err;
          failed.push(index);
          byIndex.delete(index);
          this.append(job, {
            stage: 'silhouette',
            type: 'note',
            step: 'silhouette',
            index,
            title: `剪影 #${index + 1} 失败`,
            status: 'fail',
            error: (err as Error)?.message || '剪影生成失败，请重试',
            durationMs: Date.now() - startedAt,
          });
        }
      }),
    );

    job.artifacts.silFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
    job.artifacts.silErrors = failed.map((index) => ({ index, error: '剪影生成失败' }));

    if (failed.length) {
      const c = classifyUpstreamError(firstError);
      throw new AiUpstreamError(c.code, `共 ${failed.length}/${todo.length} 张剪影生成失败（#${failed.map((i) => i + 1).join('、')}）`, {
        status: c.status,
        upstream: c.upstream,
        failedIndexes: failed,
      });
    }
  }

  /**
   * 续跑：
   * - job 不存在 → null（控制器转 404，前端提示「任务已失效」并提供重新开始）
   * - running → { resumed: false }（后端仍在跑，前端重新挂上轮询即可）
   * - done   → { resumed: false }（无需续跑）
   * - error  → 从失败阶段重跑（上游阶段与产物保留；image/silhouette 只补失败/缺失下标）
   */
  async resume(jobId: string): Promise<{ resumed: boolean; status: JobStatus } | null> {
    const job = this.jobs.get(jobId);
    if (!job) return null;
    if (job.status === 'running') return { resumed: false, status: 'running' };
    if (job.status === 'done') return { resumed: false, status: 'done' };

    const failedStage = job.error?.stage ?? 'analyze';
    const requested: PipelineStage[] = job.mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
    const stages = requested.slice(requested.indexOf(failedStage));
    if (!stages.length) return { resumed: false, status: job.status };

    const onlyIndexes: Partial<Record<PipelineStage, number[]>> = {};
    if (failedStage === 'analyze') {
      // 识别重跑会产出新草稿 → 下游产物作废并全量重跑
      job.artifacts.poseFiles = [];
      job.artifacts.poseErrors = [];
      job.artifacts.silFiles = [];
      job.artifacts.silErrors = [];
    } else if (failedStage === 'image') {
      onlyIndexes.image = job.artifacts.poseErrors.length
        ? job.artifacts.poseErrors.map((e) => e.index)
        : undefined;
      // 此处不预置 silhouette 下标：image 阶段失败时剪影阶段必未运行，且重跑会新增姿势图，
      // 若用重跑前的 poseFiles 算「缺剪影的下标」会算死缺失集合（静默漏产出/一张不生成）。
      // 交由 runSilhouetteStage 在只传 undefined 时对全部姿势图生成剪影。
    } else {
      onlyIndexes.silhouette = job.artifacts.silErrors.length ? job.artifacts.silErrors.map((e) => e.index) : undefined;
    }

    for (const stage of stages) job.stages[stage] = { status: 'pending' };
    job.status = 'running';
    job.error = undefined;
    this.append(job, {
      stage: failedStage,
      type: 'note',
      step: 'resume',
      title: `从「${STAGE_TITLES[failedStage]}」继续`,
      status: 'done',
      resultBrief: '已保留上游产物，仅重跑失败部分',
    });
    void this.runPipeline(job, { stages, onlyIndexes });
    return { resumed: true, status: 'running' };
  }

  /**
   * 序列化（响应体收敛的关键）：
   * - running 且非 verbose：事件按 since 增量返回并收紧（长文本截断、丢弃 rawResponse），
   *   不返回 base64 产物与草稿（避免每轮整包回传导致响应体随耗时膨胀）。
   * - 终态（done/error）或 verbose=1：返回完整事件（含 rawResponse）与全部产物，供前端最后一次性取回。
   */
  serialize(job: AiPipelineJob, since = 0, verbose = false) {
    const compact = job.status === 'running' && !verbose;
    const a = job.artifacts.analyze;
    return {
      jobId: job.id,
      status: job.status,
      mode: job.mode,
      stages: job.stages,
      error: job.error ?? null,
      events: job.events.filter((e) => e.seq > since).map((e) => (compact ? capEvent(e) : e)),
      lastSeq: job.events.length ? job.events[job.events.length - 1]!.seq : 0,
      draft: compact ? null : (a?.draft ?? null),
      warnings: compact ? [] : (a?.warnings ?? []),
      trace: compact ? [] : (a?.trace ?? []),
      raw: compact ? null : (a?.raw ?? null),
      research: compact ? [] : (a?.research ?? []),
      researchBrief: compact ? null : (a?.brief ?? null),
      researchImages: compact ? [] : (a?.researchImages ?? []),
      researchVision: compact ? null : (a?.researchVision ?? null),
      poseImages: compact ? [] : job.artifacts.poseFiles,
      poseErrors: compact ? [] : job.artifacts.poseErrors,
      silhouetteImages: compact ? [] : job.artifacts.silFiles,
      silhouetteErrors: compact ? [] : job.artifacts.silErrors,
    };
  }

  /** 查询 job；不存在返回 null（前端据此提示任务失效） */
  get(jobId: string): AiPipelineJob | null {
    return this.jobs.get(jobId) ?? null;
  }

  /** 删除 job（放弃本次生成；前端「放弃」按钮调用）。幂等：不存在也不报错 */
  remove(jobId: string): void {
    this.jobs.delete(jobId);
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}