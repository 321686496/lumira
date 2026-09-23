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
    for (let i = 0; i < 12000; i++) {
      if (service.get(id)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for status ${status}`);
  }

  async function waitBatchStatus(batchId: string, status: string): Promise<void> {
    for (let i = 0; i < 12000; i++) {
      if (service.getBatch(batchId)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for batch status ${status}`);
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
  }, 15000);

  it('get 不存在的 taskId 返回 null', () => {
    expect(service.get('img_nope')).toBeNull();
  });

  it('批量姿势任务：返回单个 batchId，进度 indices 完整，首张用锚点结果启动剩余任务', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockImplementation(async (_reference, metaJson: string) => {
      const meta = JSON.parse(metaJson);
      if (meta.consistency?.anchor !== 'first') {
        return { base64: 'YW5jaG9y', mimeType: 'image/png' };
      }
      return { base64: 'cG9zZQ==', mimeType: 'image/png' };
    });
    const draft = { pose: [{ index: 0 }, { index: 1 }, { index: 2 }] };

    const { batchId } = await service.submitBatch(undefined, JSON.stringify(draft));
    expect(batchId).toMatch(/^bimg_/);

    const initial = service.getBatch(batchId);
    expect(initial?.total).toBe(3);
    expect(initial?.results.map((r) => r.index)).toEqual([0, 1, 2]);

    await waitBatchStatus(batchId, 'done');
    const done = service.getBatch(batchId);
    expect(done?.completed).toBe(3);
    expect(done?.status).toBe('done');
    expect(done?.results.every((r) => r.status === 'done' && r.error === undefined)).toBe(true);
    expect(generateMock).toHaveBeenCalledTimes(3);

    const calls = generateMock.mock.calls as Array<[UploadFile | undefined, string]>;
    const anchorBuffer = calls[1][0]?.buffer;
    expect(anchorBuffer?.toString('base64')).toBe('YW5jaG9y');
    expect(calls[1][0]?.buffer.equals(anchorBuffer!)).toBe(true);
    expect(calls[2][0]?.buffer.equals(anchorBuffer!)).toBe(true);
  });

  it('批量姿势任务：首张锚点失败时停止后续（批次 done 且带汉字错误）', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockRejectedValue(new Error('生图失败'));
    const draft = { pose: [{ index: 0 }, { index: 1 }, { index: 2 }] };

    const { batchId } = await service.submitBatch(undefined, JSON.stringify(draft));

    await waitBatchStatus(batchId, 'done');
    const results = service.getBatch(batchId)?.results ?? [];
    expect(generateMock).toHaveBeenCalledTimes(1);
    expect(results[0].error).toBe('生图失败');
    expect(results[1].error).toContain('锚点');
    expect(results[2].error).toContain('锚点');
  });

  it('批量姿势任务：限流等瞬时失败自动重试', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock
      .mockResolvedValueOnce({ base64: 'YW5jaG9y', mimeType: 'image/png' })
      .mockRejectedValueOnce(new Error('AI 上游错误（HTTP 429）：rate limited'))
      .mockResolvedValue({ base64: 'cG9zZQ==', mimeType: 'image/png' });
    const draft = { pose: [{ index: 0 }, { index: 1 }] };

    const { batchId } = await service.submitBatch(undefined, JSON.stringify(draft));

    await waitBatchStatus(batchId, 'done');
    expect(generateMock).toHaveBeenCalledTimes(3);
  });

  it('批量姿势任务：「生图服务返回内容为空」纳入可重试并最终成功', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock
      .mockResolvedValueOnce({ base64: 'YW5jaG9y', mimeType: 'image/png' })
      .mockRejectedValueOnce(new Error('生图服务返回内容为空'))
      .mockResolvedValue({ base64: 'cG9zZQ==', mimeType: 'image/png' });
    const draft = { pose: [{ index: 0 }, { index: 1 }] };

    const { batchId } = await service.submitBatch(undefined, JSON.stringify(draft));

    await waitBatchStatus(batchId, 'done');
    const results = service.getBatch(batchId)?.results ?? [];
    expect(results.every((r) => r.status === 'done' && r.error === undefined)).toBe(true);
    expect(generateMock).toHaveBeenCalledTimes(3);
  });

  it('research 全链路透传：单任务 submit 与批量锚点/依赖任务均收到 research', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockResolvedValue({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    const researchJson = JSON.stringify([{ source: 'sogou', title: '千金风', snippet: '流行' }]);

    const { taskId } = await service.submit(undefined, '{}', null, researchJson);
    await waitStatus(taskId, 'done');
    expect(generateMock).toHaveBeenCalledTimes(1);
    expect(generateMock.mock.calls[0][3]).toBe(researchJson);

    const draft = { pose: [{ index: 0 }, { index: 1 }] };
    const { batchId } = await service.submitBatch(undefined, JSON.stringify(draft), null, researchJson);
    await waitBatchStatus(batchId, 'done');
    expect(generateMock).toHaveBeenCalledTimes(3); // 1 单任务 + 锚点 + 依赖
    for (const call of generateMock.mock.calls) {
      expect(call[3]).toBe(researchJson); // 识别阶段研究结果原样到达生图服务
    }
  });
});
