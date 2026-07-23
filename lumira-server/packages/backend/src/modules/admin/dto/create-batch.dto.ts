// lumira-server/packages/backend/src/modules/admin/dto/create-batch.dto.ts

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
  @Min(1)
  rewardTier!: number;

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
