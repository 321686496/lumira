// lumira-server/packages/backend/src/modules/templates/categories.controller.ts
// 客户端分类接口（spec 3.2 + 11.4）：GET /templates/categories[/tree]

import { Controller, Get, UseGuards } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';

@Controller('templates')
@UseGuards(DeviceAuthGuard)
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  /** 三级树形结构（仅 isActive=1，含 children 嵌套） */
  @Get('categories/tree')
  async tree() {
    return this.categoriesService.listTree();
  }

  /** 扁平分类列表（仅 isActive=1，含 parentKey/level 字段，客户端自行构造树） */
  @Get('categories')
  async list() {
    return this.categoriesService.listActive();
  }
}
