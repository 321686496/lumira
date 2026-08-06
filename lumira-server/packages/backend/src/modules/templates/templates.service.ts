// lumira-server/packages/backend/src/modules/templates/templates.service.ts

import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, gt, asc, desc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { ownedTemplates, templatePrices, templates, templateCategories } from '../../database/schema';
import { PointsService } from '../points/points.service';
import type {
  RemoteTemplateMeta,
  RemoteTemplateListResponse,
  RemoteTemplateDetail,
  TemplateCategory,
} from '@lumira/shared';

@Injectable()
export class TemplatesService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly pointsService: PointsService,
  ) {}

  /** 查询设备已拥有的模板 id 列表 */
  async listOwned(deviceId: string) {
    const db = this.dbService.getDb();
    const rows = await db.query.ownedTemplates.findMany({
      where: eq(ownedTemplates.deviceId, deviceId),
      orderBy: (t, { desc }) => [desc(t.unlockedAt)],
    });
    return {
      templateIds: rows.map((r) => r.templateId),
      records: rows.map((r) => ({
        id: r.id,
        templateId: r.templateId,
        source: r.source as 'redemption' | 'points' | 'invite' | 'admin_grant',
        sourceDetail: r.sourceDetail,
        unlockedAt: r.unlockedAt,
      })),
    };
  }

  /** 查询所有模板积分定价 */
  async listPrices() {
    const db = this.dbService.getDb();
    const rows = await db.query.templatePrices.findMany({
      where: eq(templatePrices.isActive, 1),
    });
    return {
      prices: rows.map((r) => ({
        templateId: r.templateId,
        priceCredits: r.priceCredits,
        isActive: r.isActive === 1,
      })),
    };
  }

  /** 积分兑换模板 */
  async exchange(deviceId: string, templateId: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 查定价
    const price = await db.query.templatePrices.findFirst({
      where: and(
        eq(templatePrices.templateId, templateId),
        eq(templatePrices.isActive, 1),
      ),
    });
    if (!price) {
      throw new NotFoundException('Template not available for exchange');
    }

    // 2. 检查是否已拥有（幂等：已拥有则直接返回成功）
    const existing = await db.query.ownedTemplates.findFirst({
      where: and(
        eq(ownedTemplates.deviceId, deviceId),
        eq(ownedTemplates.templateId, templateId),
      ),
    });
    if (existing) {
      throw new ConflictException('Template already owned');
    }

    // 3. 扣积分（余额不足会抛 BadRequestException）
    const newBalance = await this.pointsService.spendPoints(
      deviceId,
      price.priceCredits,
      'exchange_template',
      templateId,
    );

    // 4. 写入拥有记录
    await db.insert(ownedTemplates).values({
      deviceId,
      templateId,
      source: 'points',
      sourceDetail: `credits:${price.priceCredits}`,
      unlockedAt: now,
    }).run();

    return {
      success: true,
      templateId,
      spentCredits: price.priceCredits,
      balance: newBalance,
    };
  }

  /**
   * 内部方法：直接授予模板拥有权（供兑换码/邀请奖励调用，不扣积分）
   * 幂等：已拥有则跳过
   */
  async grantTemplate(
    deviceId: string,
    templateId: string,
    source: 'redemption' | 'invite' | 'admin_grant',
    sourceDetail: string | null = null,
  ): Promise<boolean> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 幂等检查
    const existing = await db.query.ownedTemplates.findFirst({
      where: and(
        eq(ownedTemplates.deviceId, deviceId),
        eq(ownedTemplates.templateId, templateId),
      ),
    });
    if (existing) {
      return false; // 已拥有，未实际写入
    }

    await db.insert(ownedTemplates).values({
      deviceId,
      templateId,
      source,
      sourceDetail,
      unlockedAt: now,
    }).run();
    return true;
  }

  // ===== 客户端：后端动态模板列表 / 详情 / 分类（spec 3.2）=====

  /** 客户端拉取后端动态模板 meta 列表（仅 isActive=1） */
  async listRemoteTemplates(since?: number, category?: string): Promise<RemoteTemplateListResponse> {
    const db = this.dbService.getDb();

    // 构建条件：isActive=1 + 可选 since + 可选 category
    const conditions = [eq(templates.isActive, 1)];
    if (since !== undefined && !Number.isNaN(since)) {
      conditions.push(gt(templates.updatedAt, since));
    }
    if (category) {
      conditions.push(eq(templates.category, category));
    }

    const rows = await db.select().from(templates)
      .where(and(...conditions))
      .orderBy(asc(templates.sortOrder), desc(templates.updatedAt));

    const metas = rows.map(rowToMeta);
    const serverUpdatedAt = metas.length > 0
      ? metas.reduce((max, m) => Math.max(max, m.updatedAt), 0)
      : Math.floor(Date.now() / 1000);

    return { templates: metas, serverUpdatedAt };
  }

  /** 客户端拉取单个模板完整内容（5 段） */
  async getRemoteTemplateDetail(id: string): Promise<RemoteTemplateDetail> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templates).where(eq(templates.id, id)).limit(1);
    const row = rows[0];
    if (!row) {
      throw new NotFoundException('Template not found');
    }
    return rowToDetail(row);
  }
}

