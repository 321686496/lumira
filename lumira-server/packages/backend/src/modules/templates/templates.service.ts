// lumira-server/packages/backend/src/modules/templates/templates.service.ts

import { Injectable, NotFoundException, BadRequestException, ConflictException, HttpException, HttpStatus } from '@nestjs/common';
import { eq, and, or, asc, desc, sql, inArray, type SQL } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { ownedTemplates, templatePrices, templates, templateCategories } from '../../database/schema';
import { PointsService } from '../points/points.service';
import { UsageService } from '../usage/usage.service';
import { buildAssetUrl } from '../../common/storage/asset-url';
import { RedisService } from '../../common/redis/redis.service';
import type {
  RemoteTemplateMeta,
  RemoteTemplateListResponse,
  RemoteTemplateDetail,
  TemplateCategory,
  TemplateAmbience,
  TemplateImage,
  TemplatePose,
  TemplateClassification,
  TemplateSearchSort,
  TemplateSearchResponse,
} from '@lumira/shared';

@Injectable()
export class TemplatesService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly pointsService: PointsService,
    private readonly redisService: RedisService,
    private readonly usageService: UsageService,
  ) {}

  /**
   * 模板搜索（客户端实时搜索线上模板）。
   *
   * 性能/QPS 设计：
   * - 把「活跃模板全集 + 每项全站热度」整体物化到 Redis（key `lumira:cache:templateSearch:base`，
   *   TTL 120s），搜索命中该 base 后在内存过滤/排序/分页，几乎不打 DB。
   * - 全站热度聚合（GROUP BY usage_events）只在 base 过期重建时执行一次，
   *   避免每次搜索都对大表聚合（这是 /usage/stats 的瓶颈）。
   * - Admin 写模板后通过 `lumira:cache:templateSearch:*` 失效，下次请求惰性重建。
   * - 单设备轻量限流（60 次/分钟）防刷，配合客户端防抖进一步降低 QPS。
   */
  async searchTemplates(params: {
    deviceId: string;
    q: string;
    sort: TemplateSearchSort;
    category?: string;
    page: number;
    pageSize: number;
  }): Promise<TemplateSearchResponse> {
    await this.checkSearchRateLimit(params.deviceId);

    const items = await this.getSearchBase();
    const q = params.q.trim().toLowerCase();

    // 关键词过滤：多字段不区分大小写子串匹配（name/author/category/description/tags）
    let matched = items;
    if (q) {
      matched = items.filter((it) => {
        const base = it.base;
        if (base.name.toLowerCase().includes(q)) return true;
        if (base.author.toLowerCase().includes(q)) return true;
        if (base.category.toLowerCase().includes(q)) return true;
        if (base.description.toLowerCase().includes(q)) return true;
        return base.tags.some((t) => t.toLowerCase().includes(q));
      });
    }

    // 分类子树/分类 key 过滤（可选）
    if (params.category) {
      matched = matched.filter((it) => it.base.category === params.category);
    }

    // 排序（后端统一按全站数据排序，客户端无需二次排序）
    const sorted = [...matched];
    switch (params.sort) {
      case 'latest':
        sorted.sort((a, b) => b.meta.updatedAt - a.meta.updatedAt);
        break;
      case 'hot':
        sorted.sort((a, b) => b.hotScore - a.hotScore || b.meta.updatedAt - a.meta.updatedAt);
        break;
      case 'photos':
        sorted.sort((a, b) => b.shootCount - a.shootCount || a.base.name.localeCompare(b.base.name));
        break;
      case 'name':
        sorted.sort((a, b) => (a.base.name || '').localeCompare(b.base.name || '', 'zh-CN'));
        break;
      case 'comprehensive':
      default:
        sorted.sort((a, b) => a.base.sortOrder - b.base.sortOrder || b.meta.updatedAt - a.meta.updatedAt);
        break;
    }

    const total = sorted.length;
    const offset = (params.page - 1) * params.pageSize;
    const pageItems = sorted.slice(offset, offset + params.pageSize);
    return {
      items: pageItems.map((it) => ({
        ...it.meta,
        hotScore: it.hotScore,
        shootCount: it.shootCount,
        openCount: it.openCount,
      })),
      total,
      page: params.page,
      pageSize: params.pageSize,
    };
  }

  /** 从 Redis 读取（或重建）搜索 base：活跃模板 meta + 全站热度。 */
  private async getSearchBase(): Promise<SearchBaseItem[]> {
    const key = 'lumira:cache:templateSearch:base';
    const cached = await this.redisService.getJson<SearchBaseItem[]>(key);
    if (cached !== null) return cached;

    const db = this.dbService.getDb();
    // 列裁剪：只投影 meta 所需列，不把 5 段 longtext 从 MySQL 拉回内存（见 TEMPLATE_META_SELECT）
    const rows = await db.select(TEMPLATE_META_SELECT).from(templates)
      .where(eq(templates.isActive, 1))
      .orderBy(asc(templates.sortOrder), desc(templates.updatedAt));

    // 全站热度聚合（仅在 base 重建时执行一次；命中 usageStats 30s 缓存则零 DB）
    const stats = await this.usageService.stats('template');
    const statsMap = new Map(stats.items.map((i) => [i.itemId, i]));

    const base = rows.map((row): SearchBaseItem => {
      const shootCount = statsMap.get(row.id)?.useShoot ?? 0;
      const openCount = statsMap.get(row.id)?.openDetail ?? 0;
      return {
        meta: rowToMeta(row),
        base: {
          name: row.name,
          author: row.author,
          category: row.category,
          description: row.description,
          tags: safeParseStringArray(row.tagsJson),
          sortOrder: row.sortOrder,
        },
        // 热度 = 2×拍摄数 + 1×查看数（权重 2:1，用户确认）
        hotScore: shootCount * 2 + openCount,
        shootCount,
        openCount,
      };
    });

    // 重建成本已因列裁剪 + 热度缓存大幅下降，TTL 从 120s 提升到 300s 降低重建频率
    await this.redisService.setJson(key, base, 300);
    return base;
  }

  /** 单设备搜索限流（60 次/分钟），防止刷接口。 */
  private async checkSearchRateLimit(deviceId: string): Promise<void> {
    const rk = `lumira:ratelimit:${deviceId}:templateSearch`;
    const windowSec = 60;
    const limit = 60;
    if (!this.redisService.isEnabled()) return; // 降级放行（现状行为）
    // incrEx 单命令原子自增：并发请求无法绕过计数（第 61 次起返回 429）
    const cnt = await this.redisService.incrEx(rk, windowSec);
    if (cnt > limit) {
      throw new HttpException('rate_limited', HttpStatus.TOO_MANY_REQUESTS);
    }
  }

  /** 查询设备已拥有的模板 id 列表 */
  async listOwned(deviceId: string) {
    const key = `lumira:cache:ownedTemplates:${deviceId}`;
    const cached = await this.redisService.getJson<{ templateIds: string[]; records: Array<Record<string, unknown>> }>(key);
    if (cached !== null) return cached;

    const db = this.dbService.getDb();
    const rows = await db.query.ownedTemplates.findMany({
      where: eq(ownedTemplates.deviceId, deviceId),
      orderBy: (t, { desc }) => [desc(t.unlockedAt)],
    });
    const result = {
      templateIds: rows.map((r) => r.templateId),
      records: rows.map((r) => ({
        id: r.id,
        templateId: r.templateId,
        source: r.source as 'redemption' | 'points' | 'invite' | 'admin_grant',
        sourceDetail: r.sourceDetail,
        unlockedAt: r.unlockedAt,
      })),
    };

    await this.redisService.setJson(key, result, 120);
    return result;
  }

  /** 查询所有模板积分定价 */
  async listPrices() {
    const key = 'lumira:cache:templatePrices:list';
    const cached = await this.redisService.getJson<{ prices: { templateId: string; priceCredits: number; isActive: boolean }[] }>(key);
    if (cached !== null) return cached;

    const db = this.dbService.getDb();
    const rows = await db.query.templatePrices.findMany({
      where: eq(templatePrices.isActive, 1),
    });
    const result = {
      prices: rows.map((r) => ({
        templateId: r.templateId,
        priceCredits: r.priceCredits,
        isActive: r.isActive === 1,
      })),
    };

    await this.redisService.setJson(key, result, 600);
    return result;
  }

  /** 积分 / 免费解锁次数 兑换模板 */
  async exchange(
    deviceId: string,
    templateId: string,
    priceCredits?: number,
    payBy: 'points' | 'free_unlock' = 'points',
  ) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 整体事务：已拥有检查 + 定价 + 扣积分/扣免费解锁 + 写入 owned
    // 任一环节失败（已拥有 / 余额不足 / 无定价记录）则整体回滚
    const result = await db.transaction(async (tx) => {
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

      // 3. 支付：free_unlock → 扣 1 次免费解锁额度（任意价位模板均只耗 1 次，不耗积分）；
      //    points（默认）→ 扣积分（余额不足抛 BadRequestException，事务回滚）
      let newBalance: number | null = null;
      let freeUnlockLeft: number | null = null;
      let spentCredits = 0;
      if (payBy === 'free_unlock') {
        freeUnlockLeft = await this.pointsService.spendFreeUnlockSync(
          tx, deviceId, templateId,
        );
      } else {
        newBalance = await this.pointsService.spendPointsSync(
          tx,
          deviceId,
          price,
          'exchange_template',
          templateId,
        );
        spentCredits = price;
      }

      // 4. 写入拥有记录
      await tx.insert(ownedTemplates).values({
        deviceId,
        templateId,
        source: payBy === 'free_unlock' ? 'free_unlock' : 'points',
        sourceDetail: payBy === 'free_unlock'
          ? 'free_unlock'
          : `credits:${price}`,
        unlockedAt: now,
      });

      return {
        success: true,
        templateId,
        spentCredits,
        balance: newBalance,
        freeUnlockLeft,
        payBy,
      };
    });

    // 兑换可能 UPSERT 本地内置模板定价，失效定价缓存
    await this.redisService.delByPattern('lumira:cache:templatePrices:*');
    // 兑换变更余额与已拥有，失效对应用户热数据缓存
    await this.redisService.del(`lumira:cache:userPoints:${deviceId}`);
    await this.redisService.del(`lumira:cache:ownedTemplates:${deviceId}`);
    return result;
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
    // 变更已拥有，失效该设备缓存
    await this.redisService.del(`lumira:cache:ownedTemplates:${deviceId}`);
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
    // 缓存 key 按筛选维度（category × subtree）分 key，不含 since 时间戳 → 键数量从"无界"收敛为"有限组合数"；
    // 命中后 since 在内存过滤（缓存存的是整份筛选结果）。subtreeKeys 先 sort() 消除客户端顺序不稳定导致的 key 漂移。
    const scopeKey = `${category ?? ''}:${subtreeKeys ? [...subtreeKeys].sort().join('|') : ''}`;
    const key = `lumira:cache:templateList:list:${scopeKey}`;
    const result = await this.redisService.getJson<RemoteTemplateListResponse>(key);
    if (result !== null) {
      // 命中：since 在内存过滤
      let templates = result.templates;
      if (since !== undefined && !Number.isNaN(since)) {
        templates = templates.filter((m) => m.updatedAt > since);
      }
      return { templates, serverUpdatedAt: result.serverUpdatedAt };
    }

    const db = this.dbService.getDb();

    // 未命中：构建整份筛选列表（条件不含 since），并计算
    //   serverUpdatedAt = 源列表 max(updatedAt)（不代表 since 过滤后的子集，保证增量拉取不漏数据）
    const conditions = [eq(templates.isActive, 1)];
    if (subtreeKeys && subtreeKeys.length > 0) {
      // 子树集合匹配：任一 classification 字段命中集合即算（含 category 直接命中）
      const keyList = sql.join(subtreeKeys.map((k) => sql`${k}`), sql`, `) as SQL;
      const jsonIn = (field: string) => sql`JSON_UNQUOTE(JSON_EXTRACT(${templates.classificationJson}, ${field})) IN (${keyList})`;
      conditions.push(or(
        inArray(templates.category, subtreeKeys),
        jsonIn('$.type'),
        jsonIn('$.majorStyle'),
        jsonIn('$.style'),
        jsonIn('$.subStyle'),
        jsonIn('$.method'),
      ) as SQL);
    } else if (category) {
      conditions.push(eq(templates.category, category));
    }

    // 列裁剪：只投影 meta 所需列，不拉 5 段 longtext（subtree 的 JSON_EXTRACT 过滤仅在重建时执行一次）
    const rows = await db.select(TEMPLATE_META_SELECT).from(templates)
      .where(and(...conditions))
      .orderBy(asc(templates.sortOrder), desc(templates.updatedAt));

    const metas = rows.map(rowToMeta);
    const serverUpdatedAt = metas.length > 0
      ? metas.reduce((max, m) => Math.max(max, m.updatedAt), 0)
      : Math.floor(Date.now() / 1000);

    const cached: RemoteTemplateListResponse = { templates: metas, serverUpdatedAt };
    await this.redisService.setJson(key, cached, 600);

    // 响应仍按 since 过滤子集（与缓存命中路径语义一致），serverUpdatedAt 用源列表 max
    if (since !== undefined && !Number.isNaN(since)) {
      return { templates: metas.filter((m) => m.updatedAt > since), serverUpdatedAt };
    }
    return cached;
  }

  /** 客户端拉取单个模板完整内容（5 段）*/
  async getRemoteTemplateDetail(id: string): Promise<RemoteTemplateDetail> {
    const key = `lumira:cache:templateDetail:${id}`;
    const cached = await this.redisService.getJson<RemoteTemplateDetail>(key);
    if (cached !== null) return cached;

    const db = this.dbService.getDb();
    const rows = await db.select().from(templates).where(eq(templates.id, id)).limit(1);
    const row = rows[0];
    if (!row) {
      throw new NotFoundException('Template not found');
    }
    const detail = rowToDetail(row);
    await this.redisService.setJson(key, detail, 600);
    return detail;
  }
}

