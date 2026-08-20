// lumira-server/packages/backend/src/modules/weather/weather.service.ts
//
// 天气代理服务：调用 open-meteo 免费 API（无需 key），按经纬度返回简化天气信息。
// 支持两种取数模式：
//   1) 显式传经纬度：getWeather(lat, lon)；
//   2) 仅传客户端 IP：getWeatherForIp(ip)，先用 ipwho.is 反查近似城市经纬度，
//      再取当地天气，返回天气 + 城市名（用于"今日灵感"卡片按真实位置给建议）。
// 均为内存缓存：天气 30 分钟、IP→位置 6 小时，避免重复调用上游。
// 失败抛标准 Nest 异常，由过滤器转 500。
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
  /** 城市名（按 client IP 反查，缺省或定位失败时为空字符串） */
  city?: string;
}

interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}

/** IP → 近似位置 */
interface GeoResult {
  lat: number;
  lon: number;
  city: string;
}

/** 天气缓存有效期 30 分钟 */
const CACHE_TTL_MS = 30 * 60 * 1000;
/** IP 定位缓存有效期 6 小时（位置相对稳定的场景足够） */
const GEO_TTL_MS = 6 * 60 * 60 * 1000;
/** IP 定位失败时的兜底位置（上海） */
const DEFAULT_GEO: GeoResult = { lat: 31.2304, lon: 121.4737, city: '上海' };

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
  /** 天气缓存，按 "lat,lon" */
  private readonly weatherCache = new Map<string, CacheEntry<WeatherResult>>();
  /** IP 定位缓存，按 "ip" */
  private readonly geoCache = new Map<string, CacheEntry<GeoResult>>();

  async getWeather(lat: number, lon: number): Promise<WeatherResult> {
    const key = `${lat.toFixed(2)},${lon.toFixed(2)}`;
    const cached = this.weatherCache.get(key);
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

    this.weatherCache.set(key, { data: result, expiresAt: now + CACHE_TTL_MS });
    return result;
  }

  /** 根据客户端 IP 反查位置并取当地天气（含城市名）。失败时回退默认城市，绝不抛异常。 */
  async getWeatherForIp(ip: string): Promise<WeatherResult> {
    const geo = await this.geocodeIp(ip);
    const weather = await this.getWeather(geo.lat, geo.lon);
    return { ...weather, city: geo.city };
  }

  /** IP → 近似经纬度 + 城市名（内存缓存 6 小时，失败回退上海）。 */
  private async geocodeIp(ip: string): Promise<GeoResult> {
    const key = ip && ip !== '0.0.0.0' ? ip : 'unknown';
    const cached = this.geoCache.get(key);
    const now = Date.now();
    if (cached && cached.expiresAt > now) return cached.data;

    let geo = DEFAULT_GEO;
    try {
      const resp = await fetch(`https://ipwho.is/${encodeURIComponent(key)}`);
      if (resp.ok) {
        const json = (await resp.json()) as any;
        // ipwho.is 对保留/内网 IP 返回 { success:false }，此时保持默认位置
        if (json?.success !== false && typeof json?.latitude === 'number') {
          geo = {
            lat: json.latitude,
            lon: json.longitude,
            city: (json.city as string) || (json.region as string) || '',
          };
        }
      }
    } catch (e) {
      // 定位失败（网络/上游异常）→ 回退默认位置
    }

    this.geoCache.set(key, { data: geo, expiresAt: now + GEO_TTL_MS });
    return geo;
  }
}