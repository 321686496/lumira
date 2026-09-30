// lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.spec.ts
// 队列调度单测：并发上限 / FIFO 顺序 / queue_pos / 停止 / 重启恢复。
import { AiJobQueueService } from './ai-job-queue.service';
import type { AiJobStoreService, AiJobRow } from './ai-job.store';

function row(id: string, over: Partial<AiJobRow> = {}): AiJobRow {
  return {
    id, status: 'queued', mode: 'auto', title: id, currentStage: null,
    poseTotal: 0, poseDone: 0, silTotal: 0, silDone: 0, queuePos: 0,
    inputSummary: {}, errorCode: null, errorMessage: null, detailKey: null,
    createdAt: 1, startedAt: null, finishedAt: null, ...over,
  };
}

describe('AiJobQueueService', () => {
  let store: jest.Mocked<Pick<AiJobStoreService,
    'updateJob' | 'findJob' | 'listQueued' | 'setQueuePositions'>>;
  let pipeline: jest.Mocked<{
    startJob: (id: string) => Promise<void>;
    requestStop: (id: string) => boolean;
    hydrate: (id: string) => Promise<boolean>;
    prepareResume: (id: string) => Promise<{ stages: string[]; onlyIndexes: Record<string, number[]> } | null>;
  }>;
  let release: Array<() => void>;

  function build(concurrency = 2) {
    release = [];
    pipeline = {
      startJob: jest.fn(
        () => new Promise<void>((resolve) => release.push(resolve)),
      ),
      requestStop: jest.fn(() => true),
      hydrate: jest.fn(async () => true),
      prepareResume: jest.fn(async () => ({ stages: ['analyze'], onlyIndexes: {} })),
    };
    const queue = new AiJobQueueService(
      store as never,
      { get: jest.fn(async () => ({ configured: true, jobConcurrency: concurrency })) } as never,
      pipeline as never,
    );
    return queue;
  }

  beforeEach(() => {
    store = {
      updateJob: jest.fn(async () => undefined),
      findJob: jest.fn(async (id: string) => row(id)),
      listQueued: jest.fn(async () => []),
      setQueuePositions: jest.fn(async () => undefined),
    };
  });

  it('并发上限 2：第 3 个任务排队，开跑的前两个置 running', async () => {
    const queue = build(2);
    await expect(queue.enqueue('a')).resolves.toEqual({ status: 'running', queuePos: 0 });
    await expect(queue.enqueue('b')).resolves.toEqual({ status: 'running', queuePos: 0 });
    await expect(queue.enqueue('c')).resolves.toEqual({ status: 'queued', queuePos: 1 });
    expect(store.updateJob).toHaveBeenCalledWith('c', { status: 'queued', queuePos: 1 });
  });

  it('任一任务结束后自动出队下一个', async () => {
    const queue = build(1);
    await queue.enqueue('a');
    await queue.enqueue('b');
    expect(pipeline.startJob).toHaveBeenCalledTimes(1);
    release[0]!();
    await new Promise((r) => setImmediate(r));
    expect(pipeline.startJob).toHaveBeenCalledTimes(2);
    expect(pipeline.startJob).toHaveBeenLastCalledWith('b');
  });

  it('stop：running 任务置停止标记并返回 stopped', async () => {
    const queue = build(1);
    await queue.enqueue('a');
    await expect(queue.stop('a')).resolves.toEqual({ stopped: true, status: 'stopped' });
  });

  it('onModuleInit：queued 重新入队，running 置 interrupted', async () => {
    store.listQueued = jest.fn(async () => [row('q1')]);
    store.findJob = jest.fn(async (id: string) =>
      id === 'q1' ? row('q1') : row(id, { status: 'running' }),
    );
    const queue = build(1);
    const markInterrupted = jest.fn(async () => undefined);
    (queue as unknown as { markInterrupted: typeof markInterrupted }).markInterrupted = markInterrupted;
    await queue.onModuleInit();
    expect(markInterrupted).toHaveBeenCalledWith('running');
    expect(pipeline.startJob).toHaveBeenCalledWith('q1');
  });
});