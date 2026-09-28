// lumira-server/packages/backend/src/modules/ai/tools/render-fetch.spec.ts
// 用注入的假浏览器验证拦截 / cookie / 超时 / 内容返回，不启动真实 Chromium。
import { renderUrl } from './render-fetch';
import type { BrowserLike, InterceptedRequest, PageLike } from './render-fetch';

// DNS 解析打桩：单测不触网（域名统一解析为公网地址；IP 字面量不经 DNS）
jest.mock('node:dns/promises', () => ({
  lookup: jest.fn(async () => [{ address: '93.184.216.34' }]),
}));

type Req = { url: () => string; continued: boolean; aborted: boolean };

/** 假页面：记录拦截回调、cookie、goto 参数 */
function fakePage(requests: Req[], html = '<body><p>渲染正文</p></body>') {
  let handler: ((req: InterceptedRequest) => void) | null = null;
  const page: PageLike = {
    setRequestInterception: jest.fn(async () => undefined),
    on: ((_e: 'request', h: (req: InterceptedRequest) => void) => {
      handler = h;
    }) as PageLike['on'],
    setCookie: jest.fn(async () => undefined),
    goto: jest.fn(async () => undefined),
    content: jest.fn(async () => html),
    close: jest.fn(async () => undefined),
  };
  return {
    page,
    /** 触发一次拦截回调并等待其异步完成 */
    fire: async (url: string) => {
      const req: Req = { url: () => url, continued: false, aborted: false };
      requests.push(req);
      handler?.({
        url: () => url,
        continue: async () => {
          req.continued = true;
        },
        abort: async () => {
          req.aborted = true;
        },
      });
      // 拦截回调内部是 async IIFE，让出事件循环使其跑完
      await new Promise((r) => setTimeout(r, 0));
      return req;
    },
  };
}

function fakeBrowser(page: PageLike) {
  const browser: BrowserLike = {
    newPage: jest.fn(async () => page),
    close: jest.fn(async () => undefined),
    disconnect: jest.fn(),
  };
  return browser;
}

const OPTS = { timeoutMs: 5_000, cookies: { 'zhihu.com': 'z_c0=abc' } };

describe('renderUrl', () => {
  const original = process.env.RENDERER_WS_ENDPOINT;

  afterEach(() => {
    if (original === undefined) delete process.env.RENDERER_WS_ENDPOINT;
    else process.env.RENDERER_WS_ENDPOINT = original;
  });

  it('未配置 RENDERER_WS_ENDPOINT 时抛可读错误', async () => {
    delete process.env.RENDERER_WS_ENDPOINT;
    await expect(renderUrl('https://a.example/x', OPTS, { connect: jest.fn() })).rejects.toThrow('RENDERER_WS_ENDPOINT');
  });

  it('页面发起的私网请求被 abort，公网请求 continue', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const requests: Req[] = [];
    const { page, fire } = fakePage(requests);
    const browser = fakeBrowser(page);
    await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => browser });

    const bad = await fire('http://192.168.1.9/secret');
    expect(bad.aborted).toBe(true);
    expect(bad.continued).toBe(false);

    const good = await fire('https://cdn.example/a.js');
    expect(good.continued).toBe(true);
    expect(good.aborted).toBe(false);
  });

  it('非 http(s) 协议（data:/blob:）直接放行，不 abort', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const requests: Req[] = [];
    const { page, fire } = fakePage(requests);
    await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => fakeBrowser(page) });

    const data = await fire('data:text/html,<p>hi</p>');
    expect(data.continued).toBe(true);
    expect(data.aborted).toBe(false);
  });

  it('cookie 按域注入：匹配 zhihu.com 及其子域，不匹配的站点一份都不发', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const requests: Req[] = [];
    const { page } = fakePage(requests);
    await renderUrl('https://www.zhihu.com/question/1', OPTS, { connect: async () => fakeBrowser(page) });
    expect(page.setCookie).toHaveBeenCalledWith({ name: 'z_c0', value: 'abc', domain: 'zhihu.com', path: '/' });

    (page.setCookie as jest.Mock).mockClear();
    await renderUrl('https://93.184.216.34/other', OPTS, { connect: async () => fakeBrowser(page) });
    expect(page.setCookie).not.toHaveBeenCalled();
  });

  it('goto 使用 networkidle2 与传入超时', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const { page } = fakePage([]);
    await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => fakeBrowser(page) });
    expect(page.goto).toHaveBeenCalledWith('https://93.184.216.34/x', { waitUntil: 'networkidle2', timeout: 5_000 });
  });

  it('返回 page.content() 的 HTML', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const { page } = fakePage([], '<body><p>渲染正文</p></body>');
    const html = await renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => fakeBrowser(page) });
    expect(html).toContain('渲染正文');
  });

  it('goto 超时映射为可读错误，且 release 浏览器（disconnect）', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const { page } = fakePage([]);
    (page.goto as jest.Mock).mockRejectedValueOnce(Object.assign(new Error('timeout'), { name: 'TimeoutError' }));
    const browser = fakeBrowser(page);
    await expect(renderUrl('https://93.184.216.34/x', OPTS, { connect: async () => browser })).rejects.toThrow('渲染超时');
    expect(browser.disconnect).toHaveBeenCalled();
  });

  it('目标 URL 解析到私网时在连接前就拒绝', async () => {
    process.env.RENDERER_WS_ENDPOINT = 'ws://renderer:9222';
    const connect = jest.fn();
    await expect(renderUrl('http://192.168.1.9/x', OPTS, { connect })).rejects.toThrow('目标地址位于内网');
    expect(connect).not.toHaveBeenCalled();
  });
});