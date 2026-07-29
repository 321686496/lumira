// lumira-server/packages/backend/src/modules/device/dto/register-device.dto.ts

import { IsString, IsOptional, MinLength, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  // deviceId 格式由客户端平台决定，不强制 UUID：
  // - Android: ANDROID_ID（16 位十六进制字符串）
  // - iOS: identifierForVendor（UUID v4）
  // - 鸿蒙 fallback: 自定义格式
  // 数据库 schema 为 text 类型，只需保证非空且长度合理
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  deviceId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  alias?: string;
}
