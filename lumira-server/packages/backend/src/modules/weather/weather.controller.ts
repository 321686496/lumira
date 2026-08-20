// lumira-server/packages/backend/src/modules/weather/weather.controller.ts
//
// 天气代理接口：
//   GET /weather?lat=31.23&lon=121.47  → 按显式经纬度取天气（无城市名）
//   GET /weather                        → 按客户端 IP 反查当地天气（含城市名）
// 鉴权：DeviceAuthGuard（与 rewards 等接口一致，确保仅注册设备可调用）
// 返回 WeatherResult JSON

import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { WeatherService } from './weather.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { ClientIp } from '../../common/decorators/current-ip.decorator';

@Controller('weather')
@UseGuards(DeviceAuthGuard)
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Get()
  async getWeather(
    @ClientIp() ip: string,
    @Query('lat') latStr?: string,
    @Query('lon') lonStr?: string,
  ) {
    // 显式经纬度优先（兼容旧调用/调试）；缺失时按客户端 IP 定位。
    if (latStr && lonStr) {
      const lat = parseFloat(latStr);
      const lon = parseFloat(lonStr);
      if (!Number.isNaN(lat) && !Number.isNaN(lon)) {
        return this.weatherService.getWeather(lat, lon);
      }
    }
    return this.weatherService.getWeatherForIp(ip);
  }
}