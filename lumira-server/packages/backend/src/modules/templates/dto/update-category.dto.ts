// lumira-server/packages/backend/src/modules/templates/dto/update-category.dto.ts
// PATCH /admin/categories/:key multipart 中 `meta` JSON 字段对应的 DTO
// key 不可改（系统分类保护），故此处不含 key 字段

import { IsString, IsOptional, IsInt, IsBoolean, Min, MaxLength, MinLength } from 'class-validator';

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  name?: string;

  @IsOptional()
  @IsString()
  iconUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
