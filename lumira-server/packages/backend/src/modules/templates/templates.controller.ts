// lumira-server/packages/backend/src/modules/templates/templates.controller.ts

import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { TemplatesService } from './templates.service';
import { ExchangeTemplateDto } from './dto/exchange-template.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('templates')
@UseGuards(DeviceAuthGuard)
export class TemplatesController {
  constructor(private readonly templatesService: TemplatesService) {}

  // ===== 客户端：后端动态模板（spec 3.2）=====
  // 静态路由需在 :id 之前声明（NestJS 默认静态优先，但保持顺序更安全）

  @Get('list')
  async listRemote(
    @Query('since') since?: string,
    @Query('category') category?: string,
    @Query('subtree') subtree?: string,
  ) {
    const sinceNum = since !== undefined ? parseInt(since, 10) : undefined;
    // subtree：逗号分隔的子树 key 集合（含自身及所有后代 key），
    // 匹配「该分类族内所有后代挂的模板」——模板任一 classification 字段命中集合即算
    const subtreeKeys = subtree ? subtree.split(',').map((k) => k.trim()).filter(Boolean) : undefined;
    return this.templatesService.listRemoteTemplates(sinceNum, category, subtreeKeys);
  }

  @Get('owned')
  async listOwned(@DeviceId() deviceId: string) {
    return this.templatesService.listOwned(deviceId);
  }

  @Get('prices')
  async listPrices() {
    return this.templatesService.listPrices();
  }

  // :id 必须放在所有静态子路径之后
  @Get(':id')
  async getRemoteDetail(@Param('id') id: string) {
    return this.templatesService.getRemoteTemplateDetail(id);
  }

  @Post('exchange')
  async exchange(
    @DeviceId() deviceId: string,
    @Body() dto: ExchangeTemplateDto,
  ) {
    return this.templatesService.exchange(deviceId, dto.templateId, dto.priceCredits);
  }
}
