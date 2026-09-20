// lumira-server/packages/backend/src/modules/storage-migration/storage-migration.controller.ts

import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { StorageMigrationService } from './storage-migration.service';

@Controller('admin/storage')
@UseGuards(AdminAuthGuard)
export class StorageMigrationController {
  constructor(private readonly service: StorageMigrationService) {}

  @Post('migrate')
  start(@Body() body: { triggerBy?: string }) {
    return this.service.start(body?.triggerBy ?? 'admin');
  }

  @Get('migrate/status')
  status() {
    return this.service.runningView();
  }

  @Post('migrate/stop')
  stop() {
    const r = this.service.runningView();
    if (!r.id) return { stopped: false };
    return this.service.stop(r.id);
  }

  @Get('migrate')
  list() {
    return this.service.list();
  }

  @Get('migrate/:id')
  detail(@Param('id') id: string) {
    return this.service.detail(id);
  }
}