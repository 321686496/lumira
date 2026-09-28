// lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts
import { crawlUrl, htmlToText, shouldRenderFallback, clearCrawlCache } from './crawl-url';

// DNS 解析打桩：单测不触网（公网域名一律解析为公网地址）
jest.mock('node:dns/promises', () => ({
  lookup: jest.fn(async () => [{ address: '93.184.216.34' }]),
}));

function htmlResponse(body: string, contentType = 'text/html; charset=utf-8', headers: Record<string, string> = {}) {
  return new Response(body, { status: 200, headers: { 'Content-Type': contentType, ...headers } });
}

/** 足够长（≥ STATIC_MIN_CHARS=300）的正文，避免触发降级 */
const LONG_TEXT = '正'.repeat(400);
const longHtml = (extra = '') => `<body><p>${LONG_TEXT}</p>${extra}</body>`;

describe('htmlToText', () => {
  it('去噪：移除 script/style/注释，保留正文', () => {
    const html = `<html><head><style>a{color:red}</style></head><body>
      <!-- 注释 --><script>var a=1;</script><h1>标题</h1><p>第一段&amp;内容</p></body></html>`;
    const text = htmlToText(html);
    expect(text).toContain('标题');
    expect(text).toContain('第一段&内容');
    expect(text).not.toContain('color:red');
    expect(text).not.toContain('var a=1');
    expect(text).not.toContain('注释');
  });

  it('优先提取 article 区块', () => {
    const html = `<body><nav>导航项</nav><article><h2>正文标题</h2><p>正文内容</p></article><footer>页脚</footer></body>`;
    const text = htmlToText(html);
    expect(text).toContain('正文标题');
    expect(text).not.toContain('导航项');
  });
});

describe('shouldRenderFallback', () => {
  it('403 / 429 触发降级', () => {
    expect(shouldRenderFallback(403, '')).toBe(true);
    expect(shouldRenderFallback(429, '')).toBe(true);
  });
  it('正文不足 300 字触发降级', () => {
    expect(shouldRenderFallback(200, '短正文')).toBe(true);
  });
  it('正文足够时不降级', () => {
    expect(shouldRenderFallback(200, '正'.repeat(300))).toBe(false);
  });
});

describe('crawlUrl — 静态路径（渲染关闭，默认行为）', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    fetchMock.mockReset();
    clearCrawlCache();
    delete process.env.RENDERER_WS_ENDPOINT;
  });

  it('抓取 HTML 并返回纯文本', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    const r = await crawlUrl('https://example.com/post');
    expect(r.text).toContain('正');
    expect(r.truncated).toBe(false);
    expect(r.usedRender).toBe(false);
    expect(r.chars).toBe(r.text.length);
  });

  it('超过 6000 字被截断并置 truncated', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(`<body><p>${'字'.repeat(8000)}</p></body>`));
    const r = await crawlUrl('https://example.com/long');
    expect(r.chars).toBe(6000);
    expect(r.truncated).toBe(true);
  });

  it('非网页类型被拒绝', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('%PDF-1.4', 'application/pdf'));
    await expect(crawlUrl('https://example.com/a.pdf')).rejects.toThrow('不是网页正文');
  });

  it('超大响应体被拒绝（Content-Length 声明）', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml(), 'text/html', { 'Content-Length': String(2 * 1024 * 1024) }));
    await expect(crawlUrl('https://example.com/big')).rejects.toThrow('过大');
  });

  it('无 Content-Length 的超大响应被流式拒绝', async () => {
    const res = new Response('x'.repeat(2 * 1024 * 1024), { headers: { 'Content-Type': 'text/html' } });
    res.headers.delete('content-length');
    fetchMock.mockResolvedValueOnce(res);
    await expect(crawlUrl('https://example.com/big-stream')).rejects.toThrow('过大');
  });

  it('超时抛既有可读错误（文案不变）', async () => {
    fetchMock.mockRejectedValueOnce(Object.assign(new Error('aborted'), { name: 'TimeoutError' }));
    await expect(crawlUrl('https://example.com/slow')).rejects.toThrow('抓取超时（8 秒），请换其他链接');
  });

  it('相同 URL 第二次命中缓存（不再发起 fetch）', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://example.com/cached');
    await crawlUrl('https://example.com/cached');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('重定向到私网时拒绝（手动逐跳校验）', async () => {
    fetchMock.mockResolvedValueOnce(new Response('', { status: 302, headers: { Location: 'http://192.168.1.9/secret' } }));
    await expect(crawlUrl('https://example.com/redirect')).rejects.toThrow('目标地址位于内网');
  });

  it('内网 IP 字面量直接拒绝；裸公网 IP 放行（走静态抓取）', async () => {
    await expect(crawlUrl('http://192.168.1.10/x')).rejects.toThrow('目标地址位于内网');
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    const r = await crawlUrl('http://8.8.8.8/x');
    expect(r.text).toContain('正');
  });
});

