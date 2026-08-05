// lumira-server/packages/backend/src/modules/templates/dto/exchange-template.dto.ts

import { IsString, MinLength, MaxLength } from 'class-validator';

export class ExchangeTemplateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  templateId!: string;
}
