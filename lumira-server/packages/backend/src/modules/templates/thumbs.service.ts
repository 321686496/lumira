// lumira-server/packages/backend/src/modules/templates/thumbs.service.ts
// 缩略图生成与持久化：
// - 读链路：本地磁盘缓存 → 激活存储 → 生成并持久化（激活存储 + 本地缓存）
// - 写链路：admin 保存模板/分类时预生成阶梯宽度，客户端直连存储域名取图，
//   不再走后端动态端点（省一次后端往返，也避免 /api/v1/thumbs URL 暴露后端域名）。
//
// 存储键（admin / Flutter 客户端按同一规则推导直连 URL，三端改必须同步）：
//   模板：/uploads/thumbs/templates/{templateId}/{源文件主名}.w{width}.webp
//   分类：/uploads/thumbs/categories/{key}/w{width}.jpg

import { Injectable, NotFoundException } from '@nestjs/common';
import { eq, asc } from 'drizzle-orm';
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';
import { activeStorageAdapter, getActiveId } from '../../common/storage/runtime-storage';
import { mimeOf } from '../../common/storage/mime';

const THUMB_WIDTH_DEFAULT = 600;
const THUMB_WIDTH_MIN = 16;
const THUMB_WIDTH_MAX = 2000;
const JPEG_QUALITY = 88;

/**
 * 预生成宽度阶梯：与 admin `snapThumbWidth` / Flutter `snapThumbWidth` 保持一致。
 * 客户端请求宽度先吸附到本阶梯，再推导存储直连 URL；写链路按全阶梯预生成。
 */
