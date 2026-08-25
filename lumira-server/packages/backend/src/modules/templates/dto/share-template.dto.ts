import { IsInt, IsString } from 'class-validator';

export class ShareTemplateDto {
  @IsString()
  payload!: string;

  @IsInt()
  expiresInSeconds!: number;
}