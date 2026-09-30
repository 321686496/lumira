// lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts
// AI 一键建模流水线 job（识别 → 批量姿势图 → 剪影）：
// 把三阶段的输入与产物收在一个内存 job 里，前端只持 jobId；
// 任意阶段中断时保留已完成阶段的产物与统一事件流，支持「继续」（重连 / 重跑失败阶段）。
// 直接复用 AiAnalyzeService / AiGenerateImageService / AiSilhouetteService，
// 不经过既有 3 个 task service（避免任务嵌套与跨服务状态同步）。

import { BadRequestException, Injectable } from '@nestjs/common';
import { nanoid } from 'nanoid';
import type { UploadFile } from '../templates/admin-templates.service';
import { AiAnalyzeService } from './ai-analyze.service';
import type { AiAnalyzeResult } from './ai-analyze.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { AiJobStoreService } from './ai-job.store';
import { AiUpstreamError, classifyUpstreamError, isRetryableUpstream } from './ai-upstream-error';
import { creationIntentOfDraft } from './creation-intent';
import { runWithTrace, traceNote } from './llm-trace';
import type { AiTraceEvent, TraceSink } from './llm-trace';

export type PipelineStage = 'analyze' | 'image' | 'silhouette';
export type StageStatus = 'pending' | 'running' | 'done' | 'error';
export type JobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped';
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
  /** 落存储后的相对 key（序列化时以它构造 url） */
  storageKey?: string;
  url?: string;
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
    /**
     * 参考图是否兼作图生图底图（默认 true = 保持既有语义）。
     * auto 模式把 Step1 示例图兜底当参考图时置 false：示例图常为多格拼图 / 多主体合集，
     * 作底图会被照抄成拼图，故仅交视觉识别注入提示词。
     */
    referenceAnchor: boolean;
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
  /** 待执行阶段（create 后为全量待跑阶段；prepareResume 写入续跑阶段） */
  pendingStages?: PipelineStage[];
  pendingOnlyIndexes?: Partial<Record<PipelineStage, number[]>>;
  /** 用户请求停止：在检查点抛 JobStoppedError */
  stopRequested?: boolean;
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
  /** 参考图是否兼作图生图底图（默认 true）；auto 兜底传示例图时置 false，仅作视觉识别参考 */
  referenceAnchor?: boolean;
  extraPrompt?: string | null;
  mode: JobMode;
  silhouette?: { mode: 'sketch' | 'solid'; crop: boolean; engine: 'ai' | 'local' };
}

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

/** 用户主动停止：不是失败，状态落 stopped 且保留已产出 */
export class JobStoppedError extends Error {
  constructor() {
    super('任务已被用户停止');
    this.name = 'JobStoppedError';
  }
}

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
export class AiPipelineJobService {
  private readonly jobs = new Map<string, AiPipelineJob>();

  constructor(
    private readonly aiAnalyzeService: AiAnalyzeService,
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiSilhouetteService: AiSilhouetteService,
    private readonly store: AiJobStoreService,
  ) {}

  private emptyStages(): Record<PipelineStage, StageState> {
    return {
      analyze: { status: 'pending' },
      image: { status: 'pending' },
      silhouette: { status: 'pending' },
    };
  }

