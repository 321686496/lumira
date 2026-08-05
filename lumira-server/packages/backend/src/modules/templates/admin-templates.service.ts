// lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts
// Admin 模板管理业务逻辑（spec 3.3 + 3.4）

import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { eq, asc, desc, sql } from 'drizzle-orm';
import { nanoid } from 'nanoid';
import * as fs from 'fs';
import * as path from 'path';
import { DatabaseService } from '../../database/database.service';
import { templates, templateCategories, templatePrices } from '../../database/schema';
import { CreateTemplateDto } from './dto/create-template.dto';
import { UpdateTemplateDto } from './dto/update-template.dto';
import { parsePptpl } from './utils/pptpl-parser';
import { rowToDetail } from './templates.service';
import type {
  AdminTemplateListItem,
  AdminTemplateDetail,
} from '@lumira/shared';

/** 上传文件信息（controller 解析后传入 service） */
export interface UploadFile {
  buffer: Buffer;
  filename: string;
  mimetype: string;
}

/** 静态资源 URL 构造（spec 3.5：prefix 不含 /api/v1） */
function buildPublicUrl(category: 'templates' | 'categories', id: string, filename: string): string {
  const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
  return `${base}/uploads/${category}/${id}/${filename}`;
}

/** 从文件名/mimetype 提取扩展名（小写，不含点） */
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

/** 保存文件到 uploads/templates/{id}/{filename}，返回相对存储路径 */
function saveFile(uploadDir: string, category: 'templates' | 'categories', id: string, filename: string, buffer: Buffer): string {
  const dir = path.join(uploadDir, category, id);
  fs.mkdirSync(dir, { recursive: true });
  const filePath = path.join(dir, filename);
  fs.writeFileSync(filePath, buffer);
  return filePath;
}

