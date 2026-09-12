import { IsBoolean, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min, Matches, MaxLength } from 'class-validator';
import { OPERATION_BANNER_CONDITIONS, OPERATION_BANNER_ROUTES } from '../operation-banner.rules';

export class CreateBannerDto {
  /** 稳定 id（App 埋点 trackingId），省略时自动生成 */
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9_-]{2,64}$/)
  id?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  title!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  subtitle!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(32)
  tag!: string;

  @IsIn(OPERATION_BANNER_ROUTES)
  route!: string;

  /** 目标模板 id（可空）：route 为 /templates/detail 时必填 */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  templateId?: string;

  /** 配图 URL（可空）：相对 storageKey（/uploads/...）或完整 http(s) URL */
  @IsOptional()
  @IsString()
  @MaxLength(512)
  imageUrl?: string | null;

  /** 背景图水平焦点：0 左，1 右；默认/非法值归一化为 0.5 */
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  focusX?: number;

  /** 背景图垂直焦点：0 上，1 下；默认/非法值归一化为 0.5 */
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1)
  focusY?: number;

  /** 背景图缩放：1 原图 cover，3 最大放大 */
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(3)
  focusZoom?: number;

  @IsIn(OPERATION_BANNER_CONDITIONS)
  condition!: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
