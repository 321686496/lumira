// lumira-server/packages/backend/src/modules/device/dto/register-device.dto.ts

import { IsString, IsUUID, IsOptional, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsUUID('4')
  deviceId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  alias?: string;
}
