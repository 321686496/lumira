// lumira-server/packages/backend/src/modules/templates/admin-categories.controller.ts
// Admin 分类管理接口（spec 3.3）：CRUD + 显示/隐藏切换

import {
  Controller, Get, Post, Patch, Delete, Param, Req, UseGuards, BadRequestException,
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

  @Get()
  async list() {
    return this.adminCategoriesService.list();
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

    return this.adminCategoriesService.update(key, dto, parsed.files.icon);
  }

  @Delete(':key')
  async delete(@Param('key') key: string) {
    return this.adminCategoriesService.delete(key);
  }

  @Post(':key/toggle-active')
  async toggleActive(@Param('key') key: string) {
    return this.adminCategoriesService.toggleActive(key);
  }
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
