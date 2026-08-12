// lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts

import { IsString, MinLength, MaxLength, IsOptional, IsInt, Min } from 'class-validator';

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
}
