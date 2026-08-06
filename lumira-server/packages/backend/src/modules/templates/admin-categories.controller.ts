// lumira-server/packages/backend/src/modules/templates/admin-categories.controller.ts
// Admin 分类管理接口（spec 3.3 + 11.4 三级分类扩展）：CRUD + 显示/隐藏切换
//
// URL 约定：
// - 一级分类用 :key 定位（parentKey 省略或为 null）
// - 二/三级分类用 :key + ?parentKey=<父key> 定位（消歧，因 key 在不同 parent 下可能重复）

import {
  Controller, Get, Post, Patch, Delete, Param, Query, Req, UseGuards, BadRequestException,
} from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { AdminCategoriesService } from './admin-categories.service';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { parseMultipart } from './admin-templates.controller';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

@Controller('admin/categories')
@UseGuards(AdminAuthGuard)
export class AdminCategoriesController {
  constructor(private readonly adminCategoriesService: AdminCategoriesService) {}

  /**
   * 分类列表（含 isActive=0）。
   * 查询参数：
   * - ?level=1|2|3 按层级筛选
   * - ?parentKey=key 按父分类筛选（一级传 ?parentKey=null 或省略）
   */
  @Get()
  async list(
    @Query('level') level?: string,
    @Query('parentKey') parentKey?: string,
  ) {
    const filters: { level?: number; parentKey?: string | null } = {};
    if (level !== undefined) {
      const n = parseInt(level, 10);
      if (Number.isNaN(n) || n < 1 || n > 3) {
        throw new BadRequestException('level must be 1, 2 or 3');
      }
      filters.level = n;
    }
    if (parentKey !== undefined) {
      // ?parentKey=null 表示显式查一级分类
      filters.parentKey = parentKey === 'null' || parentKey === '' ? null : parentKey;
    }
    return this.adminCategoriesService.list(filters);
  }

  @Post()
  async create(@Req() req: FastifyRequest) {
    const parsed = await parseMultipart(req);
    if (!parsed.meta) {
      throw new BadRequestException('Missing "meta" field');
    }

    const metaObj = safeJsonParse(parsed.meta);
    const dto = plainToInstance(CreateCategoryDto, metaObj);
    const errors = await validate(dto, { skipMissingProperties: false });
    if (errors.length > 0) {
      throw new BadRequestException(formatErrors(errors));
    }

    return this.adminCategoriesService.create(dto, parsed.files.icon);
  }

  @Patch(':key')
  async update(
    @Param('key') key: string,
    @Query('parentKey') parentKey: string | undefined,
    @Req() req: FastifyRequest,
  ) {
    const parsed = await parseMultipart(req);
    if (!parsed.meta) {
      throw new BadRequestException('Missing "meta" field');
    }

    const metaObj = safeJsonParse(parsed.meta);
    const dto = plainToInstance(UpdateCategoryDto, metaObj);
    const errors = await validate(dto, { skipMissingProperties: true });
    if (errors.length > 0) {
      throw new BadRequestException(formatErrors(errors));
    }

    return this.adminCategoriesService.update(key, resolveParentKey(parentKey), dto, parsed.files.icon);
  }

  @Delete(':key')
  async delete(
    @Param('key') key: string,
    @Query('parentKey') parentKey: string | undefined,
  ) {
    return this.adminCategoriesService.delete(key, resolveParentKey(parentKey));
  }

  @Post(':key/toggle-active')
  async toggleActive(
    @Param('key') key: string,
    @Query('parentKey') parentKey: string | undefined,
  ) {
    return this.adminCategoriesService.toggleActive(key, resolveParentKey(parentKey));
  }
}

/** 将查询参数 parentKey 解析为 string | null。省略或 "null" 或空 → null（一级分类）。 */
function resolveParentKey(parentKey: string | undefined): string | null {
  if (parentKey === undefined || parentKey === 'null' || parentKey === '') {
    return null;
  }
  return parentKey;
}

function safeJsonParse(s: string): Record<string, unknown> {
  try {
    const v = JSON.parse(s);
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      return v as Record<string, unknown>;
    }
    throw new Error('not a plain object');
  } catch {
    throw new BadRequestException('Invalid JSON in "meta" field');
  }
}

function formatErrors(errors: import('class-validator').ValidationError[]): string {
  return errors
    .map((e) => Object.values(e.constraints || {}).join('; '))
    .join(' | ');
}
