// src/lib/ai-task.ts
// 生图异步任务轮询工具（step-cover 手动生成 + wizard 全自动 复用）。
// 后端提交返回 taskId 后，这里以固定间隔轮询状态直到 done/error/超时，避免同步长请求撑爆 Vercel serverless。

import { aiGenerateImageStatusAction } from '@/actions/ai';
import type { AiImageStatusResult } from '@/types/admin';

/** 用户可读的错误（含超时 / 上游失败 / 任务不存在） */
export class AiTaskPollError extends Error {}

const DEFAULT_INTERVAL_MS = 2000;
const DEFAULT_TIMEOUT_MS = 180_000;

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