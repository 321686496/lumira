// lumira-server/packages/backend/src/common/redis/redis.service.spec.ts
// RedisService 无损降级单元测试：不依赖真实 Redis，确保无 REDIS_URL 时行为为「空缓存、不抛错」。

import { RedisService } from './redis.service';

describe('RedisService (degraded)', () => {
  const originalUrl = process.env.REDIS_URL;

  afterEach(() => {
    if (originalUrl === undefined) {
      delete process.env.REDIS_URL;
    } else {
      process.env.REDIS_URL = originalUrl;
    }
  });

  it('is disabled when REDIS_URL is not set', () => {
    delete process.env.REDIS_URL;
    const svc = new RedisService();
    expect(svc.isEnabled()).toBe(false);
  });

  it('getJson returns null instead of throwing', async () => {
    delete process.env.REDIS_URL;
    const svc = new RedisService();
    await expect(svc.getJson('x')).resolves.toBeNull();
  });

  it('setJson / del / delByPattern silently no-op when disabled', async () => {
    delete process.env.REDIS_URL;
    const svc = new RedisService();
    await expect(svc.setJson('x', { a: 1 }, 60)).resolves.toBeUndefined();
    await expect(svc.del('x')).resolves.toBeUndefined();
    await expect(svc.delByPattern('lumira:cache:*')).resolves.toBeUndefined();
  });
});