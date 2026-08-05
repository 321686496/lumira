// lumira-server/packages/backend/src/modules/templates/templates.controller.ts

import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { TemplatesService } from './templates.service';
import { ExchangeTemplateDto } from './dto/exchange-template.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('templates')
@UseGuards(DeviceAuthGuard)
export class TemplatesController {
  constructor(private readonly templatesService: TemplatesService) {}

  @Get('owned')
  async listOwned(@DeviceId() deviceId: string) {
    return this.templatesService.listOwned(deviceId);
  }

  @Get('prices')
  async listPrices() {
    return this.templatesService.listPrices();
  }

  @Post('exchange')
  async exchange(
    @DeviceId() deviceId: string,
    @Body() dto: ExchangeTemplateDto,
  ) {
    return this.templatesService.exchange(deviceId, dto.templateId);
  }
}
