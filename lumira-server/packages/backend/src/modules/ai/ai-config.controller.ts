// lumira-server/packages/backend/src/modules/ai/ai-config.controller.ts
// AI 服务商配置管理端点（/api/v1/admin/ai-config，AdminAuthGuard 保护）

import { Body, Controller, Get, Post, Put, UseGuards } from '@nestjs/common';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { AiConfigService } from './ai-config.service';
import { UpdateAiConfigDto } from './dto/update-ai-config.dto';
import type { AiConfigTestTarget } from './ai-config.service';

@Controller('admin/ai-config')
@UseGuards(AdminAuthGuard)
export class AiConfigController {
  constructor(private readonly aiConfigService: AiConfigService) {}

  @Get()
  get() {
    return this.aiConfigService.get();
  }

  @Put()
  save(@Body() dto: UpdateAiConfigDto) {
    return this.aiConfigService.save(dto);
  }

  @Post('test')
  test(@Body() body?: { targets?: AiConfigTestTarget[] }) {
    return this.aiConfigService.test(body?.targets);
  }
}