export const THUMB_WIDTH_LADDER = [160, 320, 480, 640, 800, 1080] as const;

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

  /** storageKey → 本地磁盘绝对路径；解析结果必须位于 uploadDir 之内 */
  private localFilePath(storageKey: string): string | null {
    const rel = storageKey.replace(/^\/uploads\//, '');
    if (!rel || rel.includes('..')) return null;
    const file = path.join(this.uploadDir, ...rel.split('/'));
    return file.startsWith(this.uploadDir + path.sep) ? file : null;
  }

  /**
   * 读源图字节：跟随「当前激活存储」。
   * 激活=远端（七牛/R2…）→ 先读远端，缺失时回落本地磁盘（迁移过渡期旧文件仍在本地）；
   * 激活=本地 → 只读本地磁盘。
   */
  private async readSourceBytes(storageKey: string): Promise<Buffer | null> {
    if (getActiveId() !== 'local') {
      try {
        return await activeStorageAdapter.readBuffer(storageKey);
      } catch {
        // 远端缺失/读取失败 → 本地兜底
      }
    }
    const file = this.localFilePath(storageKey);
    if (file && fs.existsSync(file)) {
      try {
        return fs.readFileSync(file);
      } catch {
        return null;
      }
    }
    return null;
  }

  /** 定位某分类图标源图（DB 拿文件名 → 读源图字节），找不到返回 null */
  private async resolveIconSource(key: string): Promise<{ data: Buffer; filename: string } | null> {
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
    const data = await this.readSourceBytes(`/uploads/categories/${key}/${filename}`);
    return data ? { data, filename } : null;
  }

  // ===== 缩略图存储键（客户端按同一规则推导直连 URL）=====

  private templateThumbKey(templateId: string, filename: string, width: number): string {
    const base = path.basename(filename, path.extname(filename));
    return `/uploads/thumbs/templates/${templateId}/${base}.w${width}.webp`;
  }

  private categoryThumbKey(key: string, width: number): string {
    return `/uploads/thumbs/categories/${key}/w${width}.jpg`;
  }

  /**
   * 读已持久化的缩略图字节：本地磁盘缓存 → 激活存储。
   * 两级都 miss 返回 null（由调用方走生成链路）。
   */
  private async readPersistedThumb(thumbKey: string): Promise<Buffer | null> {
    const file = this.localFilePath(thumbKey);
    if (file && fs.existsSync(file)) {
      try {
        return fs.readFileSync(file);
      } catch {
        // 读盘失败 → 继续查远端
      }
    }
    if (getActiveId() !== 'local') {
      try {
        return await activeStorageAdapter.readBuffer(thumbKey);
      } catch {
        // 远端缺失 → 走生成
      }
    }
    return null;
  }

  /**
   * 持久化缩略图：写入激活存储（客户端直连的来源）+ 本地磁盘缓存（后端读链路兜底）。
   * 任一步失败都静默跳过，不影响本次响应。
   */
  private async persistThumb(thumbKey: string, data: Buffer): Promise<void> {
    // thumbKey 形如 /uploads/thumbs/{group}/{id}/{filename}，换算为 write(category, id, filename)
    const rel = thumbKey.replace(/^\/uploads\/thumbs\//, '');
    const parts = rel.split('/');
    const filename = parts.pop();
    const id = parts.join('/');
    if (!filename || !id) return;
    try {
      await activeStorageAdapter.write('thumbs', id, filename, data);
    } catch {
      // 远端写失败不影响响应（本地缓存仍会写）
    }
    const file = this.localFilePath(thumbKey);
    if (file) {
      try {
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, data);
      } catch {
        // 缩略图写盘失败不影响本次响应
      }
    }
  }

  /** sharp 生成单张缩略图；源图解码失败返回 null */
  private async renderThumb(source: Buffer, width: number, format: 'webp' | 'jpeg'): Promise<Buffer | null> {
    try {
      const pipeline = sharp(source, { failOn: 'error' })
        .rotate()
        .resize({ width, withoutEnlargement: true });
      return format === 'webp'
        ? await pipeline.webp({ quality: 82 }).toBuffer()
        : await pipeline.jpeg({ quality: JPEG_QUALITY }).toBuffer();
    } catch {
      return null;
    }
  }

  // ===== 读链路（/api/v1/thumbs 端点，保留作按需兜底）=====

  /** 返回（或生成并持久化）分类图标的指定宽度 JPEG 缩略图 */
  async categoryIcon(key: string, rawWidth: string | number): Promise<ThumbResult> {
    const width = this.clampWidth(rawWidth);
    const thumbKey = this.categoryThumbKey(key, width);

    // 已持久化（本地缓存 / 激活存储）→ 直接返回，零 DB、零 CPU
    const cached = await this.readPersistedThumb(thumbKey);
    if (cached) return { data: cached, type: 'image/jpeg' };

    // 未命中才查 DB（只为了拿上传文件名），并懒生成（覆盖旧分类/迁移前数据）
    const src = await this.resolveIconSource(key);
    if (!src) throw new NotFoundException('category icon not found');

    // 与模板缩略图一致使用 sharp，确保 WebP 源图也能正常生成 JPEG 缩略图。
    // 若图片解码失败，回退返回原图。
    const buf = await this.renderThumb(src.data, width, 'jpeg');
    if (!buf) return { data: src.data, type: mimeOf(src.filename) };
    await this.persistThumb(thumbKey, buf);
    return { data: buf, type: 'image/jpeg' };
  }

  /** 返回（或生成并持久化）模板图的指定宽度 WebP 缩略图 */
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
    const thumbKey = this.templateThumbKey(templateId, filename, width);

    const cached = await this.readPersistedThumb(thumbKey);
    if (cached) return { data: cached, type: 'image/webp' };

    const source = await this.readSourceBytes(`/uploads/templates/${templateId}/${filename}`);
    if (!source) {
      throw new NotFoundException('template image not found');
    }

    const data = await this.renderThumb(source, width, 'webp');
    if (!data) return { data: source, type: mimeOf(filename) };
    await this.persistThumb(thumbKey, data);
    return { data, type: 'image/webp' };
  }

  // ===== 写链路（admin 保存时预生成，客户端直连存储域名）=====

  /**
   * 预生成某模板全部图片的阶梯宽度缩略图（写链路调用）。
   * 先删旧缩略图再生成，避免图片删减/替换后残留陈旧键。
   * 源图不存在（如复制场景引用他库图片）时跳过，由读链路兜底。
   */
  async ensureTemplateThumbs(templateId: string, filenames: string[]): Promise<void> {
    const valid = filenames.filter((f) => /^[a-z0-9][a-z0-9._-]*$/i.test(f));
    if (valid.length === 0) return;
    await this.deleteTemplateThumbs(templateId);
    const jobs: Promise<void>[] = [];
    for (const filename of valid) {
      const source = await this.readSourceBytes(`/uploads/templates/${templateId}/${filename}`);
      if (!source) continue;
      for (const w of THUMB_WIDTH_LADDER) {
        const width = this.clampWidth(w);
        jobs.push(
          this.renderThumb(source, width, 'webp').then((buf) => {
            if (buf) return this.persistThumb(this.templateThumbKey(templateId, filename, width), buf);
          }),
        );
      }
    }
    await Promise.all(jobs);
  }

  /** 预生成某分类图标的阶梯宽度缩略图（写链路调用；先删旧再生成） */
  async ensureCategoryThumbs(key: string): Promise<void> {
    if (!/^[a-z0-9][a-z0-9_-]*$/i.test(key)) return;
    const src = await this.resolveIconSource(key);
    if (!src) return;
    await this.deleteCategoryThumbs(key);
    const jobs = THUMB_WIDTH_LADDER.map(async (w) => {
      const width = this.clampWidth(w);
      const buf = await this.renderThumb(src.data, width, 'jpeg');
      if (buf) await this.persistThumb(this.categoryThumbKey(key, width), buf);
    });
    await Promise.all(jobs);
  }

  /** 删除某模板的缩略图（激活存储 + 本地磁盘） */
  async deleteTemplateThumbs(templateId: string): Promise<void> {
    if (!/^[a-z0-9][a-z0-9_-]*$/i.test(templateId)) return;
    await this.deleteThumbDir(`templates/${templateId}`);
  }

  /** 删除某分类的缩略图（激活存储 + 本地磁盘） */
  async deleteCategoryThumbs(key: string): Promise<void> {
    if (!/^[a-z0-9][a-z0-9_-]*$/i.test(key)) return;
    await this.deleteThumbDir(`categories/${key}`);
  }

  private async deleteThumbDir(relativeId: string): Promise<void> {
    try {
      await activeStorageAdapter.deleteByDir('thumbs', relativeId);
    } catch {
      // 远端删除失败不影响后续（本地仍会清）
    }
    const dir = path.join(this.uploadDir, 'thumbs', ...relativeId.split('/'));
    if (fs.existsSync(dir)) {
      try {
        fs.rmSync(dir, { recursive: true, force: true });
      } catch {
        // 忽略
      }
    }
  }
}
