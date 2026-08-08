import { IsString, IsArray, IsInt, IsOptional, Min, ArrayMinSize, MaxLength } from 'class-validator';

export class CreateBatchDto {
  @IsString()
  @MaxLength(100)
  campaignName!: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  codes!: string[];

  @IsInt()
  @Min(0)
  rewardPoints!: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  rewardTemplates?: string[];

  @IsInt()
  @Min(1)
  maxUsesPerCode!: number;

  @IsOptional()
  @IsInt()
  validFrom?: number;

  @IsOptional()
  @IsInt()
  validUntil?: number;
}