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
    expect(cfg.crawl).toEqual({ enabled: true, maxPerSession: 5, renderEnabled: false, renderTimeoutMs: 20_000, cookies: {} });
  });

  it('getActiveConfig() 缺列 → crawl 默认关闭、上限 3', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const cfg = await service.getActiveConfig();
    expect(cfg.crawl).toEqual({ enabled: false, maxPerSession: 3, renderEnabled: false, renderTimeoutMs: 20_000, cookies: {} });
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
    expect(updateSet).toHaveBeenCalledWith(
      expect.objectContaining({
        crawlEnabled: 1,
        crawlMaxPerSession: 5,
        crawlRenderEnabled: 0,
        crawlRenderTimeoutMs: 20_000,
        crawlCookies: null,
      }),
    );
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
    expect(insertValues).toHaveBeenCalledWith(
      expect.objectContaining({
        crawlEnabled: 0,
        crawlMaxPerSession: 3,
        crawlRenderEnabled: 0,
        crawlRenderTimeoutMs: 20_000,
        crawlCookies: null,
      }),
    );
  });

  it('get() 映射渲染开关 / 超时 / cookie 域名列表（只回显域名）', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { encryptCookies } = await import('./cookie-crypto');
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' });
    const service = new AiConfigService(
      readonlyDb(row({ crawlRenderEnabled: 1, crawlRenderTimeoutMs: 12_000, crawlCookies: stored })),
    );
    const view = await service.get();
    expect(view).toMatchObject({
      crawlRenderEnabled: true,
      crawlRenderTimeoutMs: 12_000,
      crawlCookieDomains: ['zhihu.com'],
    });
    expect(JSON.stringify(view)).not.toContain('z_c0=abc');
    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('get() 缺列 → 渲染关闭 / 默认 20000 / 无域名', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const view = await service.get();
    expect(view).toMatchObject({ crawlRenderEnabled: false, crawlRenderTimeoutMs: 20_000, crawlCookieDomains: [] });
  });

  it('getActiveConfig() 暴露渲染配置（cookie 解密为明文映射）', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { encryptCookies } = await import('./cookie-crypto');
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' });
    const service = new AiConfigService(readonlyDb(row({ crawlRenderEnabled: 1, crawlCookies: stored })));
    const cfg = await service.getActiveConfig();
    expect(cfg.crawl).toEqual({
      enabled: false,
      maxPerSession: 3,
      renderEnabled: true,
      renderTimeoutMs: 20_000,
      cookies: { 'zhihu.com': 'z_c0=abc' },
    });
    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('save() 渲染超时越界 → 400', async () => {
    const { service } = writableDb(row());
    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlRenderTimeoutMs: 1_000,
      } as never),
    ).rejects.toThrow('5000~60000');
  });

  it('save() cookie 落库值不是明文，且域名非法被拒', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { service, updateSet } = writableDb(row());
    await service.save({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      visionModel: 'qwen-vl-max',
      imageModel: 'wanx2.1-t2i-turbo',
      enabled: true,
      crawlCookies: { 'zhihu.com': 'z_c0=abc' },
    } as never);
    const patch = updateSet.mock.calls[0][0] as Record<string, unknown>;
    expect(String(patch.crawlCookies)).toMatch(/^v1:/);
    expect(String(patch.crawlCookies)).not.toContain('z_c0=abc');

    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlCookies: { 'not a domain': 'x=1' },
      } as never),
    ).rejects.toThrow('cookie 域名非法');

    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('save() 未配置密钥时保存 cookie → 400（绝不落明文）', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    delete process.env.CRAWL_COOKIE_SECRET;
    const { service, updateSet } = writableDb(row());
    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://x.example',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx2.1-t2i-turbo',
        enabled: true,
        crawlCookies: { 'zhihu.com': 'z_c0=abc' },
      } as never),
    ).rejects.toThrow('未配置 CRAWL_COOKIE_SECRET');
    expect(updateSet).not.toHaveBeenCalled();
    if (secret !== undefined) process.env.CRAWL_COOKIE_SECRET = secret;
  });

  it('save() 未传 cookie → 保留存量', async () => {
    const secret = process.env.CRAWL_COOKIE_SECRET;
    process.env.CRAWL_COOKIE_SECRET = 'a'.repeat(64);
    const { encryptCookies } = await import('./cookie-crypto');
    const stored = encryptCookies({ 'zhihu.com': 'z_c0=abc' }) as string;
    const { service, updateSet } = writableDb(row({ crawlCookies: stored }));
    await service.save({
      provider: 'qwen',
      baseUrl: 'https://x.example',
      visionModel: 'qwen-vl-max',
      imageModel: 'wanx2.1-t2i-turbo',
      enabled: true,
    });
    const patch = updateSet.mock.calls[0][0] as Record<string, unknown>;
    expect(patch.crawlCookies).toBe(stored);
    if (secret === undefined) delete process.env.CRAWL_COOKIE_SECRET;
    else process.env.CRAWL_COOKIE_SECRET = secret;
  });
});
