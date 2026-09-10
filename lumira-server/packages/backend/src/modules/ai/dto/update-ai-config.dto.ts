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

  /** 文本模态独立平台：非空 = 启用（需 textBaseUrl）；空/缺省 = 清除独立配置（跟随共享平台） */
  @IsOptional()
  @IsIn(PROVIDERS)
  textProvider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  textBaseUrl?: string;

  /** 独立平台 apiKey：空/缺省 = 保留原值；首次启用独立平台必须提供 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  textApiKey?: string;

  @IsString()
  @MaxLength(64)
  imageModel!: string;

  /** 生图模态独立平台：语义同 textProvider */
  @IsOptional()
  @IsIn(PROVIDERS)
  imageProvider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  imageBaseUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  imageApiKey?: string;

  /** 剪影专用模型：空串/缺省 = 与生图模型一致（存 null）；非空 = 单独指定 */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  silhouetteModel?: string;

  @IsBoolean()
  enabled!: boolean;
}
