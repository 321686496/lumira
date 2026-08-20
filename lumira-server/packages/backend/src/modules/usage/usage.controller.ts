// lumira-server/packages/backend/src/modules/usage/usage.controller.ts
import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { UsageService } from './usage.service';
import { BatchEventDto } from './dto/batch-events.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';
import type { BuiltinTemplateSyncInput } from '@lumira/shared';

@Controller('usage')
@UseGuards(DeviceAuthGuard)
export class UsageController {
  constructor(private readonly usageService: UsageService) {}

  @Post('events')
  async batch(@DeviceId() deviceId: string, @Body() dto: BatchEventDto) {
    return this.usageService.recordBatch(deviceId, dto.events);
  }

  @Get('stats')
  async stats(@Query('itemType') itemType?: string) {
    return this.usageService.stats(
      itemType === 'scene' ? 'scene' : itemType === 'template' ? 'template' : undefined,
    );
  }

  @Post('builtin-templates')
  async builtinTemplates(@Body() dto: BuiltinTemplateSyncInput) {
    return this.usageService.upsertBuiltinTemplates(dto.items);
  }
}