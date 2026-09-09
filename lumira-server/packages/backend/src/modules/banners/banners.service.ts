// lumira-server/packages/backend/src/modules/banners/banners.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { RedisService } from '../../common/redis/redis.service';
import { operationBanners } from '../../database/schema';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

/** App 端列表缓存 TTL：写操作即时失效，正常最多延迟 60s 生效 */
const LIST_CACHE_TTL = 60;
const LIST_CACHE_KEY = 'lumira:cache:bannerList';

@Injectable()
export class BannersService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly redisService: RedisService,
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
        condition: r.condition,
      })),
    };
    await this.redisService.setJson(LIST_CACHE_KEY, result, LIST_CACHE_TTL);
    return result;
  }

  // ===== 后台 Admin CRUD =====

  /** 后台：全部条目（含停用与审计字段） */
  async listAdmin() {
    const db = this.dbService.getDb();
    return db.select()
      .from(operationBanners)
      .orderBy(asc(operationBanners.sortOrder), asc(operationBanners.createdAt));
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

  private async getById(id: string) {
    const db = this.dbService.getDb();
    const rows = await db.select().from(operationBanners).where(eq(operationBanners.id, id)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }

  private async requireExists(id: string) {
    const row = await this.getById(id);
    if (!row) throw new NotFoundException(`Banner not found: ${id}`);
    return row;
  }
}
