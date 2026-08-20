// lumira-server/packages/backend/src/modules/usage/admin-usage.controller.ts
import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { UsageService } from './usage.service';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import type { UsageItemType } from '@lumira/shared';

@Controller('admin/usage')
@UseGuards(AdminAuthGuard)
export class AdminUsageController {
  constructor(private readonly usageService: UsageService) {}

  @Get('stats')
  async stats(@Query('itemType') itemType?: string) {
    return this.usageService.stats(
      itemType === 'scene' ? 'scene' : itemType === 'template' ? 'template' : undefined,
    );
  }
}