// lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts
// Admin 模板管理业务逻辑（spec 3.3 + 3.4）

import { Injectable, NotFoundException, BadRequestException, Inject } from '@nestjs/common';
import { eq, asc, desc, sql } from 'drizzle-orm';
import { nanoid } from 'nanoid';
import { DatabaseService } from '../../database/database.service';
import { templates, templateCategories, templatePrices } from '../../database/schema';
import { STORAGE_ADAPTER } from '../../common/storage/storage.provider';
import type { StorageAdapter } from '../../common/storage/storage-adapter.interface';
import { RedisService } from '../../common/redis/redis.service';
import { CreateTemplateDto } from './dto/create-template.dto';
import { UpdateTemplateDto } from './dto/update-template.dto';
import { parsePptpl } from './utils/pptpl-parser';
import { rowToDetail, sanitizeAmbience } from './templates.service';
import type {
  AdminTemplateListItem,
  AdminTemplateDetail,
} from '@lumira/shared';

/** 上传文件信息（controller 解析后传入 service）*/
export interface UploadFile {
  buffer: Buffer;
  filename: string;
  mimetype: string;
}

/** 图片上传上限：封面 / 剪影 8MB */
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
/** .pptpl 上传上限（25MB）：文件内嵌 base64 封面图/剪影，体积远大于原始 JSON */
export const MAX_PPTPL_BYTES = 25 * 1024 * 1024;

/** 校验上传文件大小，超限时抛出明确的 400 错误（避免依赖 busboy 的 413）*/
function assertFileSize(file: UploadFile, maxBytes: number, fieldLabel: string): void {
  if (file.buffer.byteLength > maxBytes) {
    const mb = (maxBytes / 1024 / 1024).toFixed(0);
    throw new BadRequestException(`${fieldLabel}不能超过 ${mb}MB（当前${(file.buffer.byteLength / 1024 / 1024).toFixed(2)}MB）`);
  }
}

/** 从文件名/mimetype 提取扩展名（小写，不含点）*/
function extractExt(file: UploadFile): string {
  // 优先用文件名扩展名
  if (file.filename) {
    const dot = file.filename.lastIndexOf('.');
    if (dot >= 0) {
      const ext = file.filename.slice(dot + 1).toLowerCase();
      if (/^[a-z0-9]+$/.test(ext)) return ext;
    }
  }
  // 回退到 mimetype 映射
  const mimeMap: Record<string, string> = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/svg+xml': 'svg',
    'image/gif': 'gif',
    'application/json': 'json',
  };
  return mimeMap[file.mimetype] || 'bin';
}

@Injectable()
export class AdminTemplatesService {
  constructor(
    private readonly dbService: DatabaseService,
    @Inject(STORAGE_ADAPTER) private readonly storage: StorageAdapter,
    private readonly redisService: RedisService,
  ) {}

  /** 模板内容变更后统一失效内容缓存 */
  private async invalidateTemplateCaches(): Promise<void> {
    await this.redisService.delByPattern('lumira:cache:templateList:*');
    await this.redisService.delByPattern('lumira:cache:templateDetail:*');
    await this.redisService.delByPattern('lumira:cache:templatePrices:*');
  }

  // ===== 列表 / 详情 =====

  /** Admin 模板列表（含 isActive=0），分页 + 分类名 JOIN */
  async list(page = 1, pageSize = 20): Promise<{ data: AdminTemplateListItem[]; total: number; page: number; pageSize: number }> {
    const db = this.dbService.getDb();
    const offset = (page - 1) * pageSize;

    // LEFT JOIN template_categories 取 categoryName
    const rows = await db.select({
      id: templates.id,
      name: templates.name,
      category: templates.category,
      categoryName: templateCategories.name,
      price: templates.price,
      coverUrl: templates.coverUrl,
      isActive: templates.isActive,
      sortOrder: templates.sortOrder,
      createdAt: templates.createdAt,
      updatedAt: templates.updatedAt,
    })
      .from(templates)
      .leftJoin(templateCategories, eq(templates.category, templateCategories.key))
      .orderBy(asc(templates.sortOrder), desc(templates.updatedAt))
      .limit(pageSize)
      .offset(offset);

    const countRows = await db.select({ count: sql<number>`count(*)` }).from(templates);
    const total = countRows[0]?.count ?? 0;

    return {
      data: rows.map((r) => ({
        id: r.id,
        name: r.name,
        category: r.category,
        categoryName: r.categoryName || '',
        price: r.price,
        coverUrl: r.coverUrl,
        isActive: r.isActive === 1,
        sortOrder: r.sortOrder,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      })),
      total,
      page,
      pageSize,
    };
  }

