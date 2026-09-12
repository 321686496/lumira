// lumira-server/packages/backend/src/modules/banners/banners.service.ts
import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { RedisService } from '../../common/redis/redis.service';
import { STORAGE_ADAPTER } from '../../common/storage/storage.provider';
import { buildAssetUrl } from '../../common/storage/asset-url';
import type { StorageAdapter } from '../../common/storage/storage-adapter.interface';
import { ImageCompressionService } from '../../common/storage/image-compression.service';
import { operationBanners } from '../../database/schema';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

/** App 端列表缓存 TTL：写操作即时失效，正常最多延迟 60s 生效 */
const LIST_CACHE_TTL = 60;
const LIST_CACHE_KEY = 'lumira:cache:bannerList';

/** Banner 配图上传：格式白名单与大小上限（与后台 FileUpload 组件限制一致） */
const BANNER_IMAGE_MIME_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};
const BANNER_IMAGE_MAX_BYTES = 2 * 1024 * 1024;

const clampFocus = (value: number | undefined, min: number, max: number, fallback: number) => {
  if (typeof value !== 'number' || Number.isNaN(value)) return fallback;
  return Math.min(max, Math.max(min, value));
};

@Injectable()
export class BannersService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly redisService: RedisService,
    @Inject(STORAGE_ADAPTER) private readonly storage: StorageAdapter,
    private readonly imageCompression: ImageCompressionService,
  ) {}

  /** 写操作后统一失效列表缓存（后台改配置 → App 端即刻可见） */
  private async invalidateListCache(): Promise<void> {
    await this.redisService.delByPattern('lumira:cache:bannerList*');
  }

  /** App 端：启用中的运营条目（顺序即优先级），只暴露渲染所需字段 */
  async listForApp() {
    const cached = await this.redisService.getJson<{ banners: unknown[] }>(LIST_CACHE_KEY);
    if (cached !== null) return cached;

    const db = this.dbService.getDb();
    const rows = await db.select()
      .from(operationBanners)
      .where(eq(operationBanners.isActive, 1))
      .orderBy(asc(operationBanners.sortOrder), asc(operationBanners.createdAt));
    const result = {
      banners: rows.map((r) => ({
        id: r.id,
        title: r.title,
        subtitle: r.subtitle,
        tag: r.tag,
        route: r.route,
        // 目标模板 id（route=/templates/detail 时 App 用于拼详情页跳转）
        templateId: r.templateId,
        // 配图完整 URL（空串 = 无配图，App 回退品牌渐变背景）
        imageUrl: buildAssetUrl(r.imageUrl),
        focusX: r.focusX ?? 0.5,
        focusY: r.focusY ?? 0.5,
        focusZoom: r.focusZoom ?? 1,
        condition: r.condition,
      })),
    };
    await this.redisService.setJson(LIST_CACHE_KEY, result, LIST_CACHE_TTL);
    return result;
  }

  // ===== 后台 Admin CRUD =====

  /** 后台：全部条目（含停用与审计字段）；imageUrl 规整为完整 URL 便于预览 */
  async listAdmin() {
    const db = this.dbService.getDb();
    const rows = await db.select()
      .from(operationBanners)
      .orderBy(asc(operationBanners.sortOrder), asc(operationBanners.createdAt));
    return rows.map((r) => ({ ...r, imageUrl: buildAssetUrl(r.imageUrl) }));
  }

  async create(dto: CreateBannerDto) {
    const db = this.dbService.getDb();
    const id = dto.id || `op-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    if (dto.id) {
      const existing = await db.select().from(operationBanners).where(eq(operationBanners.id, id)).limit(1);
      if (existing.length > 0) throw new ConflictException(`Banner id already exists: ${id}`);
    }
    const now = Math.floor(Date.now() / 1000);
    await db.insert(operationBanners).values({
      id,
      title: dto.title,
      subtitle: dto.subtitle,
      tag: dto.tag,
      route: dto.route,
      templateId: dto.templateId ?? null,
      imageUrl: dto.imageUrl || null,
      focusX: clampFocus(dto.focusX, 0, 1, 0.5),
      focusY: clampFocus(dto.focusY, 0, 1, 0.5),
      focusZoom: clampFocus(dto.focusZoom, 1, 3, 1),
      condition: dto.condition,
      isActive: dto.isActive === false ? 0 : 1,
      sortOrder: dto.sortOrder ?? 0,
      createdAt: now,
      updatedAt: now,
    });
    await this.invalidateListCache();
    return (await this.getById(id))!;
  }

  async update(id: string, dto: UpdateBannerDto) {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    const patch: Record<string, unknown> = { updatedAt: Math.floor(Date.now() / 1000) };
    if (dto.title !== undefined) patch.title = dto.title;
    if (dto.subtitle !== undefined) patch.subtitle = dto.subtitle;
    if (dto.tag !== undefined) patch.tag = dto.tag;
    if (dto.route !== undefined) patch.route = dto.route;
    if ('templateId' in dto) patch.templateId = dto.templateId || null;
    // imageUrl：null/空串清除配图，其余原样存（storageKey 或完整 URL）
    if (dto.imageUrl !== undefined) patch.imageUrl = dto.imageUrl || null;
    if (dto.focusX !== undefined) patch.focusX = clampFocus(dto.focusX, 0, 1, 0.5);
    if (dto.focusY !== undefined) patch.focusY = clampFocus(dto.focusY, 0, 1, 0.5);
    if (dto.focusZoom !== undefined) patch.focusZoom = clampFocus(dto.focusZoom, 1, 3, 1);
    if (dto.condition !== undefined) patch.condition = dto.condition;
    if (dto.isActive !== undefined) patch.isActive = dto.isActive ? 1 : 0;
    if (dto.sortOrder !== undefined) patch.sortOrder = dto.sortOrder;
    await db.update(operationBanners).set(patch).where(eq(operationBanners.id, id));
    await this.invalidateListCache();
    return (await this.getById(id))!;
  }

  async remove(id: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    await db.delete(operationBanners).where(eq(operationBanners.id, id));
    await this.invalidateListCache();
    return { success: true };
  }

  async toggleActive(id: string): Promise<{ id: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const row = await this.requireExists(id);
    const next = row.isActive ? 0 : 1;
    await db.update(operationBanners)
      .set({ isActive: next, updatedAt: Math.floor(Date.now() / 1000) })
      .where(eq(operationBanners.id, id));
    await this.invalidateListCache();
    return { id, isActive: next === 1 };
  }

  // ===== 配图上传 =====

  /**
   * 上传 Banner 配图（multipart file 字段）。
   * 存储：{UPLOAD_DIR}/banners/{随机id}/image.{ext}；返回 App 可访问的完整 URL。
   * 上传与 Banner 保存解耦（选中即传，保存时随 payload 落库），
   * 未保存的孤儿文件由后续清理任务兜底（见 future-optimizations）。
   */
  async uploadImage(buffer: Buffer, mimetype: string): Promise<{ url: string }> {
    const ext = BANNER_IMAGE_MIME_EXT[mimetype];
    if (!ext) {
      throw new BadRequestException(`不支持的图片格式（仅 jpg/png/webp）：${mimetype || 'unknown'}`);
    }
    if (buffer.length > BANNER_IMAGE_MAX_BYTES) {
      throw new BadRequestException('图片超过 2MB 上限');
    }
    const compressed = await this.imageCompression.compress(buffer, `image.${ext}`, mimetype);
    const subId = `bnr-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const storageKey = await this.storage.write('banners', subId, `image.${compressed.ext}`, compressed.buffer);
    return { url: buildAssetUrl(storageKey) };
  }

  private async getById(id: string) {
    const db = this.dbService.getDb();
    const rows = await db.select().from(operationBanners).where(eq(operationBanners.id, id)).limit(1);
    return rows.length > 0 ? { ...rows[0], imageUrl: buildAssetUrl(rows[0].imageUrl) } : null;
  }

  private async requireExists(id: string) {
    const row = await this.getById(id);
    if (!row) throw new NotFoundException(`Banner not found: ${id}`);
    return row;
  }
}
