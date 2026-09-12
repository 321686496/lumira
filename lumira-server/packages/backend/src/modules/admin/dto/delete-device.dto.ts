import { IsString, MinLength } from 'class-validator';

export class DeleteDeviceDto {
  @IsString()
  @MinLength(1)
  loginKey!: string;
}
