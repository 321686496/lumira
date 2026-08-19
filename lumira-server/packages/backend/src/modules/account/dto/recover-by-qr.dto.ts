import { IsString, MinLength, MaxLength } from 'class-validator';
export class RecoverByQrDto {
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  secret!: string;
}