// ===== 表 → DTO 映射函数（模块内共享）=====

type TemplateRow = typeof templates.$inferSelect;
type CategoryRow = typeof templateCategories.$inferSelect;

/**
 * meta 类查询（list / search base）的列投影：只拉 rowToMeta 需要的列，
 * 不把 composition/pose/camera/scene_guide/post_process/ambience 等 longtext 大列从 MySQL 拉回内存再丢弃。
 * detail 查询（有 600s 缓存）仍用全列。
 */
const TEMPLATE_META_SELECT = {
  id: templates.id,
  name: templates.name,
  author: templates.author,
  version: templates.version,
  category: templates.category,
  price: templates.price,
  coverUrl: templates.coverUrl,
  description: templates.description,
  referenceSource: templates.referenceSource,
  tagsJson: templates.tagsJson,
  tagIdsJson: templates.tagIdsJson,
  classificationJson: templates.classificationJson,
  ambienceJson: templates.ambienceJson,
  imagesJson: templates.imagesJson,
  shortDesc: templates.shortDesc,
  sortOrder: templates.sortOrder,
  updatedAt: templates.updatedAt,
} as const;

/** rowToMeta 入参类型：meta 投影行的子集（TemplateRow 全行可赋值给该类型） */
type TemplateMetaRow = Pick<TemplateRow, keyof typeof TEMPLATE_META_SELECT>;

