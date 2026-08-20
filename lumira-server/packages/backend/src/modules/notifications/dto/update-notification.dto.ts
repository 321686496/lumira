// lumira-server/packages/backend/src/modules/notifications/dto/update-notification.dto.ts
// PATCH /admin/notifications/:id 的 DTO，所有字段可选（Partial），id 不可改
import {
  IsBoolean, IsIn, IsInt, IsOptional, IsString, MinLength,
} from 'class-validator';

export class UpdateNotificationDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  title?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  body?: string;

  @IsOptional()
  @IsString()
  iconKey?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsIn(['all', 'devices', 'criteria'])
  targetScope?: string;

  @IsOptional()
  @IsString()
  targetDeviceIdsJson?: string;

  @IsOptional()
  @IsString()
  targetCriteriaJson?: string;

  @IsOptional()
  @IsInt()
  startAt?: number;

  @IsOptional()
  @IsInt()
  endAt?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}