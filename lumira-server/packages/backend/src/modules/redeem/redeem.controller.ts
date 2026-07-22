// lumira-server/packages/backend/src/modules/redeem/redeem.controller.ts

import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { RedeemService } from './redeem.service';
import { RedeemCodeDto } from './dto/redeem-code.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

@Controller('redeem')
@UseGuards(DeviceAuthGuard)
export class RedeemController {
  constructor(private readonly redeemService: RedeemService) {}

  @Post()
  async redeem(
    @DeviceId() deviceId: string,
    @Body() dto: RedeemCodeDto,
    @ClientIp() ip: string,
  ) {
    return this.redeemService.redeem(deviceId, dto.code, ip);
  }
}
