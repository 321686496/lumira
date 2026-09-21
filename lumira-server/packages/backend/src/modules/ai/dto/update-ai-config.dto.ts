// lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts
// AI 服务商配置保存入参（PUT /api/v1/admin/ai-config）

import { IsIn, IsOptional, IsString, IsBoolean, MaxLength, IsArray, ArrayMaxSize, ArrayNotEmpty, IsInt, Min, Max } from 'class-validator';
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

  /** 剪影模态独立平台：语义同 imageProvider（非空 = 启用，需 silhouetteBaseUrl + apiKey） */
  @IsOptional()
  @IsIn(PROVIDERS)
  silhouetteProvider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  silhouetteBaseUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  silhouetteApiKey?: string;

  @IsBoolean()
  enabled!: boolean;

  // ===== Agentic 研究管线（spec 2026-09-21）=====

  /** 研究开关：1=启用；0/缺省 = 关闭（保留原单次路径） */
  @IsOptional()
  @IsBoolean()
  searchEnabled?: boolean;

  /** 搜索服务商：'general'（通用搜索 API）| 'vendor'（厂商联网检索）| 'qwen'（Qwen 模型自带）| 'off'（关闭） */
  @IsOptional()
  @IsIn(['general', 'vendor', 'off', 'qwen'] as const)
  searchProvider?: string;

  /** 通用搜索 API 的 baseUrl（searchProvider=general 时使用） */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchBaseUrl?: string;

  /** 通用搜索 API 的 apiKey：空串/缺省 = 保留原值；首次启用通用 API 时必填 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchApiKey?: string;

  /** 启用的搜索来源数组（searxng/vendor/baidu/qwen）；缺省 = 沿用原值 */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(3)
  @ArrayNotEmpty()
  @IsIn(['searxng', 'vendor', 'baidu', 'qwen'], { each: true })
  searchSources?: string[];

  /** SearXNG 站点限定（可选，如 xiaohongshu.com / v.douyin.com）；空串/缺省 = 全站搜索 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchSite?: string;

  /** 迭代上限（预算护栏，1~3）；缺省 = 沿用原值 */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  maxIterations?: number;

  /** Qwen 模型自带搜索端点（searchProvider=qwen 时使用） */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchQwenBaseUrl?: string;

  /** Qwen 搜索 API key：空串/缺省 = 保留原值；首次启用 Qwen 搜索必填 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchQwenApiKey?: string;

  /** Qwen 搜索模型（缺省 = qwen-plus） */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  searchQwenModel?: string;
}
