// lumira-server/packages/backend/src/common/net/guarded-fetch.ts
// 出站请求的 SSRF 守卫：host 为 IP 字面量时直接判定，否则 DNS 全量解析、任一私网即拒；
// 下载走手动逐跳重定向，每跳重新校验。
// 从 modules/ai/trend-research/research-image-fetch.ts 原样搬迁，供参考图抓取与网页爬取共用。

import { lookup } from 'node:dns/promises';

/** 手动跟随重定向的最大跳数（值与原 RESEARCH_IMAGE_MAX_REDIRECTS 一致） */
export const GUARDED_FETCH_MAX_REDIRECTS = 3;

/** DNS 解析注入点（缺省用 node:dns/promises 的 lookup；单测注入假实现以避免触网） */
export type DnsLookup = (host: string) => Promise<{ address: string }[]>;

const defaultLookup: DnsLookup = (host) => lookup(host, { all: true });

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
export async function assertPublicHttpUrl(raw: string, deps: { lookup?: DnsLookup } = {}): Promise<URL> {
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
  const resolve = deps.lookup ?? defaultLookup;
  let addrs: { address: string }[];
  try {
    addrs = await resolve(host);
  } catch {
    throw new Error(`域名解析失败：${host}`);
  }
  if (!addrs.length) throw new Error(`域名无解析结果：${host}`);
  if (addrs.some((a) => isPrivateAddress(a.address))) throw new Error('目标地址解析到内网，已拦截');
  return url;
}

/**
 * 受控下载：手动跟随重定向（≤ GUARDED_FETCH_MAX_REDIRECTS 跳），每跳重新做 SSRF 校验。
 * 返回最终 Response（调用方负责读体与 content-type 判断）。
 * `opts.headers` 为可选覆盖（缺省 undefined → 与搬迁前行为完全一致）。
 */
export async function fetchGuarded(
  url: string,
  opts: { timeoutMs: number; accept?: string; headers?: Record<string, string>; lookup?: DnsLookup },
): Promise<Response> {
  let current = url;
  for (let hop = 0; hop <= GUARDED_FETCH_MAX_REDIRECTS; hop++) {
    await assertPublicHttpUrl(current, { lookup: opts.lookup });
    const headers: Record<string, string> = { 'User-Agent': 'Mozilla/5.0 (compatible; LumiraBot/1.0)' };
    if (opts.accept) headers.Accept = opts.accept;
    if (opts.headers) Object.assign(headers, opts.headers);
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