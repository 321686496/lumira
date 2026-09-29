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
    // 终态返回完整正文：运行期收到的收敛版（截断 + 丢 rawResponse）必须被完整版覆盖
    const doneLlm = done.events.find((e) => e.type === 'llm')!;
    expect(doneLlm.response!.length).toBe(5000);
    expect(doneLlm.rawResponse).toBe('b'.repeat(5000));
  });

  it('serialize：running 态按 since 只返回增量事件；lastSeq 为最大 seq', async () => {
    analyzeMock.mockImplementation(() => new Promise(() => undefined));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    const job = service.get(jobId)!;
    // 流水线启动时可能已追加事件，故以现有长度为基准续编 seq
    const base = job.events.length;
    for (const i of [1, 2, 3]) {
      job.events.push({
        seq: base + i, ts: base + i, stage: 'analyze', type: 'note', step: 'analyze', title: `e${base + i}`, status: 'done',
      });
    }
    const all = service.serialize(job, 0, false);
    expect(all.status).toBe('running');
    expect(all.events.map((e) => e.seq)).toEqual(job.events.map((e) => e.seq));
    expect(all.lastSeq).toBe(base + 3);

    const incremental = service.serialize(job, base + 2, false);
    expect(incremental.events.map((e) => e.seq)).toEqual([base + 3]);
  });

  it('serialize：终态忽略 since，一次性返回全量事件（供前端覆盖收敛版）', async () => {
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await waitStatus(jobId, 'done');
    const job = service.get(jobId)!;
    const all = service.serialize(job, 0, false);
    expect(all.events.length).toBeGreaterThan(0);
    expect(all.lastSeq).toBe(job.events[job.events.length - 1]!.seq);

    // 即使带 since（= lastSeq），终态仍返回全量，前端才能整体替换累积的收敛版
    const withSince = service.serialize(job, all.lastSeq, false);
    expect(withSince.events.map((e) => e.seq)).toEqual(all.events.map((e) => e.seq));
  });
});

