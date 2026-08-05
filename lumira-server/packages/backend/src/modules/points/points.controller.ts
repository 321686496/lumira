// lumira-server/packages/backend/src/modules/points/points.controller.ts

import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { PointsService } from './points.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('points')
@UseGuards(DeviceAuthGuard)
export class PointsController {
  constructor(private readonly pointsService: PointsService) {}

  @Get('balance')
  async getBalance(@DeviceId() deviceId: string) {
    return this.pointsService.getBalance(deviceId);
  }

  @Get('transactions')
  async listTransactions(
    @DeviceId() deviceId: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const lim = limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50;
    const off = offset ? Math.max(parseInt(offset, 10) || 0, 0) : 0;
    return this.pointsService.listTransactions(deviceId, lim, off);
  }
}
