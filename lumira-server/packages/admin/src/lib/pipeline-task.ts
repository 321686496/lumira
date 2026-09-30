// src/lib/pipeline-task.ts
// AI 流水线 job 的前端驱动：提交 / 轮询（增量事件 + 退避重试）/ 续跑 / 放弃，
// 并把 job 事件转换为既有「风格识别」「姿势图生成」两个 Tab 所需的既有事件类型。
import { aiPipelineStartAction } from '@/actions/ai';
import {
  deleteAiJob,
  fetchJobFile,
  getAiJobDetail,
  isSettled,
  resumeAiJob,
  type AiJobDetail,
  type AiJobStatus,
} from '@/lib/ai-jobs';
import { formatSec, type AiPoseProgress } from '@/lib/ai-task';
import type {
  AiAnalyzeStatusResult,
  AiBatchImageTraceEvent,
  AiInterruptionCode,
  AiInterruptionInfo,
  AiPipelineEvent,
  AiPipelineJobMode,
  AiPipelineStage,
  AiPipelineStatusResult,
  AiTraceEvent,
} from '@/types/admin';

/** 前端可读的 job 轮询错误（带分类错误码，供中断 Banner 选文案） */
export class PipelinePollError extends Error {
  constructor(
    message: string,
    public readonly code?: AiInterruptionCode,
  ) {
    super(message);
    this.name = 'PipelinePollError';
  }
}

/** 轮询总预算：对齐后端 job 保留期（60 分钟）。超出后前端放弃等待，但 job 仍可「继续」重连 */
const PIPELINE_TIMEOUT_MS = 3_600_000;
const DEFAULT_INTERVAL_MS = 2000;
/** 传输层失败退避：1s / 2s / 4s / 8s（最多 4 次尝试） */
const RETRY_DELAYS_MS = [1000, 2000, 4000, 8000];

/** 分类建议文案（后端 job 的 error.hint 优先；此处仅覆盖传输层合成的中断） */
const HINTS: Record<AiInterruptionCode, string> = {
  job_missing: '任务已失效（后端重启或超过 1 小时保留期被清理），请重新开始',
  upstream_timeout: '上游模型响应超时；可点「继续」重试该阶段，或调大「AI 设置 → 识别稳定性」的单次 LLM 超时',
  upstream_http: '上游返回错误状态；请检查「AI 设置」中的模型与 apiKey（含权限/额度）',
  upstream_empty: '上游返回空内容（多为瞬时故障）；点「继续」重试该阶段',
  poll_timeout: '前端等待超时但后端可能仍在运行；点「继续」重连接着等',
  network: '网络中断或后端不可达；恢复后点「继续」重连',
  payload_too_large: '上传内容过大被网关拒绝；请压缩示例图（建议 ≤3MB/张）后重新开始',
  aborted: '已手动中止；点「继续」可从当前阶段续跑',
  invalid_input: '输入不合法；请按提示修正后重新开始',
  internal: '未归类异常；详情见「生成过程」面板，可点「继续」重试该阶段',
};

