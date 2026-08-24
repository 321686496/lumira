// lumira-server/packages/backend/src/modules/templates/thumbs.controller.ts
// 公开缩略图接口（无鉴权，图片资源与 /uploads 静态资源一样对外公开）。

import { Controller, Get, Param, Query, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { ThumbsService } from './thumbs.service';

@Controller('thumbs')
export class ThumbsController {
  constructor(private readonly thumbs: ThumbsService) {}

  /**
   * 分类图标缩略图：GET /api/v1/thumbs/categories/:key?w=600
   * 供 App 网格/卡片以较小尺寸请求封面，显著减少首次加载的下载字节量。
   */
  @Get('categories/:key')
  async categoryIcon(
    @Param('key') key: string,
    @Query('w') w: string,
    @Res() reply: FastifyReply,
  ) {
    if (!/^[a-z0-9][a-z0-9_-]*$/i.test(key)) {
      return reply.code(400).type('text/plain').send('bad key');
    }
    try {
      const { data, type } = await this.thumbs.categoryIcon(key, w);
      // 缩略图按 (类别+宽度) 固定命名，内容不可变 → 强缓存。
      reply.header('Cache-Control', 'public, max-age=31536000, immutable');
      return reply.type(type).send(data);
    } catch (e) {
      return reply.code(404).type('text/plain').send('not found');
    }
  }
}