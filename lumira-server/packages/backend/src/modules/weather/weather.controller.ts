// lumira-server/packages/backend/src/modules/weather/weather.controller.ts
//
// 天气代理接口：GET /weather?lat=31.23&lon=121.47
// 鉴权：DeviceAuthGuard（与 rewards 等接口一致，确保仅注册设备可调用）
// 返回 WeatherResult JSON

import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { WeatherService } from './weather.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';

@Controller('weather')
@UseGuards(DeviceAuthGuard)
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Get()
  async getWeather(
    @Query('lat') latStr: string,
    @Query('lon') lonStr: string,
  ) {
    const lat = parseFloat(latStr);
    const lon = parseFloat(lonStr);
    if (Number.isNaN(lat) || Number.isNaN(lon)) {
      return { error: 'invalid lat or lon' };
    }
    return this.weatherService.getWeather(lat, lon);
  }
}
