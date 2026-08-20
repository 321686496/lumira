// lumira-server/packages/backend/src/modules/usage/dto/batch-events.dto.ts
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsIn, IsInt, IsNotEmpty, IsString, Min, ValidateNested } from 'class-validator';
import type { UsageEventType, UsageItemType } from '@lumira/shared';

export class BatchEventDto {
  @Type(() => EventInputDto)
  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  events!: EventInputDto[];
}

export class EventInputDto {
  @IsString() @IsNotEmpty() clientEventId!: string;
  @IsIn(['template', 'scene']) itemType!: UsageItemType;
  @IsString() @IsNotEmpty() itemId!: string;
  @IsString() @IsNotEmpty() itemSource!: string;
  @IsIn(['open_detail', 'use_shoot', 'scene_select']) eventType!: UsageEventType;
  @IsInt() @Min(0) occurredAt!: number;
}