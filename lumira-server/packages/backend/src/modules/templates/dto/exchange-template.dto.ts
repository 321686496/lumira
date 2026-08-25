// lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts

import { IsString, MinLength, MaxLength, IsOptional, IsInt, Min, IsIn } from 'class-validator';

export class ExchangeTemplateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  templateId!: string;

  // 内置模板（id 无 srv_ 前缀）积分价格，客户端上报，≥1
  @IsOptional()
  @IsInt()
  @Min(1)
  priceCredits?: number;

  // 支付方式：points（积分，默认）/ free_unlock（免费解锁次数，邀请里程碑奖励，不耗积分）
  @IsOptional()
  @IsIn(['points', 'free_unlock'])
  payBy?: 'points' | 'free_unlock';
}
