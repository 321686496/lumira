// lumira-server/packages/backend/src/modules/device/device.controller.ts

import { Controller, Post, Patch, Body, Req, UseGuards } from '@nestjs/common';
import { DeviceService } from './device.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { UpdateDeviceInfoDto } from './dto/update-device-info.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
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

  /// 已注册设备补传/更新设备信息（不轮换 token，供客户端启动时上报）
  @Patch('info')
  @UseGuards(DeviceAuthGuard)
  async updateInfo(
    @Req() req: any,
    @Body() dto: UpdateDeviceInfoDto,
  ) {
    await this.deviceService.updateDeviceInfo(req.deviceId, {
      platform: dto.platform,
      osVersion: dto.osVersion,
      deviceModel: dto.deviceModel,
      appVersion: dto.appVersion,
    });
    return { success: true };
  }
}