export function rowToMeta(row: TemplateMetaRow): RemoteTemplateMeta {
  const coverUrl = buildAssetUrl(row.coverUrl);
  // images: 优先 images_json；为空数组时由 coverUrl 派生单元素（兼容旧数据）
  const parsedImages = safeParseImagesArray(row.imagesJson).map((img) => ({
    url: buildAssetUrl(img.url),
    ...(img.data ? { data: img.data } : {}),
  }));
  const images: TemplateImage[] | undefined =
    parsedImages.length > 0 ? parsedImages : (coverUrl ? [{ url: coverUrl }] : undefined);
  return {
    id: row.id,
    name: row.name,
    author: row.author,
    version: row.version,
    category: row.category,
    price: row.price,
    coverUrl,
    images,
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
  // poses: pose_json 为数组时直接用；旧单对象包装为 [obj]；空对象/空数组 → []
  const posesArr = safeParsePosesArray(row.poseJson);
  // 旧数据修复：剪影 URL 可能在 BACKEND_PUBLIC_URL 配置前写入，前缀为 localhost
  for (const p of posesArr) {
    const silhouette = p.silhouette;
    if (silhouette && typeof silhouette === 'object') {
      const s = silhouette as Record<string, unknown>;
      if (typeof s.url === 'string') s.url = buildAssetUrl(s.url);
      if (typeof s.data === 'string') s.data = buildAssetUrl(s.data);
    }
  }
  // pose 兼容旧 App：poses[0] 或空对象
  const pose: Record<string, unknown> = posesArr.length > 0 ? posesArr[0] : {};
  return {
    ...rowToMeta(row),
    composition: safeParseObject(row.compositionJson),
    pose,
    // pose_json 结构自由（兼容旧数据），按 TemplatePose[] 透出
    poses: posesArr.length > 0 ? (posesArr as unknown as TemplatePose[]) : undefined,
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

/** 模板搜索基项：meta + 用于关键词过滤的标量字段 + 全站热度。 */
interface SearchBaseItem {
  meta: RemoteTemplateMeta;
  base: {
    name: string;
    author: string;
    category: string;
    description: string;
    tags: string[];
    sortOrder: number;
  };
  hotScore: number;
  shootCount: number;
  openCount: number;
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

function safeParseClassification(json: string): TemplateClassification {
  const obj = safeParseObject(json);
  const type = typeof obj.type === 'string' ? obj.type : '';
  const majorStyle = typeof obj.majorStyle === 'string' ? obj.majorStyle : '';
  // 三级分类：新字段 style 优先；旧数据无 style 时回退 subStyle
  const style = typeof obj.style === 'string'
    ? obj.style
    : (typeof obj.subStyle === 'string' ? obj.subStyle : '');
  // subStyle 兼容字段：与 style 同值（旧数据原值；新数据保持与 style 一致）
  const subStyle = typeof obj.subStyle === 'string' ? obj.subStyle : style;
  // method 不再作为树层级（兼容保留，可空）
  const method = typeof obj.method === 'string' && obj.method.length > 0 ? obj.method : undefined;
  return { type, majorStyle, style, subStyle, method };
}

/**
 * 安全解析 images_json 数组：返回有 url 字段的对象数组。
 * 非数组 / 非对象元素 / 无 url 字段均被过滤掉。
 */
function safeParseImagesArray(json: string): TemplateImage[] {
  try {
    const v = JSON.parse(json);
    if (!Array.isArray(v)) return [];
    return v.filter((x): x is TemplateImage =>
      !!x && typeof x === 'object' && !Array.isArray(x) && typeof (x as { url?: unknown }).url === 'string'
    );
  } catch {
    return [];
  }
}

/**
 * 安全解析 pose_json 数组：返回非空对象数组。
 * - 数组 → 过滤掉空对象/非对象元素
 * - 旧单对象（非空） → 包装为 [obj]
 * - 空对象 {} / 空数组 [] / 非对象 → 返回 []
 */
function safeParsePosesArray(json: string): Record<string, unknown>[] {
  try {
    const v = JSON.parse(json);
    const isNonNullObject = (x: unknown): x is Record<string, unknown> =>
      !!x && typeof x === 'object' && !Array.isArray(x) && Object.keys(x as object).length > 0;
    if (Array.isArray(v)) {
      return v.filter(isNonNullObject);
    }
    if (isNonNullObject(v)) {
      return [v];
    }
    return [];
  } catch {
    return [];
  }
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
