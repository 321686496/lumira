// lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts
// AI 服务商配置保存入参（PUT /api/v1/admin/ai-config）

import { IsIn, IsOptional, IsString, IsBoolean, MaxLength } from 'class-validator';
import { PROVIDERS } from '../enums';

export class UpdateAiConfigDto {
  @IsIn(PROVIDERS)
  provider!: string;

  @IsString()
  @MaxLength(255)
  baseUrl!: string;

  /** 空串 / 缺省 = 不修改原值；首次保存（无既有配置）必须提供 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiKey?: string;

  @IsString()
  @MaxLength(64)
  visionModel!: string;

  /** 空串 / 缺省 = 清除（回退视觉模型） */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  textModel?: string;

  @IsString()
  @MaxLength(64)
  imageModel!: string;

  @IsBoolean()
  enabled!: boolean;
}
