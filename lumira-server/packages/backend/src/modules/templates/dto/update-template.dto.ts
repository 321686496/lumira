// lumira-server/packages/backend/src/modules/templates/dto/update-template.dto.ts
// PATCH /admin/templates/:id multipart 中 `meta` JSON 字段对应的 DTO
// 所有字段都是可选的（Partial），id 不可改
// 注意：未引入 @nestjs/mapped-types 依赖，故手写所有可选字段

import {
  IsString, IsOptional, IsInt, IsArray, IsBoolean, Min, MaxLength, MinLength,
} from 'class-validator';

export class UpdateTemplateDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  author?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  version?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  category?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  price?: number;

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
