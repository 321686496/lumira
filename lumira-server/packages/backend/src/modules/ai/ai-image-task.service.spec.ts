// lumira-server/packages/backend/src/modules/ai/ai-image-task.service.spec.ts
// 生图异步任务化单测：submit 快速失败 / 返回 taskId / 后台执行 done+result /
// 失败 error / get 不存在 null。直接手工 stub AiGenerateImageService + AiConfigService。

import { ServiceUnavailableException } from '@nestjs/common';
import { AiImageTaskService } from './ai-image-task.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiConfigService } from './ai-config.service';
import type { UploadFile } from '../templates/admin-templates.service';

describe('AiImageTaskService', () => {
  let service: AiImageTaskService;
  let generateMock: jest.Mock;
  let getActiveConfigMock: jest.Mock;

  beforeEach(() => {
    generateMock = jest.fn();
    getActiveConfigMock = jest.fn();
    service = new AiImageTaskService(
      { generate: generateMock } as unknown as AiGenerateImageService,
      { getActiveConfig: getActiveConfigMock } as unknown as AiConfigService,
    );
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.useRealTimers();
  });

  async function waitStatus(id: string, status: string): Promise<void> {
    for (let i = 0; i < 100; i++) {
      if (service.get(id)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for status ${status}`);
  }

  it('submit 快速失败：未配置/未启用抛 503，且不触发生图', async () => {
    getActiveConfigMock.mockRejectedValue(
      new ServiceUnavailableException('AI 未配置或未启用'),
    );
    await expect(service.submit(undefined, null)).rejects.toThrow(ServiceUnavailableException);
    expect(generateMock).not.toHaveBeenCalled();
  });

  it('submit 返回 taskId，后台执行完成后 done 且带 image/mimeType', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockResolvedValue({ base64: 'aGVsbG8=', mimeType: 'image/png' });

    const { taskId } = await service.submit(undefined, '{}');
    expect(taskId).toMatch(/^img_/);

    await waitStatus(taskId, 'done');
    const task = service.get(taskId);
    expect(task?.status).toBe('done');
    expect(task?.result).toEqual({ image: 'aGVsbG8=', mimeType: 'image/png' });
    expect(generateMock).toHaveBeenCalledTimes(1);
  });

  it('生图失败：done 转 error 且带可读 message', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockRejectedValue(new Error('AI 上游错误（HTTP 500）：boom'));

    const { taskId } = await service.submit(undefined, '{}');
    await waitStatus(taskId, 'error');
    expect(service.get(taskId)?.error).toBe('AI 上游错误（HTTP 500）：boom');
    expect(service.get(taskId)?.result).toBeUndefined();
  });

  it('get 不存在的 taskId 返回 null', () => {
    expect(service.get('img_nope')).toBeNull();
  });

  it('批量姿势任务：首张完成后用锚点结果启动剩余任务', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockImplementation(async (_reference, metaJson: string) => {
      const meta = JSON.parse(metaJson);
      if (meta.consistency?.anchor !== 'first') {
        return { base64: 'YW5jaG9y', mimeType: 'image/png' };
      }
      return { base64: 'cG9zZQ==', mimeType: 'image/png' };
    });
    const draft = { pose: [{ index: 0 }, { index: 1 }, { index: 2 }] };

    const { tasks } = await service.submitBatch(undefined, JSON.stringify(draft));

    expect(tasks).toHaveLength(3);
    await Promise.all(tasks.map(({ taskId }) => waitStatus(taskId, 'done')));
    expect(generateMock).toHaveBeenCalledTimes(3);

    const calls = generateMock.mock.calls as Array<[UploadFile | undefined, string]>;
    const anchorBuffer = calls[1][0]?.buffer;
    expect(anchorBuffer?.toString('base64')).toBe('YW5jaG9y');
    expect(calls[1][0]?.buffer.equals(anchorBuffer!)).toBe(true);
    expect(calls[2][0]?.buffer.equals(anchorBuffer!)).toBe(true);
  });

  it('批量姿势任务：首张锚点失败时停止剩余任务', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockRejectedValue(new Error('生图失败'));
    const draft = { pose: [{ index: 0 }, { index: 1 }, { index: 2 }] };

    const { tasks } = await service.submitBatch(undefined, JSON.stringify(draft));

    await Promise.all(tasks.map(({ taskId }) => waitStatus(taskId, 'error')));
    expect(generateMock).toHaveBeenCalledTimes(1);
    expect(service.get(tasks[0].taskId)?.error).toBe('生图失败');
    expect(service.get(tasks[1].taskId)?.error).toContain('锚点');
    expect(service.get(tasks[2].taskId)?.error).toContain('锚点');
  });
});
