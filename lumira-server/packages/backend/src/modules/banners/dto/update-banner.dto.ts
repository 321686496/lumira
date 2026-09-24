// lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts
// PATCH /admin/banners/:id 的 DTO，所有字段可选（Partial），id 不可改
import {
  IsBoolean, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min,
  MaxLength, ValidateIf,
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
  @ValidateIf((o: UpdateBannerDto) => o.kind !== 'ad')
  @IsIn(OPERATION_BANNER_ROUTES)
  route?: string;

  /** 条目类型：operation=条件触达运营位 / ad=活动广告曝光 / search=App 内搜索（默认 operation） */
  @IsOptional()
  @IsIn(['operation', 'ad', 'search'])
  kind?: string;

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
  @ValidateIf((o: UpdateBannerDto) => o.kind !== 'ad')
  @IsIn(OPERATION_BANNER_CONDITIONS)
  condition?: string;

  /** 广告点击跳转的外部 URL（kind=ad 时必填）；null/空串清除 */
  @IsOptional()
  @IsString()
  @MaxLength(512)
  externalUrl?: string | null;

  /** App 内搜索关键字（kind=search 时必填）；null/空串清除 */
  @IsOptional()
  @ValidateIf((o: UpdateBannerDto) => o.kind === 'search')
  @IsString()
  @IsNotEmpty()
  @MaxLength(128)
  searchKeyword?: string | null;

  /** 搜索范围：all=全部 / template=模板 / scene=场景 / academy=美学院（默认 all） */
  @IsOptional()
  @IsIn(['all', 'template', 'scene', 'academy'])
  searchScope?: string;

  /** 广告位绝对槽位下标（0 起）；null/缺省 = 放最后一个槽位 */
  @IsOptional()
  @IsInt()
  position?: number | null;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
