// lumira-server/packages/backend/src/common/storage/asset-url.ts
// 静态资源 URL 规整工具：DB 存相对路径 storageKey，返回前端时拼当前激活存储的公网 URL。

import { STORAGE_KEY_PREFIX } from './storage-adapter.interface';
import { getActivePublicUrl } from './runtime-storage';

/** 取 URL 的 origin（小写，无结尾斜杠）；非 http(s) URL 返回空串 */
function originOf(url: string): string {
  const m = /^(https?:\/\/[^/]+)/i.exec(url.trim());
  return m ? m[1].toLowerCase() : '';
}

/**
 * 是否为「自己后端」的绝对 URL：
 * - localhost / 127.0.0.1（本地开发期写入 DB 的旧形态）
 * - BACKEND_PUBLIC_URL / STORAGE_PUBLIC_URL 指向的域名（线上旧 buildPublicUrl 写入的形态）
 * 这类 URL 的路径部分仍可能有效，但域名应跟随当前激活存储重建，否则切换七牛/R2 后
 * DB 里的旧绝对 URL 永远停在旧域名，新存储的公网 URL 不生效。
 */
function isOwnBackendUrl(url: string): boolean {
  const origin = originOf(url);
  if (!origin) return false;
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) return true;
  const ownOrigins = [process.env.BACKEND_PUBLIC_URL, process.env.STORAGE_PUBLIC_URL]
    .filter((v): v is string => !!v)
    .map((v) => originOf(v));
  return ownOrigins.includes(origin);
}

/**
 * 将存储 key / 完整 URL 规整为 App 可访问的完整 URL。
 * - 相对路径 `{STORAGE_KEY_PREFIX}/...` → 拼当前激活存储的公网 URL
 * - 完整 https? URL：若为「自己后端域名 + {STORAGE_KEY_PREFIX}/...」（旧数据），
 *   提取路径后用当前激活存储公网 URL 重建；其它完整 URL（外部 CDN 等）原样返回
 * - 空值 → 空字符串
 */
export function buildAssetUrl(url: string | null | undefined): string {
  if (!url) return url || '';
  const base = getActivePublicUrl();
  if (url.startsWith(STORAGE_KEY_PREFIX)) {
    return `${base}${url}`;
  }
  if (/^https?:\/\//i.test(url)) {
    if (isOwnBackendUrl(url)) {
      const pathPart = url.replace(/^https?:\/\/[^/]+/i, '');
      if (pathPart.startsWith(STORAGE_KEY_PREFIX)) {
        return `${base}${pathPart}`;
      }
    }
    return url; // 外部完整 URL 原样返回
  }
  // 兜底：未知格式直接返回
  return url;
}
