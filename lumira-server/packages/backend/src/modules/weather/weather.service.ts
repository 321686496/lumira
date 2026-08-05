// lumira-server/packages/backend/src/modules/weather/weather.service.ts
//
// 天气代理服务：调用 open-meteo 免费 API（无需 key），按经纬度返回简化天气信息。
// 内存缓存 30 分钟，避免重复调用。失败抛标准 Nest 异常，由过滤器转 500。
//
// open-meteo 文档：https://open-meteo.com/en/docs
// 接口示例：
//   https://api.open-meteo.com/v1/forecast?latitude=31.23&longitude=121.47
//     &current=temperature_2m,weather_code
//     &daily=sunrise,sunset
//     &timezone=auto&forecast_days=1

import { Injectable, ServiceUnavailableException } from '@nestjs/common';

export interface WeatherResult {
  /** 气温（摄氏度） */
  temperature: number;
  /** 天气状态中文描述：晴/多云/阴/雨/雪/雾 */
  condition: string;
  /** 日出时间 ISO 8601（含时区） */
  sunrise: string;
  /** 日落时间 ISO 8601（含时区） */
  sunset: string;
  /** 数据获取时间戳（毫秒） */
  fetchedAt: number;
}

interface CacheEntry {
  data: WeatherResult;
  expiresAt: number;
}

/** 缓存有效期 30 分钟 */
const CACHE_TTL_MS = 30 * 60 * 1000;

/** WMO weather code → 中文描述 */
function describeWeatherCode(code: number): string {
  if (code === 0) return '晴';
  if (code <= 2) return '多云';
  if (code === 3) return '阴';
  if (code >= 45 && code <= 48) return '雾';
  if (code >= 51 && code <= 67) return '雨';
  if (code >= 71 && code <= 77) return '雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 95) return '雷雨';
  return '多云';
}

@Injectable()
export class WeatherService {
  /** 按 "lat,lon" 缓存 */
  private readonly cache = new Map<string, CacheEntry>();

  async getWeather(lat: number, lon: number): Promise<WeatherResult> {
    const key = `${lat.toFixed(2)},${lon.toFixed(2)}`;
    const cached = this.cache.get(key);
    const now = Date.now();
    if (cached && cached.expiresAt > now) {
      return cached.data;
    }

    const url =
      `https://api.open-meteo.com/v1/forecast` +
      `?latitude=${lat}&longitude=${lon}` +
      `&current=temperature_2m,weather_code` +
      `&daily=sunrise,sunset` +
      `&timezone=auto&forecast_days=1`;

    let resp: Response;
    try {
      resp = await fetch(url, { method: 'GET' });
    } catch (e) {
      // 网络错误：若有旧缓存（即使过期）也返回，避免完全无数据
      if (cached) return cached.data;
      throw new ServiceUnavailableException('Weather upstream unreachable');
    }

    if (!resp.ok) {
      if (cached) return cached.data;
      throw new ServiceUnavailableException(`Weather upstream ${resp.status}`);
    }

    const json = (await resp.json()) as any;
    const result: WeatherResult = {
      temperature: Math.round(json?.current?.temperature_2m ?? 0),
      condition: describeWeatherCode(json?.current?.weather_code ?? 0),
      sunrise: json?.daily?.sunrise?.[0] ?? '',
      sunset: json?.daily?.sunset?.[0] ?? '',
      fetchedAt: now,
    };

    this.cache.set(key, { data: result, expiresAt: now + CACHE_TTL_MS });
    return result;
  }
}
