import { CRAWL_TOOL_NAME, buildCrawlToolDef, createToolExecutor, resolveTextTools } from './text-tools';
import { crawlUrl } from './crawl-url';

jest.mock('./crawl-url', () => ({ crawlUrl: jest.fn() }));
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