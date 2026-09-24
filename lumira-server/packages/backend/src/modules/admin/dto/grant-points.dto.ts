import { IsInt, Min, IsString, MaxLength, IsOptional } from 'class-validator';

export class GrantPointsDto {
  @IsInt()
  @Min(1)
  delta!: number;

  /** 充值原因（选填）：填写后写入流水备注，App 端积分流水优先展示该原因 */
  @IsOptional()
  @IsString()
  @MaxLength(256)
  reason?: string;
}