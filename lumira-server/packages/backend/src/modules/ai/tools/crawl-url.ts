// lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts
// 网页正文抓取：仅抓公开静态 HTML，清洗为纯文本供文本模型阅读。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md 第二节
//
// 安全：仅 http/https、拦内网/本机/裸 IP、限体积（1MB）与超时（8s）、限长度（6000 字）。
// 不做 JS 渲染，不引入第三方解析库（正则 + 原生字符串处理）。

import { LruCache } from '../trend-research/lru-cache';

export interface CrawlResult {
  url: string;
  text: string;
  chars: number;
  truncated: boolean;
}

const CRAWL_TIMEOUT_MS = 8_000;
const MAX_BYTES = 1_048_576; // 1MB
const MAX_CHARS = 6_000;
const USER_AGENT = 'LumiraBot/1.0 (+https://lumira.iwtle.top)';
const ALLOWED_MIME = ['text/html', 'application/xhtml+xml', 'text/plain'];

/** 成功结果进程内缓存（key = 归一化 URL） */
const cache = new LruCache<CrawlResult>(100);

/** 裸 IP 字面量（IPv4 点分十进制 / IPv6 带方括号）一律拒绝（防 SSRF） */
const IP_LITERAL = /^\d{1,3}(\.\d{1,3}){3}$|^\[/;

/** 内网 / 本机 / 保留地址（防 SSRF） */
const BLOCKED_HOST_PATTERNS = [
  /^localhost$/i,
  /\.local$/i,
  /\.internal$/i,
  /^127\./,
  /^10\./,
  /^169\.254\./,
  /^192\.168\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
  /^::1$/,
  /^\[::1\]$/,
];

/** 校验可抓取 URL；非法抛可读 Error */
export function assertCrawlableUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`无效网址：${raw}`);
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error(`仅支持 http/https 网址：${raw}`);
  }
  if (IP_LITERAL.test(url.hostname)) {
    throw new Error(`不允许抓取裸 IP 地址：${raw}`);
  }
  if (BLOCKED_HOST_PATTERNS.some((p) => p.test(url.hostname))) {
    throw new Error(`不允许抓取内网/本机地址：${raw}`);
  }
  return url;
}

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

/** 抓取网页正文；失败抛面向模型可读的 Error（由工具执行器转成 error 文本回填） */
export async function crawlUrl(raw: string): Promise<CrawlResult> {
  const url = assertCrawlableUrl(raw);
  const key = url.toString();

  const cached = cache.get(key);
  if (cached) return cached;

  let res: Response;
  try {
    res = await fetch(key, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml,text/plain;q=0.9' },
      redirect: 'follow',
      signal: AbortSignal.timeout(CRAWL_TIMEOUT_MS),
    });
  } catch (err) {
    const name = (err as { name?: string } | null | undefined)?.name;
    if (name === 'AbortError' || name === 'TimeoutError') {
      throw new Error('抓取超时（8 秒），请换其他链接');
    }
    throw new Error('网页抓取失败，请换其他链接');
  }

  // 重定向可能落到内网：以最终地址再次校验
  if (res.url) assertCrawlableUrl(res.url);
  if (!res.ok) throw new Error(`网页返回错误（HTTP ${res.status}），请换其他链接`);

  const mime = (res.headers.get('content-type') ?? '').toLowerCase();
  if (!ALLOWED_MIME.some((m) => mime.includes(m))) {
    throw new Error('该链接不是网页正文（类型不支持），请换其他链接');
  }

  const declared = Number(res.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > MAX_BYTES) {
    throw new Error('网页内容过大（超过 1MB），已跳过');
  }

  const rawBody = await res.text();
  if (Buffer.byteLength(rawBody, 'utf8') > MAX_BYTES) {
    throw new Error('网页内容过大（超过 1MB），已跳过');
  }

  const text = mime.includes('text/plain') ? rawBody.replace(/\s+/g, ' ').trim() : htmlToText(rawBody);
  if (!text) throw new Error('网页未提取到正文内容，请换其他链接');

  const truncated = text.length > MAX_CHARS;
  const clipped = truncated ? text.slice(0, MAX_CHARS) : text;
  const result: CrawlResult = { url: key, text: clipped, chars: clipped.length, truncated };
  cache.set(key, result);
  return result;
}

/** 清空抓取缓存（测试用） */
export function clearCrawlCache(): void {
  cache.clear();
}