// ===== 行 → DTO 映射函数（模块内共享）=====

type TemplateRow = typeof templates.$inferSelect;
type CategoryRow = typeof templateCategories.$inferSelect;

export function rowToMeta(row: TemplateRow): RemoteTemplateMeta {
  return {
    id: row.id,
    name: row.name,
    author: row.author,
    version: row.version,
    category: row.category,
    price: row.price,
    coverUrl: normalizeAssetUrl(row.coverUrl),
    description: row.description,
    referenceSource: row.referenceSource,
    tags: safeParseStringArray(row.tagsJson),
    tagIds: safeParseStringArray(row.tagIdsJson),
    classification: safeParseClassification(row.classificationJson),
    sortOrder: row.sortOrder,
    updatedAt: row.updatedAt,
  };
}

export function rowToDetail(row: TemplateRow): RemoteTemplateDetail {
  const pose = safeParseObject(row.poseJson);
  const silhouette = pose.silhouette;
  if (silhouette && typeof silhouette === 'object') {
    const s = silhouette as Record<string, unknown>;
    // 旧数据修复：剪影 URL 可能在 BACKEND_PUBLIC_URL 配置前写入，前缀为 localhost
    if (typeof s.url === 'string') s.url = normalizeAssetUrl(s.url);
    if (typeof s.data === 'string') s.data = normalizeAssetUrl(s.data);
  }
  return {
    ...rowToMeta(row),
    composition: safeParseObject(row.compositionJson),
    pose,
    camera: safeParseObject(row.cameraJson),
    sceneGuide: safeParseObject(row.sceneGuideJson),
    postProcess: safeParseObject(row.postProcessJson),
  };
}

export function rowToCategory(row: CategoryRow): TemplateCategory {
  return {
    key: row.key,
    name: row.name,
    iconUrl: normalizeAssetUrl(row.iconUrl),
    parentKey: row.parentKey,
    level: row.level,
    sortOrder: row.sortOrder,
    isSystem: row.isSystem === 1,
    isActive: row.isActive === 1,
    updatedAt: row.updatedAt,
  };
}

/**
 * 规范化静态资源 URL。
 *
 * 背景：`BACKEND_PUBLIC_URL` 配置前上传的模板/分类，数据库中的 coverUrl、
 * 剪影 url/data、iconUrl 前缀为 `http://localhost:3000`，App 端无法访问。
 * 这里在返回客户端前将 localhost/127.0.0.1 前缀替换为当前 `BACKEND_PUBLIC_URL`，
 * 保证旧数据也能被 App 正常加载（不依赖手动改库）。
 */
function normalizeAssetUrl(url: string | null | undefined): string {
  if (!url) return url || '';
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//i.test(url)) {
    const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
    return url.replace(/^https?:\/\/[^/]+/, base);
  }
  return url;
}

function safeParseObject(json: string): Record<string, unknown> {
  try {
    const v = JSON.parse(json);
    return v && typeof v === 'object' && !Array.isArray(v)
      ? v as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

function safeParseStringArray(json: string): string[] {
  try {
    const v = JSON.parse(json);
    return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

function safeParseClassification(json: string): { type: string; style: string; method: string } {
  const obj = safeParseObject(json);
  return {
    type: typeof obj.type === 'string' ? obj.type : '',
    style: typeof obj.style === 'string' ? obj.style : '',
    method: typeof obj.method === 'string' ? obj.method : '',
  };
}
