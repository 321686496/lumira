// lumira-server/packages/backend/src/modules/profile/dto/update-profile.dto.ts

import { IsOptional, IsString, MinLength, MaxLength } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(20)
  username?: string;

  @IsOptional() @IsString() @MinLength(1) @MaxLength(64)
  avatarSeed?: string;
}
