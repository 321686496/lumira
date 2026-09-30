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
  let config: { get: jest.Mock };

  function build(concurrency = 2) {
    release = [];
    config = { get: jest.fn(async () => ({ configured: true, jobConcurrency: concurrency })) };
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
      config as never,
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
    expect(pipeline.requestStop).toHaveBeenCalledWith('a');
  });

  it('stop：requestStop 返回 false 时不谎报成功，如实回报持久化状态', async () => {
    const queue = build(1);
    await queue.enqueue('a');
    pipeline.requestStop.mockReturnValue(false);
    store.findJob = jest.fn(async () => row('a', { status: 'running' }));
    await expect(queue.stop('a')).resolves.toEqual({ stopped: false, status: 'running' });
    expect(store.updateJob).not.toHaveBeenCalledWith('a', expect.objectContaining({ status: 'stopped' }));
  });

  it('FIFO：有空位但已有人排队时，新任务不得插队（排队尾，由出队按序拉起）', async () => {
    const queue = build(1);
    await queue.enqueue('a'); // running
    await queue.enqueue('b'); // waiting=[b]
    expect(pipeline.startJob).toHaveBeenCalledTimes(1);

    // 并发上限被调高（AI 设置改动）后出现空位，但 a 仍占位、b 仍排队
    config.get.mockResolvedValue({ configured: true, jobConcurrency: 2 });

    await expect(queue.enqueue('c')).resolves.toEqual({ status: 'queued', queuePos: 1 });
    // 新任务 c 不得先于 b 开跑：本次被拉起的是 b
    expect(pipeline.startJob).toHaveBeenCalledTimes(2);
    expect(pipeline.startJob).toHaveBeenLastCalledWith('b');
    expect(pipeline.startJob).not.toHaveBeenCalledWith('c');
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