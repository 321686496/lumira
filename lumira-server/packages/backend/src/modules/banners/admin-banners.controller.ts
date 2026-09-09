// lumira-server/packages/backend/src/modules/banners/admin-banners.controller.ts
import { BadRequestException, Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { BannersService } from './banners.service';
import { CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';

@Controller('admin/banners')
@UseGuards(AdminAuthGuard)
export class AdminBannersController {
  constructor(private readonly bannersService: BannersService) {}

  @Get()
  list() {
    return this.bannersService.listAdmin();
  }

  @Post()
  create(@Body() dto: CreateBannerDto) {
    return this.bannersService.create(dto);
  }

  /** POST /admin/banners/upload（multipart，file 字段名 image）→ { url } */
  @Post('upload')
  async upload(@Req() req: FastifyRequest) {
    // 与 templates 模块一致：@fastify/multipart 的 parts() 异步迭代器手写解析
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const reqAny = req as any;
    if (typeof reqAny.parts !== 'function') {
      throw new BadRequestException('Multipart not enabled on this request');
    }
    let buffer: Buffer | null = null;
    let mimetype = '';
    for await (const part of reqAny.parts()) {
      if (part.type === 'file' && part.fieldname === 'image') {
        buffer = await part.toBuffer();
        mimetype = part.mimetype || '';
      }
      // 其他字段忽略
    }
    if (!buffer || buffer.length === 0) {
      throw new BadRequestException('缺少 image 文件字段');
    }
    return this.bannersService.uploadImage(buffer, mimetype);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateBannerDto) {
    return this.bannersService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.bannersService.remove(id);
  }

  @Post(':id/toggle')
  toggle(@Param('id') id: string) {
    return this.bannersService.toggleActive(id);
  }
}
