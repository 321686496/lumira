// lumira-server/packages/backend/src/modules/ai/ai.module.ts
// AI 模块：ai-config 配置管理（Task 4）；ai-analyze 识别端点（Task 5）后续并入本模块
//
// AdminAuthGuard 是静态 token 比对（ADMIN_TOKEN 环境变量），不依赖 JwtService，无需 JwtModule。

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AiConfigController } from './ai-config.controller';
import { AiConfigService } from './ai-config.service';

@Module({
  imports: [DatabaseModule],
  controllers: [AiConfigController],
  providers: [AiConfigService],
})
export class AiModule {}
