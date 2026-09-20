// lumira-server/packages/backend/src/modules/ai/ai.module.ts
// AI 模块：ai-config 配置管理（Task 4）+ ai-analyze 识别端点（Task 5）+ ai-generate-image 生图端点（Task 7）
//
// AdminAuthGuard 是静态 token 比对（ADMIN_TOKEN 环境变量），不依赖 JwtService，无需 JwtModule。

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AiConfigController } from './ai-config.controller';
import { AiConfigService } from './ai-config.service';
import { AiTemplatesController } from './ai-templates.controller';
import { AiAnalyzeService } from './ai-analyze.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiImageTaskService } from './ai-image-task.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { AiSilhouetteTaskService } from './ai-silhouette-task.service';
import { TrendResearchService } from './trend-research';
import { ImageDescribeService } from './image-describe.service';
import { PoseRefSheetService } from './pose-ref-sheet.service';
import { ParamValidateService } from './param-validate.service';
import { ImageScoreService } from './image-score.service';
import { AiOrchestratorService } from './ai-orchestrator.service';

@Module({
  imports: [DatabaseModule],
  controllers: [AiConfigController, AiTemplatesController],
  providers: [
    AiConfigService, AiAnalyzeService, AiGenerateImageService, AiImageTaskService, AiSilhouetteService, AiSilhouetteTaskService,
    // Task 9 Agentic 管线工具 + 中枢（稳定性：getActiveConfig 缺 search 配置时 research 自动降级关闭）
    TrendResearchService, ImageDescribeService, PoseRefSheetService, ParamValidateService, ImageScoreService,
    AiOrchestratorService,
  ],
})
export class AiModule {}
