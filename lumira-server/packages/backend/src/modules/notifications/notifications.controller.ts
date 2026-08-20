// lumira-server/packages/backend/src/modules/notifications/notifications.controller.ts

import { Controller, Get, UseGuards } from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators/device.decorator';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
@UseGuards(DeviceAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(@DeviceId() deviceId: string) {
    return this.notificationsService.listForDevice(deviceId);
  }
}