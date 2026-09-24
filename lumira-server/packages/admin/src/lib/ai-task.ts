// 生图异步任务轮询工具（step-cover 手动生成 + wizard 全自动 复用）。
// 批量姿势图已改为「一次性提交 → 拿到单个 batchId → 只轮询一个批次进度接口」的架构，
// 后端在批次内维护 total/completed/current/status/results，前端据此实时展示「第 X/Y 张」。
import {
  aiAnalyzeStatusAction,
  aiGenerateImageBatchStartAction,
  aiGenerateImageBatchStatusAction,
  aiGenerateImageStatusAction,
  aiGenerateSilhouetteStatusAction,
} from '@/actions/ai';
import { aiGenerateSilhouetteStartAction } from '@/actions/ai';
import type {
  AiAnalyzeStatusResult,
  AiImageStatusResult,
  AiSilhouetteStatusResult,
  AiBatchStatusResult,
  AiBatchImageTraceEvent,
  AiResearchRef,
  AiTraceEvent,
} from '@/types/admin';
import { compressImage } from '@/lib/image-compress';

/** 用户可读的错误（含超时 / 上游失败 / 任务不存在） */
export class AiTaskPollError extends Error {}

const DEFAULT_INTERVAL_MS = 2000;
const DEFAULT_TIMEOUT_MS = 600_000;

function sleep(intervalMs: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, intervalMs));
}

export interface AiTaskFileResult {
  index: number;
  file?: File;
  error?: string;
}

/** 实时进度（第 current/total 张、是否处理完毕 status） */
export interface AiPoseProgress {
  current: number;
  total: number;
  status: 'pending' | 'running' | 'done' | 'error';
}

function base64ToFile(b64: string, mime: string, name: string): File {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new File([bytes], name, { type: mime });
}

/** 生成姿势图：一次性提交 → 后端返回单个 batchId → 只轮询 GET batch/:batchId，实时回调进度。 */
export function generateAiPoseImages(options: {
  draft: Record<string, unknown>;
  referenceFile?: File | null;
  extraPrompt?: string | null;
  /** 识别阶段的网络趋势研究结果（透传给后端生图提示词组织器，与草稿同源保持一致） */
  research?: AiResearchRef[] | null;
  onResult?: (result: AiTaskFileResult) => void;
  onProgress?: (progress: AiPoseProgress) => void;
  /** 逐张实时过程事件（按 seq 增量累积；用于可溯源的姿势图过程展示） */
  onEvents?: (events: AiBatchImageTraceEvent[]) => void;
}): Promise<AiTaskFileResult[]> {
  const { draft, referenceFile, extraPrompt, research, onResult, onProgress, onEvents } = options;
  return (async () => {
    const fd = new FormData();
    fd.set('meta', JSON.stringify({
      ...draft,
      consistency: { mode: 'strict' },
    }));
    if (referenceFile) fd.set('reference', referenceFile);
    const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
    if (extra) fd.set('extraPrompt', extra);
    if (research && research.length > 0) fd.set('research', JSON.stringify(research));

    const started = await aiGenerateImageBatchStartAction(fd);
    if ('error' in started) throw new AiTaskPollError(started.error || '生成任务提交失败');
    const batchId = started.batchId;

    const onResultFile = new Set<number>();
    let since = 0;
    const trace: AiBatchImageTraceEvent[] = [];
    const deadline = Date.now() + DEFAULT_TIMEOUT_MS;
    const emitProgress = (res: AiBatchStatusResult) =>
      onProgress?.({ current: res.current, total: res.total, status: res.status });

    while (Date.now() < deadline) {
      const res = await aiGenerateImageBatchStatusAction(batchId, since);
      if ('error' in res) throw new AiTaskPollError(res.error || '查询生成任务失败');
      // 增量吸收实时过程事件（按 seq 去重）
      if ((res as AiBatchStatusResult).events?.length) {
        since = (res as AiBatchStatusResult).lastSeq ?? since;
        trace.push(...(res as AiBatchStatusResult).events!);
        onEvents?.(trace.slice());
      }
      emitProgress(res);

      // 逐张实时回报已完成的姿势图
      for (const item of res.results ?? []) {
        if (!onResultFile.has(item.index) && item.status === 'done' && item.image && item.mimeType) {
          onResultFile.add(item.index);
          onResult?.({ index: item.index, file: base64ToFile(item.image, item.mimeType, `ai-pose-${Date.now()}-${item.index}.png`) });
        }
      }

      if (res.status === 'done') {
        return (res.results ?? []).map((item) => {
          if (item.status === 'done' && item.image && item.mimeType) {
            return { index: item.index, file: base64ToFile(item.image, item.mimeType, `ai-pose-${Date.now()}-${item.index}.png`) };
          }
          return { index: item.index, error: item.error || '姿势图生成失败' };
        });
      }
      await sleep(DEFAULT_INTERVAL_MS);
    }
    throw new AiTaskPollError('生成超时，请稍后重试');
  })();
}

