// lumira-server/packages/backend/src/modules/templates/templates.service.ts

import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, or, gt, asc, desc, sql, inArray, type SQL } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { ownedTemplates, templatePrices, templates, templateCategories } from '../../database/schema';
import { PointsService } from '../points/points.service';
import { buildAssetUrl } from '../../common/storage/asset-url';
import type {
  RemoteTemplateMeta,
  RemoteTemplateListResponse,
  RemoteTemplateDetail,
  TemplateCategory,
  TemplateAmbience,
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
  async exchange(deviceId: string, templateId: string, priceCredits?: number) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 整体事务：已拥有检查 + 定价 + 扣积分 + 写入 owned
    // 任一环节失败（已拥有 / 余额不足 / 无定价记录）则整体回滚
    return db.transaction(async (tx) => {
      // 1. 幂等检查（必须先于定价：已拥有 → 409，不落任何定价记录，
      //    防止重复/失败请求用上报值污染 template_prices）
      const ownedRows = await tx.select().from(ownedTemplates)
        .where(and(
          eq(ownedTemplates.deviceId, deviceId),
          eq(ownedTemplates.templateId, templateId),
        ));
      if (ownedRows.length > 0) {
        throw new ConflictException('Template already owned');
      }

      // 2. 定价：srv_ 前缀（后端远程模板）以 template_prices 记录为准（防篡改）；
      //    非 srv_ 前缀（本地内置模板）以客户端上报 priceCredits 为准，并 UPSERT 记录定价
      let price: number;
      if (templateId.startsWith('srv_')) {
        const priceRows = await tx.select().from(templatePrices)
          .where(and(
            eq(templatePrices.templateId, templateId),
            eq(templatePrices.isActive, 1),
          ));
        const record = priceRows[0];
        if (!record) {
          throw new NotFoundException('Template not available for exchange');
        }
        price = record.priceCredits;
      } else {
        if (priceCredits === undefined || !Number.isInteger(priceCredits) || priceCredits < 1) {
          throw new BadRequestException(
            'priceCredits must be a positive integer for builtin template',
          );
        }
        price = priceCredits;
        await tx.insert(templatePrices)
          .values({ templateId, priceCredits: price, isActive: 1, updatedAt: now })
          .onDuplicateKeyUpdate({
            set: { priceCredits: price, isActive: 1, updatedAt: now },
          });
      }

      // 3. 扣积分（余额不足抛 BadRequestException，事务回滚）
      const newBalance = await this.pointsService.spendPointsSync(
        tx,
        deviceId,
        price,
        'exchange_template',
        templateId,
      );

      // 4. 写入拥有记录
      await tx.insert(ownedTemplates).values({
        deviceId,
        templateId,
        source: 'points',
        sourceDetail: `credits:${price}`,
        unlockedAt: now,
      });

      return {
        success: true,
        templateId,
        spentCredits: price,
        balance: newBalance,
      };
    });
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
    });
    return true;
  }

  // ===== 客户端：后端动态模板列表 / 详情 / 分类（spec 3.2）=====

  /**
   * 客户端拉取后端动态模板 meta 列表（仅 isActive=1）。
   * @param subtreeKeys 可选的子树 key 集合（含自身及所有后代 key）：
   *   模板任一 classification 字段（type/majorStyle/subStyle/method）或 category 命中集合即返回，
   *   用于「该分类族内所有后代挂的模板」的查询（四级分类钻取）。
   */
  async listRemoteTemplates(
    since?: number,
    category?: string,
    subtreeKeys?: string[],
  ): Promise<RemoteTemplateListResponse> {
    const db = this.dbService.getDb();

    // 构建条件：isActive=1 + 可选 since + 可选 category / 可选 subtree 集合
    const conditions = [eq(templates.isActive, 1)];
    if (since !== undefined && !Number.isNaN(since)) {
      conditions.push(gt(templates.updatedAt, since));
    }
    if (subtreeKeys && subtreeKeys.length > 0) {
      // 子树集合匹配：任一 classification 字段命中集合即算（含 category 直接命中）
      const keyList = sql.join(subtreeKeys.map((k) => sql`${k}`), sql`, `) as SQL;
      const jsonIn = (field: string) => sql`JSON_UNQUOTE(JSON_EXTRACT(${templates.classificationJson}, ${field})) IN (${keyList})`;
      conditions.push(or(
        inArray(templates.category, subtreeKeys),
        jsonIn('$.type'),
        jsonIn('$.majorStyle'),
        jsonIn('$.subStyle'),
        jsonIn('$.method'),
      ) as SQL);
    } else if (category) {
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

  /** 客户端拉取单个模板完整内容（5 段）*/
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

// ===== 表 → DTO 映射函数（模块内共享）=====

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
    coverUrl: buildAssetUrl(row.coverUrl),
    description: row.description,
    referenceSource: row.referenceSource,
    tags: safeParseStringArray(row.tagsJson),
    tagIds: safeParseStringArray(row.tagIdsJson),
    classification: safeParseClassification(row.classificationJson),
    ambience: parseAmbience(row.ambienceJson),
    shortDesc: row.shortDesc ?? '',
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
    if (typeof s.url === 'string') s.url = buildAssetUrl(s.url);
    if (typeof s.data === 'string') s.data = buildAssetUrl(s.data);
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
    iconUrl: buildAssetUrl(row.iconUrl),
    description: row.description ?? '',
    parentKey: row.parentKey,
    level: row.level,
    sortOrder: row.sortOrder,
    isSystem: row.isSystem === 1,
    isActive: row.isActive === 1,
    updatedAt: row.updatedAt,
  };
}

/**
 * 安全解析 JSON 对象。
 */
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

function safeParseClassification(json: string): { type: string; majorStyle: string; subStyle: string; method: string } {
  const obj = safeParseObject(json);
  return {
    type: typeof obj.type === 'string' ? obj.type : '',
    majorStyle: typeof obj.majorStyle === 'string' ? obj.majorStyle : '',
    subStyle: typeof obj.subStyle === 'string' ? obj.subStyle : '',
    method: typeof obj.method === 'string' ? obj.method : '',
  };
}

/** 清洗入口 ambience 输入为标准三数组结构（非法值丢弃） */
export function sanitizeAmbience(input: unknown): TemplateAmbience {
  const obj =
    input && typeof input === 'object' && !Array.isArray(input)
      ? (input as Record<string, unknown>)
      : {};
  const strArr = (v: unknown): string[] =>
    Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
  return {
    seasons: strArr(obj['seasons']) as TemplateAmbience['seasons'],
    weathers: strArr(obj['weathers']) as TemplateAmbience['weathers'],
    timeTones: strArr(obj['timeTones']) as TemplateAmbience['timeTones'],
  };
}

/** 解析 ambience_json 列（失败回退空结构） */
export function parseAmbience(json: string): TemplateAmbience {
  try {
    const v = JSON.parse(json);
    if (v && typeof v === 'object' && !Array.isArray(v)) return sanitizeAmbience(v);
  } catch {
    /* 非法 JSON 回退空结构 */
  }
  return { seasons: [], weathers: [], timeTones: [] };
}
