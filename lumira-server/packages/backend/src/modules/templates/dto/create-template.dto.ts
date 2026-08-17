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
  // style 为旧 admin 前端的兼容字段（仅提交 style 时按 subStyle 存储）
  classification?: { type: string; majorStyle: string; subStyle: string; method: string; style?: string };

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
  pose?: Record<string, unknown>;

  @IsOptional()
  camera?: Record<string, unknown>;

  @IsOptional()
  sceneGuide?: Record<string, unknown>;

  @IsOptional()
  postProcess?: Record<string, unknown>;
}
