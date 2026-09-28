// lumira-server/packages/backend/src/modules/ai/tools/render-fetch.ts
// 无头渲染驱动器：连接独立 renderer 容器的 CDP 端点，取回渲染后的 HTML。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-crawl-render-fallback-design.md 第一 / 二 / 三节
//
// 安全：页面自身的每个请求都过一遍 DNS 级 SSRF 守卫（私网 abort），这是
// 「薄容器 + 后端驱动」相对现成渲染服务镜像的核心收益——守卫只有一份。

import { assertPublicHttpUrl } from '../../../common/net/guarded-fetch';
import { selectCookiesForHost } from '../cookie-crypto';

export interface RenderOptions {
  timeoutMs: number;
  /** 域名 → cookie 原始串（调用方已按域筛选，仅内存传递） */
  cookies: Record<string, string>;
}

/** 渲染期被拦截的请求（puppeteer Request 的结构子集） */
export interface InterceptedRequest {
  url(): string;
  continue(): Promise<void>;
  abort(): Promise<void>;
}

/** puppeteer Page 的结构子集（只为可注入假实现而定义，不引 puppeteer 类型） */
export interface PageLike {
  setRequestInterception(value: boolean): Promise<void>;
  on(event: 'request', handler: (req: InterceptedRequest) => void): void;
  setCookie(...cookies: Array<{ name: string; value: string; domain: string; path: string }>): Promise<void>;
  goto(url: string, opts: { waitUntil: string; timeout: number }): Promise<unknown>;
  content(): Promise<string>;
  close(): Promise<void>;
}

/** puppeteer Browser 的结构子集 */
export interface BrowserLike {
  newPage(): Promise<PageLike>;
  close(): Promise<void>;
  /** connect 得到的远端浏览器用 disconnect 释放连接（不关掉对方进程） */
  disconnect?(): void;
}

export interface RenderDeps {
  connect?: (endpoint: string) => Promise<BrowserLike>;
}

/** 缺省连接实现：puppeteer-core 是纯 JS 包（不含浏览器二进制），此处懒加载避免单测引入 */
async function defaultConnect(endpoint: string): Promise<BrowserLike> {
  const puppeteer = await import('puppeteer-core');
  const browser = await puppeteer.connect({ browserWSEndpoint: endpoint });
  return browser as unknown as BrowserLike;
}

/** 把 `a=1; b=2` 解析为 name/value 对（CDP 只能按对设置，不能整串塞） */
function parseCookiePairs(raw: string): Array<{ name: string; value: string }> {
  return raw
    .split(';')
    .map((p) => p.trim())
    .filter(Boolean)
    .map((p) => {
      const i = p.indexOf('=');
      return i === -1 ? { name: p.trim(), value: '' } : { name: p.slice(0, i).trim(), value: p.slice(i + 1).trim() };
    })
    .filter((c) => c.name);
}

function isHttpUrl(u: string): boolean {
  return u.startsWith('http://') || u.startsWith('https://');
}

/** 渲染并返回页面 HTML；失败抛可读 Error（调用方决定降级） */
export async function renderUrl(url: string, opts: RenderOptions, deps: RenderDeps = {}): Promise<string> {
  const endpoint = process.env.RENDERER_WS_ENDPOINT;
  if (!endpoint) throw new Error('未配置 RENDERER_WS_ENDPOINT，无法渲染');

  await assertPublicHttpUrl(url);

  const connect = deps.connect ?? defaultConnect;
  const browser = await connect(endpoint);
  let page: PageLike | null = null;
  try {
    page = await browser.newPage();
    await page.setRequestInterception(true);
    page.on('request', (req) => {
      void (async () => {
        try {
          // data: / blob: / about: 等非 http(s) 请求无 SSRF 面，直接放行
          if (isHttpUrl(req.url())) await assertPublicHttpUrl(req.url());
          await req.continue();
        } catch {
          await req.abort().catch(() => undefined);
        }
      })();
    });

    // 按域注入 cookie：再次按目标 host 过滤（纵深防御，调用方未筛时也不会跨站泄露）
    const scoped = selectCookiesForHost(new URL(url).hostname, opts.cookies ?? {});
    const cookieParams: Array<{ name: string; value: string; domain: string; path: string }> = [];
    for (const [domain, raw] of Object.entries(scoped)) {
      for (const pair of parseCookiePairs(raw)) cookieParams.push({ ...pair, domain, path: '/' });
    }
    if (cookieParams.length) await page.setCookie(...cookieParams);

    await page.goto(url, { waitUntil: 'networkidle2', timeout: opts.timeoutMs }).catch((err: unknown) => {
      const name = (err as { name?: string } | null | undefined)?.name;
      if (name === 'TimeoutError') throw new Error('渲染超时，请换其他来源');
      throw new Error('渲染失败，请换其他来源');
    });

    return await page.content();
  } finally {
    await page?.close().catch(() => undefined);
    // 远端浏览器：断开连接（puppeteer 的 disconnect 为同步方法）
    try {
      if (browser.disconnect) browser.disconnect();
      else await browser.close();
    } catch {
      /* 释放失败不影响结果 */
    }
  }
}