const STAGE_LABELS: Record<AiPipelineStage, string> = {
  analyze: '示例图识别',
  image: '封面姿势图生成',
  silhouette: '剪影生成',
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function throwIfAborted(signal?: AbortSignal): void {
  if (signal?.aborted) throw new PipelinePollError('已中止', 'aborted');
}

export function pipelineStageLabel(stage: AiPipelineStage): string {
  return STAGE_LABELS[stage];
}

/**
 * 传输层错误分类：只匹配本仓库自己生成的稳定文案（api.ts 的 `API_ERROR: <status> <detail>`、
 * 超时 / 无法连接 / 空响应），不猜上游自由文本；上游真因由后端 job 的 error 权威给出。
 */
export function classifyPipelineError(message: string): AiInterruptionCode {
  const m = message || '';
  if (/API_ERROR:\s*404/.test(m) || /not found/i.test(m)) return 'job_missing';
  if (/API_ERROR:\s*413/.test(m) || /过大|too large|payload/i.test(m)) return 'payload_too_large';
  if (/API_ERROR:\s*4\d\d/.test(m)) return 'invalid_input';
  if (/超时|无法连接后端|Failed to fetch|NetworkError|ECONNREFUSED|fetch failed/i.test(m)) return 'network';
  return 'internal';
}

/** 是否值得「继续」（可重试）：传输/上游瞬时类可；job 失效、入参错误不可 */
export function isRetryablePipelineError(code: AiInterruptionCode): boolean {
  return (
    code === 'upstream_timeout' ||
    code === 'upstream_http' ||
    code === 'upstream_empty' ||
    code === 'poll_timeout' ||
    code === 'network' ||
    code === 'aborted' ||
    code === 'internal'
  );
}

/** 把传输层异常合成为中断详情（用于 Banner；stage 取当前阶段） */
export function interruptionFromPollError(err: unknown, stage: AiPipelineStage): AiInterruptionInfo {
  const message = err instanceof Error ? err.message : String(err);
  const code = err instanceof PipelinePollError && err.code ? err.code : classifyPipelineError(message);
  return { code, stage, message, hint: HINTS[code], at: Date.now() };
}

/** 有界退避重试：仅对可重试分类重试（默认 1/2/4/8s，共 4 次） */
export async function withRetry<T>(
  fn: () => Promise<T>,
  options: { attempts?: number; delaysMs?: number[]; signal?: AbortSignal } = {},
): Promise<T> {
  const attempts = options.attempts ?? 4;
  const delays = options.delaysMs ?? RETRY_DELAYS_MS;
  let last: unknown;
  for (let i = 1; i <= attempts; i += 1) {
    try {
      return await fn();
    } catch (err) {
      last = err;
      if (options.signal?.aborted) throw err;
      const message = err instanceof Error ? err.message : String(err);
      const code = err instanceof PipelinePollError && err.code ? err.code : classifyPipelineError(message);
      if (!isRetryablePipelineError(code) || i >= attempts) throw err;
      await sleep(delays[i - 1] ?? delays[delays.length - 1] ?? 1000);
    }
  }
  throw last;
}

/** 提交 job → { jobId, status, queuePos }（提交本身失败直接抛，不做重试：入参错误重试无意义） */
export async function startPipelineJob(
  formData: FormData,
): Promise<{ jobId: string; status: AiJobStatus; queuePos: number }> {
  const started = await aiPipelineStartAction(formData);
  if ('error' in started) {
    // server action 只透传 message（收敛 #5）：在此按自有稳定文案补分类，供 Banner 展示与「继续」判定
    const message = started.error || '提交生成任务失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
  return { jobId: started.jobId, status: started.status, queuePos: started.queuePos };
}

/** 单次拉取 job 详情（失败 → 抛 PipelinePollError）；供轮询复用 */
async function fetchJobDetail(jobId: string, since: number): Promise<AiJobDetail> {
  const res = await getAiJobDetail(jobId, since);
  // 注意：AiJobDetail 自带 `error` 字段（失败详情，可为 null），不能以 `'error' in res` 判定失败；
  // 以成功必备的 `jobId` 作判别（与详情页 JobDetail.load 同策略）。
  if (!('jobId' in res)) {
    const message = res.error || '查询生成任务失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
  return res;
}

export interface PollPipelineOptions {
  intervalMs?: number;
  timeoutMs?: number;
  signal?: AbortSignal;
  /** 增量事件累积回调（供两个 Tab 实时渲染） */
  onEvents?: (events: AiPipelineEvent[]) => void;
  /** 每次成功查询回调（供阶段栏 / 进度更新） */
  onStatus?: (result: AiJobDetail) => void;
  /** 传输层重试退避（测试注入小值） */
  retryDelaysMs?: number[];
}

/**
 * 轮询 job 到终态（done/error/stopped/interrupted 统一用 isSettled 判定）：
 * - 单次查询失败 → 退避重试（1/2/4/8s），不因一次抖动就中断（原「查询识别任务失败」的致盲点）
 * - 未终态 → 按 since 增量吸收事件后继续
 * - 终态 → 直接返回该次响应（终态响应为全量：含完整事件 / draft / 产物 / error 详情，
 *   前端据 status 整体替换累积事件，避免运行期收敛版残留）
 * - 超过总预算 → 抛 PipelinePollError(code=poll_timeout)，前端展示「继续」重连
 */
export async function pollPipelineJob(
  jobId: string,
  options: PollPipelineOptions = {},
): Promise<AiJobDetail> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = PIPELINE_TIMEOUT_MS, signal, onEvents, onStatus, retryDelaysMs } =
    options;
  const startedAt = Date.now();
  const deadline = startedAt + timeoutMs;
  let since = 0;
  const events: AiPipelineEvent[] = [];

  const absorb = (res: AiJobDetail) => {
    const incoming = (res.events ?? []) as AiPipelineEvent[];
    if (!incoming.length) return;
    since = res.lastSeq ?? since;
    // 终态响应为全量事件（后端忽略 since 返回完整正文）：整体替换，
    // 让运行期收到的收敛版（长文本截断 / 无 rawResponse）被完整版覆盖，而不是继续增量累积。
    if (isSettled(res.status)) {
      events.splice(0, events.length, ...incoming);
    } else {
      events.push(...incoming);
    }
    onEvents?.(events.slice());
  };

  while (Date.now() < deadline) {
    throwIfAborted(signal);
    const res = await withRetry(() => fetchJobDetail(jobId, since), {
      signal,
      delaysMs: retryDelaysMs,
    });
    absorb(res);
    onStatus?.(res);
    if (isSettled(res.status)) return res;
    await sleep(intervalMs);
  }
  throw new PipelinePollError(
    `等待超时：已等待 ${formatSec(Date.now() - startedAt)}，后端任务可能仍在运行`,
    'poll_timeout',
  );
}

/** 续跑：running → resumed=false（仅重连）；error/stopped/interrupted → resumed=true（从失败阶段重跑） */
export async function resumePipelineJob(jobId: string): Promise<{ resumed: boolean; status: string }> {
  const res = await resumeAiJob(jobId);
  if ('error' in res) {
    const message = res.error || '续跑请求失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
  return res;
}

/** 放弃本次生成（删除 job，幂等） */
export async function cancelPipelineJob(jobId: string): Promise<void> {
  const res = await deleteAiJob(jobId);
  if ('error' in res) {
    const message = res.error || '放弃任务失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
}

/** 取 analyze 阶段事件（喂「风格识别」Tab） */
export function toRecogEvents(events: AiPipelineEvent[]): AiTraceEvent[] {
  return events.filter((e) => e.stage === 'analyze');
}

/** 取 image 阶段事件并转成批次事件类型（喂「姿势图生成」Tab；fail→error、type→kind） */
export function toPoseEvents(events: AiPipelineEvent[]): AiBatchImageTraceEvent[] {
  return events
    .filter((e) => e.stage === 'image')
    .map((e) => ({
      seq: e.seq,
      ts: e.ts,
      index: e.index ?? 0,
      title: e.title,
      status: e.status === 'fail' ? 'error' : e.status,
      kind: e.type === 'llm' ? 'llm' : e.type === 'search' ? 'search' : 'pose',
      callId: e.callId,
      prompt: e.prompt,
      model: e.model,
      systemPrompt: e.systemPrompt,
      userPrompt: e.userPrompt,
      response: e.response,
      rawResponse: e.rawResponse,
      attempts: e.attempts,
      error: e.error,
      durationMs: e.durationMs,
    }));
}

/** 姿势图实时进度（第 current/total 张） */
export function poseProgressFromEvents(events: AiPipelineEvent[]): AiPoseProgress | null {
  const img = events.filter((e) => e.stage === 'image' && typeof e.index === 'number');
  if (!img.length) return null;
  const total = new Set(img.map((e) => e.index)).size;
  if (!total) return null;
  const doneSet = new Set(img.filter((e) => e.status === 'done').map((e) => e.index));
  const running = img.some((e) => e.status === 'running');
  const current = Math.min(total, doneSet.size + (running ? 1 : 0));
  return {
    current,
    total,
    status: doneSet.size >= total ? 'done' : running ? 'running' : 'pending',
  };
}

/** 当前阶段：优先 running，其次 error，再次最后一个 done，缺省首个阶段（兼容 AiJobDetail 与 AiPipelineStatusResult） */
export function currentPipelineStage(
  result: { stages: Record<AiPipelineStage, { status: string }>; mode: AiPipelineJobMode },
): AiPipelineStage {
  const order: AiPipelineStage[] =
    result.mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
  const running = order.find((s) => result.stages[s]?.status === 'running');
  if (running) return running;
  const errored = order.find((s) => result.stages[s]?.status === 'error');
  if (errored) return errored;
  const lastDone = [...order].reverse().find((s) => result.stages[s]?.status === 'done');
  return lastDone ?? order[0]!;
}

/** 按 URL 取回产物并包装为 File（替代旧 base64 版 pipelineFiles）；空 url 跳过，保持输入顺序 */
export async function pipelineFilesFromUrls(
  files: Array<{ index: number; url: string; mimeType: string }>,
): Promise<Array<{ index: number; file: File }>> {
  const out: Array<{ index: number; file: File }> = [];
  for (const f of files) {
    if (!f.url) continue;
    const name = f.url.split('/').pop() ?? `pose-${f.index}.png`;
    out.push({ index: f.index, file: await fetchJobFile(f.url, name) });
  }
  return out;
}

/** job 结果 → 既有「识别详情」弹窗所需结构 */
export function toAnalyzeDetail(result: AiPipelineStatusResult): AiAnalyzeStatusResult {
  const err = result.error;
  return {
    taskId: result.jobId,
    status: result.status,
    draft: result.draft ?? undefined,
    warnings: result.warnings,
    trace: result.trace,
    raw: result.raw ?? undefined,
    research: result.research,
    researchBrief: result.researchBrief,
    researchImages: result.researchImages,
    researchVision: result.researchVision,
    events: toRecogEvents(result.events),
    lastSeq: result.lastSeq,
    error: err ? `${err.message}${err.upstream ? `（上游：${err.upstream}）` : ''}` : undefined,
  };
}