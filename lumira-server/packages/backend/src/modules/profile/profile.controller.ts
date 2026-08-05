// lumira-server/packages/backend/src/modules/profile/profile.controller.ts

import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import { ProfileService } from './profile.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('profile')
@UseGuards(DeviceAuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  async get(@DeviceId() deviceId: string) {
    return this.profileService.getOrCreateProfile(deviceId);
  }

  @Patch()
  async update(@DeviceId() deviceId: string, @Body() dto: UpdateProfileDto) {
    return this.profileService.updateProfile(deviceId, dto);
  }
}
