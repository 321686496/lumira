// 生图异步任务轮询工具（step-cover 手动生成 + wizard 全自动 复用）。
// 后端提交返回 taskId 后，这里以固定间隔轮询状态直到 done/error/超时，避免同步长请求撑爆 Vercel serverless。

'use client';

import { aiGenerateImageStatusAction, aiGenerateSilhouetteStatusAction } from '@/actions/ai';
import { aiGenerateImageStartAction, aiGenerateSilhouetteStartAction } from '@/actions/ai';
import type { AiImageStatusResult, AiSilhouetteStatusResult } from '@/types/admin';
import { compressImage } from '@/lib/image-compress';

/** 用户可读的错误（含超时 / 上游失败 / 任务不存在） */
export class AiTaskPollError extends Error {}

const DEFAULT_INTERVAL_MS = 2000;
const DEFAULT_TIMEOUT_MS = 180_000;

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

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function posePrompt(pose: Record<string, unknown> | undefined, extraPrompt?: string | null): string {
  const name = typeof pose?.name === 'string' ? pose.name.trim() : '';
  const description = typeof pose?.description === 'string' ? pose.description.trim() : '';
  const poseParts = [name, description].filter(Boolean);
  const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
  return [...poseParts.map((part) => `姿势要求：${part}`), extra].filter(Boolean).join('；');
}

/** 并行提交每个姿势的生图任务，并分别轮询到完成；单张失败不影响其它任务。 */
export function generateAiPoseImages(options: {
  draft: Record<string, unknown>;
  exampleFile?: File | null;
  extraPrompt?: string | null;
}): Promise<AiTaskFileResult[]> {
  const { draft, exampleFile, extraPrompt } = options;
  const rawPose = draft.pose;
  const poses = Array.isArray(rawPose)
    ? rawPose.filter(isPlainObject)
    : isPlainObject(rawPose)
      ? [rawPose]
      : [];
  const targets = poses.length > 0 ? poses : [undefined];

  return (async () => Promise.all(targets.map(async (pose, index) => {
    try {
      const fd = new FormData();
      fd.set('meta', JSON.stringify(draft));
      if (exampleFile) fd.set('reference', exampleFile);
      const prompt = posePrompt(pose, extraPrompt);
      if (prompt) fd.set('extraPrompt', prompt);
      const start = await aiGenerateImageStartAction(fd);
      if ('error' in start) throw new Error(start.error);
      const result = await pollAiImageTask(start.taskId);
      return {
        index,
        file: base64ToFile(result.image!, result.mimeType!, `ai-pose-${Date.now()}-${index}.png`),
      };
    } catch (err) {
      return { index, error: (err as Error).message || '姿势图生成失败' };
    }
  })))();
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

  return new Promise<AiImageStatusResult>((resolve, reject) => {
    let timer: ReturnType<typeof setInterval> | null = null;
    const cleanup = () => {
      if (timer) clearInterval(timer);
    };

    const fail = (message: string) => {
      cleanup();
      reject(new AiTaskPollError(message));
    };

    const tick = async () => {
      if (Date.now() >= deadline) {
        fail('生成超时，请稍后重试');
        return;
      }
      const res = await aiGenerateImageStatusAction(taskId);
      if ('error' in res) {
        fail(res.error || '查询生图任务失败');
        return;
      }
      if (res.status === 'done') {
        cleanup();
        resolve(res);
        return;
      }
      if (res.status === 'error') {
        fail(res.error || '生图失败，请重试');
        return;
      }
      onTick?.(res.status);
    };

    // 立即首查，随后按间隔轮询
    timer = setInterval(() => {
      tick().catch((err) => fail((err as Error).message));
    }, intervalMs);
    void tick().catch((err) => fail((err as Error).message));
  });
}

/** 轮询剪影异步任务直到完成，避免同步请求被网关 504 掐断。 */
export function pollAiSilhouetteTask(
  taskId: string,
  options: AiTaskPollOptions = {},
  onTick?: (status: AiSilhouetteStatusResult['status']) => void,
): Promise<AiSilhouetteStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const deadline = Date.now() + timeoutMs;

  return new Promise<AiSilhouetteStatusResult>((resolve, reject) => {
    let timer: ReturnType<typeof setInterval> | null = null;
    const cleanup = () => {
      if (timer) clearInterval(timer);
    };
    const fail = (message: string) => {
      cleanup();
      reject(new AiTaskPollError(message));
    };
    const tick = async () => {
      if (Date.now() >= deadline) {
        fail('剪影生成超时，请稍后重试');
        return;
      }
      const res = await aiGenerateSilhouetteStatusAction(taskId);
      if (!res || 'error' in res) {
        fail((res as { error?: string } | undefined)?.error || '查询剪影任务失败');
        return;
      }
      if (res.status === 'done') {
        cleanup();
        resolve(res);
        return;
      }
      if (res.status === 'error') {
        fail(res.error || '剪影生成失败，请重试');
        return;
      }
      onTick?.(res.status);
    };

    timer = setInterval(() => {
      tick().catch((err) => fail((err as Error).message));
    }, intervalMs);
    void tick().catch((err) => fail((err as Error).message));
  });
}
