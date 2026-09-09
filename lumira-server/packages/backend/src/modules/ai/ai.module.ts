// lumira-server/packages/backend/src/modules/ai/ai.module.ts
// AI 模块：ai-config 配置管理（Task 4）+ ai-analyze 识别端点（Task 5，生图/剪影后续并入）
//
// AdminAuthGuard 是静态 token 比对（ADMIN_TOKEN 环境变量），不依赖 JwtService，无需 JwtModule。

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AiConfigController } from './ai-config.controller';
import { AiConfigService } from './ai-config.service';
import { AiTemplatesController } from './ai-templates.controller';
import { AiAnalyzeService } from './ai-analyze.service';

@Module({
  imports: [DatabaseModule],
  controllers: [AiConfigController, AiTemplatesController],
  providers: [AiConfigService, AiAnalyzeService],
})
export class AiModule {}
