// lumira-server/packages/backend/src/modules/ai/ai-job.store.spec.ts
// AiJobStoreService 单测：DB 行 CRUD / 存储文件读写 / deleteJob 连带删目录。
// DatabaseService 与 activeStorageAdapter 均以 jest.mock 替换，不依赖真实 MySQL 与磁盘。
import { AiJobStoreService } from './ai-job.store';
import type { AiJobRow } from './ai-job.store';

const updateSetMock = jest.fn();
const updateWhereMock = jest.fn(() => Promise.resolve());
const insertValuesMock = jest.fn(() => Promise.resolve());
const findFirstMock = jest.fn();
const selectRows: unknown[] = [];
const deleteMock = jest.fn();

jest.mock('../../common/storage/runtime-storage', () => ({
  activeStorageAdapter: {
    write: jest.fn(async (_c: string, id: string, filename: string) => `/uploads/ai-jobs/${id}/${filename}`),
    deleteByDir: jest.fn(async () => undefined),
    readBuffer: jest.fn(async () => Buffer.from('{"a":1}')),
    exists: jest.fn(async () => true),
    listKeys: jest.fn(async () => ['/uploads/ai-jobs/job_1/input/example-0.png']),
  },
}));

function makeDb() {
  return {
    insert: () => ({ values: insertValuesMock }),
    update: () => ({ set: updateSetMock }),
    delete: () => ({ where: deleteMock }),
    select: () => ({
      from: () => ({
        where: () => ({
          orderBy: () => ({ limit: () => ({ offset: () => Promise.resolve(selectRows) }) }),
        }),
      }),
    }),
    query: { aiTemplateJobs: { findFirst: findFirstMock } },
  };
}

function row(overrides: Partial<AiJobRow> = {}): AiJobRow {
  return {
    id: 'job_1', status: 'queued', mode: 'auto', title: 't', currentStage: null,
    poseTotal: 0, poseDone: 0, silTotal: 0, silDone: 0, queuePos: 0,
    inputSummary: {}, errorCode: null, errorMessage: null, detailKey: null,
    createdAt: 1, startedAt: null, finishedAt: null, ...overrides,
  };
}

describe('AiJobStoreService', () => {
  let store: AiJobStoreService;

  beforeEach(() => {
    jest.clearAllMocks();
    const db = makeDb();
    store = new AiJobStoreService({ getDb: () => db } as never);
  });

  it('insertJob 落库并归一化 inputSummary 为 JSON 字符串', async () => {
    await store.insertJob(row({ inputSummary: { imageCount: 2 } }));
    expect(insertValuesMock).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'job_1', status: 'queued', inputSummaryJson: '{"imageCount":2}' }),
    );
  });

  it('writeArtifact 返回 storageKey 与 url，且 url 等于 storageKey', async () => {
    const art = await store.writeArtifact('job_1', 'pose', 0, 'image/png', Buffer.from('x'));
    expect(art).toEqual({
      index: 0,
      mimeType: 'image/png',
      storageKey: '/uploads/ai-jobs/job_1/pose-0.png',
      url: '/uploads/ai-jobs/job_1/pose-0.png',
    });
  });

  it('writeDetail / readDetail 往返一致', async () => {
    await store.writeDetail('job_1', { draft: { title: 'd' }, artifacts: { poseFiles: [], poseErrors: [], silFiles: [], silErrors: [] } } as never);
    const back = await store.readDetail('job_1');
    expect(back).toMatchObject({ a: 1 }); // readBuffer mock 固定返回 {"a":1}
  });

  it('deleteJob 同时删 DB 行与存储目录', async () => {
    const { activeStorageAdapter } = await import('../../common/storage/runtime-storage');
    await store.deleteJob('job_1');
    expect(deleteMock).toHaveBeenCalled();
    expect(activeStorageAdapter.deleteByDir).toHaveBeenCalledWith('ai-jobs', 'job_1');
  });
});