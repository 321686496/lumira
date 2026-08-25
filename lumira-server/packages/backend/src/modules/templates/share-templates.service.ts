import { ForbiddenException, Injectable } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { RedisService } from '../../common/redis/redis.service';

export const SHARE_KEY_PREFIX = 'lumira:share:';
export const MAX_TTL = 43200;
export const MIN_TTL = 60;
export const MAX_PAYLOAD_BYTES = 3 * 1024 * 1024;
export const GET_RATE_LIMIT = 30;
export const RATE_WINDOW = 60; // 秒

interface ShareRecord {
  payload: string;
  expiresAt: number;
  ownerDeviceId: string;
}

@Injectable()
export class ShareTemplatesService {
  constructor(private readonly redis: RedisService) {}

  private key(token: string): string {
    return SHARE_KEY_PREFIX + token;
  }

  async create(
    payload: string,
    expiresInSeconds: number,
    ownerDeviceId: string,
  ): Promise<{ token: string; expiresAt: number }> {
    if (!payload || payload.length === 0) {
      throw new Error('empty_payload');
    }
    const bytes = Buffer.byteLength(payload, 'utf8');
    if (bytes > MAX_PAYLOAD_BYTES) {
      throw new Error('payload_too_large');
    }
    if (!Number.isInteger(expiresInSeconds)) {
      throw new Error('invalid_ttl');
    }
    if (expiresInSeconds < MIN_TTL || expiresInSeconds > MAX_TTL) {
      throw new Error('invalid_ttl');
    }
    const token = randomBytes(16).toString('base64url');
    const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const record: ShareRecord = { payload, expiresAt, ownerDeviceId };
    await this.redis.setJson<ShareRecord>(this.key(token), record, expiresInSeconds);
    return { token, expiresAt };
  }

  async get(
    token: string,
  ): Promise<{ payload: string; expiresAt: number } | null> {
    if (!token) return null;
    const record = await this.redis.getJson<ShareRecord>(this.key(token));
    if (!record) return null;
    return { payload: record.payload, expiresAt: record.expiresAt };
  }

  async revoke(token: string, deviceId: string): Promise<boolean> {
    if (!/^[A-Za-z0-9_-]{10,64}$/.test(token)) return false;
    const record = await this.redis.getJson<ShareRecord>(this.key(token));
    if (!record) return false;
    if (record.ownerDeviceId !== deviceId) {
      throw new ForbiddenException('not_owner');
    }
    await this.redis.del(this.key(token));
    return true;
  }

  async checkRateLimit(deviceId: string): Promise<void> {
    const rk = `lumira:ratelimit:${deviceId}:shareGet`;
    const current = (await this.redis.getJson<number>(rk)) ?? 0;
    if (current >= GET_RATE_LIMIT) {
      throw new Error('rate_limited');
    }
    await this.redis.setJson<number>(rk, current + 1, RATE_WINDOW);
  }
}