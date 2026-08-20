import { IsBoolean, IsIn, IsInt, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateNotificationDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsString()
  @IsNotEmpty()
  body!: string;

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