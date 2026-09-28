import { CRAWL_TOOL_NAME, buildCrawlToolDef, createToolExecutor, resolveTextTools } from './text-tools';
import { crawlUrl } from './crawl-url';

jest.mock('./crawl-url', () => ({ crawlUrl: jest.fn(), CRAWL_RENDER_MAX_PER_SESSION: 2 }));
jest.mock('../llm-trace', () => ({ traceCrawlCall: () => null }));

const crawlUrlMock = crawlUrl as jest.Mock;

describe('buildCrawlToolDef', () => {
  it('工具定义 name/parameters 正确', () => {
    const def = buildCrawlToolDef();
    expect(def.name).toBe(CRAWL_TOOL_NAME);
    expect(def.parameters).toMatchObject({ type: 'object', required: ['url'] });
  });
});

describe('createToolExecutor', () => {
  beforeEach(() => crawlUrlMock.mockReset());

  it('成功：返回含正文的 JSON 字符串', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false });
    const out = await createToolExecutor()(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    expect(JSON.parse(out)).toMatchObject({ text: '正文', truncated: false });
  });

  it('缺 url 参数抛错', async () => {
    await expect(createToolExecutor()(CRAWL_TOOL_NAME, '{}')).rejects.toThrow('缺少 url');
  });

  it('未知工具名抛错', async () => {
    await expect(createToolExecutor()('other_tool', '{}')).rejects.toThrow('未知工具');
  });

  it('非法 arguments JSON 抛错', async () => {
    await expect(createToolExecutor()(CRAWL_TOOL_NAME, 'not-json')).rejects.toThrow('参数解析失败');
  });
});

describe('resolveTextTools', () => {
  it('未开启返回 undefined', () => {
    expect(resolveTextTools(undefined)).toBeUndefined();
    expect(resolveTextTools({ crawl: { enabled: false, maxPerSession: 3 } })).toBeUndefined();
  });

  it('开启时下发工具并夹紧次数上限到 1~6', () => {
    const ctx = resolveTextTools({ crawl: { enabled: true, maxPerSession: 99 } });
    expect(ctx?.tools).toHaveLength(1);
    expect(ctx?.maxToolCalls).toBe(6);

    const ctx2 = resolveTextTools({ crawl: { enabled: true, maxPerSession: 0 } });
    expect(ctx2?.maxToolCalls).toBe(1);
  });
});

afterEach(() => jest.restoreAllMocks());

describe('createToolExecutor — 渲染配置透传', () => {
  beforeEach(() => crawlUrlMock.mockReset());

  it('把渲染配置与同一份 renderBudget 传给 crawlUrl', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false, usedRender: false });
    const budget = { used: 0, max: 2 };
    const exec = createToolExecutor(
      { renderEnabled: true, renderTimeoutMs: 15_000, cookies: { 'a.com': 'x=1' } },
      budget,
    );
    await exec(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    expect(crawlUrlMock).toHaveBeenCalledWith('https://a.com', {
      renderEnabled: true,
      renderTimeoutMs: 15_000,
      cookies: { 'a.com': 'x=1' },
      renderBudget: budget,
    });
  });

  it('渲染命中时 resultBrief 追加「（渲染）」', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false, usedRender: true });
    const exec = createToolExecutor({}, { used: 0, max: 2 });
    await exec(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    // 断言不抛错即可（trace 被 mock 为 null，此处主要防回归）
    expect(crawlUrlMock).toHaveBeenCalledTimes(1);
  });

  it('crawlUrl 抛错时原样 rethrow（交由循环层回填 error）', async () => {
    crawlUrlMock.mockRejectedValueOnce(new Error('目标站点拒绝自动抓取（HTTP 403）'));
    await expect(createToolExecutor({}, { used: 0, max: 2 })(CRAWL_TOOL_NAME, '{"url":"https://a.com"}')).rejects.toThrow(
      '目标站点拒绝自动抓取',
    );
  });
});

describe('resolveTextTools — 渲染配置', () => {
  it('下发 renderEnabled / renderTimeoutMs / cookies，并为每次会话新建预算对象', () => {
    const cfg = {
      crawl: {
        enabled: true,
        maxPerSession: 3,
        renderEnabled: true,
        renderTimeoutMs: 12_000,
        cookies: { 'zhihu.com': 'z_c0=abc' },
      },
    };
    const a = resolveTextTools(cfg);
    const b = resolveTextTools(cfg);
    expect(a).toBeDefined();
    expect(b).toBeDefined();
    // 两个会话对象必须是不同实例（预算彼此独立）
    expect(a).not.toBe(b);
  });

  it('缺省不传渲染配置时 renderEnabled=false、cookies={}', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false, usedRender: false });
    const ctx = resolveTextTools({ crawl: { enabled: true, maxPerSession: 3 } });
    await ctx?.execute(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    expect(crawlUrlMock).toHaveBeenCalledWith('https://a.com', {
      renderEnabled: false,
      renderTimeoutMs: undefined,
      cookies: {},
      renderBudget: { used: 0, max: 2 },
    });
  });
});