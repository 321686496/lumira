// lumira-server/packages/backend/src/modules/banners/banners.controller.ts
import { Controller, Get, UseGuards } from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { BannersService } from './banners.service';

@Controller('banners')
@UseGuards(DeviceAuthGuard)
export class BannersController {
  constructor(private readonly bannersService: BannersService) {}

  /** GET /api/v1/banners → { banners: [...] }（App 首页运营位下发） */
  @Get()
  list() {
    return this.bannersService.listForApp();
  }
}
