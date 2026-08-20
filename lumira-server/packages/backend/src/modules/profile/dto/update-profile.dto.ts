// lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.ts

import {
  IsOptional, IsString, MinLength, MaxLength,
  IsIn, IsArray, ArrayUnique,
} from 'class-validator';

const FAVORITE_CATEGORIES = ['portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'];
const PAIN_POINTS = ['composition', 'lighting', 'posing', 'camera_settings', 'post_processing', 'no_subject', 'no_time'];
const EXPECTATIONS = ['learn_photo', 'inspiration', 'better_composition', 'master_camera', 'share_works', 'record_life'];
const COMMON_SCENES = ['indoor_home', 'cafe', 'outdoor_park', 'street', 'travel', 'office', 'studio'];

export class UpdateProfileDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(20)
  username?: string;

  @IsOptional() @IsString() @MinLength(1) @MaxLength(64)
  avatarSeed?: string;

  @IsOptional() @IsString() @IsIn(['male', 'female', 'prefer_not'])
  gender?: string;

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(FAVORITE_CATEGORIES, { each: true })
  favoriteCategories?: string[];

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(PAIN_POINTS, { each: true })
  painPoints?: string[];

  @IsOptional() @IsString() @IsIn(['beginner', 'intermediate', 'advanced', 'pro'])
  skillLevel?: string;

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(EXPECTATIONS, { each: true })
  expectations?: string[];

  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) @IsIn(COMMON_SCENES, { each: true })
  commonScenes?: string[];

  @IsOptional() @IsString() @IsIn(['rarely', 'monthly', 'weekly', 'daily'])
  shootFrequency?: string;

  @IsOptional() @IsString() @MaxLength(255)
  avatarUrl?: string;
}