// lumira-server/packages/backend/src/modules/templates/dto/create-template.dto.ts
// POST /admin/templates multipart 中 `meta` JSON 字段对应的 DTO（spec 3.4）
// 注意：multipart 不走 NestJS @Body() 自动校验，service 中需手动 plainToInstance + validate

import {
  IsString, IsOptional, IsInt, IsArray, IsBoolean, Min, MaxLength, MinLength,
} from 'class-validator';

export class CreateTemplateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  author?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  version?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  category!: string;

  @IsInt()
  @Min(0)
  price!: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  shortDesc?: string;

  @IsOptional()
  ambience?: {
    seasons?: string[];
    weathers?: string[];
    timeTones?: string[];
  };

  @IsOptional()
  @IsString()
  @MaxLength(256)
  referenceSource?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  tagIds?: string[];

  @IsOptional()
  // 三级分类：type → majorStyle → style；subStyle 为旧字段兼容（与 style 同值）；
  // method 不再作为树层级（兼容保留）
  classification?: { type: string; majorStyle: string; style: string; subStyle?: string; method?: string };

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  composition?: Record<string, unknown>;

  @IsOptional()
  /** 兼容旧 admin：单个姿势（poses 优先） */
  pose?: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  /** 姿势组（多姿势，优先于 pose） */
  poses?: Record<string, unknown>[];

  @IsOptional()
  @IsArray()
  /** 效果图列表（[0]=封面，优先于 cover 文件上传） */
  images?: Record<string, unknown>[];

  @IsOptional()
  camera?: Record<string, unknown>;

  @IsOptional()
  sceneGuide?: Record<string, unknown>;

  @IsOptional()
  postProcess?: Record<string, unknown>;
}
