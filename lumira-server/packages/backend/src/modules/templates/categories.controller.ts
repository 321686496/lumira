// lumira-server/packages/backend/src/modules/templates/categories.controller.ts
// 客户端分类接口（spec 3.2）：GET /templates/categories

import { Controller, Get, UseGuards } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';

@Controller('templates')
@UseGuards(DeviceAuthGuard)
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get('categories')
  async list() {
    return this.categoriesService.listActive();
  }
}
