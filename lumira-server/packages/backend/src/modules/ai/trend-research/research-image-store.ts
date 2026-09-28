// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.ts
// 参考图落盘与生命周期：URL/内容哈希、压缩写盘、读盘、公网 URL 拼接、TTL 清理。
//
// 不走 StorageAdapter：参考图是短 TTL 的内部缓存，固定写本地 UPLOAD_DIR/research/，
// 由后端自身 /uploads 静态服务对外，URL 用 BACKEND_PUBLIC_URL 拼接（与 admin-templates 的 buildPublicUrl 同款）。

import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import * as path from 'node:path';
import sharp from 'sharp';
import {
  RESEARCH_IMAGE_JPEG_QUALITY,
  RESEARCH_IMAGE_MAX_SIDE,
  RESEARCH_IMAGE_MIN_SIDE,
} from './research-image';

/** sha256 前 16 位 hex */
function sha16(input: Buffer | string): string {
  return createHash('sha256').update(input).digest('hex').slice(0, 16);
}

/** 归一化原图 URL → 去重键 / 文件名 */
export function hashUrl(url: string): string {
  return sha16((url || '').trim());
}

/** 图片内容 → 去重键（同图不同 URL 只保留一张） */
export function hashBuffer(buf: Buffer): string {
  return sha16(buf);
}

/** 参考图落盘目录（测试可通过 UPLOAD_DIR 隔离） */
export function researchDir(): string {
  return path.join(process.env.UPLOAD_DIR || './data/uploads', 'research');
}

/** 落盘后的公网可访问 URL */
export function researchImageUrl(id: string): string {
  const base = (process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000').replace(/\/+$/, '');
  return `${base}/uploads/research/${id}.jpg`;
}

/** 压缩落盘结果 */
export interface WrittenImage {
  url: string;
  width: number;
  height: number;
  bytes: number;
}

/**
 * 压缩（长边 ≤1280、jpeg q80）并落盘为 `{id}.jpg`。
 * 任一边 <400px → 返回 null（画面太小，不保留）。
 */
export async function writeResearchImage(id: string, buffer: Buffer): Promise<WrittenImage | null> {
  const meta = await sharp(buffer, { failOn: 'error' }).metadata();
  const width0 = meta.width ?? 0;
  const height0 = meta.height ?? 0;
  if (!width0 || !height0) throw new Error('无法解析图片尺寸');
  if (Math.min(width0, height0) < RESEARCH_IMAGE_MIN_SIDE) return null;

  const out = await sharp(buffer, { failOn: 'error' })
    .rotate()
    .resize({ width: RESEARCH_IMAGE_MAX_SIDE, height: RESEARCH_IMAGE_MAX_SIDE, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: RESEARCH_IMAGE_JPEG_QUALITY })
    .toBuffer({ resolveWithObject: true });

  const dir = researchDir();
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, `${id}.jpg`), out.data);
  return {
    url: researchImageUrl(id),
    width: out.info.width,
    height: out.info.height,
    bytes: out.info.size,
  };
}

/** 读回图片字节（多模态解读用）；不存在 → null */
export async function readResearchImage(id: string): Promise<Buffer | null> {
  // 计划原文守卫为 /^[0-9a-f]{16}$/，但计划自带用例以 'id-ok' 写入并读取，
  // 二者冲突（用例 > 实现细节）。此处放宽为「安全文件名字符」白名单：
  // 仍拒绝目录穿越字符（/ \ .. NUL 等），同时兼容任意安全 id 与 16 位 hex 哈希。
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(id)) return null;
  try {
    return await fs.readFile(path.join(researchDir(), `${id}.jpg`));
  } catch {
    return null;
  }
}

/** 删除 mtime 超过 ttlDays 的落盘图片，返回删除数量 */
export async function cleanupResearchImages(ttlDays: number): Promise<number> {
  const dir = researchDir();
  let names: string[];
  try {
    names = await fs.readdir(dir);
  } catch {
    return 0;
  }
  const ttlMs = Math.max(1, ttlDays) * 24 * 3600 * 1000;
  const deadline = Date.now() - ttlMs;
  let removed = 0;
  for (const name of names) {
    if (!name.endsWith('.jpg')) continue;
    const file = path.join(dir, name);
    try {
      const st = await fs.stat(file);
      if (st.mtimeMs < deadline) {
        await fs.unlink(file);
        removed += 1;
      }
    } catch {
      // 单个文件异常不影响整体清理
    }
  }
  return removed;
}
