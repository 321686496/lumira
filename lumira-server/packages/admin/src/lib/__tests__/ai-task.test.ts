// src/lib/__tests__/ai-task.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('@/actions/ai', () => ({
  aiGenerateImageStatusAction: vi.fn(),
  aiGenerateImageStartAction: vi.fn(),
  aiGenerateSilhouetteStartAction: vi.fn(),
  aiGenerateSilhouetteStatusAction: vi.fn(),
}));

import { aiGenerateImageStartAction, aiGenerateImageStatusAction } from '@/actions/ai';
import { generateAiPoseImages, pollAiImageTask, AiTaskPollError } from '../ai-task';

const statusMock = vi.mocked(aiGenerateImageStatusAction);
const startMock = vi.mocked(aiGenerateImageStartAction);

describe('pollAiImageTask', () => {
  beforeEach(() => {
    statusMock.mockReset();
    startMock.mockReset();
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

describe('generateAiPoseImages', () => {
  beforeEach(() => {
    statusMock.mockReset();
    startMock.mockReset();
  });

  it('多张姿势图先生成首张锚点，再并发参考首图生成剩余图片', async () => {
    const draft = {
      pose: [{ index: 0 }, { index: 1 }, { index: 2 }],
    };
    startMock.mockImplementation(async (formData: FormData) => {
      const meta = JSON.parse(formData.get('meta') as string);
      const index = meta.pose.index as number;
      await new Promise((resolve) => setTimeout(resolve, index === 0 ? 25 : 0));
      return { taskId: `task-${index}` };
    });
    statusMock.mockImplementation(async (taskId: string) => ({
      taskId,
      status: 'done' as const,
      image: 'aGVsbG8=',
      mimeType: 'image/png',
    }));

    const results = await generateAiPoseImages({ draft });

    expect(results).toHaveLength(3);
    expect(results.every((result) => result.file)).toBe(true);
    expect(startMock).toHaveBeenCalledTimes(3);

    const metas = startMock.mock.calls.map(([formData]) => JSON.parse(formData.get('meta') as string));
    expect(metas[0].consistency).toEqual({ mode: 'strict' });
    expect(metas.slice(1).map((meta) => meta.consistency)).toEqual([
      { mode: 'strict', anchor: 'first' },
      { mode: 'strict', anchor: 'first' },
    ]);
  });

  it('首张锚点失败时不再消耗后续生成请求', async () => {
    const draft = {
      pose: [{ index: 0 }, { index: 1 }, { index: 2 }],
    };
    startMock.mockResolvedValue({ error: '生图服务不可用' });

    const results = await generateAiPoseImages({ draft });

    expect(startMock).toHaveBeenCalledTimes(1);
    expect(results).toHaveLength(3);
    expect(results[0]?.error).toBe('生图服务不可用');
    expect(results.slice(1).every((result) => result.error?.includes('锚点'))).toBe(true);
  });
});
