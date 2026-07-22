// lumira-server/packages/backend/src/modules/invite/dto/activate-invite.dto.ts

import { IsString, IsIn, IsOptional } from 'class-validator';

export class ActivateInviteDto {
  @IsString()
  inviteCode!: string;

  @IsOptional()
  @IsIn(['direct', 'share_card', 'qrcode'])
  channel?: string;
}
