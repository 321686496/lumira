// lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts
// 网页正文抓取：静态优先，失败（403/429/正文过短）时降级到无头渲染。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-crawl-render-fallback-design.md 第二节
//
// 安全：SSRF 守卫统一走 common/net/guarded-fetch（DNS 全量解析 + 逐跳校验）；
// 限体积（1MB）、超时（静态 8s / 渲染默认 20s）、限长度（6000 字）；
// cookie 按域名后缀匹配，无匹配则一份不发。

import { LruCache } from '../trend-research/lru-cache';
import { assertPublicHttpUrl, fetchGuarded } from '../../../common/net/guarded-fetch';
import { selectCookiesForHost } from '../cookie-crypto';

export interface CrawlResult {
  url: string;
  text: string;
  chars: number;
  truncated: boolean;
  /** 本次结果是否来自无头渲染 */
  usedRender: boolean;
}

/** 渲染实现签名（注入点，便于单测不启动 Chromium） */
export type RenderFn = (
  url: string,
  o: { timeoutMs: number; cookies: Record<string, string> },
) => Promise<string>;

export interface CrawlOptions {
  /** 静态失败时是否降级渲染；缺省 false → 纯静态 */
  renderEnabled?: boolean;
  /** 单次渲染超时；缺省 20000 */
  renderTimeoutMs?: number;
  /** 域名 → cookie 原始串（仅内存传递） */
  cookies?: Record<string, string>;
  /** 会话级渲染预算（同一工具会话内共享同一对象，跨多次 crawl 调用累计） */
  renderBudget?: { used: number; max: number };
  /** 渲染实现注入点；缺省用 tools/render-fetch.ts 的真实实现 */
  render?: RenderFn;
}

const CRAWL_TIMEOUT_MS = 8_000;
const MAX_BYTES = 1_048_576; // 1MB
const MAX_CHARS = 6_000;
/** 静态正文短于此值即认为「没拿到内容」，尝试渲染降级 */
const STATIC_MIN_CHARS = 300;
/** 单会话最多渲染次数（与 maxPerSession 配合控制最坏耗时；调优入口见后续优化登记） */
export const CRAWL_RENDER_MAX_PER_SESSION = 2;
const DEFAULT_CRAWL_RENDER_TIMEOUT_MS = 20_000;

/** 浏览器伪装头（静态与渲染共用；不伪造 Sec-Fetch-* / Referer——服务端发起时语义不成立） */
const BROWSER_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
const ALLOWED_MIME = ['text/html', 'application/xhtml+xml', 'text/plain'];

/** 面向模型的可读错误文案（逐条单测断言，让模型能判断「该换来源了」） */
export const ERR_CRAWL_TIMEOUT = '抓取超时（8 秒），请换其他链接';
export const ERR_CRAWL_OTHER = '网站响应异常，请换其他来源';
export const ERR_CRAWL_RENDER_EMPTY = '该站内容由脚本动态加载或需登录，未取到正文，请换来源';
export const errCrawlBlocked = (status: number, rendered: boolean): string =>
  `目标站点拒绝自动抓取（HTTP ${status}），请改用搜索摘要或换其他来源${rendered ? '，已尝试浏览器渲染仍未取到正文' : ''}`;

/** 成功结果进程内缓存（key = 归一化 URL） */
const cache = new LruCache<CrawlResult>(100);

/** 块级标签 → 换行，保证段落不粘连 */
const BLOCK_TAGS =
  /<\/?(p|div|section|article|main|header|footer|li|ul|ol|h[1-6]|tr|td|th|table|thead|tbody|blockquote|br|hr|pre|figure|figcaption|aside|nav|address|dl|dt|dd)[^>]*>/gi;

/** HTML → 纯文本：去噪 → 提正文区块 → 去标签 → 解实体 → 压缩空白 */
export function htmlToText(html: string): string {
  let s = html
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<(script|style|noscript|svg|iframe|template|head)\b[\s\S]*?<\/\1>/gi, '');

  const body = s.match(/<article\b[\s\S]*?<\/article>/i)?.[0] ?? s.match(/<main\b[\s\S]*?<\/main>/i)?.[0];
  if (body) s = body;

  return s
    .replace(BLOCK_TAGS, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t\f\v]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** 流式读取响应体：逐块累计字节数，超 MAX_BYTES 立即中止并抛「过大」 */
