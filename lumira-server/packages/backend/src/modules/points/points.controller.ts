// lumira-server/packages/backend/src/modules/points/points.controller.ts

import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
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

  /**
   * 事件型积分领取：每日首次拍摄（type='shoot_daily'）、完成挑战（type='challenge', refId=challengeId）、
   * 每日首次分享（type='share'）。
   * 幂等：同一设备同一事件只发放一次；重复领取返回 { granted: false }（200，不抛错）。
   */
  @Post('earn')
  async earn(
    @DeviceId() deviceId: string,
    @Body() body: { type?: string; refId?: string },
  ) {
    const type = (body?.type ?? '').trim();
    const refId = (body?.refId ?? '').trim() || null;
    return this.pointsService.earnEvent(
      deviceId,
      type as 'shoot_daily' | 'challenge' | 'share',
      refId,
    );
  }
}
