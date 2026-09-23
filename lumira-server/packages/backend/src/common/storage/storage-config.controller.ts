// lumira-server/packages/backend/src/common/storage/storage-config.controller.ts

import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { AdminAuthGuard } from '../guards/admin-auth.guard';
import { StorageConfigService, StorageConfigPayload } from './storage-config.service';
import { StorageId } from './storage-registry';

@Controller('admin/storage/config')
@UseGuards(AdminAuthGuard)
export class StorageConfigController {
  constructor(private readonly service: StorageConfigService) {}

  @Get()
  list() {
    return this.service.list();
  }

  @Post(':id')
  save(
    @Param('id') id: string,
    @Body() body: StorageConfigPayload & { active?: boolean },
  ) {
    return this.service.save(id as StorageId, body, !!body.active);
  }
}