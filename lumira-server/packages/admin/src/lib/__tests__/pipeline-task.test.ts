// src/lib/__tests__/pipeline-task.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('@/actions/ai', () => ({
  aiPipelineStartAction: vi.fn(),
  aiPipelineStatusAction: vi.fn(),
  aiPipelineResumeAction: vi.fn(),
  aiPipelineCancelAction: vi.fn(),
}));

import { aiPipelineStatusAction } from '@/actions/ai';
import type {
  AiBatchImageTraceEvent,
  AiPipelineEvent,
  AiPipelineStatusResult,
  AiTraceEvent,
} from '@/types/admin';
import {
  PipelinePollError,
  classifyPipelineError,
  currentPipelineStage,
  isRetryablePipelineError,
  pipelineFiles,
  pollPipelineJob,
  poseProgressFromEvents,
  toAnalyzeDetail,
  toPoseEvents,
  toRecogEvents,
  withRetry,
} from '../pipeline-task';

const statusMock = vi.mocked(aiPipelineStatusAction);

/** 造一个最小可用的 AiPipelineStatusResult */
function mkStatus(over: Partial<AiPipelineStatusResult> = {}): AiPipelineStatusResult {
  return {
    jobId: 'job_1',
    status: 'running',
    mode: 'auto',
    stages: {
      analyze: { status: 'pending' },
      image: { status: 'pending' },
      silhouette: { status: 'pending' },
    },
    error: null,
    events: [],
    lastSeq: 0,
    draft: null,
    warnings: [],
    trace: [],
    raw: null,
    research: [],
    researchBrief: null,
    researchImages: [],
    researchVision: null,
    poseImages: [],
    poseErrors: [],
    silhouetteImages: [],
    silhouetteErrors: [],
    ...over,
  };
}

function mkEvent(over: Partial<AiPipelineEvent>): AiPipelineEvent {
  return {
    seq: 1,
    ts: 1,
    type: 'note',
    step: 'pose',
    title: 'x',
    status: 'running',
    stage: 'image',
    ...over,
  };
}

describe('classifyPipelineError', () => {
  it('按后端/网关稳定文案分类', () => {
    expect(classifyPipelineError('API_ERROR: 404 AI pipeline job not found')).toBe('job_missing');
    expect(classifyPipelineError('API_ERROR: 413 Payload Too Large')).toBe('payload_too_large');
    expect(classifyPipelineError('无法连接后端服务，请检查网络与后端状态')).toBe('network');
    expect(classifyPipelineError('请求后端超时（300s），可能后端处理较慢或网络不通，请稍后重试')).toBe('network');
    expect(classifyPipelineError('API_ERROR: 400 封面图片不能超过 5MB')).toBe('invalid_input');
    expect(classifyPipelineError('莫名其妙')).toBe('internal');
  });
});

describe('isRetryablePipelineError', () => {
  it('传输/上游类可重试；失效/入参类不可', () => {
    expect(isRetryablePipelineError('upstream_timeout')).toBe(true);
    expect(isRetryablePipelineError('network')).toBe(true);
    expect(isRetryablePipelineError('poll_timeout')).toBe(true);
    expect(isRetryablePipelineError('job_missing')).toBe(false);
    expect(isRetryablePipelineError('payload_too_large')).toBe(false);
    expect(isRetryablePipelineError('invalid_input')).toBe(false);
  });
});

