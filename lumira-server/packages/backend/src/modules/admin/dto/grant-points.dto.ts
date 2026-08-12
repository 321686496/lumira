import { IsInt, Min, IsString, MaxLength } from 'class-validator';

export class GrantPointsDto {
  @IsInt()
  @Min(1)
  delta!: number;

  @IsString()
  @MaxLength(256)
  reason!: string;
}