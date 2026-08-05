// lumira-server/packages/backend/src/modules/sign-in/sign-in.controller.ts

import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { SignInService } from './sign-in.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('sign-in')
@UseGuards(DeviceAuthGuard)
export class SignInController {
  constructor(private readonly signInService: SignInService) {}

  @Get('status')
  async getStatus(@DeviceId() deviceId: string) {
    return this.signInService.getStatus(deviceId);
  }

  @Post()
  async signIn(@DeviceId() deviceId: string) {
    return this.signInService.signIn(deviceId);
  }
}
