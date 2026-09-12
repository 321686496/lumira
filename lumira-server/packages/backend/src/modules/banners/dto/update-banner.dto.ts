// lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts
// PATCH /admin/banners/:id 的 DTO，所有字段可选（Partial），id 不可改
import {
  IsBoolean, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min,
  MaxLength,
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

  /** 目标模板 id：空串/缺省时清除 */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  templateId?: string | null;

  /** 配图 URL：null/空串清除配图；其余为相对 storageKey 或完整 http(s) URL */
  @IsOptional()
  @IsString()
  @MaxLength(512)
  imageUrl?: string | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  focusX?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  focusY?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(3)
  focusZoom?: number;

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
