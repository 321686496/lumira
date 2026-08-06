// lumira-server/packages/backend/src/modules/templates/categories.service.ts
// 分类业务逻辑（客户端 + Admin 共用底层查询）

import { Injectable } from '@nestjs/common';
import { eq, and, asc, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';
import { rowToCategory } from './templates.service';
import type {
  TemplateCategory,
  TemplateCategoryListResponse,
  TemplateCategoryTree,
  TemplateCategoryTreeResponse,
} from '@lumira/shared';

@Injectable()
export class CategoriesService {
  constructor(private readonly dbService: DatabaseService) {}

  /** 客户端：仅返回 isActive=1 的分类（扁平列表），按 level + sortOrder 排序 */
  async listActive(): Promise<TemplateCategoryListResponse> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(eq(templateCategories.isActive, 1))
      .orderBy(asc(templateCategories.level), asc(templateCategories.sortOrder));
    return { categories: rows.map(rowToCategory) };
  }

  /** 客户端：返回完整三级树（仅 isActive=1） */
  async listTree(): Promise<TemplateCategoryTreeResponse> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(eq(templateCategories.isActive, 1))
      .orderBy(asc(templateCategories.level), asc(templateCategories.sortOrder));
    const flat = rows.map(rowToCategory);
    return { categories: buildTree(flat) };
  }

  /** 返回指定父分类的直接子分类（isActive=1） */
  async listByParent(parentKey: string): Promise<TemplateCategory[]> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(and(
        eq(templateCategories.parentKey, parentKey),
        eq(templateCategories.isActive, 1),
      ))
      .orderBy(asc(templateCategories.sortOrder));
    return rows.map(rowToCategory);
  }

  /** 获取直接子分类（含 isActive=0，供 Admin 内部使用） */
  async getChildren(key: string): Promise<TemplateCategory[]> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(eq(templateCategories.parentKey, key))
      .orderBy(asc(templateCategories.sortOrder));
    return rows.map(rowToCategory);
  }

  /**
   * 判断指定分类是否有子分类。
   * @param key 分类 key
   * @param level 该分类的 level（level=3 永远无子分类，直接返回 false 避免 key 歧义）
   */
  async hasChildren(key: string, level?: number): Promise<boolean> {
    if (level === 3) {
      return false; // 三级分类是叶子节点
    }
    const db = this.dbService.getDb();
    // 若已知 level，查 level = level+1 的子分类，避免跨层级同名 key 歧义
    const childLevel = level !== undefined ? level + 1 : undefined;
    const conditions = [eq(templateCategories.parentKey, key)];
    if (childLevel !== undefined) {
      conditions.push(eq(templateCategories.level, childLevel));
    }
    const rows = await db.select({ count: sql<number>`count(*)` })
      .from(templateCategories)
      .where(and(...conditions));
    return (rows[0]?.count ?? 0) > 0;
  }
}

/**
 * 将扁平分类列表构造为三级树。
 * 一级（parentKey=null）为根节点，二级挂到对应一级下，三级挂到对应二级下。
 */
export function buildTree(flat: TemplateCategory[]): TemplateCategoryTree[] {
  const map = new Map<string, TemplateCategoryTree>();
  const roots: TemplateCategoryTree[] = [];

  // 第一遍：创建所有节点
  for (const cat of flat) {
    map.set(nodeId(cat.key, cat.parentKey), { ...cat, children: [] });
  }

  // 第二遍：组装父子关系
  for (const cat of flat) {
    const node = map.get(nodeId(cat.key, cat.parentKey))!;
    if (cat.parentKey === null) {
      roots.push(node);
    } else {
      // 父节点：parentKey 匹配且 level = cat.level - 1
      const parentLevel = cat.level - 1;
      const parent = findNode(map, cat.parentKey, parentLevel);
      if (parent) {
        parent.children.push(node);
      } else {
        // 父节点不存在（可能 isActive=0 被过滤），作为根节点兜底
        roots.push(node);
      }
    }
  }

  return roots;
}

/** 生成节点 Map key：level + '|' + key（处理同 key 不同 level 的情况） */
function nodeId(key: string, parentKey: string | null): string {
  return `${parentKey ?? '\0'}|${key}`;
}

/** 在 Map 中按 parentKey + level 查找父节点（parentKey 可能在多个 level 出现，需按 level 精确匹配） */
function findNode(
  map: Map<string, TemplateCategoryTree>,
  parentKey: string,
  parentLevel: number,
): TemplateCategoryTree | undefined {
  for (const node of map.values()) {
    if (node.key === parentKey && node.level === parentLevel) {
      return node;
    }
  }
  return undefined;
}
