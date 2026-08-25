// lumira-server/packages/backend/src/modules/templates/admin-templates.controller.ts
// Admin 模板管理接口（spec 3.3）：multipart 上传 + CRUD

import {
  Controller, Get, Post, Patch, Delete, Param, Query, Req, UseGuards, BadRequestException,
} from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { AdminTemplatesService, UploadFile } from './admin-templates.service';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { CreateTemplateDto } from './dto/create-template.dto';
import { UpdateTemplateDto } from './dto/update-template.dto';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

@Controller('admin/templates')
@UseGuards(AdminAuthGuard)
export class AdminTemplatesController {
  constructor(private readonly adminTemplatesService: AdminTemplatesService) {}

  @Get()
  async list(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.adminTemplatesService.list(
      page ? parseInt(page, 10) : 1,
      pageSize ? parseInt(pageSize, 10) : 20,
    );
  }

  @Get(':id')
  async detail(@Param('id') id: string) {
    return this.adminTemplatesService.getDetail(id);
  }

  @Post()
  async create(@Req() req: FastifyRequest) {
    const parsed = await parseMultipart(req);
    if (!parsed.meta) {
      throw new BadRequestException('Missing "meta" field');
    }
    if (!parsed.files.cover && !(parsed.files.images && parsed.files.images.length > 0)) {
      throw new BadRequestException('Missing "cover" file');
    }

    // 解析 + 校验 meta JSON
    const metaObj = safeJsonParse(parsed.meta, 'meta');
    const dto = plainToInstance(CreateTemplateDto, metaObj);
    const errors = await validate(dto, { skipMissingProperties: false });
    if (errors.length > 0) {
      throw new BadRequestException(formatErrors(errors));
    }

    return this.adminTemplatesService.create(
      dto,
      parsed.files.cover,
      parsed.files.silhouette,
      parsed.files.pptpl,
      parsed.files.images,
    );
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Req() req: FastifyRequest,
  ) {
    const parsed = await parseMultipart(req);
    if (!parsed.meta) {
      throw new BadRequestException('Missing "meta" field');
    }

    const metaObj = safeJsonParse(parsed.meta, 'meta');
    const dto = plainToInstance(UpdateTemplateDto, metaObj);
    const errors = await validate(dto, { skipMissingProperties: true });
    if (errors.length > 0) {
      throw new BadRequestException(formatErrors(errors));
    }

    return this.adminTemplatesService.update(
      id,
      dto,
      parsed.files.cover,
      parsed.files.silhouette,
      parsed.files.pptpl,
      parsed.files.images,
    );
  }

  @Delete(':id')
  async delete(@Param('id') id: string) {
    return this.adminTemplatesService.delete(id);
  }

  @Post(':id/toggle-active')
  async toggleActive(@Param('id') id: string) {
    return this.adminTemplatesService.toggleActive(id);
  }
}

// ===== multipart 解析工具（模板管理 + 分类管理共用）=====

interface ParsedMultipart {
  meta: string | null;
  files: {
    cover?: UploadFile;
    silhouette?: UploadFile;
    pptpl?: UploadFile;
    icon?: UploadFile;
    /** 多效果图（[0]=封面） */
    images?: UploadFile[];
  };
}

/**
 * 解析 multipart 请求，提取 `meta` 文本字段和文件字段
 * （cover/silhouette/pptpl/icon/多张 images）。
 * 使用 @fastify/multipart 的 request.parts() 异步迭代器。
 */
export async function parseMultipart(req: FastifyRequest): Promise<ParsedMultipart> {
  const result: ParsedMultipart = { meta: null, files: {} };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }

  for await (const part of reqAny.parts()) {
    if (part.type === 'field') {
      if (part.fieldname === 'meta') {
        result.meta = part.value as string;
      }
    } else if (part.type === 'file') {
      const fieldname = part.fieldname as string;
      const buffer = await part.toBuffer();
      const file: UploadFile = {
        buffer,
        filename: part.filename || '',
        mimetype: part.mimetype || '',
      };
      if (fieldname === 'cover') {
        result.files.cover = file;
      } else if (fieldname === 'silhouette') {
        result.files.silhouette = file;
      } else if (fieldname === 'pptpl') {
        result.files.pptpl = file;
      } else if (fieldname === 'icon') {
        result.files.icon = file;
      } else if (fieldname === 'images' || fieldname?.startsWith('images[')) {
        // 多效果图：字段名 images 或 images[N]
        (result.files.images = result.files.images || []).push(file);
      }
      // 其他字段名忽略
    }
  }

  return result;
}

function safeJsonParse(s: string, fieldname: string): Record<string, unknown> {
  try {
    const v = JSON.parse(s);
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      return v as Record<string, unknown>;
    }
    throw new Error('not a plain object');
  } catch {
    throw new BadRequestException(`Invalid JSON in "${fieldname}" field`);
  }
}

function formatErrors(errors: import('class-validator').ValidationError[]): string {
  return errors
    .map((e) => Object.values(e.constraints || {}).join('; '))
    .join(' | ');
}
