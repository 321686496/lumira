// lumira-server/packages/backend/src/modules/templates/dto/create-category.dto.ts
// POST /admin/categories multipart 中 `meta` JSON 字段对应的 DTO

import { IsString, IsOptional, IsInt, IsBoolean, Min, MaxLength, MinLength, Matches } from 'class-validator';

export class CreateCategoryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  // key 仅允许小写字母/数字/连字符，避免与 URL 路径冲突
  @Matches(/^[a-z0-9-]+$/, { message: 'key must be lowercase letters, digits or hyphens' })
  key!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  /** 简短描述（可为空，仅一/二级分类使用） */
  description?: string;

  @IsOptional()
  @IsString()
  iconUrl?: string;

  /** 父分类 key；省略或 null 表示一级分类 */
  @IsOptional()
  @IsString()
  parentKey?: string | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
