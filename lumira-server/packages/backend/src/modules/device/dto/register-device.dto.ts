// lumira-server/packages/backend/src/modules/device/dto/register-device.dto.ts

import { IsString, IsOptional, MinLength, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  deviceId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  alias?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  platform?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  osVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceModel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  appVersion?: string;
}
