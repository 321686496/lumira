// lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts
// ai-config.service 单测：网页爬取开关（crawlEnabled / crawlMaxPerSession）的读取映射 / 保存归一 / 越界校验
// 复用 ai-config.service.spec.ts 既有的 row / readonlyDb / writableDb 构造风格

import { AiConfigService } from './ai-config.service';
import { DatabaseService } from '../../database/database.service';

/** DB 行夹具（列名对齐 drizzle schema camelCase 映射） */
function row(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    textModel: null,
    enabled: 1,
    createdAt: 1,
    updatedAt: 1,
    ...overrides,
  };
}

/** 只读 db mock（get / getActiveConfig 用）：query.aiProviderConfig.findFirst 恒返回 row */
function readonlyDb(r: Record<string, unknown> | undefined) {
  return {
    getDb: () => ({ query: { aiProviderConfig: { findFirst: async () => r } } }),
  } as unknown as DatabaseService;
}

/** 可写 db mock（save 用）：findFirst 状态化；insert/update 后同步内存行（save 末尾 get() 重新读取） */
function writableDb(existing: Record<string, unknown> | undefined) {
  let current = existing;
  const insertValues = jest.fn(async (v: Record<string, unknown>) => {
    current = { ...row(), ...v };
  });
  const updateWhere = jest.fn(async () => undefined);
  const updateSet = jest.fn((patch: Record<string, unknown>) => {
    current = { ...(current as Record<string, unknown>), ...patch };
    return { where: updateWhere };
  });
  return {
    service: new AiConfigService({
      getDb: () => ({
        query: { aiProviderConfig: { findFirst: async () => current } },
        insert: () => ({ values: insertValues }),
        update: () => ({ set: updateSet }),
      }),
    } as unknown as DatabaseService),
    insertValues,
    updateSet,
  };
}

describe('AiConfigService — 网页爬取开关', () => {
  afterEach(() => jest.restoreAllMocks());

  it('get() 映射 crawlEnabled / crawlMaxPerSession', async () => {
    const service = new AiConfigService(readonlyDb(row({ crawlEnabled: 1, crawlMaxPerSession: 5 })));
    const view = await service.get();
    expect(view).toMatchObject({ configured: true, crawlEnabled: true, crawlMaxPerSession: 5 });
  });

  it('get() 缺列（老数据 / 未选列）→ crawlEnabled=false、crawlMaxPerSession 回退 3', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const view = await service.get();
    expect(view).toMatchObject({ crawlEnabled: false, crawlMaxPerSession: 3 });
  });

  it('getActiveConfig() 暴露 crawl 配置', async () => {
    const service = new AiConfigService(readonlyDb(row({ crawlEnabled: 1, crawlMaxPerSession: 5 })));
    const cfg = await service.getActiveConfig();
    expect(cfg.crawl).toEqual({ enabled: true, maxPerSession: 5 });
  });

  it('getActiveConfig() 缺列 → crawl 默认关闭、上限 3', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const cfg = await service.getActiveConfig();
    expect(cfg.crawl).toEqual({ enabled: false, maxPerSession: 3 });
  });

  it('save() 越界次数上限（>6）→ 400', async () => {
    const { service } = writableDb(row());
    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlMaxPerSession: 9,
      } as never),
    ).rejects.toThrow('1~6');
  });

  it('save() 更新未传 crawl 字段 → 保留存量值', async () => {
    const { service, updateSet } = writableDb(row({ crawlEnabled: 1, crawlMaxPerSession: 5 }));
    await service.save({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      visionModel: 'qwen-vl-max',
      imageModel: 'wanx2.1-t2i-turbo',
      enabled: true,
    });
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ crawlEnabled: 1, crawlMaxPerSession: 5 }));
  });

  it('save() 首次保存缺 crawl 字段 → insert 收到默认值（关闭 / 3）', async () => {
    const { service, insertValues } = writableDb(undefined);
    await service.save({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      apiKey: 'sk-1',
      visionModel: 'qwen-vl-max',
      imageModel: 'wanx2.1-t2i-turbo',
      enabled: true,
    });
    expect(insertValues).toHaveBeenCalledWith(expect.objectContaining({ crawlEnabled: 0, crawlMaxPerSession: 3 }));
  });
});
