// lumira-server/packages/backend/src/common/redis/redis.service.ts
// Redis 缓存封装（无损降级：REDIS_URL 未配置或连接失败时退化为空缓存，不抛错）

import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis | null;

  constructor() {
    const url = process.env.REDIS_URL;
    if (!url) {
      this.logger.warn('REDIS_URL not set — cache disabled (graceful fallback to DB)');
      this.client = null;
      return;
    }
    try {
      this.client = new Redis(url, {
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
        lazyConnect: false,
      });
      this.client.on('error', (err) => this.logger.warn(`Redis connection error: ${err.message}`));
    } catch (err) {
      this.logger.warn(`Redis init failed, cache disabled: ${(err as Error).message}`);
      this.client = null;
    }
  }

  isEnabled(): boolean {
    return this.client !== null;
  }

  async getJson<T>(key: string): Promise<T | null> {
    if (!this.client) return null;
    try {
      const raw = await this.client.get(key);
      return raw === null ? null : (JSON.parse(raw) as T);
    } catch (err) {
      this.logger.verbose(`getJson miss for ${key}: ${(err as Error).message}`);
      return null;
    }
  }

  async setJson<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    if (!this.client) return;
    try {
      await this.client.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch (err) {
      this.logger.verbose(`setJson failed for ${key}: ${(err as Error).message}`);
    }
  }

  async del(key: string): Promise<void> {
    if (!this.client) return;
    try {
      await this.client.del(key);
    } catch (err) {
      this.logger.verbose(`del failed for ${key}: ${(err as Error).message}`);
    }
  }

  async delByPattern(pattern: string): Promise<void> {
    if (!this.client) return;
    try {
      let cursor = '0';
      do {
        const [next, keys] = await this.client.scan(cursor, 'MATCH', pattern, 'COUNT', 200);
        cursor = next;
        if (keys.length > 0) {
          await this.client.del(...keys);
        }
      } while (cursor !== '0');
    } catch (err) {
      this.logger.verbose(`delByPattern failed for ${pattern}: ${(err as Error).message}`);
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client) await this.client.quit();
  }
}