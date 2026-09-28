import { crawlUrl, htmlToText, assertCrawlableUrl, clearCrawlCache } from './crawl-url';

function htmlResponse(body: string, contentType = 'text/html; charset=utf-8', headers: Record<string, string> = {}) {
  return new Response(body, { status: 200, headers: { 'Content-Type': contentType, ...headers } });
}

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

describe('assertCrawlableUrl', () => {
  it.each([
    ['file:///etc/passwd', '协议'],
    ['http://localhost/x', 'localhost'],
    ['http://127.0.0.1/x', '回环'],
    ['http://192.168.1.10/x', '私有网段'],
    ['http://10.0.0.5/x', '私有网段'],
    ['http://172.20.3.4/x', '私有网段'],
    ['http://foo.internal/x', '内网域名'],
    ['http://8.8.8.8/x', '裸 IP'],
    ['http://[2001:4860:4860::8888]/x', '裸 IPv6'],
  ])('拒绝 %s', (url) => {
    expect(() => assertCrawlableUrl(url)).toThrow();
  });

  it('接受公网 https 地址', () => {
    expect(assertCrawlableUrl('https://example.com/a?b=1').hostname).toBe('example.com');
  });
});

describe('crawlUrl', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    fetchMock.mockReset();
    clearCrawlCache();
  });

  it('抓取 HTML 并返回纯文本', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<html><body><h1>标题</h1><p>正文</p></body></html>'));
    const r = await crawlUrl('https://example.com/post');
    expect(r.text).toContain('标题');
    expect(r.truncated).toBe(false);
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

  it('超大响应体被拒绝', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body>x</body>', 'text/html', { 'Content-Length': String(2 * 1024 * 1024) }));
    await expect(crawlUrl('https://example.com/big')).rejects.toThrow('过大');
  });

  it('超时抛可读错误', async () => {
    fetchMock.mockRejectedValueOnce(Object.assign(new Error('aborted'), { name: 'TimeoutError' }));
    await expect(crawlUrl('https://example.com/slow')).rejects.toThrow('抓取超时');
  });

  it('相同 URL 第二次命中缓存（不再发起 fetch）', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>缓存内容</p></body>'));
    await crawlUrl('https://example.com/cached');
    await crawlUrl('https://example.com/cached');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('重定向落到私有网段时拒绝', async () => {
    const res = new Response('<body>x</body>', {
      status: 200,
      headers: { 'Content-Type': 'text/html' },
    });
    // Response.url 只读，改用 defineProperty 模拟重定向后的最终地址
    Object.defineProperty(res, 'url', { value: 'http://192.168.1.9/secret' });
    fetchMock.mockResolvedValueOnce(res);
    await expect(crawlUrl('https://example.com/redirect')).rejects.toThrow();
  });
});