async function readBodyWithinLimit(res: Response): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return res.text();
  const decoder = new TextDecoder();
  let text = '';
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    received += value.byteLength;
    if (received > MAX_BYTES) {
      await reader.cancel();
      throw new Error('网页内容过大（超过 1MB），已跳过');
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

/** 降级判定：403/429，或正文不足 STATIC_MIN_CHARS */
export function shouldRenderFallback(status: number, text: string): boolean {
  if (status === 403 || status === 429) return true;
  return text.length < STATIC_MIN_CHARS;
}

/** 伪装头 + 按域 cookie（无匹配则不带 Cookie） */
function buildStaticHeaders(cookies: Record<string, string>): Record<string, string> {
  const headers: Record<string, string> = {
    'User-Agent': BROWSER_UA,
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };
  const cookieHeader = Object.values(cookies).join('; ');
  if (cookieHeader) headers.Cookie = cookieHeader;
  return headers;
}

/** 静态阶段错误 → 可读文案（SSRF 守卫的既有可读错误原样透出） */
function mapStaticFetchError(err: unknown): Error {
  const msg = err instanceof Error ? err.message : '';
  if (msg === '抓取超时') return new Error(ERR_CRAWL_TIMEOUT);
  if (msg === '抓取失败（网络不可达）') return new Error('网页抓取失败，请换其他链接');
  if (msg.startsWith('重定向次数超出上限') || msg.startsWith('重定向缺少 location')) return new Error(ERR_CRAWL_OTHER);
  return err instanceof Error ? err : new Error(ERR_CRAWL_OTHER);
}

/** 裁剪 + 缓存 + 返回 */
function finalize(key: string, text: string, usedRender: boolean): CrawlResult {
  const truncated = text.length > MAX_CHARS;
  const clipped = truncated ? text.slice(0, MAX_CHARS) : text;
  const result: CrawlResult = { url: key, text: clipped, chars: clipped.length, truncated, usedRender };
  cache.set(key, result);
  return result;
}

/** 抓取网页正文；失败抛面向模型可读的 Error（由工具执行器转成 error 文本回填） */
export async function crawlUrl(raw: string, opts: CrawlOptions = {}): Promise<CrawlResult> {
  // 1. 统一 SSRF 守卫（DNS 全量解析）
  const url = await assertPublicHttpUrl(raw);
  const key = url.toString();

  // 2. 缓存
  const cached = cache.get(key);
  if (cached) return cached;

  const cookies = selectCookiesForHost(url.hostname, opts.cookies ?? {});

  // 3. 静态抓取（手动逐跳重定向 + 每跳校验）
  let res: Response;
  try {
    res = await fetchGuarded(key, {
      timeoutMs: CRAWL_TIMEOUT_MS,
      accept: 'text/html,application/xhtml+xml,text/plain;q=0.9',
      headers: buildStaticHeaders(cookies),
    });
  } catch (err) {
    throw mapStaticFetchError(err);
  }

  const status = res.status;
  let staticText = '';
  let staticError: Error | null = null;

  // 4. 仅在 res.ok 时读体与判类型（403/429 的体是反爬壳，解析无价值）
  if (res.ok) {
    const mime = (res.headers.get('content-type') ?? '').toLowerCase();
    if (!ALLOWED_MIME.some((m) => mime.includes(m))) {
      throw new Error('该链接不是网页正文（类型不支持），请换其他链接');
    }
    const declared = Number(res.headers.get('content-length') ?? '0');
    if (Number.isFinite(declared) && declared > MAX_BYTES) {
      throw new Error('网页内容过大（超过 1MB），已跳过');
    }
    try {
      const rawBody = await readBodyWithinLimit(res);
      staticText = mime.includes('text/plain') ? rawBody.replace(/\s+/g, ' ').trim() : htmlToText(rawBody);
    } catch (err) {
      staticError = err instanceof Error ? err : new Error(ERR_CRAWL_OTHER);
    }
  }

  // 5. 降级判定
  if (!shouldRenderFallback(status, staticText)) return finalize(key, staticText, false);

  // 6. 渲染前提：开关开 + 预算未耗尽 + 端点已配置
  const budget = opts.renderBudget;
  const canRender =
    opts.renderEnabled === true && (!budget || budget.used < budget.max) && !!process.env.RENDERER_WS_ENDPOINT;

  let renderTried = false;
  let renderEmpty = false;
  if (canRender) {
    // 7. 记账（失败的尝试也计入预算，避免同一会话反复重试同一渲染）
    if (budget) budget.used += 1;
    renderTried = true;
    try {
      const render = opts.render ?? (await import('./render-fetch')).renderUrl;
      const html = await render(key, {
        timeoutMs: opts.renderTimeoutMs ?? DEFAULT_CRAWL_RENDER_TIMEOUT_MS,
        cookies,
      });
      const rendered = htmlToText(html);
      if (rendered) return finalize(key, rendered, true);
      renderEmpty = true;
    } catch {
      // 渲染不可用/失败 → 落到下面的错误优先级
    }
  }

  // 8. 错误优先级：渲染拿到空正文 → 静态短正文兜底 → 403/429 文案 → 其余
  //    （渲染「成功但空」说明目标确实是脚本站/需登录，比静态那点零碎正文更有信息量）
  if (renderEmpty) throw new Error(ERR_CRAWL_RENDER_EMPTY);
  if (staticText) return finalize(key, staticText, false);
  if (status === 403 || status === 429) throw new Error(errCrawlBlocked(status, renderTried));
  throw staticError ?? new Error(ERR_CRAWL_OTHER);
}

/** 清空抓取缓存（测试用） */
export function clearCrawlCache(): void {
  cache.clear();
}