describe('AiPipelineJobService（续跑：image 阶段锚点失败后剪影补齐）', () => {
  let service: AiPipelineJobService;
  let analyzeMock: jest.Mock;
  let generateMock: jest.Mock;
  let silhouetteMock: jest.Mock;

  beforeEach(() => {
    analyzeMock = jest.fn().mockResolvedValue({
      draft: { pose: [{ index: 0 }, { index: 1 }] },
      warnings: [],
      trace: [],
      raw: {},
      research: [],
    });
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

  it('image 阶段锚点（index 0）失败 → resume 后全部姿势图与全部剪影都最终生成、job 状态为 done', async () => {
    let resumePhase = false;
    generateMock.mockImplementation((_refs: unknown, metaJson: string) => {
      const meta = JSON.parse(metaJson) as { pose?: { index?: number } };
      if (meta.pose?.index === 0 && !resumePhase) {
        // 非可重试错误：锚点首次生成即失败（不触发 4 次有界重试），命中「锚点不可用」分支
        return Promise.reject(new Error('生图失败：HTTP 400 Bad Request'));
      }
      return Promise.resolve({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    });

    const { jobId } = await service.create({ text: '文字', mode: 'auto' });
    await waitStatus(jobId, 'error');
    const failed = service.get(jobId)!;
    expect(failed.stages.image.status).toBe('error');
    expect(failed.artifacts.poseFiles).toHaveLength(0);

    resumePhase = true;
    const r = await service.resume(jobId);
    expect(r?.resumed).toBe(true);
    await waitStatus(jobId, 'done');

    const job = service.get(jobId)!;
    expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0, 1]);
    // 核心回归点：修复前这里会得到 []（用重跑前的空 poseFiles 算死剪影下标 → 一张剪影都不生成）
    expect(job.artifacts.silFiles.map((f) => f.index)).toEqual([0, 1]);
    expect(job.stages.silhouette.status).toBe('done');
    expect(job.status).toBe('done');
  });
});

describe('AiPipelineJobService（三阶段与续跑）', () => {
  let service: AiPipelineJobService;
  let analyzeMock: jest.Mock;
  let generateMock: jest.Mock;
  let silhouetteMock: jest.Mock;

  const DRAFT = { pose: [{ index: 0 }, { index: 1 }] };

  beforeEach(() => {
    analyzeMock = jest.fn().mockResolvedValue({
      draft: DRAFT, warnings: [], trace: [], raw: {}, research: [], brief: null, researchVision: null,
    });
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
    for (let i = 0; i < 12000; i += 1) {
      if (service.get(jobId)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for job status ${status}`);
  }

  it('auto：识别 → 2 张姿势图 → 2 张剪影 → done，产物齐备且事件带 stage/index', async () => {
    const { jobId } = await service.create({ text: '文字描述', mode: 'auto' });
    await waitStatus(jobId, 'done');
    const job = service.get(jobId)!;
    expect(job.stages.analyze.status).toBe('done');
    expect(job.stages.image.status).toBe('done');
    expect(job.stages.silhouette.status).toBe('done');
    expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0, 1]);
    expect(job.artifacts.silFiles.map((f) => f.index)).toEqual([0, 1]);
    // 首张锚点先用用户参考图（此处无参考图 → undefined），依赖张以锚点为参考
    expect(generateMock).toHaveBeenCalledTimes(2);
    expect(job.events.some((e) => e.stage === 'image' && e.index === 1 && e.title === '姿势图 #2 完成')).toBe(true);
    expect(job.events.some((e) => e.stage === 'silhouette' && e.index === 0)).toBe(true);
    // seq 严格递增 1..n
    expect(job.events.map((e) => e.seq)).toEqual(job.events.map((_, i) => i + 1));
  });

  it(
    'auto：单张姿势图失败 → image 阶段 error，中断详情带失败下标且不继续到剪影',
    async () => {
      generateMock.mockImplementation((_refs: unknown, metaJson: string) => {
        const meta = JSON.parse(metaJson) as { pose?: { index?: number } };
        if (meta.pose?.index === 1) return Promise.reject(new Error('AI 请求超时，请稍后重试'));
        return Promise.resolve({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
      });

      const { jobId } = await service.create({ text: '文字描述', mode: 'auto' });
      await waitStatus(jobId, 'error');
      const job = service.get(jobId)!;
      expect(job.error?.stage).toBe('image');
      expect(job.error?.code).toBe('upstream_timeout');
      expect(job.error?.failedIndexes).toEqual([1]);
      expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0]);
      expect(job.stages.silhouette.status).toBe('pending');
      expect(silhouetteMock).not.toHaveBeenCalled();
    },
    30_000,
  );

  it(
    'resume：image 失败后只补失败张，成功后继续跑剪影到 done',
    async () => {
      generateMock.mockImplementation((_refs: unknown, metaJson: string) => {
        const meta = JSON.parse(metaJson) as { pose?: { index?: number } };
        if (meta.pose?.index === 1) return Promise.reject(new Error('AI 请求超时，请稍后重试'));
        return Promise.resolve({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
      });

      const { jobId } = await service.create({ text: '文字描述', mode: 'auto' });
      await waitStatus(jobId, 'error');
      const callsBeforeResume = generateMock.mock.calls.length;

      generateMock.mockResolvedValue({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
      const resumed = await service.resume(jobId);
      expect(resumed).toEqual({ resumed: true, status: 'running' });

      await waitStatus(jobId, 'done');
      const job = service.get(jobId)!;
      // 仅补失败张：resume 后只多调了 1 次生图（未重跑已成功的 #1）
      expect(generateMock.mock.calls.length - callsBeforeResume).toBe(1);
      expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0, 1]);
      expect(job.artifacts.silFiles.map((f) => f.index)).toEqual([0, 1]);
    },
    30_000,
  );

  it('resume：running 的 job 不重跑（前端重连即可）；不存在的 jobId 返回 null', async () => {
    analyzeMock.mockImplementation(() => new Promise(() => undefined));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await expect(service.resume(jobId)).resolves.toEqual({ resumed: false, status: 'running' });
    await expect(service.resume('job_nope')).resolves.toBeNull();
  });

  it('识别失败：bad request → invalid_input 中断，分析服务被调用一次', async () => {
    analyzeMock.mockRejectedValue(new BadRequestException('示例图不能超过 8MB（当前 9.00MB）'));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await waitStatus(jobId, 'error');
    const job = service.get(jobId)!;
    expect(job.error?.code).toBe('invalid_input');
    expect(job.error?.stage).toBe('analyze');
    expect(job.error?.message).toContain('8MB');
  });
});