  /** 新任务落库 + 落输入文件（供停止后续跑 / 重启后续跑） */
  private async persistNew(job: AiPipelineJob): Promise<void> {
    const inputs = job.inputs;
    let i = 0;
    for (const img of inputs.images ?? []) {
      await this.store.writeInput(job.id, 'example', i, img.mimetype, img.buffer);
      i += 1;
    }
    let r = 0;
    for (const img of inputs.references ?? []) {
      await this.store.writeInput(job.id, 'ref', r, img.mimetype, img.buffer);
      r += 1;
    }
    await this.store.insertJob({
      id: job.id,
      status: 'queued',
      mode: job.mode,
      title: buildJobTitle(job),
      currentStage: job.pendingStages?.[0] ?? null,
      poseTotal: 0,
      poseDone: 0,
      silTotal: 0,
      silDone: 0,
      queuePos: 0,
      inputSummary: buildInputSummary(job),
      errorCode: null,
      errorMessage: null,
      detailKey: this.store.detailKeyOf(job.id),
      createdAt: Math.floor(job.createdAt / 1000),
      startedAt: null,
      finishedAt: null,
    });
    // 创建即落 detail.json：冷启动 hydrate 依赖它重建 job.inputs / stages（重启后 queued 才能续跑）
    await this.persistDetail(job);
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
      status: 'queued',
      mode,
      inputs: {
        images: input.images,
        text: text || undefined,
        extra: input.extra ?? {},
        references: input.references,
        referenceAnchor: input.referenceAnchor !== false,
        extraPrompt: input.extraPrompt ?? null,
        silhouette: input.silhouette ?? { mode: 'sketch', crop: true, engine: 'local' },
      },
      stages: this.emptyStages(),
      events: [],
      artifacts: { poseFiles: [], poseErrors: [], silFiles: [], silErrors: [] },
    };
    job.pendingStages = mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
    this.jobs.set(job.id, job);
    await this.persistNew(job);
    return { jobId: job.id };
  }

  /** 队列调度入口：执行 pendingStages，resolve 于终态（done / error / stopped） */
  async startJob(jobId: string): Promise<void> {
    const job = this.jobs.get(jobId);
    if (!job) return;
    const stages = job.pendingStages ?? [];
    const onlyIndexes = job.pendingOnlyIndexes;
    job.pendingStages = undefined;
    job.pendingOnlyIndexes = undefined;
    if (!stages.length) return;
    job.stopRequested = false;
    await this.store.updateJob(jobId, { status: 'running', startedAt: Math.floor(Date.now() / 1000) });
    await this.runPipeline(job, { stages, onlyIndexes });
    await this.persistTerminal(job);
  }

  /** 请求停止：置标记，实际停在下一个检查点 */
  requestStop(jobId: string): boolean {
    const job = this.jobs.get(jobId);
    if (!job) return false;
    job.stopRequested = true;
    return true;
  }

  /** 检查点：命中停止请求则抛出 JobStoppedError */
  private assertNotStopped(job: AiPipelineJob): void {
    if (job.stopRequested) throw new JobStoppedError();
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
        this.assertNotStopped(job);
        const onlyIndexes = opts.onlyIndexes?.[stage];
        if (stage === 'analyze') await this.runAnalyzeStage(job);
        else if (stage === 'image') await this.runImageStage(job, onlyIndexes);
        else await this.runSilhouetteStage(job, onlyIndexes);
        state.status = 'done';
        state.finishedAt = Date.now();
      } catch (err) {
        if (err instanceof JobStoppedError) {
          state.status = 'pending';
          state.finishedAt = Date.now();
          job.status = 'stopped';
          this.append(job, {
            stage,
            type: 'note',
            step: 'stop',
            title: '任务已停止',
            status: 'fail',
            resultBrief: '已保留当前产出，可点「继续」从该阶段续跑',
          });
          return;
        }
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
    await this.persistDetail(job);
    await this.store.updateJob(job.id, { currentStage: job.mode === 'analyze-only' ? null : 'image' });
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
    job: AiPipelineJob,
    references: UploadFile[] | undefined,
    metaJson: string,
    extraPrompt: string | null,
    research: string | null,
    anchor: boolean,
  ): Promise<{ base64: string; mimeType: string; prompt: string; model: string }> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= GENERATE_RETRY_LIMIT; attempt += 1) {
      this.assertNotStopped(job);
      try {
        return await this.aiGenerateImageService.generate(references, metaJson, extraPrompt, research, { anchor });
      } catch (err) {
        lastError = err;
        const c = classifyUpstreamError(err);
        if (!isRetryableUpstream(c.code, c.status) || attempt >= GENERATE_RETRY_LIMIT) break;
        // 重试留痕：让后台时间线看得见「同一张图正在重试」，而不是停在「生成中」无变化
        traceNote('pose', `生图重试第 ${attempt + 1} 次`, (err as Error)?.message || c.code);
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
    // 创作意图：跨图是否同一人物决定「依赖张是否以首张成片为锚点」。
    // sameSubjectAcross=false（每张不同人物）时不能用首张成片当底图，否则各张被强行画成同一个人。
    const crossSameSubject = creationIntentOfDraft(draft)?.sameSubjectAcross ?? true;
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
      this.assertNotStopped(job);
      const startedAt = Date.now();
      const queuedMs = await this.aiGenerateImageService.acquireImageSlot();
      try {
        // 等待生图额度期间可能已请求停止：命中则不再发起生图（finally 会释放已获取的额度）
        this.assertNotStopped(job);
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
          consistency:
            index === 0
              ? { mode: 'strict' }
              : crossSameSubject
                ? { mode: 'strict', anchor: 'first' }
                : { mode: 'loose' },
        });
        // 首张用的是外部参考图，是否作底图由 referenceAnchor 决定；
        // 依赖张（index>0）的 refs 是首张锚点成片：跨图同一人物时保留底图以维持一致性，
        // 每张不同人物（sameSubjectAcross=false）时不传锚点，各张独立按参考图/提示词生成。
        const useAnchor = index === 0 ? job.inputs.referenceAnchor : crossSameSubject;
        const r = await runWithTrace(sink, () =>
          this.generateWithRetry(job, refs, meta, job.inputs.extraPrompt ?? null, research, useAnchor),
        );
        const file: PipelinePoseFile = { index, base64: r.base64, mimeType: r.mimeType };
        const stored = await this.store.writeArtifact(job.id, 'pose', index, file.mimeType, Buffer.from(file.base64, 'base64'));
        file.storageKey = stored.storageKey;
        file.url = stored.url;
        byIndex.set(index, file);
        // 即时回写：任何时刻（含并发兄弟张抛 JobStoppedError）中断，内存产物都与 DB 计数一致
        job.artifacts.poseFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
        await this.store.updateJob(job.id, {
          poseDone: byIndex.size,
          poseTotal: total,
          currentStage: 'image',
        });
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
        if (err instanceof JobStoppedError) throw err;
        if (firstError === undefined) firstError = err;
        failed.push(index);
        byIndex.delete(index);
        job.artifacts.poseErrors = failed.map((i) => ({ index: i, error: '姿势图生成失败' }));
        job.artifacts.poseFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
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
    if (!anchor && crossSameSubject) {
      // 跨图同一人物时锚点不可用：依赖张全部标记失败（与既有批次语义一致），阶段整体失败。
      // 每张不同人物（crossSameSubject=false）时各张互不依赖，锚点缺失不阻塞后续张。
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
      const anchorRef: UploadFile | undefined = anchor
        ? {
            buffer: Buffer.from(anchor.base64, 'base64'),
            filename: 'anchor.png',
            mimetype: anchor.mimeType,
          }
        : undefined;
      // 依赖张并发提交（真正的多路上游并行由生图服务内部并发额度控制）
      const settled = await Promise.allSettled(
        rest.map((index) => runOne(index, crossSameSubject && anchorRef ? [anchorRef] : undefined)),
      );
      // 停止：等所有在飞张收口（期间不再启动新张），确保产物计入内存/DB 后再让停止冒泡落终态快照
      const stoppedSibling = settled.find(
        (s): s is PromiseRejectedResult => s.status === 'rejected' && s.reason instanceof JobStoppedError,
      );
      if (stoppedSibling) throw stoppedSibling.reason;
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

    const settled = await Promise.allSettled(
      todo.map(async (index) => {
        const src = sources.find((s) => s.index === index)!;
        this.assertNotStopped(job);
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
          const out: PipelinePoseFile = { index, base64: r.image, mimeType: r.mimeType };
          const stored = await this.store.writeArtifact(job.id, 'sil', index, out.mimeType, Buffer.from(out.base64, 'base64'));
          out.storageKey = stored.storageKey;
          out.url = stored.url;
          byIndex.set(index, out);
          job.artifacts.silFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
          await this.store.updateJob(job.id, {
            silDone: byIndex.size,
            silTotal: sources.length,
            currentStage: 'silhouette',
          });
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
          job.artifacts.silErrors = failed.map((i) => ({ index: i, error: '剪影生成失败' }));
          job.artifacts.silFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
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
    const stoppedSibling = settled.find(
      (s): s is PromiseRejectedResult => s.status === 'rejected' && s.reason instanceof JobStoppedError,
    );
    if (stoppedSibling) throw stoppedSibling.reason;

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

  /** 冷启动恢复：从存储文件重建内存 job（后端重启后的「继续」用） */
  async hydrate(jobId: string): Promise<boolean> {
    if (this.jobs.has(jobId)) return true;
    const row = await this.store.findJob(jobId);
    if (!row) return false;
    const detail = await this.store.readDetail(jobId);
    if (!detail) return false;
    const inputs = await this.store.readInputs(jobId);
    const pick = (kind: 'example' | 'ref') =>
      inputs
        .map((f) => ({ f, m: /^(?:input\/)?(example|ref)-(\d+)\./.exec(f.name) }))
        .filter((x) => x.m && x.m[1] === kind)
        .sort((x, y) => Number(x.m![2]) - Number(y.m![2]))
        .map((x) => ({ buffer: x.f.buffer, filename: x.f.name.split('/').pop() ?? x.f.name, mimetype: mimeFromName(x.f.name) }));
    // 完整输入快照（新 detail 才有）；旧 detail.json 缺失时逐项回退到摘要字段
    const inputFull = ((detail as { inputFull?: unknown }).inputFull ?? {}) as {
      text?: string | null;
      extra?: AiPipelineJob['inputs']['extra'] | null;
      extraPrompt?: string | null;
      referenceAnchor?: boolean;
      silhouette?: AiPipelineJob['inputs']['silhouette'];
    };
    // 重启后 queued 的任务需按默认全量阶段重建待跑计划（error/stopped 的续跑阶段由 prepareResume 计算）
    const pendingStages: PipelineStage[] | undefined =
      row.status === 'queued'
        ? row.mode === 'analyze-only'
          ? ['analyze']
          : ['analyze', 'image', 'silhouette']
        : undefined;
    const job: AiPipelineJob = {
      id: jobId,
      createdAt: row.createdAt * 1000,
      // DB 的 interrupted 只是「待续跑」的 error 语义，统一映射为 error；stopped 原样保留，
      // queued（重启后尚未开跑）原样保留，其待跑阶段由 pendingStages 给出
      status: row.status === 'stopped' ? 'stopped' : row.status === 'queued' ? 'queued' : 'error',
      mode: row.mode,
      error: (detail.error as InterruptionInfo | null) ?? undefined,
      pendingStages,
      inputs: {
        images: pick('example'),
        text: (inputFull.text ?? (detail.inputs.textPreview as string)) || undefined,
        extra: inputFull.extra ?? {},
        references: pick('ref'),
        referenceAnchor: inputFull.referenceAnchor ?? detail.inputs.refAnchor !== false,
        extraPrompt: inputFull.extraPrompt ?? null,
        silhouette: {
          mode: inputFull.silhouette?.mode ?? (detail.inputs.silMode as 'sketch' | 'solid') ?? 'sketch',
          crop: inputFull.silhouette?.crop ?? true,
          engine: inputFull.silhouette?.engine ?? (detail.inputs.silEngine as 'ai' | 'local') ?? 'local',
        },
      },
      stages: detail.stages as Record<PipelineStage, StageState>,
      events: [],
      artifacts: {
        analyze: detail.draft
          ? ({ draft: detail.draft, warnings: detail.warnings, trace: detail.trace, raw: detail.raw, research: detail.research, brief: detail.researchBrief, researchVision: detail.researchVision } as unknown as AiAnalyzeResult)
          : undefined,
        poseFiles: detail.artifacts.poseFiles.map((s) => ({ index: s.index, mimeType: s.mimeType, base64: '', storageKey: s.storageKey, url: s.url })),
        poseErrors: detail.artifacts.poseErrors as never,
        silFiles: detail.artifacts.silFiles.map((s) => ({ index: s.index, mimeType: s.mimeType, base64: '', storageKey: s.storageKey, url: s.url })),
        silErrors: detail.artifacts.silErrors as never,
      },
    };
    this.jobs.set(jobId, job);
    return true;
  }

  /**
   * 续跑准备：算出待重跑阶段并写入 pendingStages；实际执行由队列调度 startJob 触发。
   * - job 不存在 → null（控制器转 404，前端提示「任务已失效」并提供重新开始）
   * - running / done → null（无需续跑）
   * - error / stopped → 从失败阶段重跑（上游阶段与产物保留；image/silhouette 只补失败/缺失下标）
   */
  async prepareResume(jobId: string): Promise<{ stages: PipelineStage[]; onlyIndexes: Partial<Record<PipelineStage, number[]>> } | null> {
    const job = this.jobs.get(jobId);
    if (!job) return null;
    if (job.status === 'running' || job.status === 'done') return null;

    const requested: PipelineStage[] =
      job.mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
    // 失败阶段：优先取错误携带的阶段；停止/中断（无 error）时回退到首个未完成阶段
    let failedStage: PipelineStage =
      job.error?.stage ?? requested.find((s) => job.stages[s].status !== 'done') ?? 'analyze';
    // 冷启动恢复的产物没有字节（base64 为空），无法充当锚点/剪影源图；
    // 若仍从 image/silhouette 续跑会喂 0 字节图片，故退化为从 analyze 全量重跑（保守但正确）
    if (failedStage !== 'analyze' && job.artifacts.poseFiles.some((f) => !f.base64)) {
      failedStage = 'analyze';
    }
    const stages = requested.slice(requested.indexOf(failedStage));
    if (!stages.length) return null;

    const onlyIndexes: Partial<Record<PipelineStage, number[]>> = {};
    if (failedStage === 'analyze') {
      // 识别重跑会产出新草稿 → 下游产物作废并全量重跑
      job.artifacts.poseFiles = [];
      job.artifacts.poseErrors = [];
      job.artifacts.silFiles = [];
      job.artifacts.silErrors = [];
    } else if (failedStage === 'image') {
      // 只补「缺失下标」（= 未成功产出姿势图的下标），停止/失败两种入口语义一致
      const total = this.targetsFor(job.artifacts.analyze?.draft).length;
      const done = new Set(job.artifacts.poseFiles.map((f) => f.index));
      const missing = Array.from({ length: total }, (_, i) => i).filter((i) => !done.has(i));
      onlyIndexes.image = missing.length ? missing : undefined;
      // 此处不预置 silhouette 下标：image 阶段重跑会新增姿势图，
      // 若用重跑前的 poseFiles 算「缺剪影的下标」会算死缺失集合（静默漏产出）。
      // 交由 runSilhouetteStage 在只传 undefined 时对全部姿势图生成剪影。
    } else {
      onlyIndexes.silhouette = job.artifacts.silErrors.length
        ? job.artifacts.silErrors.map((e) => e.index)
        : undefined;
    }

    for (const stage of stages) job.stages[stage] = { status: 'pending' };
    job.pendingStages = stages;
    job.pendingOnlyIndexes = onlyIndexes;
    job.status = 'queued';
    job.error = undefined;
    return { stages, onlyIndexes };
  }

  /**
   * 序列化（响应体收敛的关键）：
   * - running 且非 verbose：事件按 since 增量返回并收紧（长文本截断、丢弃 rawResponse），
   *   不返回 base64 产物与草稿（避免每轮整包回传导致响应体随耗时膨胀）。
   * - 终态（done/error/stopped/interrupted）：忽略 since，一次性返回**全量**完整事件（含 rawResponse）与全部产物；
   *   运行期返回的是收敛版（截断 / 无 rawResponse），前端又按 seq 增量累积，
   *   终态若仍只返回增量，累积列表里的收敛版将永远无法被完整版覆盖（截断残留 bug）。
   * - verbose=1：按 since 返回增量，但按完整字段返回（供带 since 的显式全量查询）。
   */
  serialize(job: AiPipelineJob, since = 0, verbose = false) {
    const terminal = job.status !== 'running' && job.status !== 'queued';
    const compact = !terminal && !verbose;
    const from = terminal ? 0 : since;
    const a = job.artifacts.analyze;
    return {
      jobId: job.id,
      status: job.status,
      mode: job.mode,
      stages: job.stages,
      error: job.error ?? null,
      events: job.events.filter((e) => e.seq > from).map((e) => (compact ? capEvent(e) : e)),
      lastSeq: job.events.length ? job.events[job.events.length - 1]!.seq : 0,
      draft: compact ? null : (a?.draft ?? null),
      warnings: compact ? [] : (a?.warnings ?? []),
      trace: compact ? [] : (a?.trace ?? []),
      raw: compact ? null : (a?.raw ?? null),
      research: compact ? [] : (a?.research ?? []),
      researchBrief: compact ? null : (a?.brief ?? null),
      researchImages: compact ? [] : (a?.researchImages ?? []),
      researchVision: compact ? null : (a?.researchVision ?? null),
      poseImages: compact ? [] : job.artifacts.poseFiles.map(toStored),
      poseErrors: compact ? [] : job.artifacts.poseErrors,
      silhouetteImages: compact ? [] : job.artifacts.silFiles.map(toStored),
      silhouetteErrors: compact ? [] : job.artifacts.silErrors,
    };
  }

  /** 详情快照落存储（analyze 完成 / image 完成 / 终态调用；运行中详情页读内存，不读它） */
  async persistDetail(job: AiPipelineJob): Promise<void> {
    const a = job.artifacts.analyze;
    const detail = {
      stages: job.stages,
      error: job.error ?? null,
      warnings: a?.warnings ?? [],
      draft: a?.draft ?? null,
      trace: a?.trace ?? [],
      raw: a?.raw ?? null,
      research: a?.research ?? [],
      researchBrief: a?.brief ?? null,
      researchVision: a?.researchVision ?? null,
      artifacts: {
        poseFiles: job.artifacts.poseFiles.map(toStored),
        poseErrors: job.artifacts.poseErrors,
        silFiles: job.artifacts.silFiles.map(toStored),
        silErrors: job.artifacts.silErrors,
      },
      inputs: buildInputSummary(job),
      // 完整输入快照（供冷启动续跑还原，避免回退到截断摘要重跑 analyze）
      inputFull: {
        text: job.inputs.text ?? null,
        extra: job.inputs.extra ?? null,
        extraPrompt: job.inputs.extraPrompt ?? null,
        referenceAnchor: job.inputs.referenceAnchor,
        silhouette: job.inputs.silhouette,
      },
    };
    await this.store.writeDetail(job.id, detail);
  }

  /** 终态收尾：写 detail + events + DB 终态字段 */
  private async persistTerminal(job: AiPipelineJob): Promise<void> {
    await this.persistDetail(job);
    await this.store.writeEvents(job.id, job.events);
    const settledAt = Math.floor(Date.now() / 1000);
    await this.store.updateJob(job.id, {
      status: job.status,
      errorCode: job.error?.code ?? null,
      errorMessage: job.error?.message ?? null,
      startedAt: null,
      finishedAt: settledAt,
      currentStage: null,
    });
  }

  /** 查询 job；不存在返回 null（前端据此提示任务失效） */
  get(jobId: string): AiPipelineJob | null {
    return this.jobs.get(jobId) ?? null;
  }

  /** 删除 job（放弃本次生成；前端「放弃」按钮调用）。幂等：不存在也不报错 */
  remove(jobId: string): void {
    this.jobs.delete(jobId);
  }
}

/** 列表标题：文字描述前 20 字，否则「N 张示例图」 */
export function buildJobTitle(job: AiPipelineJob): string {
  const text = (job.inputs.text ?? job.inputs.extra.textDesc ?? '').trim();
  if (text) return text.length > 20 ? `${text.slice(0, 20)}…` : text;
  const n = job.inputs.images?.length ?? 0;
  return n ? `${n} 张示例图` : '未命名任务';
}

/** 列表输入摘要（不含图片字节） */
export function buildInputSummary(job: AiPipelineJob): Record<string, unknown> {
  const text = (job.inputs.text ?? '').trim();
  return {
    imageCount: job.inputs.images?.length ?? 0,
    refCount: job.inputs.references?.length ?? 0,
    hasText: Boolean(text),
    textPreview: text.slice(0, 80),
    poseCount: job.inputs.extra.poseCount ?? null,
    subjectCount: job.inputs.extra.subjectCount ?? null,
    silMode: job.inputs.silhouette.mode,
    silEngine: job.inputs.silhouette.engine,
    refAnchor: job.inputs.referenceAnchor,
  };
}

/** 产物引用（序列化 / detail 落盘共用，剔除 base64） */
export function toStored(f: PipelinePoseFile) {
  return { index: f.index, mimeType: f.mimeType, storageKey: f.storageKey ?? '', url: f.url ?? '' };
}

function mimeFromName(name: string): string {
  const ext = name.split('.').pop()?.toLowerCase();
  if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'gif') return 'image/gif';
  return 'image/png';
}