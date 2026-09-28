// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts
// 参考图抓取的网络工具层：SSRF 拦截 + 受控重定向下载 + 限流读体 + 页面 og:image 提取。
// 全部失败都抛可读 Error（调用方决定是降级跳过还是记入 errors）。

import { lookup } from 'node:dns/promises';
import {
  RESEARCH_IMAGE_ALLOWED_MIMES,
  RESEARCH_IMAGE_MAX_BYTES,
  RESEARCH_IMAGE_MAX_REDIRECTS,
} from './research-image';

/** IPv4 → 32 位整数 */
function ipv4ToInt(ip: string): number | null {
  const parts = ip.split('.');
  if (parts.length !== 4) return null;
  let n = 0;
  for (const p of parts) {
    if (!/^\d{1,3}$/.test(p)) return null;
    const v = Number(p);
    if (v > 255) return null;
    n = (n << 8) | v;
  }
  return n >>> 0;
}

/** IPv4 私网 / 环回 / 链路本地 / 保留段判定 */
function isPrivateV4(ip: string): boolean {
  const n = ipv4ToInt(ip);
  if (n === null) return false;
  const inRange = (base: string, bits: number): boolean => {
    const b = ipv4ToInt(base);
    if (b === null) return false;
    const mask = bits === 0 ? 0 : (0xffffffff << (32 - bits)) >>> 0;
    return (n & mask) === (b & mask);
  };
  return (
    inRange('0.0.0.0', 8) ||
    inRange('10.0.0.0', 8) ||
    inRange('100.64.0.0', 10) ||
    inRange('127.0.0.0', 8) ||
    inRange('169.254.0.0', 16) ||
    inRange('172.16.0.0', 12) ||
    inRange('192.0.0.0', 24) ||
    inRange('192.168.0.0', 16) ||
    inRange('198.18.0.0', 15) ||
    inRange('224.0.0.0', 4) ||
    inRange('240.0.0.0', 4)
  );
}

/** IP 字面量是否属于私网 / 环回 / 链路本地 / 保留段（IPv4 与 IPv6） */
export function isPrivateAddress(ip: string): boolean {
  const s = (ip || '').trim().toLowerCase().replace(/^\[|\]$/g, '');
  if (!s) return true;
  // v4 映射 v6
  const mapped = s.match(/^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/);
  if (mapped) return isPrivateV4(mapped[1]);
  if (s.includes(':')) {
    if (s === '::1' || s === '::') return true;
    if (/^f[cd][0-9a-f]{2}:/.test(s)) return true; // fc00::/7（ULA）
    if (/^fe[89ab][0-9a-f]:/.test(s)) return true; // fe80::/10（链路本地）
    return false;
  }
  return isPrivateV4(s);
}

const IPV4_LITERAL = /^\d{1,3}(?:\.\d{1,3}){3}$/;

/**
 * 校验 URL 可安全外发：仅 http/https；host 为 IP 字面量时直接判定，
 * 否则 DNS 解析全部地址，任一为私网即拒绝。
 */
export async function assertPublicHttpUrl(raw: string): Promise<URL> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('图片地址非法');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error(`不支持的协议：${url.protocol}`);
  }
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (IPV4_LITERAL.test(host) || host.includes(':')) {
    if (isPrivateAddress(host)) throw new Error('目标地址位于内网，已拦截');
    return url;
  }
  let addrs: { address: string }[];
  try {
    addrs = await lookup(host, { all: true });
  } catch {
    throw new Error(`域名解析失败：${host}`);
  }
  if (!addrs.length) throw new Error(`域名无解析结果：${host}`);
  if (addrs.some((a) => isPrivateAddress(a.address))) throw new Error('目标地址解析到内网，已拦截');
  return url;
}

/**
 * 受控下载：手动跟随重定向（≤ RESEARCH_IMAGE_MAX_REDIRECTS 跳），每跳重新做 SSRF 校验。
 * 返回最终 Response（调用方负责读体与 content-type 判断）。
 */