  /** Admin 模板详情 */
  async getDetail(id: string): Promise<AdminTemplateDetail> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templates).where(eq(templates.id, id)).limit(1);
    const row = rows[0];
    if (!row) {
      throw new NotFoundException('Template not found');
    }

    // 取分类名
    const catRows = await db.select({ name: templateCategories.name })
      .from(templateCategories)
      .where(eq(templateCategories.key, row.category))
      .limit(1);

    const detail = rowToDetail(row);
    return {
      ...detail,
      categoryName: catRows[0]?.name || '',
      isActive: row.isActive === 1,
      createdAt: row.createdAt,
      sortOrder: row.sortOrder,
    };
  }

  // ===== 创建 / 更新 / 删除 =====

  /**
   * 创建模板（spec 3.4 + Phase 3 处理流程）：
   * 1. 解析 meta JSON → 2. 若有 pptpl 覆盖 5 段 → 3. 生成 ID →
   * 4. 保存多图（images[] 或旧单 cover）→ 5. 保存剪影注入 poses[0] →
   * 6. 构造 imagesJson + poseJson（数组） → 7. INSERT → 8. 若 price>0 UPSERT template_prices → 9. 返回详情
   */
  async create(
    meta: CreateTemplateDto,
    cover?: UploadFile,
    silhouette?: UploadFile,
    pptpl?: UploadFile,
    images?: UploadFile[],
  ): Promise<AdminTemplateDetail> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);
    const id = `srv_${nanoid(12)}`;

    // 校验分类存在
    const catRows = await db.select().from(templateCategories)
      .where(eq(templateCategories.key, meta.category)).limit(1);
    if (catRows.length === 0) {
      throw new BadRequestException(`Category not found: ${meta.category}`);
    }

    // 校验上传文件大小（图片 8MB / pptpl 25MB），超限返回明确的 400 而不是 413
    if (cover) {
      assertFileSize(cover, MAX_IMAGE_BYTES, '封面图片');
    }
    if (silhouette) {
      assertFileSize(silhouette, MAX_IMAGE_BYTES, '剪影图片');
    }
    if (pptpl) {
      assertFileSize(pptpl, MAX_PPTPL_BYTES, '.pptpl 文件');
    }
    if (images && images.length > 0) {
      images.forEach((img, i) => assertFileSize(img, MAX_IMAGE_BYTES, `效果图 ${i + 1}`));
    }

    // 5 段内容：默认取 meta，若有 pptpl 则覆盖
    let composition = meta.composition || {};
    let pose = meta.pose || {};          // 兼容旧字段（单 pose）
    let poses = meta.poses;              // 新字段（pose 数组，优先）
    let camera = meta.camera || {};
    let sceneGuide = meta.sceneGuide || {};
    let postProcess = meta.postProcess || {};

    if (pptpl) {
      try {
        const pptplContent = parsePptpl(pptpl.buffer);
        composition = pptplContent.composition;
        pose = pptplContent.pose;  // pptpl 旧结构：单 pose 对象
        poses = undefined;          // 让 fallback 走 [pose]
        camera = pptplContent.camera;
        sceneGuide = pptplContent.sceneGuide;
        postProcess = pptplContent.postProcess;
      } catch (e) {
        throw new BadRequestException(e instanceof Error ? e.message : 'Invalid pptpl format');
      }
    }

    // ===== 多图上传 (Phase 3) =====
    // 优先级：images 文件 > cover 文件（兼容旧 admin）> meta.images URL 数组
    let imagesArr: Array<{ url: string; data?: string }> = [];
    let coverUrl = '';
    if (images && images.length > 0) {
      for (let i = 0; i < images.length; i++) {
        const img = images[i];
        const ext = extractExt(img);
        const filename = `image_${i}.${ext}`;
        const url = await this.storage.write('templates', id, filename, img.buffer);
        imagesArr.push({ url });
      }
      coverUrl = imagesArr[0].url;
    } else if (cover) {
      // 旧单图路径：cover 文件同时作为效果图首元素
      const coverExt = extractExt(cover);
      const coverFilename = `cover.${coverExt}`;
      coverUrl = await this.storage.write('templates', id, coverFilename, cover.buffer);
      imagesArr = [{ url: coverUrl }];
    } else if (Array.isArray(meta.images) && meta.images.length > 0) {
      // meta.images 已是 URL/data 数组（如复制场景），直接用
      imagesArr = meta.images
        .map((img) => {
          const r = img as Record<string, unknown>;
          const url = typeof r.url === 'string' ? r.url : '';
          const data = typeof r.data === 'string' ? r.data : undefined;
          if (!url) return null;
          return data ? { url, data } : { url };
        })
        .filter((x): x is { url: string; data?: string } => x !== null);
      coverUrl = imagesArr[0]?.url || '';
    }

    // ===== pose 数组化 + silhouette 注入 =====
    // 优先级：meta.poses > [meta.pose] > []
    let posesArr: Record<string, unknown>[];
    if (Array.isArray(poses) && poses.length > 0) {
      posesArr = poses as Record<string, unknown>[];
    } else if (pose && typeof pose === 'object' && Object.keys(pose).length > 0) {
      posesArr = [pose as Record<string, unknown>];
    } else {
      posesArr = [];
    }

    if (silhouette) {
      const silExt = extractExt(silhouette);
      const silFilename = `silhouette.${silExt}`;
      const silUrl = await this.storage.write('templates', id, silFilename, silhouette.buffer);
      if (posesArr.length > 0) {
        // 注入到首元素（不修改 meta 原值，做浅拷贝）
        const first = { ...posesArr[0] };
        const silObj = (first.silhouette && typeof first.silhouette === 'object')
          ? { ...(first.silhouette as Record<string, unknown>) }
          : {};
        silObj.type = 'image';
        silObj.url = silUrl;
        silObj.data = silUrl; // 兼容字段
        first.silhouette = silObj;
        posesArr = [first, ...posesArr.slice(1)];
      } else {
        // 无 pose 数据，仅构造 silhouette
        posesArr = [{ silhouette: { type: 'image', url: silUrl, data: silUrl } }];
      }
    }

    const poseJson = JSON.stringify(posesArr);
    const imagesJson = JSON.stringify(imagesArr);

    // INSERT
    await db.insert(templates).values({
      id,
      name: meta.name,
      author: meta.author || 'Lumira',
      version: meta.version || '1.0.0',
      category: meta.category,
      price: meta.price,
      coverUrl,
      description: meta.description || '',
      referenceSource: meta.referenceSource || '',
      tagsJson: JSON.stringify(meta.tags || []),
      tagIdsJson: JSON.stringify(meta.tagIds || []),
      classificationJson: JSON.stringify({
        // 自动同步：classification.type = category（spec 11.4）
        type: meta.category,
        majorStyle: meta.classification?.majorStyle || '',
        // 三级分类：style 主字段；旧 admin 仅提交 subStyle 时按 subStyle 写 style
        style: meta.classification?.style || meta.classification?.subStyle || '',
        subStyle: meta.classification?.subStyle || meta.classification?.style || '',
        method: meta.classification?.method || '',
      }),
      sortOrder: meta.sortOrder ?? 0,
      isActive: meta.isActive === false ? 0 : 1,
      compositionJson: JSON.stringify(composition),
      poseJson,
      imagesJson,
      cameraJson: JSON.stringify(camera),
      sceneGuideJson: JSON.stringify(sceneGuide),
      postProcessJson: JSON.stringify(postProcess),
      ambienceJson: JSON.stringify(sanitizeAmbience(meta.ambience)),
      shortDesc: meta.shortDesc ?? '',
      createdAt: now,
      updatedAt: now,
    });

    // 若 price > 0，UPSERT template_prices
    if (meta.price > 0) {
      await db.insert(templatePrices)
        .values({
          templateId: id,
          priceCredits: meta.price,
          isActive: 1,
          updatedAt: now,
        })
        .onDuplicateKeyUpdate({
          set: {
            priceCredits: meta.price,
            isActive: 1,
            updatedAt: now,
          },
        });
    }

    await this.invalidateTemplateCaches();
    return this.getDetail(id);
  }

  /** 更新模板（multipart：可选新封面 / 多图 / 新剪影 / pptpl 覆盖 5 段）*/
  async update(
    id: string,
    meta: UpdateTemplateDto,
    cover?: UploadFile,
    silhouette?: UploadFile,
    pptpl?: UploadFile,
    images?: UploadFile[],
  ): Promise<AdminTemplateDetail> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 取旧记录
    const existingRows = await db.select().from(templates).where(eq(templates.id, id)).limit(1);
    const existing = existingRows[0];
    if (!existing) {
      throw new NotFoundException('Template not found');
    }

    // 校验上传文件大小（图片 8MB / pptpl 25MB），超限返回明确的 400 而不是 413
    if (cover) {
      assertFileSize(cover, MAX_IMAGE_BYTES, '封面图片');
    }
    if (silhouette) {
      assertFileSize(silhouette, MAX_IMAGE_BYTES, '剪影图片');
    }
    if (pptpl) {
      assertFileSize(pptpl, MAX_PPTPL_BYTES, '.pptpl 文件');
    }
    if (images && images.length > 0) {
      images.forEach((img, i) => assertFileSize(img, MAX_IMAGE_BYTES, `效果图 ${i + 1}`));
    }

    // 若改了分类，校验新分类存在
    if (meta.category && meta.category !== existing.category) {
      const catRows = await db.select().from(templateCategories)
        .where(eq(templateCategories.key, meta.category)).limit(1);
      if (catRows.length === 0) {
        throw new BadRequestException(`Category not found: ${meta.category}`);
      }
    }

    // 5 段内容：默认取旧值，若 meta 提供则覆盖，若有 pptpl 则全覆盖
    let composition = meta.composition !== undefined ? meta.composition : safeParse(existing.compositionJson);
    let pose = meta.pose !== undefined ? meta.pose : safeParse(existing.poseJson);
    let poses = meta.poses;
    let camera = meta.camera !== undefined ? meta.camera : safeParse(existing.cameraJson);
    let sceneGuide = meta.sceneGuide !== undefined ? meta.sceneGuide : safeParse(existing.sceneGuideJson);
    let postProcess = meta.postProcess !== undefined ? meta.postProcess : safeParse(existing.postProcessJson);

    if (pptpl) {
      try {
        const pptplContent = parsePptpl(pptpl.buffer);
        composition = pptplContent.composition;
        pose = pptplContent.pose;
        poses = undefined;
        camera = pptplContent.camera;
        sceneGuide = pptplContent.sceneGuide;
        postProcess = pptplContent.postProcess;
      } catch (e) {
        throw new BadRequestException(e instanceof Error ? e.message : 'Invalid pptpl format');
      }
    }

    // ===== 多图上传 (Phase 3) =====
    // 优先级：images 文件 > cover 文件 > meta.images URL 数组 > 旧 imagesJson/coverUrl
    let imagesArr: Array<{ url: string; data?: string }>;
    let coverUrl = existing.coverUrl;
    if (images && images.length > 0) {
      imagesArr = [];
      for (let i = 0; i < images.length; i++) {
        const img = images[i];
        const ext = extractExt(img);
        const filename = `image_${i}.${ext}`;
        const url = await this.storage.write('templates', id, filename, img.buffer);
        imagesArr.push({ url });
      }
      coverUrl = imagesArr[0].url;
    } else if (cover) {
      // 旧单图路径：cover 文件同时作为效果图首元素，丢弃旧 imagesJson 其他元素
      const coverExt = extractExt(cover);
      const coverFilename = `cover.${coverExt}`;
      coverUrl = await this.storage.write('templates', id, coverFilename, cover.buffer);
      imagesArr = [{ url: coverUrl }];
    } else if (Array.isArray(meta.images)) {
      // meta.images 提供则覆盖（可空数组表示清空）
      imagesArr = meta.images
        .map((img) => {
          const r = img as Record<string, unknown>;
          const url = typeof r.url === 'string' ? r.url : '';
          const data = typeof r.data === 'string' ? r.data : undefined;
          if (!url) return null;
          return data ? { url, data } : { url };
        })
        .filter((x): x is { url: string; data?: string } => x !== null);
      coverUrl = imagesArr[0]?.url || '';
    } else {
      // 无文件、无 meta.images：保留旧 imagesJson
      imagesArr = safeParseImagesArrayExisting(existing.imagesJson);
    }

    // ===== pose 数组化 + silhouette 注入 =====
    let posesArr: Record<string, unknown>[];
    if (Array.isArray(poses) && poses.length > 0) {
      posesArr = poses as Record<string, unknown>[];
    } else if (pose !== undefined && pose && typeof pose === 'object' && Object.keys(pose).length > 0) {
      posesArr = [pose as Record<string, unknown>];
    } else if (Array.isArray(meta.poses)) {
      // meta.poses 显式为空数组 → 清空 poses
      posesArr = [];
    } else {
      // 无 pose / poses 提供：保留旧 poseJson（数组化）
      posesArr = safeParsePosesArrayExisting(existing.poseJson);
    }

    if (silhouette) {
      const silExt = extractExt(silhouette);
      const silFilename = `silhouette.${silExt}`;
      const silUrl = await this.storage.write('templates', id, silFilename, silhouette.buffer);
      if (posesArr.length > 0) {
        const first = { ...posesArr[0] };
        const silObj = (first.silhouette && typeof first.silhouette === 'object')
          ? { ...(first.silhouette as Record<string, unknown>) }
          : {};
        silObj.type = 'image';
        silObj.url = silUrl;
        silObj.data = silUrl;
        first.silhouette = silObj;
        posesArr = [first, ...posesArr.slice(1)];
      } else {
        posesArr = [{ silhouette: { type: 'image', url: silUrl, data: silUrl } }];
      }
    }

    const poseJson = JSON.stringify(posesArr);
    const imagesJson = JSON.stringify(imagesArr);

    // 更新字段（仅赋值 meta 中出现的字段，undefined 保留旧值）
    const updateData: Record<string, unknown> = {
      updatedAt: now,
    };
    if (meta.name !== undefined) updateData.name = meta.name;
    if (meta.author !== undefined) updateData.author = meta.author;
    if (meta.version !== undefined) updateData.version = meta.version;
    if (meta.category !== undefined) updateData.category = meta.category;
    if (meta.price !== undefined) updateData.price = meta.price;
    if (meta.description !== undefined) updateData.description = meta.description;
    if (meta.referenceSource !== undefined) updateData.referenceSource = meta.referenceSource;
    if (meta.tags !== undefined) updateData.tagsJson = JSON.stringify(meta.tags);
    if (meta.tagIds !== undefined) updateData.tagIdsJson = JSON.stringify(meta.tagIds);
    // 自动同步：classification.type = category（spec 11.4）
    // 当 category 或 classification 任一变化时，重写 classificationJson 保持 type 与 category 一致
    if (meta.category !== undefined || meta.classification !== undefined) {
      const finalCategory = meta.category !== undefined ? meta.category : existing.category;
      const existingCls = safeParseClassification(existing.classificationJson);
      updateData.classificationJson = JSON.stringify({
        type: finalCategory,
        majorStyle: meta.classification?.majorStyle ?? existingCls.majorStyle,
        // 三级分类：style 主字段；旧 admin 仅提交 subStyle 时按 subStyle 写 style
        style: meta.classification?.style ?? meta.classification?.subStyle ?? existingCls.style,
        subStyle: meta.classification?.subStyle ?? meta.classification?.style ?? existingCls.subStyle,
        method: meta.classification?.method ?? existingCls.method ?? '',
      });
    }
    if (meta.sortOrder !== undefined) updateData.sortOrder = meta.sortOrder;
    if (meta.isActive !== undefined) updateData.isActive = meta.isActive ? 1 : 0;
    updateData.coverUrl = coverUrl;
    updateData.compositionJson = JSON.stringify(composition);
    updateData.poseJson = poseJson;
    updateData.imagesJson = imagesJson;
    updateData.cameraJson = JSON.stringify(camera);
    updateData.sceneGuideJson = JSON.stringify(sceneGuide);
    updateData.postProcessJson = JSON.stringify(postProcess);
    if (meta.ambience !== undefined) updateData.ambienceJson = JSON.stringify(sanitizeAmbience(meta.ambience));
    if (meta.shortDesc !== undefined) updateData.shortDesc = meta.shortDesc;

    await db.update(templates).set(updateData).where(eq(templates.id, id));

    // 若 price > 0 且 price 发生变化，UPSERT template_prices
    if (meta.price !== undefined && meta.price > 0) {
      await db.insert(templatePrices)
        .values({
          templateId: id,
          priceCredits: meta.price,
          isActive: 1,
          updatedAt: now,
        })
        .onDuplicateKeyUpdate({
          set: {
            priceCredits: meta.price,
            isActive: 1,
            updatedAt: now,
          },
        });
    }

    await this.invalidateTemplateCaches();
    return this.getDetail(id);
  }

  /** 删除模板 + 删除关联文件 */
  async delete(id: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();

    // 检查存在
    const existingRows = await db.select({ id: templates.id }).from(templates).where(eq(templates.id, id)).limit(1);
    if (existingRows.length === 0) {
      throw new NotFoundException('Template not found');
    }

    // 删除 DB 记录
    await db.delete(templates).where(eq(templates.id, id));

    // 删除 template_prices 记录（若存在）
    await db.delete(templatePrices).where(eq(templatePrices.templateId, id));

    // 删除文件目录
    await this.storage.deleteByDir('templates', id);

    await this.invalidateTemplateCaches();
    return { success: true };
  }

  /** 上架/下架切换 */
  async toggleActive(id: string): Promise<{ id: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const existingRows = await db.select({ isActive: templates.isActive }).from(templates).where(eq(templates.id, id)).limit(1);
    if (existingRows.length === 0) {
      throw new NotFoundException('Template not found');
    }

    const newActive = existingRows[0].isActive === 1 ? 0 : 1;
    await db.update(templates).set({ isActive: newActive, updatedAt: now }).where(eq(templates.id, id));

    // 同步 template_prices 的 isActive
    await db.update(templatePrices).set({ isActive: newActive, updatedAt: now }).where(eq(templatePrices.templateId, id));

    await this.invalidateTemplateCaches();
    return { id, isActive: newActive === 1 };
  }
}

