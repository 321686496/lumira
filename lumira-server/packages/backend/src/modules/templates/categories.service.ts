// lumira-server/packages/backend/src/modules/templates/categories.service.ts
// 分类业务逻辑（客户端 + Admin 共用底层查询）

import { Injectable } from '@nestjs/common';
import { eq, asc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { templateCategories } from '../../database/schema';
import { rowToCategory } from './templates.service';
import type { TemplateCategory, TemplateCategoryListResponse } from '@lumira/shared';

@Injectable()
export class CategoriesService {
  constructor(private readonly dbService: DatabaseService) {}

  /** 客户端：仅返回 isActive=1 的分类，按 sortOrder 排序 */
  async listActive(): Promise<TemplateCategoryListResponse> {
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories)
      .where(eq(templateCategories.isActive, 1))
      .orderBy(asc(templateCategories.sortOrder));
    return { categories: rows.map(rowToCategory) };
  }
}
