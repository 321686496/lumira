import { IsBoolean } from 'class-validator';

export class ToggleBatchDto {
  @IsBoolean()
  isActive!: boolean;
}