function safeParse(json: string): Record<string, unknown> {
  try {
    const v = JSON.parse(json);
    return v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, unknown> : {};
  } catch {
    return {};
  }
}

/** 解析既有 images_json（admin 更新保留用，原样返回 url/data，不改写） */
function safeParseImagesArrayExisting(json: string): Array<{ url: string; data?: string }> {
  try {
    const v = JSON.parse(json);
    if (!Array.isArray(v)) return [];
    return v.filter((x): x is { url: string; data?: string } =>
      !!x && typeof x === 'object' && !Array.isArray(x) &&
      typeof (x as { url?: unknown }).url === 'string'
    );
  } catch {
    return [];
  }
}

/** 解析既有 pose_json（数组或旧单对象 → 数组；原样保留对象不改写） */
function safeParsePosesArrayExisting(json: string): Record<string, unknown>[] {
  try {
    const v = JSON.parse(json);
    const isNonNullObject = (x: unknown): x is Record<string, unknown> =>
      !!x && typeof x === 'object' && !Array.isArray(x) && Object.keys(x as object).length > 0;
    if (Array.isArray(v)) return v.filter(isNonNullObject);
    if (isNonNullObject(v)) return [v];
    return [];
  } catch {
    return [];
  }
}

/** 解析 classification_json，提取 type/majorStyle/style/subStyle/method 字符串
 *  (style 为三级主字段；旧数据无 style 时回退 subStyle) */
function safeParseClassification(json: string): { type: string; majorStyle: string; style: string; subStyle: string; method: string } {
  const obj = safeParse(json);
  const style = typeof obj.style === 'string'
    ? obj.style
    : (typeof obj.subStyle === 'string' ? obj.subStyle : '');
  return {
    type: typeof obj.type === 'string' ? obj.type : '',
    majorStyle: typeof obj.majorStyle === 'string' ? obj.majorStyle : '',
    style,
    subStyle: typeof obj.subStyle === 'string' ? obj.subStyle : style,
    method: typeof obj.method === 'string' ? obj.method : '',
  };
}
