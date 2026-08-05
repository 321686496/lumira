import {
  IsString, IsOptional, IsIn, IsArray, ArrayUnique,
  IsInt, Min, ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class QuestionnaireAnswersDto {
  @IsOptional()
  @IsString()
  @IsIn(['app_store', 'social_media', 'friend', 'search', 'article', 'other'])
  source?: string | null;

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'],
    { each: true },
  )
  favorite_categories: string[] = [];

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['composition', 'lighting', 'posing', 'camera_settings', 'post_processing', 'no_subject', 'no_time'],
    { each: true },
  )
  pain_points: string[] = [];

  @IsOptional()
  @IsString()
  @IsIn(['beginner', 'intermediate', 'advanced', 'pro'])
  skill_level?: string | null;

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['learn_photo', 'inspiration', 'better_composition', 'master_camera', 'share_works', 'record_life'],
    { each: true },
  )
  expectations: string[] = [];

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  @IsIn(
    ['indoor_home', 'cafe', 'outdoor_park', 'street', 'travel', 'office', 'studio'],
    { each: true },
  )
  common_scenes: string[] = [];

  @IsOptional()
  @IsString()
  @IsIn(['rarely', 'monthly', 'weekly', 'daily'])
  shoot_frequency?: string | null;
}

export class SubmitQuestionnaireDto {
  @ValidateNested()
  @Type(() => QuestionnaireAnswersDto)
  answers!: QuestionnaireAnswersDto;

  @IsInt()
  @Min(0)
  submittedAt!: number;
}
