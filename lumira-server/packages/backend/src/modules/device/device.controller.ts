// lumira-server/packages/backend/src/modules/device/device.controller.ts

import { Controller, Post, Body, Req } from '@nestjs/common';
import { DeviceService } from './device.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { RegisterDeviceResponse } from '@lumira/shared';

@Controller('device')
export class DeviceController {
  constructor(private readonly deviceService: DeviceService) {}

  @Post('register')
  async register(
    @Body() dto: RegisterDeviceDto,
    @Req() req: any,
  ): Promise<RegisterDeviceResponse> {
    const ip = req.ip || '0.0.0.0';
    return this.deviceService.registerDevice(dto.deviceId, dto.alias, ip, {
      platform: dto.platform,
      osVersion: dto.osVersion,
      deviceModel: dto.deviceModel,
      appVersion: dto.appVersion,
    });
  }
}