/** 并行提交剪影任务，并分别轮询到完成；结果保持源图顺序。 */
export function generateAiSilhouettes(options: {
  images: File[];
  mode: 'sketch' | 'solid';
  crop: boolean;
  engine: 'ai' | 'local';
  onCompleted?: (completed: number) => void;
}): Promise<AiTaskFileResult[]> {
  const { images, mode, crop, engine, onCompleted } = options;
  const generated = new Array<File | undefined>(images.length).fill(undefined);
  const publish = () => onCompleted?.(generated.filter(Boolean).length);

  return (async () => Promise.all(images.map(async (image, index) => {
    try {
      const source = await compressImage(image, { maxDim: 640, quality: 0.6 });
      const fd = new FormData();
      fd.set('image', source);
      fd.set('meta', JSON.stringify({ mode, crop, engine }));
      const start = await aiGenerateSilhouetteStartAction(fd);
      if (!start || 'error' in start) throw new Error(start?.error || '剪影任务提交失败');
      const result = await pollAiSilhouetteTask(start.taskId);
      const file = base64ToFile(result.image!, result.mimeType!, `ai-silhouette-${Date.now()}-${index}.png`);
      generated[index] = file;
      publish();
      return { index, file };
    } catch (err) {
      return { index, error: (err as Error).message || '剪影生成失败' };
    }
  })))();
}

export interface AiTaskPollOptions {
  intervalMs?: number;
  timeoutMs?: number;
}

/**
 * 轮询直到任务完成：
 * - done → resolve(结果，含 image/mimeType)
 * - error / 状态查询失败 / 超时 → reject(AiTaskPollError)
 * - pending/running → 继续；onTick 可选回调暴露最新状态
 */
export function pollAiImageTask(
  taskId: string,
  options: AiTaskPollOptions = {},
  onTick?: (status: AiImageStatusResult['status']) => void,
): Promise<AiImageStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const deadline = Date.now() + timeoutMs;

  return (async () => {
    while (Date.now() < deadline) {
      const res = await aiGenerateImageStatusAction(taskId);
      if ('error' in res) throw new AiTaskPollError(res.error || '查询生图任务失败');
      if (res.status === 'done') return res;
      if (res.status === 'error') throw new AiTaskPollError(res.error || '生图失败，请重试');
      onTick?.(res.status);
      await sleep(intervalMs);
    }
    throw new AiTaskPollError('生成超时，请稍后重试');
  })();
}

/** 轮询剪影异步任务直到完成，避免同步请求被网关 504 掐断。 */
export function pollAiSilhouetteTask(
  taskId: string,
  options: AiTaskPollOptions = {},
  onTick?: (status: AiSilhouetteStatusResult['status']) => void,
): Promise<AiSilhouetteStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const deadline = Date.now() + timeoutMs;

  return (async () => {
    while (Date.now() < deadline) {
      const res = await aiGenerateSilhouetteStatusAction(taskId);
      if (!res || 'error' in res) {
        throw new AiTaskPollError((res as { error?: string } | undefined)?.error || '查询剪影任务失败');
      }
      if (res.status === 'done') return res;
      if (res.status === 'error') throw new AiTaskPollError(res.error || '剪影生成失败，请重试');
      onTick?.(res.status);
      await sleep(intervalMs);
    }
    throw new AiTaskPollError('剪影生成超时，请稍后重试');
  })();
}

/**
 * 轮询 AI 识别异步任务直到完成，避免同步请求被网关 504 掐断。done → {draft/warnings}；error/超时 reject AiTaskPollError。
 * 传入 options.onEvents 时，按 since 增量拉取流程事件并累积后回调（后台据此实时渲染"走到哪一步 / 提示词 / 响应"）；
 * done 时返回体带上完整 events，供结束后回看整个过程。
 */
export function pollAiAnalyzeTask(
  taskId: string,
  options: AiTaskPollOptions & { onEvents?: (events: AiTraceEvent[]) => void } = {},
  onTick?: (status: AiAnalyzeStatusResult['status']) => void,
): Promise<AiAnalyzeStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS, onEvents } = options;
  const deadline = Date.now() + timeoutMs;
  let since = 0;
  const events: AiTraceEvent[] = [];

  /** 拉取到的增量事件追加进累积列表并回调（去重靠后端 seq 递进） */
  const absorb = (res: AiAnalyzeStatusResult) => {
    if (!res.events?.length) return;
    since = res.lastSeq ?? since;
    events.push(...res.events);
    onEvents?.(events.slice());
  };

  return (async () => {
    while (Date.now() < deadline) {
      const res = await aiAnalyzeStatusAction(taskId, since);
      if (!res || 'error' in res) {
        throw new AiTaskPollError((res as { error?: string } | undefined)?.error || '查询识别任务失败');
      }
      absorb(res);
      if (res.status === 'done') return { ...res, events };
      if (res.status === 'error') {
        throw new AiTaskPollError(res.error || '识别失败，请重试');
      }
      onTick?.(res.status);
      await sleep(intervalMs);
    }
    throw new AiTaskPollError('识别超时，请稍后重试');
  })();
}
