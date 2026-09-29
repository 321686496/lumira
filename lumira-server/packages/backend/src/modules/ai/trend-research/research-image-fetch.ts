// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts
// 参考图抓取的网络工具层：SSRF 拦截 + 受控重定向下载 + 限流读体 + 页面 og:image 提取。
// 全部失败都抛可读 Error（调用方决定是降级跳过还是记入 errors）。
// SSRF 守卫已抽到 common/net/guarded-fetch.ts（爬取链路共用），本文件 re-export 保持 API 不变。

import {
  RESEARCH_IMAGE_ALLOWED_MIMES,
  RESEARCH_IMAGE_MAX_BYTES,
} from './research-image';
import {
  assertPublicHttpUrl,
  fetchGuarded,
  isPrivateAddress,
} from '../../../common/net/guarded-fetch';

// 对外保持原 API：既有调用方与 spec 继续从本模块导入这些符号
export { assertPublicHttpUrl, fetchGuarded, isPrivateAddress };

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

/**
 * 从 HTML 中按优先级提取多张候选图：og:image → twitter:image → JSON-LD image → 前 cap 个正文 <img src>。
 * 相对地址转绝对、绝对地址去重、忽略 data: 与锚点；cap 由调用方按剩余预算传入。
 */
export function extractPageImages(html: string, pageUrl: string, cap = 4): string[] {
  const out: string[] = [];
  const push = (raw: string): boolean => {
    if (out.length >= cap) return false;
    const trimmed = (raw || '').trim();
    if (!trimmed || /^data:/i.test(trimmed) || trimmed.startsWith('#')) return false;
    try {
      const abs = new URL(decodeHtml(trimmed), pageUrl).toString();
      if (!out.includes(abs)) out.push(abs);
      return out.length < cap;
    } catch {
      return out.length < cap;
    }
  };
  // 元信息图（og / twitter）少量且质量高，优先
  const metaPatterns = [
    /<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]*content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']og:image(?::url)?["']/i,
    /<meta[^>]+(?:property|name)=["']twitter:image["'][^>]*content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']twitter:image["']/i,
  ];
  for (const re of metaPatterns) {
    const m = html.match(re);
    if (m?.[1] && !push(m[1])) return out;
  }
  const jsonLd = html.match(/"image"\s*:\s*"([^"]+)"/i);
  if (jsonLd?.[1] && !push(jsonLd[1])) return out;
  // 正文 <img>：补充到 cap
  const imgRe = /<img[^>]+src=["']([^"']+)["']/gi;
  let m: RegExpExecArray | null;
  while (out.length < cap && (m = imgRe.exec(html)) !== null) {
    push(m[1]);
  }
  return out;
}

/** 从 HTML 中按优先级提取首图：og:image → twitter:image → JSON-LD image → 首个 <img src> */
export function extractPageImageUrl(html: string, pageUrl: string): string | null {
  return extractPageImages(html, pageUrl, 1)[0] ?? null;
}

/** 常见 HTML 实体反转义（只处理会出现在 URL 中的少数几个） */
function decodeHtml(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&#x2F;/gi, '/')
    .replace(/&#47;/g, '/')
    .replace(/&quot;/g, '"');
}
