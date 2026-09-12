// 生图异步任务轮询工具（step-cover 手动生成 + wizard 全自动 复用）。
// 后端提交返回 taskId 后，这里以固定间隔轮询状态直到 done/error/超时，避免同步长请求撑爆 Vercel serverless。

'use client';

import { aiGenerateImageBatchStartAction, aiGenerateImageStatusAction, aiGenerateSilhouetteStatusAction } from '@/actions/ai';
import { aiGenerateSilhouetteStartAction } from '@/actions/ai';
import type { AiImageStatusResult, AiSilhouetteStatusResult } from '@/types/admin';
import { compressImage } from '@/lib/image-compress';

/** 用户可读的错误（含超时 / 上游失败 / 任务不存在） */
export class AiTaskPollError extends Error {}

const DEFAULT_INTERVAL_MS = 2000;
const DEFAULT_TIMEOUT_MS = 180_000;

function sleep(intervalMs: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, intervalMs));
}

export interface AiTaskFileResult {
  index: number;
  file?: File;
  error?: string;
}

function base64ToFile(b64: string, mime: string, name: string): File {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new File([bytes], name, { type: mime });
}

/** 生成姿势图：后端批量编排；多张先生成首张锚点图，其余并行参考锚点图。 */
export function generateAiPoseImages(options: {
  draft: Record<string, unknown>;
  exampleFile?: File | null;
  extraPrompt?: string | null;
}): Promise<AiTaskFileResult[]> {
  const { draft, exampleFile, extraPrompt } = options;
  const pollOne = async (index: number, taskId: string): Promise<AiTaskFileResult> => {
    try {
      const result = await pollAiImageTask(taskId);
      return {
        index,
        file: base64ToFile(result.image!, result.mimeType!, `ai-pose-${Date.now()}-${index}.png`),
      };
    } catch (err) {
      return { index, error: (err as Error).message || '姿势图生成失败' };
    }
  };

  return (async () => {
    const fd = new FormData();
    fd.set('meta', JSON.stringify({
      ...draft,
      consistency: { mode: 'strict' },
    }));
    if (exampleFile) fd.set('reference', exampleFile);
    const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
    if (extra) fd.set('extraPrompt', extra);

    const batch = await aiGenerateImageBatchStartAction(fd);
    if ('error' in batch) throw new Error(batch.error);

    return Promise.all(batch.tasks.map(({ index, taskId }) => pollOne(index, taskId)));
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
