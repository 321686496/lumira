// src/lib/__tests__/ai-task.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('@/actions/ai', () => ({
  aiGenerateImageStatusAction: vi.fn(),
}));

import { aiGenerateImageStatusAction } from '@/actions/ai';
import { pollAiImageTask, AiTaskPollError } from '../ai-task';

const statusMock = vi.mocked(aiGenerateImageStatusAction);

describe('pollAiImageTask', () => {
  beforeEach(() => {
    statusMock.mockReset();
  });

  it('done 时 resolve 出结果（含 image/mimeType）', async () => {
    statusMock
      .mockResolvedValueOnce({ taskId: 't', status: 'running' })
      .mockResolvedValueOnce({ taskId: 't', status: 'done', image: 'aGVsbG8=', mimeType: 'image/png' });
    const result = await pollAiImageTask('t', { intervalMs: 5, timeoutMs: 1000 });
    expect(result.status).toBe('done');
    expect(result.image).toBe('aGVsbG8=');
  });

  it('error 时 reject AiTaskPollError', async () => {
    statusMock.mockResolvedValueOnce({ taskId: 't', status: 'error', error: '模型挂了' });
    await expect(pollAiImageTask('t', { intervalMs: 5, timeoutMs: 1000 })).rejects.toThrow(
      new AiTaskPollError('模型挂了'),
    );
  });

  it('状态查询本身失败（如任务不存在 404）时 reject', async () => {
    statusMock.mockResolvedValueOnce({ error: 'API_ERROR: 404 Image task not found' });
    await expect(pollAiImageTask('t', { intervalMs: 5, timeoutMs: 1000 })).rejects.toThrow(
      'API_ERROR: 404',
    );
  });

  it('始终 running 且超过 timeoutMs 时 reject 超时', async () => {
    statusMock.mockResolvedValue({ taskId: 't', status: 'running' });
    await expect(pollAiImageTask('t', { intervalMs: 5, timeoutMs: 60 })).rejects.toThrow(
      new AiTaskPollError('生成超时，请稍后重试'),
    );
  });

  it('状态请求未完成时不并发发起下一次查询', async () => {
    statusMock
      .mockImplementationOnce(async () => {
        await new Promise((resolve) => setTimeout(resolve, 50));
        return { taskId: 't', status: 'running' };
      })
      .mockResolvedValueOnce({ taskId: 't', status: 'done', image: 'aGVsbG8=', mimeType: 'image/png' });

    const polling = pollAiImageTask('t', { intervalMs: 5, timeoutMs: 1000 });
    await new Promise((resolve) => setTimeout(resolve, 25));
    expect(statusMock).toHaveBeenCalledTimes(1);
    await expect(polling).resolves.toMatchObject({ status: 'done' });
  });
});
