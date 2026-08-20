import { IsArray, IsBoolean, IsIn, IsInt, IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';
export class CreateSceneDto {
  @IsString() @IsNotEmpty() id!: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsIn(['light', 'outdoor', 'indoor', 'mood']) category!: string;
  @IsOptional() @IsString() style?: string;
  @IsOptional() @IsString() icon?: string;
  @IsOptional() @IsString() vibe?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsObject() filter?: Record<string, unknown>;
  @IsOptional() @IsArray() tips?: string[];
  @IsOptional() @IsArray() exampleImages?: string[];
  @IsOptional() @IsString() whereToShoot?: string;
  @IsOptional() @IsString() bestTime?: string;
  @IsOptional() @IsString() relatedCategory?: string;
  @IsOptional() @IsArray() recommendedTagIds?: string[];
  @IsOptional() @IsInt() sortOrder?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}