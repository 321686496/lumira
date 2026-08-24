// lumira-server/packages/backend/src/common/storage/asset-url.ts
// 静态资源 URL 规整工具：DB 存相对路径 storageKey，返回前端时拼 BACKEND_PUBLIC_URL

import { STORAGE_KEY_PREFIX } from './storage-adapter.interface';

/**
 * 将存储 key / 完整 URL 规整为 App 可访问的完整 URL。
 * - 相对路径 `{STORAGE_KEY_PREFIX}/...` → 拼 `BACKEND_PUBLIC_URL`
 * - 完整 https? URL：若前缀为 localhost/127.0.0.1，替换为 BACKEND_PUBLIC_URL（兼容旧数据）；否则原样返回
 * - 空值 → 空字符串
 */
export function buildAssetUrl(url: string | null | undefined): string {
  if (!url) return url || '';
  if (url.startsWith(STORAGE_KEY_PREFIX)) {
    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    return `${base}${url}`;
  }
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//i.test(url)) {
    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    return url.replace(/^https?:\/\/[^/]+/, base);
  }
  if (/^https?:\/\//i.test(url)) {
    return url; // 外部完整 URL 原样返回
  }
  // 兜底：未知格式直接返回
  return url;
}