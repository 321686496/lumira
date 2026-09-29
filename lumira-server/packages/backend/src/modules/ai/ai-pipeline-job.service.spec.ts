// lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts
// job 生命周期与序列化单测：create 快速失败 / get+remove / running 态响应收敛 / since 增量。
// 三阶段与续跑用例见 Task 5 追加。
import { BadRequestException } from '@nestjs/common';
import { AiPipelineJobService } from './ai-pipeline-job.service';
import { AiAnalyzeService } from './ai-analyze.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';

const ANALYZE_RESULT = { draft: { title: '草稿' }, warnings: [], trace: [], raw: {}, research: [] };

describe('AiPipelineJobService（生命周期与序列化）', () => {
  let service: AiPipelineJobService;
  let analyzeMock: jest.Mock;
  let generateMock: jest.Mock;
  let silhouetteMock: jest.Mock;

  beforeEach(() => {
    analyzeMock = jest.fn().mockResolvedValue(ANALYZE_RESULT);
    generateMock = jest.fn().mockResolvedValue({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    silhouetteMock = jest.fn().mockResolvedValue({ image: 'c2ls', mimeType: 'image/png' });
    service = new AiPipelineJobService(
      { analyze: analyzeMock } as unknown as AiAnalyzeService,
      {
        acquireImageSlot: jest.fn().mockResolvedValue(0),
        releaseImageSlot: jest.fn(),
        generate: generateMock,
      } as unknown as AiGenerateImageService,
      { generate: silhouetteMock } as unknown as AiSilhouetteService,
    );
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.restoreAllMocks();
  });

  async function waitStatus(jobId: string, status: string): Promise<void> {
    for (let i = 0; i < 6000; i += 1) {
      if (service.get(jobId)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for job status ${status}`);
  }

  it('create 快速失败：示例图与文字都缺 → 400，且不建 job、不调识别服务', async () => {
    await expect(service.create({ mode: 'auto' })).rejects.toThrow(BadRequestException);
    await expect(service.create({ mode: 'auto', text: '   ' })).rejects.toThrow(BadRequestException);
    expect(analyzeMock).not.toHaveBeenCalled();
  });

  it('get / remove：不存在返回 null；remove 后不可见', async () => {
    analyzeMock.mockImplementation(() => new Promise(() => undefined));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    expect(service.get(jobId)?.id).toBe(jobId);
    service.remove(jobId);
    expect(service.get(jobId)).toBeNull();
    expect(service.get('job_nope')).toBeNull();
  });

  it('serialize：running 态收敛（丢弃 rawResponse、截断长文本、不返回 base64 产物）', async () => {
    analyzeMock.mockImplementation(
      () => new Promise((resolve) => { setTimeout(() => resolve(ANALYZE_RESULT), 40); }),
    );
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    const job = service.get(jobId)!;
    job.events.push({
      seq: 9999, ts: Date.now(), stage: 'analyze', type: 'llm', step: 'analyze', title: '调用模型',
      status: 'running', response: 'a'.repeat(5000), rawResponse: 'b'.repeat(5000),
    });
    job.artifacts.poseFiles = [{ index: 0, base64: 'AAA', mimeType: 'image/png' }];

    const running = service.serialize(job, 0, false);
    expect(running.status).toBe('running');
    const llm = running.events.find((e) => e.type === 'llm')!;
    expect(llm.rawResponse).toBeUndefined();
    expect(llm.response!.length).toBeLessThan(5000);
    expect(running.poseImages).toEqual([]);
    expect(running.draft).toBeNull();

    await waitStatus(jobId, 'done');
    const done = service.serialize(service.get(jobId)!, 0, false);
    expect(done.poseImages).toHaveLength(1);
    expect(done.draft).toEqual({ title: '草稿' });
  });

  it('serialize：since 只返回增量事件；lastSeq 为最大 seq', async () => {
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await waitStatus(jobId, 'done');
    const job = service.get(jobId)!;
    const all = service.serialize(job, 0, false);
    expect(all.events.length).toBeGreaterThan(0);
    expect(all.lastSeq).toBe(job.events[job.events.length - 1]!.seq);

    const since = all.lastSeq - 1;
    const incremental = service.serialize(job, since, false);
    expect(incremental.events.length).toBe(1);
    expect(incremental.events[0]!.seq).toBe(all.lastSeq);
  });
});