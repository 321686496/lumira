// lumira-server/packages/backend/src/modules/rewards/rewards.controller.ts

import { Controller, Get, Post, Param, ParseIntPipe, UseGuards, HttpCode } from '@nestjs/common';
import { RewardsService } from './rewards.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('rewards')
@UseGuards(DeviceAuthGuard)
export class RewardsController {
  constructor(private readonly rewardsService: RewardsService) {}

  @Get()
  async listRewards(@DeviceId() deviceId: string) {
    return this.rewardsService.listRewards(deviceId);
  }

  @Post(':id/claim')
  @HttpCode(200)
  async claimReward(
    @DeviceId() deviceId: string,
    @Param('id', ParseIntPipe) rewardId: number,
  ) {
    return this.rewardsService.claimReward(deviceId, rewardId);
  }
}
