// lumira-server/packages/backend/src/modules/device/dto/update-device-info.dto.ts

import { IsString, IsOptional, MaxLength } from 'class-validator';

export class UpdateDeviceInfoDto {
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