export async function fetchGuarded(
  url: string,
  opts: { timeoutMs: number; accept?: string },
): Promise<Response> {
  let current = url;
  for (let hop = 0; hop <= RESEARCH_IMAGE_MAX_REDIRECTS; hop++) {
    await assertPublicHttpUrl(current);
    const headers: Record<string, string> = { 'User-Agent': 'Mozilla/5.0 (compatible; LumiraBot/1.0)' };
    if (opts.accept) headers.Accept = opts.accept;
    const res = await fetch(current, {
      headers,
      redirect: 'manual',
      signal: AbortSignal.timeout(opts.timeoutMs),
    }).catch((err: unknown) => {
      const name = (err as { name?: string } | null | undefined)?.name;
      if (name === 'AbortError' || name === 'TimeoutError') throw new Error('抓取超时');
      throw new Error('抓取失败（网络不可达）');
    });
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      if (!loc) throw new Error(`重定向缺少 location（HTTP ${res.status}）`);
      current = new URL(loc, current).toString();
      continue;
    }
    return res;
  }
  throw new Error('重定向次数超出上限');
}

/** 读响应体，超过上限即抛错（边读边累计，防止超大响应吃满内存） */
export async function readCapped(res: Response, maxBytes: number): Promise<Buffer> {
  const chunks: Buffer[] = [];
  let total = 0;
  const body = res.body;
  if (!body) {
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.byteLength > maxBytes) throw new Error('图片体积超出上限');
    return buf;
  }
  const reader = body.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw new Error('图片体积超出上限');
    }
    chunks.push(Buffer.from(value));
  }
  return Buffer.concat(chunks);
}

/** 下载并校验一张图片：MIME 白名单 + 体积上限；任一不满足抛错 */
export async function fetchImageSafely(sourceUrl: string): Promise<{ buffer: Buffer; mime: string }> {
  const res = await fetchGuarded(sourceUrl, { timeoutMs: 5_000, accept: 'image/*' });
  if (!res.ok) throw new Error(`图片下载失败（HTTP ${res.status}）`);
  const mime = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  if (!RESEARCH_IMAGE_ALLOWED_MIMES.includes(mime)) throw new Error(`不支持的图片类型：${mime || '未知'}`);
  const buffer = await readCapped(res, RESEARCH_IMAGE_MAX_BYTES);
  if (!buffer.byteLength) throw new Error('图片内容为空');
  return { buffer, mime };
}

/** 抓取页面 HTML（只取前 512KB，够解析 head 元信息） */
export async function fetchPageHtml(url: string, timeoutMs: number): Promise<string> {
  const res = await fetchGuarded(url, { timeoutMs, accept: 'text/html,application/xhtml+xml' });
  if (!res.ok) throw new Error(`页面抓取失败（HTTP ${res.status}）`);
  const buffer = await readCapped(res, 512 * 1024);
  return buffer.toString('utf8');
}

/** 从 HTML 中按优先级提取首图：og:image → twitter:image → JSON-LD image → 首个 <img src> */
export function extractPageImageUrl(html: string, pageUrl: string): string | null {
  const meta = (patterns: RegExp[]): string | null => {
    for (const re of patterns) {
      const m = html.match(re);
      if (m?.[1]) {
        try {
          return new URL(decodeHtml(m[1].trim()), pageUrl).toString();
        } catch {
          /* 试下一个 */
        }
      }
    }
    return null;
  };
  const byMeta = meta([
    /<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]*content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']og:image(?::url)?["']/i,
    /<meta[^>]+(?:property|name)=["']twitter:image["'][^>]*content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']twitter:image["']/i,
  ]);
  if (byMeta) return byMeta;

  const jsonLd = html.match(/"image"\s*:\s*"([^"]+)"/i);
  if (jsonLd?.[1]) {
    try {
      return new URL(decodeHtml(jsonLd[1].trim()), pageUrl).toString();
    } catch {
      /* 落回 img */
    }
  }
  const img = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  if (img?.[1]) {
    try {
      return new URL(decodeHtml(img[1].trim()), pageUrl).toString();
    } catch {
      return null;
    }
  }
  return null;
}

/** 常见 HTML 实体反转义（只处理会出现在 URL 中的少数几个） */
function decodeHtml(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&#x2F;/gi, '/')
    .replace(/&#47;/g, '/')
    .replace(/&quot;/g, '"');
}
