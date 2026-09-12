// lumira-server/packages/backend/src/modules/templates/thumbs.service.ts
// 分类图标缩略图生成：App 端网格只为小尺寸卡面请求缩略图，
// 避免首次加载把后台上传的全尺寸原图（可能是 2000-4000px）一次性拉下来。

import { Injectable, NotFoundException } from '@nestjs/common';
import { eq, asc } from 'drizzle-orm';
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';

const THUMB_WIDTH_DEFAULT = 600;
const THUMB_WIDTH_MIN = 200;
const THUMB_WIDTH_MAX = 2000;
const JPEG_QUALITY = 88;

export interface ThumbResult {
  data: Buffer;
  type: string;
}

@Injectable()
export class ThumbsService {
  private readonly uploadDir: string;

  constructor(private readonly dbService: DatabaseService) {
    this.uploadDir = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
  }

  private clampWidth(raw: string | number): number {
    const n = Math.round(Number(raw));
    if (!Number.isFinite(n)) return THUMB_WIDTH_DEFAULT;
    return Math.min(Math.max(n, THUMB_WIDTH_MIN), THUMB_WIDTH_MAX);
  }

  /** 定位某分类的上传图标源文件（返回绝对路径），找不到返回 null */
  private async findIconFile(key: string): Promise<string | null> {
    const db = this.dbService.getDb();
    // 同名 key 可能跨层级出现，取 level 最小的（最接近根）当作唯一分类
    const rows = await db
      .select({ iconUrl: templateCategories.iconUrl })
      .from(templateCategories)
      .where(eq(templateCategories.key, key))
      .orderBy(asc(templateCategories.level))
      .limit(1);
    const iconUrl = rows[0]?.iconUrl;
    if (!iconUrl) return null;
    const filename = iconUrl.split('/').pop();
    if (!filename) return null;
    // 防止路径穿越：只允许普通文件名，不允许 "../" 等
    if (!/^[a-z0-9][a-z0-9._-]*$/i.test(filename)) return null;
    const file = path.join(this.uploadDir, 'categories', key, filename);
    return fs.existsSync(file) ? file : null;
  }

  /** 返回（或生成并缓存）分类图标的指定宽度 JPEG 缩略图 */
  async categoryIcon(key: string, rawWidth: string | number): Promise<ThumbResult> {
    const width = this.clampWidth(rawWidth);

    // 磁盘命中优先：已生成缩略图直接返回（零 DB、零 CPU），
    // 配合写链路 preGenerate 后命中率接近 100%
    const thumbDir = path.join(this.uploadDir, 'thumbs', 'categories', key);
    const thumbFile = path.join(thumbDir, `w${width}.jpg`);
    if (fs.existsSync(thumbFile)) {
      return { data: fs.readFileSync(thumbFile), type: 'image/jpeg' };
    }

    // 未命中才查 DB（只为了拿上传文件名），并懒生成（覆盖旧分类/迁移前数据）
    const src = await this.findIconFile(key);
    if (!src) throw new NotFoundException('category icon not found');

    // 与模板缩略图一致使用 sharp，确保 WebP 源图也能正常生成 JPEG 缩略图。
    // 若图片解码失败，回退返回原图。
    try {
      const buf = await sharp(src, { failOn: 'error' })
        .rotate()
        .resize({ width, withoutEnlargement: true })
        .jpeg({ quality: JPEG_QUALITY })
        .toBuffer();
      try {
        fs.mkdirSync(thumbDir, { recursive: true });
        fs.writeFileSync(thumbFile, buf);
      } catch (_) {
        // 缩略图写盘失败不影响本次响应
      }
      return { data: buf, type: 'image/jpeg' };
    } catch {
      return { data: fs.readFileSync(src), type: 'application/octet-stream' };
    }
  }

  /**
   * 预生成某分类的多个宽度缩略图（写链路调用，把生成成本从读请求挪到上传时）。
   * 若源图解码失败，静默跳过，读链路懒生成兑底。
   */
  async templateImage(
    templateId: string,
    filename: string,
    rawWidth: string | number,
  ): Promise<ThumbResult> {
    if (!/^[a-z0-9][a-z0-9_-]*$/i.test(templateId)) {
      throw new NotFoundException('template image not found');
    }
    if (!/^[a-z0-9][a-z0-9._-]*$/i.test(filename)) {
      throw new NotFoundException('template image not found');
    }

    const width = this.clampWidth(rawWidth);
    const cacheDir = path.join(this.uploadDir, 'thumbs', 'templates', templateId);
    const basename = path.basename(filename, path.extname(filename));
    const cacheFile = path.join(cacheDir, `${basename}.w${width}.webp`);
    if (fs.existsSync(cacheFile)) {
      return { data: fs.readFileSync(cacheFile), type: 'image/webp' };
    }

    const source = path.join(this.uploadDir, 'templates', templateId, filename);
    if (!fs.existsSync(source)) {
      throw new NotFoundException('template image not found');
    }

    try {
      const data = await sharp(source, { failOn: 'error' })
        .rotate()
        .resize({ width, withoutEnlargement: true })
        .webp({ quality: 82 })
        .toBuffer();
      try {
        fs.mkdirSync(cacheDir, { recursive: true });
        fs.writeFileSync(cacheFile, data);
      } catch {
        // Cache write failures must not fail this response.
      }
      return { data, type: 'image/webp' };
    } catch {
      return { data: fs.readFileSync(source), type: 'application/octet-stream' };
    }
  }

  async preGenerate(key: string, widths: number[] = [200, 400, 800]): Promise<void> {
    const src = await this.findIconFile(key);
    if (!src) return;
    const thumbDir = path.join(this.uploadDir, 'thumbs', 'categories', key);
    for (const w of widths) {
      try {
        const width = this.clampWidth(w);
        const buf = await sharp(src, { failOn: 'error' })
          .rotate()
          .resize({ width, withoutEnlargement: true })
          .jpeg({ quality: JPEG_QUALITY })
          .toBuffer();
        fs.mkdirSync(thumbDir, { recursive: true });
        fs.writeFileSync(path.join(thumbDir, `w${width}.jpg`), buf);
      } catch {
        // 该宽度生成失败（源格式不支持等）静默跳过
      }
    }
  }

  /** 删除某分类的缩略图缓存目录（icon 变更/删除时清理旧宽度残留） */
  clearCache(key: string): void {
    const thumbDir = path.join(this.uploadDir, 'thumbs', 'categories', key);
    if (fs.existsSync(thumbDir)) {
      fs.rmSync(thumbDir, { recursive: true, force: true });
    }
  }
}
