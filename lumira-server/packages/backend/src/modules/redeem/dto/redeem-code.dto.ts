// lumira-server/packages/backend/src/modules/redeem/dto/redeem-code.dto.ts

import { IsString, Length } from 'class-validator';

export class RedeemCodeDto {
  @IsString()
  @Length(6, 32)  // 兼容不同长度的兑换码
  code!: string;
}
