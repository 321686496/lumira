// lumira-server/packages/backend/src/modules/scenes/dto/update-scene.dto.ts
// PATCH /admin/scenes/:id 的 DTO，所有字段可选（Partial），id 不可改
// 注意：项目未引入 @nestjs/mapped-types 依赖，故手写所有可选字段（同 update-template.dto.ts 模式）

import {
  IsArray, IsBoolean, IsIn, IsInt, IsObject, IsOptional, IsString, MinLength,
} from 'class-validator';

export class UpdateSceneDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  name?: string;

  @IsOptional()
  @IsIn(['light', 'outdoor', 'indoor', 'mood'])
  category?: string;

  @IsOptional()
  @IsString()
  style?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsString()
  vibe?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsObject()
  filter?: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  tips?: string[];

  @IsOptional()
  @IsArray()
  exampleImages?: string[];

  @IsOptional()
  @IsString()
  whereToShoot?: string;

  @IsOptional()
  @IsString()
  bestTime?: string;

  @IsOptional()
  @IsString()
  relatedCategory?: string;

  @IsOptional()
  @IsArray()
  recommendedTagIds?: string[];

  @IsOptional()
  @IsInt()
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}