/** 删除 uploads/templates/{id}/ 整个目录 */
function deleteTemplateFiles(uploadDir: string, id: string): void {
  const dir = path.join(uploadDir, 'templates', id);
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

@Injectable()
export class AdminTemplatesService {
  private readonly uploadDir: string;

  constructor(private readonly dbService: DatabaseService) {
    this.uploadDir = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
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
   * 创建模板（spec 3.4 处理流程）
   * 1. 解析 meta JSON → 2. 若有 pptpl 覆盖 5 段 → 3. 生成 ID →
   * 4. 保存封面 → 5. 保存剪影 → 6. 构造 URL 写入 poseJson →
   * 7. INSERT → 8. 若 price>0 UPSERT template_prices → 9. 返回详情
   */
  async create(
    meta: CreateTemplateDto,
    cover: UploadFile,
    silhouette?: UploadFile,
    pptpl?: UploadFile,
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

    // 5 段内容：默认取 meta，若有 pptpl 则覆盖
    let composition = meta.composition || {};
    let pose = meta.pose || {};
    let camera = meta.camera || {};
    let sceneGuide = meta.sceneGuide || {};
    let postProcess = meta.postProcess || {};

    if (pptpl) {
      try {
        const pptplContent = parsePptpl(pptpl.buffer);
        composition = pptplContent.composition;
        pose = pptplContent.pose;
        camera = pptplContent.camera;
        sceneGuide = pptplContent.sceneGuide;
        postProcess = pptplContent.postProcess;
      } catch (e) {
        throw new BadRequestException(e instanceof Error ? e.message : 'Invalid pptpl format');
      }
    }

    // 保存封面
    const coverExt = extractExt(cover);
    const coverFilename = `cover.${coverExt}`;
    saveFile(this.uploadDir, 'templates', id, coverFilename, cover.buffer);
    const coverUrl = buildPublicUrl('templates', id, coverFilename);

    // 保存剪影（若有），URL 写入 poseJson
    let poseJson = JSON.stringify(pose);
    if (silhouette) {
      const silExt = extractExt(silhouette);
      const silFilename = `silhouette.${silExt}`;
      saveFile(this.uploadDir, 'templates', id, silFilename, silhouette.buffer);
      const silUrl = buildPublicUrl('templates', id, silFilename);
      // 将 silhouette URL 注入 pose 对象
      const poseObj = typeof pose === 'object' && pose !== null ? pose as Record<string, unknown> : {};
      if (poseObj.silhouette && typeof poseObj.silhouette === 'object') {
        (poseObj.silhouette as Record<string, unknown>).url = silUrl;
        (poseObj.silhouette as Record<string, unknown>).data = silUrl; // 兼容字段
      } else {
        poseObj.silhouette = { type: 'image', url: silUrl, data: silUrl };
      }
      poseJson = JSON.stringify(poseObj);
    }

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
      classificationJson: JSON.stringify(meta.classification || { type: '', style: '', method: '' }),
      sortOrder: meta.sortOrder ?? 0,
      isActive: meta.isActive === false ? 0 : 1,
      compositionJson: JSON.stringify(composition),
      poseJson,
      cameraJson: JSON.stringify(camera),
      sceneGuideJson: JSON.stringify(sceneGuide),
      postProcessJson: JSON.stringify(postProcess),
      createdAt: now,
      updatedAt: now,
    }).run();

    // 若 price > 0：UPSERT template_prices
    if (meta.price > 0) {
      await db.insert(templatePrices)
        .values({
          templateId: id,
          priceCredits: meta.price,
          isActive: 1,
          updatedAt: now,
        })
        .onConflictDoUpdate({
          target: templatePrices.templateId,
          set: {
            priceCredits: meta.price,
            isActive: 1,
            updatedAt: now,
          },
        })
        .run();
    }

    return this.getDetail(id);
  }

  /** 更新模板（multipart：可选新封面 + 可选新剪影 + 可选 pptpl 覆盖 5 段） */
  async update(
    id: string,
    meta: UpdateTemplateDto,
    cover?: UploadFile,
    silhouette?: UploadFile,
    pptpl?: UploadFile,
  ): Promise<AdminTemplateDetail> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 取旧记录
    const existingRows = await db.select().from(templates).where(eq(templates.id, id)).limit(1);
    const existing = existingRows[0];
    if (!existing) {
      throw new NotFoundException('Template not found');
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
    let camera = meta.camera !== undefined ? meta.camera : safeParse(existing.cameraJson);
    let sceneGuide = meta.sceneGuide !== undefined ? meta.sceneGuide : safeParse(existing.sceneGuideJson);
    let postProcess = meta.postProcess !== undefined ? meta.postProcess : safeParse(existing.postProcessJson);

    if (pptpl) {
      try {
        const pptplContent = parsePptpl(pptpl.buffer);
        composition = pptplContent.composition;
        pose = pptplContent.pose;
        camera = pptplContent.camera;
        sceneGuide = pptplContent.sceneGuide;
        postProcess = pptplContent.postProcess;
      } catch (e) {
        throw new BadRequestException(e instanceof Error ? e.message : 'Invalid pptpl format');
      }
    }

    // 封面：若有新封面，保存并更新 URL；否则保留旧 URL
    let coverUrl = existing.coverUrl;
    if (cover) {
      const coverExt = extractExt(cover);
      const coverFilename = `cover.${coverExt}`;
      saveFile(this.uploadDir, 'templates', id, coverFilename, cover.buffer);
      coverUrl = buildPublicUrl('templates', id, coverFilename);
    }

    // 剪影：若有新剪影，保存并注入 pose URL
    let poseJson = JSON.stringify(pose);
    if (silhouette) {
      const silExt = extractExt(silhouette);
      const silFilename = `silhouette.${silExt}`;
      saveFile(this.uploadDir, 'templates', id, silFilename, silhouette.buffer);
      const silUrl = buildPublicUrl('templates', id, silFilename);
      const poseObj = typeof pose === 'object' && pose !== null ? pose as Record<string, unknown> : {};
      if (poseObj.silhouette && typeof poseObj.silhouette === 'object') {
        (poseObj.silhouette as Record<string, unknown>).url = silUrl;
        (poseObj.silhouette as Record<string, unknown>).data = silUrl;
      } else {
        poseObj.silhouette = { type: 'image', url: silUrl, data: silUrl };
      }
      poseJson = JSON.stringify(poseObj);
    }

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
    if (meta.classification !== undefined) updateData.classificationJson = JSON.stringify(meta.classification);
    if (meta.sortOrder !== undefined) updateData.sortOrder = meta.sortOrder;
    if (meta.isActive !== undefined) updateData.isActive = meta.isActive ? 1 : 0;
    updateData.coverUrl = coverUrl;
    updateData.compositionJson = JSON.stringify(composition);
    updateData.poseJson = poseJson;
    updateData.cameraJson = JSON.stringify(camera);
    updateData.sceneGuideJson = JSON.stringify(sceneGuide);
    updateData.postProcessJson = JSON.stringify(postProcess);

    await db.update(templates).set(updateData).where(eq(templates.id, id)).run();

    // 若 price > 0 且 price 发生变化：UPSERT template_prices
    if (meta.price !== undefined && meta.price > 0) {
      await db.insert(templatePrices)
        .values({
          templateId: id,
          priceCredits: meta.price,
          isActive: 1,
          updatedAt: now,
        })
        .onConflictDoUpdate({
          target: templatePrices.templateId,
          set: {
            priceCredits: meta.price,
            isActive: 1,
            updatedAt: now,
          },
        })
        .run();
    }

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
    await db.delete(templates).where(eq(templates.id, id)).run();

    // 删除 template_prices 记录（若存在）
    await db.delete(templatePrices).where(eq(templatePrices.templateId, id)).run();

    // 删除文件目录
    deleteTemplateFiles(this.uploadDir, id);

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
    await db.update(templates).set({ isActive: newActive, updatedAt: now }).where(eq(templates.id, id)).run();

    // 同步 template_prices 的 isActive
    await db.update(templatePrices).set({ isActive: newActive, updatedAt: now }).where(eq(templatePrices.templateId, id)).run();

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