describe('withRetry', () => {
  it('可重试错误按退避重试后成功', async () => {
    let calls = 0;
    const fn = vi.fn(async () => {
      calls += 1;
      if (calls < 3) throw new PipelinePollError('无法连接后端服务，请检查网络与后端状态');
      return 'ok';
    });
    await expect(
      withRetry(fn, { attempts: 4, delaysMs: [1, 1, 1, 1] }),
    ).resolves.toBe('ok');
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('不可重试错误立即抛出', async () => {
    const fn = vi.fn(async () => {
      throw new PipelinePollError('API_ERROR: 404 AI pipeline job not found');
    });
    await expect(withRetry(fn, { attempts: 4, delaysMs: [1] })).rejects.toThrow(
      'API_ERROR: 404',
    );
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('达到上限后抛最后一次错误', async () => {
    const fn = vi.fn(async () => {
      throw new PipelinePollError('无法连接后端服务，请检查网络与后端状态');
    });
    await expect(withRetry(fn, { attempts: 3, delaysMs: [1, 1, 1] })).rejects.toThrow(
      '无法连接后端服务',
    );
    expect(fn).toHaveBeenCalledTimes(3);
  });
});

describe('pollPipelineJob', () => {
  beforeEach(() => statusMock.mockReset());

  it('单次查询抖动不中断：重试后继续轮询到 done', async () => {
    statusMock
      .mockRejectedValueOnce(new Error('无法连接后端服务，请检查网络与后端状态'))
      .mockResolvedValueOnce(
        mkStatus({
          status: 'done',
          stages: {
            analyze: { status: 'done' },
            image: { status: 'done' },
            silhouette: { status: 'done' },
          },
          draft: { name: 'd' },
          poseImages: [{ index: 0, base64: 'AAA', mimeType: 'image/png' }],
        }),
      );
    const res = await pollPipelineJob('job_1', {
      intervalMs: 1,
      timeoutMs: 2000,
      retryDelaysMs: [1, 1, 1, 1],
    });
    expect(res.status).toBe('done');
    expect(res.draft).toEqual({ name: 'd' });
  });

  it('job 不存在（404）→ 抛 PipelinePollError 且 code=job_missing', async () => {
    // 真实链路：server action 捕获 api 抛错后返回 { error }（不抛出），故此处 mock resolve
    statusMock.mockResolvedValue({ error: 'API_ERROR: 404 AI pipeline job not found' });
    await expect(
      pollPipelineJob('job_x', { intervalMs: 1, timeoutMs: 500, retryDelaysMs: [1] }),
    ).rejects.toMatchObject({ code: 'job_missing' });
  });

  it('job 阶段失败（status=error）时返回结果而非抛错（由调用方展示中断详情）', async () => {
    statusMock.mockResolvedValue(
      mkStatus({
        status: 'error',
        stages: {
          analyze: { status: 'done' },
          image: { status: 'error' },
          silhouette: { status: 'pending' },
        },
        error: {
          code: 'upstream_timeout',
          stage: 'image',
          message: '共 1/3 张姿势图生成失败（#2）',
          hint: '点「继续」重试该阶段',
          at: 1,
        },
      }),
    );
    const res = await pollPipelineJob('job_1', { intervalMs: 1, timeoutMs: 2000 });
    expect(res.status).toBe('error');
    expect(res.error?.code).toBe('upstream_timeout');
  });

  it('增量事件按 seq 累积并回调', async () => {
    statusMock
      .mockResolvedValueOnce(mkStatus({ events: [mkEvent({ seq: 1 })], lastSeq: 1 }))
      .mockResolvedValueOnce(mkStatus({ events: [mkEvent({ seq: 2 })], lastSeq: 2 }))
      .mockResolvedValueOnce(mkStatus({ status: 'done', events: [], lastSeq: 2 }));
    const seen: number[] = [];
    const res = await pollPipelineJob('job_1', {
      intervalMs: 1,
      timeoutMs: 2000,
      onEvents: (evs) => seen.push(evs.length),
    });
    expect(res.status).toBe('done');
    expect(seen[seen.length - 1]).toBe(2);
    // 第二次查询带 since=1（增量）
    expect(statusMock.mock.calls[1]?.[1]).toBe(1);
  });

  it('终态为全量事件：整体替换运行期收敛版（截断正文被完整版覆盖）', async () => {
    const truncated = mkEvent({ seq: 1, stage: 'analyze', response: 'a'.repeat(2000) + '…（已截断，原长 5000 字）' });
    statusMock
      .mockResolvedValueOnce(mkStatus({ events: [truncated], lastSeq: 1 }))
      .mockResolvedValueOnce(
        mkStatus({
          status: 'done',
          events: [
            mkEvent({ seq: 1, stage: 'analyze', response: 'a'.repeat(5000), rawResponse: 'raw' }),
            mkEvent({ seq: 2, stage: 'image' }),
          ],
          lastSeq: 2,
        }),
      );
    const snapshots: AiPipelineEvent[][] = [];
    const res = await pollPipelineJob('job_1', {
      intervalMs: 1,
      timeoutMs: 2000,
      onEvents: (evs) => snapshots.push(evs.slice()),
    });
    expect(res.status).toBe('done');
    const last = snapshots[snapshots.length - 1]!;
    expect(last.map((e) => e.seq)).toEqual([1, 2]);
    expect(last[0]!.response!.length).toBe(5000);
    expect(last[0]!.rawResponse).toBe('raw');
  });
});

describe('事件转换', () => {
  it('toRecogEvents 只留 analyze 阶段', () => {
    const events: AiPipelineEvent[] = [
      mkEvent({ seq: 1, stage: 'analyze', step: 'describe' }),
      mkEvent({ seq: 2, stage: 'image' }),
      mkEvent({ seq: 3, stage: 'silhouette' }),
    ];
    const out: AiTraceEvent[] = toRecogEvents(events);
    expect(out.map((e) => e.seq)).toEqual([1]);
  });

  it('toPoseEvents 保留 index、fail→error、kind 由 type 推断', () => {
    const events: AiPipelineEvent[] = [
      mkEvent({ seq: 1, type: 'note', index: 0, status: 'running' }),
      mkEvent({ seq: 2, type: 'llm', index: 0, status: 'fail', callId: 'c1' }),
      mkEvent({ seq: 3, type: 'note', index: 1, status: 'done', prompt: 'p' }),
    ];
    const out: AiBatchImageTraceEvent[] = toPoseEvents(events);
    expect(out.map((e) => e.index)).toEqual([0, 0, 1]);
    expect(out.map((e) => e.kind)).toEqual(['pose', 'llm', 'pose']);
    expect(out.map((e) => e.status)).toEqual(['running', 'error', 'done']);
    expect(out[2]!.prompt).toBe('p');
  });

  it('poseProgressFromEvents 统计完成/进行中/总数', () => {
    const events: AiPipelineEvent[] = [
      mkEvent({ seq: 1, index: 0, status: 'done' }),
      mkEvent({ seq: 2, index: 1, status: 'running' }),
      mkEvent({ seq: 3, index: 2, status: 'running' }),
      mkEvent({ seq: 4, index: 0, type: 'llm', status: 'done' }),
    ];
    expect(poseProgressFromEvents(events)).toEqual({ current: 2, total: 3, status: 'running' });
    expect(poseProgressFromEvents([])).toBeNull();
  });

  it('currentPipelineStage 优先 running，其次 error，再次最后 done', () => {
    expect(
      currentPipelineStage(
        mkStatus({
          stages: {
            analyze: { status: 'done' },
            image: { status: 'running' },
            silhouette: { status: 'pending' },
          },
        }),
      ),
    ).toBe('image');
    expect(
      currentPipelineStage(
        mkStatus({
          stages: {
            analyze: { status: 'done' },
            image: { status: 'error' },
            silhouette: { status: 'pending' },
          },
        }),
      ),
    ).toBe('image');
    expect(
      currentPipelineStage(
        mkStatus({
          stages: {
            analyze: { status: 'done' },
            image: { status: 'pending' },
            silhouette: { status: 'pending' },
          },
        }),
      ),
    ).toBe('analyze');
  });

  it('toAnalyzeDetail 把 job 结果映射成识别详情结构', () => {
    const detail = toAnalyzeDetail(
      mkStatus({
        status: 'done',
        draft: { name: 'd' },
        warnings: ['w'],
        events: [mkEvent({ seq: 1, stage: 'analyze', step: 'describe' })],
        lastSeq: 1,
      }),
    );
    expect(detail.status).toBe('done');
    expect(detail.draft).toEqual({ name: 'd' });
    expect(detail.events?.map((e) => e.seq)).toEqual([1]);
  });

  it('pipelineFiles 按 index 排序并转 File', () => {
    const files = pipelineFiles([
      { index: 1, base64: btoa('b'), mimeType: 'image/png' },
      { index: 0, base64: btoa('a'), mimeType: 'image/png' },
    ]);
    expect(files.map((f) => f.index)).toEqual([0, 1]);
    expect(files[0]!.file).toBeInstanceOf(File);
  });
});