// lumira-server/packages/backend/src/modules/templates/admin-categories.service.ts
// Admin 分类管理业务逻辑（spec 3.3）

import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, asc, sql } from 'drizzle-orm';
import * as fs from 'fs';
import * as path from 'path';
import { DatabaseService } from '../../database/database.service';
import { templateCategories, templates } from '../../database/schema';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { rowToCategory } from './templates.service';
import type { TemplateCategory } from '@lumira/shared';
import type { UploadFile } from './admin-templates.service';

/** 静态资源 URL 构造（spec 3.5：prefix 不含 /api/v1） */
function buildIconUrl(key: string, filename: string): string {
  const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
  return `${base}/uploads/categories/${key}/${filename}`;
}

/** 从文件名/mimetype 提取扩展名（小写，不含点） */
function extractIconExt(file: UploadFile): string {
  if (file.filename) {
    const dot = file.filename.lastIndexOf('.');
    if (dot >= 0) {
      const ext = file.filename.slice(dot + 1).toLowerCase();
      if (/^[a-z0-9]+$/.test(ext)) return ext;
    }
  }
  const mimeMap: Record<string, string> = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/svg+xml': 'svg',
    'image/gif': 'gif',
  };
  return mimeMap[file.mimetype] || 'bin';
}

function saveIconFile(uploadDir: string, key: string, filename: string, buffer: Buffer): void {
  const dir = path.join(uploadDir, 'categories', key);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, filename), buffer);
}

function deleteCategoryFiles(uploadDir: string, key: string): void {
  const dir = path.join(uploadDir, 'categories', key);
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

@Injectable()
export class AdminCategoriesService {
  private readonly uploadDir: string;

  constructor(private readonly dbService: DatabaseService) {
    this.uploadDir = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
  }

  /** Admin 分类列表（含 isActive=0） */
  async list(): Promise<{ categories: TemplateCategory[] }> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .orderBy(asc(templateCategories.sortOrder));
    return { categories: rows.map(rowToCategory) };
  }

  /** 创建分类（multipart：JSON 表单 + 图标文件） */
  async create(meta: CreateCategoryDto, icon?: UploadFile): Promise<TemplateCategory> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 检查 key 唯一
    const existing = await db.select({ key: templateCategories.key })
      .from(templateCategories)
      .where(eq(templateCategories.key, meta.key))
      .limit(1);
    if (existing.length > 0) {
      throw new ConflictException(`Category key already exists: ${meta.key}`);
    }

    // 处理图标 URL：若上传了图标文件，保存并构造 URL；否则用 meta.iconUrl 或空字符串
    let iconUrl = meta.iconUrl || '';
    if (icon) {
      const ext = extractIconExt(icon);
      const filename = `icon.${ext}`;
      saveIconFile(this.uploadDir, meta.key, filename, icon.buffer);
      iconUrl = buildIconUrl(meta.key, filename);
    }

    await db.insert(templateCategories).values({
      key: meta.key,
      name: meta.name,
      iconUrl,
      sortOrder: meta.sortOrder ?? 0,
      isSystem: 0,  // Admin 创建的分类永远不是系统分类
      isActive: meta.isActive === false ? 0 : 1,
      createdAt: now,
      updatedAt: now,
    }).run();

    return this.getByKey(meta.key);
  }

  /** 更新分类（系统分类 key 不可改，multipart：JSON 表单 + 可选新图标） */
  async update(key: string, meta: UpdateCategoryDto, icon?: UploadFile): Promise<TemplateCategory> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const existingRows = await db.select().from(templateCategories)
      .where(eq(templateCategories.key, key)).limit(1);
    if (existingRows.length === 0) {
      throw new NotFoundException(`Category not found: ${key}`);
    }
    const existing = existingRows[0];

    // 系统分类：key 锁定（此接口本身不接受 key 参数，但额外检查 meta 中不含 key）
    // key 由 URL 路径参数决定，不会被修改

    // 处理图标
    let iconUrl = existing.iconUrl;
    if (icon) {
      const ext = extractIconExt(icon);
      const filename = `icon.${ext}`;
      saveIconFile(this.uploadDir, key, filename, icon.buffer);
      iconUrl = buildIconUrl(key, filename);
    } else if (meta.iconUrl !== undefined) {
      iconUrl = meta.iconUrl;
    }

    const updateData: Record<string, unknown> = {
      updatedAt: now,
      iconUrl,
    };
    if (meta.name !== undefined) updateData.name = meta.name;
    if (meta.sortOrder !== undefined) updateData.sortOrder = meta.sortOrder;
    if (meta.isActive !== undefined) updateData.isActive = meta.isActive ? 1 : 0;

    await db.update(templateCategories).set(updateData).where(eq(templateCategories.key, key)).run();

    return this.getByKey(key);
  }

  /** 删除分类（系统分类不可删返回 400；有模板引用返回 409） */
  async delete(key: string): Promise<{ success: true }> {
    const db = this.dbService.getDb();

    const existingRows = await db.select().from(templateCategories)
      .where(eq(templateCategories.key, key)).limit(1);
    if (existingRows.length === 0) {
      throw new NotFoundException(`Category not found: ${key}`);
    }

    // 系统分类保护
    if (existingRows[0].isSystem === 1) {
      throw new BadRequestException('System category cannot be deleted');
    }

    // 检查是否有模板引用此分类
    const refCount = await db.select({ count: sql<number>`count(*)` })
      .from(templates)
      .where(eq(templates.category, key));
    if ((refCount[0]?.count ?? 0) > 0) {
      throw new ConflictException('Category is referenced by existing templates');
    }

    await db.delete(templateCategories).where(eq(templateCategories.key, key)).run();
    deleteCategoryFiles(this.uploadDir, key);

    return { success: true };
  }

  /** 显示/隐藏切换 */
  async toggleActive(key: string): Promise<{ key: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const existingRows = await db.select({ isActive: templateCategories.isActive })
      .from(templateCategories)
      .where(eq(templateCategories.key, key)).limit(1);
    if (existingRows.length === 0) {
      throw new NotFoundException(`Category not found: ${key}`);
    }

    const newActive = existingRows[0].isActive === 1 ? 0 : 1;
    await db.update(templateCategories)
      .set({ isActive: newActive, updatedAt: now })
      .where(eq(templateCategories.key, key))
      .run();

    return { key, isActive: newActive === 1 };
  }

  private async getByKey(key: string): Promise<TemplateCategory> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(eq(templateCategories.key, key)).limit(1);
    if (rows.length === 0) {
      throw new NotFoundException(`Category not found: ${key}`);
    }
    return rowToCategory(rows[0]);
  }
}
