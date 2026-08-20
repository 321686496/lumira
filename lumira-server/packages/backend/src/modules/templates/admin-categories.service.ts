// lumira-server/packages/backend/src/modules/templates/admin-categories.service.ts
// Admin 分类管理业务逻辑（spec 3.3 + 11.4 三级分类扩展）

import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, or, asc, sql, isNull } from 'drizzle-orm';
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

/** 最大层级（四级：type/majorStyle/subStyle/method） */
const MAX_LEVEL = 4;

@Injectable()
export class AdminCategoriesService {
  private readonly uploadDir: string;

  constructor(private readonly dbService: DatabaseService) {
    this.uploadDir = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
  }

  /**
   * Admin 分类列表（含 isActive=0），支持按 level/parentKey 筛选。
   * 不传任何筛选参数时返回全量扁平列表。
   */
  async list(filters?: { level?: number; parentKey?: string | null }): Promise<{ categories: TemplateCategory[] }> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(and(
        filters?.level !== undefined ? eq(templateCategories.level, filters.level) : undefined,
        filters?.parentKey === null
          ? isNull(templateCategories.parentKey)
          : filters?.parentKey !== undefined
            ? eq(templateCategories.parentKey, filters.parentKey)
            : undefined,
      ))
      .orderBy(asc(templateCategories.level), asc(templateCategories.sortOrder));
    return { categories: rows.map(rowToCategory) };
  }

  /**
   * 创建分类（multipart：JSON 表单 + 图标文件）。
   * - parentKey 为 null/空 → 一级分类（level=1）
   * - parentKey 非空 → 校验父分类存在（level IN (1,2)，避免同名 key 歧义），
   *   新分类 level = parent.level + 1，不允许超过 MAX_LEVEL
   */
  async create(meta: CreateCategoryDto, icon?: UploadFile): Promise<TemplateCategory> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const parentKey = meta.parentKey && meta.parentKey.trim() !== '' ? meta.parentKey.trim() : null;

    // 推算 level
    let level = 1;
    if (parentKey !== null) {
      // 父分类 key 匹配且 level <= 3（level 4 是叶子，不能作为父）
      // 同名 key 跨 level 时取 level 最小的（即最接近根的），保证唯一确定
      const parentCandidates = await db.select().from(templateCategories)
        .where(eq(templateCategories.key, parentKey))
        .orderBy(asc(templateCategories.level))
        .limit(2);
      const parent = parentCandidates.find((r) => r.level <= 3);
      if (!parent) {
        throw new BadRequestException(`Parent category not found: ${parentKey}`);
      }
      level = parent.level + 1;
      if (level > MAX_LEVEL) {
        throw new BadRequestException(`Category level exceeds max depth (${MAX_LEVEL})`);
      }
    }

    // 检查 (key, parentKey) 唯一
    const existing = await this.findByKeyAndParent(meta.key, parentKey);
    if (existing) {
      throw new ConflictException(`Category key already exists: ${meta.key} under parent ${parentKey ?? '(root)'}`);
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
      parentKey,
      level,
      description: meta.description ?? '',
      sortOrder: meta.sortOrder ?? 0,
      isSystem: 0,  // Admin 创建的分类永远不是系统分类
      isActive: meta.isActive === false ? 0 : 1,
      createdAt: now,
      updatedAt: now,
    });

    return this.getByKeyAndParent(meta.key, parentKey);
  }

  /**
   * 更新分类（系统分类 key 不可改；parent_key 不可改——移动节点暂不支持）。
   * @param key URL 路径参数中的分类 key
   * @param parentKey 可选查询参数，用于消歧（非一级分类需提供）
   */
  async update(key: string, parentKey: string | null, meta: UpdateCategoryDto, icon?: UploadFile): Promise<TemplateCategory> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const existing = await this.getByKeyAndParent(key, parentKey);

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
    if (meta.description !== undefined) updateData.description = meta.description;
    if (meta.sortOrder !== undefined) updateData.sortOrder = meta.sortOrder;
    if (meta.isActive !== undefined) updateData.isActive = meta.isActive ? 1 : 0;
    // parentKey 不可改（meta 中即使传了也忽略）

    await db.update(templateCategories)
      .set(updateData)
      .where(eq(templateCategories.id, existing.id));

    return this.getByKeyAndParent(key, parentKey);
  }

  /**
   * 删除分类。
   * - 系统分类不可删（返回 400）
   * - 有子分类不可删（返回 409）
   * - 有模板引用不可删（返回 409）
   * @param parentKey 可选查询参数，用于消歧
   */
  async delete(key: string, parentKey: string | null): Promise<{ success: true }> {
    const db = this.dbService.getDb();

    const existing = await this.getByKeyAndParent(key, parentKey);

    // 系统分类保护
    if (existing.isSystem) {
      throw new BadRequestException('System category cannot be deleted');
    }

    // 检查子分类（用 level 精确匹配，避免同名 key 跨层级歧义）
    if (existing.level < MAX_LEVEL) {
      const childCount = await db.select({ count: sql<number>`count(*)` })
        .from(templateCategories)
        .where(and(
          eq(templateCategories.parentKey, key),
          eq(templateCategories.level, existing.level + 1),
        ));
      if ((childCount[0]?.count ?? 0) > 0) {
        throw new ConflictException('Category has child categories, cannot delete');
      }
    }

    // 检查模板引用
    const refCount = await this.countTemplateReferences(key, existing.level);
    if (refCount > 0) {
      throw new ConflictException('Category is referenced by existing templates');
    }

    await db.delete(templateCategories).where(eq(templateCategories.id, existing.id));
    deleteCategoryFiles(this.uploadDir, key);

    return { success: true };
  }

  /** 显示/隐藏切换 */
  async toggleActive(key: string, parentKey: string | null): Promise<{ key: string; isActive: boolean }> {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const existing = await this.getByKeyAndParent(key, parentKey);
    const newActive = existing.isActive ? 0 : 1;
    await db.update(templateCategories)
      .set({ isActive: newActive, updatedAt: now })
      .where(eq(templateCategories.id, existing.id));

    return { key, isActive: newActive === 1 };
  }

  // ===== 内部工具 =====

  /** 按 (key, parentKey) 精确查找分类。parentKey=null 时查一级分类。 */
  private async findByKeyAndParent(key: string, parentKey: string | null): Promise<TemplateCategory | null> {
    const db = this.dbService.getDb();
    const condition = parentKey === null
      ? and(eq(templateCategories.key, key), isNull(templateCategories.parentKey))
      : and(eq(templateCategories.key, key), eq(templateCategories.parentKey, parentKey));
    const rows = await db.select().from(templateCategories).where(condition).limit(1);
    return rows.length > 0 ? rowToCategory(rows[0]) : null;
  }

  /** 按 (key, parentKey) 精确查找，不存在则抛 404 */
  private async getByKeyAndParent(key: string, parentKey: string | null): Promise<TemplateCategory & { id: number; isSystem: boolean }> {
    const db = this.dbService.getDb();
    const condition = parentKey === null
      ? and(eq(templateCategories.key, key), isNull(templateCategories.parentKey))
      : and(eq(templateCategories.key, key), eq(templateCategories.parentKey, parentKey));
    const rows = await db.select().from(templateCategories).where(condition).limit(1);
    if (rows.length === 0) {
      throw new NotFoundException(`Category not found: ${key}${parentKey ? ` (parent: ${parentKey})` : ''}`);
    }
    const row = rows[0];
    return {
      ...rowToCategory(row),
      id: row.id,
      isSystem: row.isSystem === 1,
    };
  }

  /**
   * 统计引用该分类的模板数量。
   * - level 1：templates.category = key
   * - level >= 2：classification_json 任一字段（type/majorStyle/subStyle/method）命中 key 即算。
   *   不按 level 映射单一字段，因为人像为四级而其余题材为浅层（L2 可能是 subStyle 语义、L3 可能是 method 语义），
   *   直接匹配全部字段可兼容混合层级。
   */
  private async countTemplateReferences(key: string, level: number): Promise<number> {
    const db = this.dbService.getDb();
    const rows = await db.select({ count: sql<number>`count(*)` })
      .from(templates)
      .where(level === 1
        ? eq(templates.category, key)
        : or(
          sql`JSON_UNQUOTE(JSON_EXTRACT(${templates.classificationJson}, '$.type')) = ${key}`,
          sql`JSON_UNQUOTE(JSON_EXTRACT(${templates.classificationJson}, '$.majorStyle')) = ${key}`,
          sql`JSON_UNQUOTE(JSON_EXTRACT(${templates.classificationJson}, '$.subStyle')) = ${key}`,
          sql`JSON_UNQUOTE(JSON_EXTRACT(${templates.classificationJson}, '$.method')) = ${key}`,
        ));
    return rows[0]?.count ?? 0;
  }
}
