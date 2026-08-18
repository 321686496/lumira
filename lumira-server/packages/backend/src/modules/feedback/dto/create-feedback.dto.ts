// lumira-server/packages/backend/src/modules/feedback/dto/create-feedback.dto.ts
import { IsIn, IsString, IsOptional, MinLength, MaxLength } from 'class-validator';

export class CreateFeedbackDto {
  @IsString()
  @IsIn(['bug', 'inconvenience', 'feature', 'template', 'scene', 'other'])
  type!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  content!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  contact?: string | null;
}