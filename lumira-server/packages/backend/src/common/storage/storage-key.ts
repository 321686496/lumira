// lumira-server/packages/backend/src/common/storage/storage-key.ts
// storageKey 归一化与厂商对象键换算工具。

import { STORAGE_KEY_PREFIX } from './storage-adapter.interface';

/**
 * 将任意图片值归整为「相对 storageKey」（`{STORAGE_KEY_PREFIX}/...`）。
 * 兼容：相对 key / 绝对 http(s) URL（含 localhost / 生产域名）。
 * 非本存储的值（data: URI、外部无关 URL、空值）返回 null。
 */
export function toStorageKey(value: string | null | undefined): string | null {
  if (!value) return null;
  const v = value.trim();
  if (!v) return null;
  // 已是相对 key
  if (v.startsWith(STORAGE_KEY_PREFIX)) return v;
  // data: URI 或其它协议 → 非文件
  if (!/^https?:\/\//i.test(v)) return null;
  // 提取 pathname 中 `{STORAGE_KEY_PREFIX}/...` 部分
  try {
    const u = new URL(v);
    const p = u.pathname;
    if (p.startsWith(STORAGE_KEY_PREFIX)) return p;
  } catch {
    // ignore
  }
  return null;
}

/** storageKey → R2 对象键（去前导 `/uploads`；R2 key 不带前导斜杠更规范） */
export function storageKeyToR2Key(storageKey: string): string {
  return storageKey.replace(/^\/uploads/, 'uploads');
}

/** R2 对象键 → storageKey */
export function r2KeyToStorageKey(r2key: string): string {
  if (r2key.startsWith(STORAGE_KEY_PREFIX)) return r2key;
  return `${STORAGE_KEY_PREFIX}/${r2key}`;
}