describe('crawlUrl — 渲染降级', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    fetchMock.mockReset();
    clearCrawlCache();
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
  });
  afterAll(() => {
    delete process.env.RENDERER_WS_ENDPOINT;
  });

  const opts = (render: jest.Mock, extra: Record<string, unknown> = {}) => ({
    renderEnabled: true,
    render,
    renderBudget: { used: 0, max: 2 },
    ...extra,
  });

  it('静态成功且正文充足 → 不调用渲染', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    const render = jest.fn();
    const r = await crawlUrl('https://example.com/ok-1', opts(render));
    expect(render).not.toHaveBeenCalled();
    expect(r.usedRender).toBe(false);
  });

  it('静态 403 → 调用渲染并返回渲染正文', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn(async () => `<body><p>${LONG_TEXT}</p></body>`);
    const r = await crawlUrl('https://example.com/403-ok', opts(render));
    expect(render).toHaveBeenCalledTimes(1);
    expect(r.usedRender).toBe(true);
    expect(r.text).toContain('正');
  });

  it('静态正文不足 300 字 → 调用渲染', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>太短</p></body>'));
    const render = jest.fn(async () => `<body><p>${LONG_TEXT}</p></body>`);
    const r = await crawlUrl('https://example.com/short-1', opts(render));
    expect(render).toHaveBeenCalledTimes(1);
    expect(r.usedRender).toBe(true);
  });

  it('开关关闭 → 不调用渲染，403 抛新文案', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn();
    await expect(crawlUrl('https://example.com/403-off', { renderEnabled: false, render })).rejects.toThrow(
      '目标站点拒绝自动抓取（HTTP 403）',
    );
    expect(render).not.toHaveBeenCalled();
  });

  it('渲染抛错 + 静态有短正文 → 静默降级返回静态正文', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>短但可用</p></body>'));
    const render = jest.fn(async () => {
      throw new Error('渲染失败');
    });
    const r = await crawlUrl('https://example.com/short-fallback', opts(render));
    expect(r.text).toContain('短但可用');
    expect(r.usedRender).toBe(false);
  });

  it('渲染抛错 + 静态无正文（403）→ 403 文案追加「已尝试浏览器渲染」', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn(async () => {
      throw new Error('渲染失败');
    });
    await expect(crawlUrl('https://example.com/403-fail', opts(render))).rejects.toThrow('已尝试浏览器渲染仍未取到正文');
  });

  it('渲染成功但正文为空 → 动态加载/需登录文案', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>太短</p></body>'));
    const render = jest.fn(async () => '<html><head></head><body></body></html>');
    await expect(crawlUrl('https://example.com/empty-render', opts(render))).rejects.toThrow('脚本动态加载或需登录');
  });

  it('渲染预算耗尽 → 不再调用渲染', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn();
    await expect(
      crawlUrl('https://example.com/budget-out', { renderEnabled: true, render, renderBudget: { used: 2, max: 2 } }),
    ).rejects.toThrow('目标站点拒绝自动抓取（HTTP 403）');
    expect(render).not.toHaveBeenCalled();
  });

  it('渲染成功后预算计数 +1', async () => {
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn(async () => `<body><p>${LONG_TEXT}</p></body>`);
    const budget = { used: 0, max: 2 };
    await crawlUrl('https://example.com/budget-count', { renderEnabled: true, render, renderBudget: budget });
    expect(budget.used).toBe(1);
  });

  it('RENDERER_WS_ENDPOINT 未配置 → 视为渲染不可用', async () => {
    delete process.env.RENDERER_WS_ENDPOINT;
    fetchMock.mockResolvedValueOnce(new Response('blocked', { status: 403 }));
    const render = jest.fn();
    await expect(crawlUrl('https://example.com/no-endpoint', opts(render))).rejects.toThrow('目标站点拒绝自动抓取（HTTP 403）');
    expect(render).not.toHaveBeenCalled();
  });

  it('静态带 cookie 按域发送；无匹配域名时不带 Cookie 头', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://www.zhihu.com/q/1', {
      cookies: { 'zhihu.com': 'z_c0=abc', 'other.com': 'y=1' },
    });
    const headers = (fetchMock.mock.calls[0][1] as RequestInit).headers as Record<string, string>;
    expect(headers.Cookie).toBe('z_c0=abc');

    clearCrawlCache();
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://example.com/other', { cookies: { 'zhihu.com': 'z_c0=abc' } });
    const headers2 = (fetchMock.mock.calls[1][1] as RequestInit).headers as Record<string, string>;
    expect(headers2.Cookie).toBeUndefined();
  });

  it('静态请求使用浏览器伪装头', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(longHtml()));
    await crawlUrl('https://example.com/ua');
    const headers = (fetchMock.mock.calls[0][1] as RequestInit).headers as Record<string, string>;
    expect(headers['User-Agent']).toContain('Mozilla/5.0');
    expect(headers['Accept-Language']).toContain('zh-CN');
  });
});