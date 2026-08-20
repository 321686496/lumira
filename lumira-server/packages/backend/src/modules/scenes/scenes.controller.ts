import { Controller, Get, UseGuards } from '@nestjs/common';
import { ScenesService } from './scenes.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
@Controller('scenes')
@UseGuards(DeviceAuthGuard)
export class ScenesController {
  constructor(private readonly scenesService: ScenesService) {}
  @Get()
  list() { return this.scenesService.listActive(); }
}