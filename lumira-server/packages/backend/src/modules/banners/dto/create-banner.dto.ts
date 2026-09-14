import { IsBoolean, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, Max, Min, Matches, MaxLength, ValidateIf } from 'class-validator';
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

  /** 运营位 route 仅对 operation 类型校验白名单；ad 跳外部 URL，route 不受限（可省略） */
  @ValidateIf((o: CreateBannerDto) => o.kind !== 'ad')
  @IsIn(OPERATION_BANNER_ROUTES)
  route?: string;

  /** 条目类型：operation=条件触达运营位 / ad=活动广告曝光（默认 operation） */
  @IsOptional()
  @IsIn(['operation', 'ad'])
  kind?: string;

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

  /** 条件仅对 operation 类型必填；ad 不参与条件匹配 */
  @ValidateIf((o: CreateBannerDto) => o.kind !== 'ad')
  @IsIn(OPERATION_BANNER_CONDITIONS)
  condition!: string;

  /** 广告点击跳转的外部 URL（kind=ad 时必填） */
  @ValidateIf((o: CreateBannerDto) => o.kind === 'ad')
  @IsString()
  @IsNotEmpty()
  @MaxLength(512)
  externalUrl?: string;

  /** 广告位绝对槽位下标（0 起）；缺省/越界 = 放最后一个槽位 */
  @IsOptional()
  @IsInt()
  position?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
