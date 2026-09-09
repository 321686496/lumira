// lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts
// PATCH /admin/banners/:id 的 DTO，所有字段可选（Partial），id 不可改
import {
  IsBoolean, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength,
} from 'class-validator';
import { OPERATION_BANNER_CONDITIONS, OPERATION_BANNER_ROUTES } from '../operation-banner.rules';

export class UpdateBannerDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  title?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  subtitle?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(32)
  tag?: string;

  @IsOptional()
  @IsIn(OPERATION_BANNER_ROUTES)
  route?: string;

  @IsOptional()
  @IsIn(OPERATION_BANNER_CONDITIONS)
  condition?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
