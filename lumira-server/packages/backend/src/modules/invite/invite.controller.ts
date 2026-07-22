// lumira-server/packages/backend/src/modules/invite/invite.controller.ts

import { Controller, Post, Get, Body, UseGuards } from '@nestjs/common';
import { InviteService } from './invite.service';
import { ActivateInviteDto } from './dto/activate-invite.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

@Controller('invite')
@UseGuards(DeviceAuthGuard)
export class InviteController {
  constructor(private readonly inviteService: InviteService) {}

  @Post('generate')
  async generateInviteCode(@DeviceId() deviceId: string) {
    const inviteCode = await this.inviteService.generateInviteCode(deviceId);
    return { inviteCode };
  }

  @Post('activate')
  async activate(
    @DeviceId() deviceId: string,
    @Body() dto: ActivateInviteDto,
    @ClientIp() ip: string,
  ) {
    return this.inviteService.activateInvite(
      deviceId,
      dto.inviteCode,
      dto.channel || 'direct',
      ip,
    );
  }

  @Get('stats')
  async getStats(@DeviceId() deviceId: string) {
    return this.inviteService.getInviteStats(deviceId);
  }
}
