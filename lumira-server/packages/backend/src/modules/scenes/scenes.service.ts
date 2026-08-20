import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { asc, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { systemScenes } from '../../database/schema';
import { UsageService } from '../usage/usage.service';
import { CreateSceneDto } from './dto/create-scene.dto';
import { UpdateSceneDto } from './dto/update-scene.dto';
import type { SystemScene } from '@lumira/shared';

@Injectable()
export class ScenesService {
  constructor(private readonly dbService: DatabaseService, private readonly usageService: UsageService) {}

  private toScene(row: Record<string, unknown>): SystemScene {
    return {
      id: String(row.id),
      name: String(row.name),
      category: String(row.category),
      style: String(row.style ?? ''),
      icon: String(row.icon ?? ''),
      vibe: String(row.vibe ?? ''),
      description: String(row.description ?? ''),
      filter: safeParse(row.filter_json),
      tips: safeJsonArray(row.tips_json),
      exampleImages: safeJsonArray(row.example_images_json),
      whereToShoot: String(row.where_to_shoot ?? ''),
      bestTime: String(row.best_time ?? ''),
      relatedCategory: String(row.related_category ?? ''),
      recommendedTagIds: safeJsonArray(row.recommended_tag_ids_json),
      sortOrder: Number(row.sort_order ?? 0),
      isActive: Number(row.is_active ?? 1) === 1,
      updatedAt: Number(row.updated_at ?? 0),
    };
  }

  /** 客户端：返回启用场景 + 对应使用次数 */
  async listActive(): Promise<{ scenes: Array<SystemScene & { usage: { useShoot: number; openDetail: number; sceneSelect: number } }> }> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(systemScenes)
      .where(sql`${systemScenes.isActive} = 1`)
      .orderBy(asc(systemScenes.sortOrder));
    const stats = await this.usageService.stats('scene');
    const statsMap = new Map(stats.items.map((i) => [i.itemId, i]));
    return {
      scenes: rows.map((r) => {
        const u = statsMap.get(r.id);
        return { ...this.toScene(r), usage: { useShoot: u?.useShoot ?? 0, openDetail: u?.openDetail ?? 0, sceneSelect: u?.sceneSelect ?? 0 } };
      }),
    };
  }

  async listAdmin(): Promise<{ scenes: SystemScene[] }> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(systemScenes).orderBy(asc(systemScenes.sortOrder));
    return { scenes: rows.map((r) => this.toScene(r)) };
  }

  async create(dto: CreateSceneDto): Promise<SystemScene> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const existing = await db.select().from(systemScenes).where(sql`${systemScenes.id} = ${dto.id}`).limit(1);
    if (existing.length > 0) throw new ConflictException(`Scene id already exists: ${dto.id}`);
    const row = { ...dto, filterJson: dto.filter ? JSON.stringify(dto.filter) : '{}' };
    await db.insert(systemScenes).values({
      id: dto.id,
      name: dto.name,
      category: dto.category,
      style: dto.style ?? '',
      icon: dto.icon ?? '',
      vibe: dto.vibe ?? '',
      description: dto.description ?? '',
      filterJson: row.filterJson,
      tipsJson: JSON.stringify(dto.tips ?? []),
      exampleImagesJson: JSON.stringify(dto.exampleImages ?? []),
      whereToShoot: dto.whereToShoot ?? '',
      bestTime: dto.bestTime ?? '',
      relatedCategory: dto.relatedCategory ?? '',
      recommendedTagIdsJson: JSON.stringify(dto.recommendedTagIds ?? []),
      sortOrder: dto.sortOrder ?? 0,
      isActive: dto.isActive === false ? 0 : 1,
      createdAt: now,
      updatedAt: now,
    });
    return (await this.getById(dto.id))!;
  }

  async update(id: string, dto: UpdateSceneDto): Promise<SystemScene> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    const now = Math.floor(Date.now() / 1000);
    const patch: Record<string, unknown> = { updatedAt: now };
    for (const k of ['name', 'category', 'style', 'icon', 'vibe', 'description', 'whereToShoot', 'bestTime', 'relatedCategory'] as const) {
      if (dto[k] !== undefined) patch[k] = dto[k];
    }
    if (dto.filter !== undefined) patch.filterJson = JSON.stringify(dto.filter);
    if (dto.tips !== undefined) patch.tipsJson = JSON.stringify(dto.tips);
    if (dto.exampleImages !== undefined) patch.exampleImagesJson = JSON.stringify(dto.exampleImages);
    if (dto.recommendedTagIds !== undefined) patch.recommendedTagIdsJson = JSON.stringify(dto.recommendedTagIds);
    if (dto.sortOrder !== undefined) patch.sortOrder = dto.sortOrder;
    if (dto.isActive !== undefined) patch.isActive = dto.isActive ? 1 : 0;
    await db.update(systemScenes).set(patch).where(sql`${systemScenes.id} = ${id}`);
    return (await this.getById(id))!;
  }

  async remove(id: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();
    await this.requireExists(id);
    await db.delete(systemScenes).where(sql`${systemScenes.id} = ${id}`);
    return { success: true };
  }

  async toggleActive(id: string): Promise<{ id: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const scene = await this.requireExists(id);
    const next = scene.isActive ? 0 : 1;
    await db.update(systemScenes).set({ isActive: next, updatedAt: Math.floor(Date.now() / 1000) }).where(sql`${systemScenes.id} = ${id}`);
    return { id, isActive: next === 1 };
  }

  private async getById(id: string): Promise<SystemScene | null> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(systemScenes).where(sql`${systemScenes.id} = ${id}`).limit(1);
    return rows.length > 0 ? this.toScene(rows[0]) : null;
  }
  private async requireExists(id: string): Promise<SystemScene> {
    const s = await this.getById(id);
    if (!s) throw new NotFoundException(`Scene not found: ${id}`);
    return s;
  }
}

function safeParse(json: unknown): Record<string, unknown> {
  if (typeof json !== 'string' || !json) return {};
  try { return JSON.parse(json); } catch { return {}; }
}
function safeJsonArray(json: unknown): string[] {
  if (typeof json !== 'string' || !json) return [];
  try { const v = JSON.parse(json); return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : []; } catch { return []; }
}