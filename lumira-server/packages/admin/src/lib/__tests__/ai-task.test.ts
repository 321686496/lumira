// src/lib/__tests__/ai-task.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('@/actions/ai', () => ({
  aiGenerateImageStatusAction: vi.fn(),
  aiGenerateImageStartAction: vi.fn(),
  aiGenerateImageBatchStartAction: vi.fn(),
  aiGenerateSilhouetteStartAction: vi.fn(),
  aiGenerateSilhouetteStatusAction: vi.fn(),
}));

import { aiGenerateImageBatchStartAction, aiGenerateImageStatusAction } from '@/actions/ai';
import { generateAiPoseImages, pollAiImageTask, AiTaskPollError } from '../ai-task';

const statusMock = vi.mocked(aiGenerateImageStatusAction);
const batchStartMock = vi.mocked(aiGenerateImageBatchStartAction);

describe('pollAiImageTask', () => {
  beforeEach(() => {
    statusMock.mockReset();
    batchStartMock.mockReset();
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
    batchStartMock.mockReset();
  });

  it('一次提交批量任务，并保持源图顺序轮询结果', async () => {
    const draft = {
      pose: [{ index: 0 }, { index: 1 }, { index: 2 }],
    };
    batchStartMock.mockResolvedValue({
      tasks: [
        { index: 0, taskId: 'task-0' },
        { index: 1, taskId: 'task-1' },
        { index: 2, taskId: 'task-2' },
      ],
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
    expect(batchStartMock).toHaveBeenCalledTimes(1);

    const formData = batchStartMock.mock.calls[0]?.[0];
    const meta = JSON.parse(formData?.get('meta') as string);
    expect(meta.pose).toHaveLength(3);
    expect(meta.consistency).toEqual({ mode: 'strict' });
    expect(formData?.get('reference')).toBeNull();
    expect(results.map((result) => result.index)).toEqual([0, 1, 2]);
  });

  it('提交指定姿势参考图时传给后端', async () => {
    const draft = { pose: [{ index: 0 }] };
    batchStartMock.mockResolvedValue({ tasks: [{ index: 0, taskId: 'task-0' }] });
    statusMock.mockResolvedValue({
      taskId: 'task-0',
      status: 'done' as const,
      image: 'aGVsbG8=',
      mimeType: 'image/png',
    });
    const reference = new File(['reference'], 'pose.png', { type: 'image/png' });

    await generateAiPoseImages({ draft, referenceFile: reference });

    const formData = batchStartMock.mock.calls[0]?.[0];
    expect(formData?.get('reference')).toBe(reference);
  });

  it('批量提交失败时抛出错误并停止轮询', async () => {
    batchStartMock.mockResolvedValue({ error: '生图服务不可用' });
    await expect(generateAiPoseImages({ draft: {} })).rejects.toThrow('生图服务不可用');
    expect(statusMock).not.toHaveBeenCalled();
  });
});
