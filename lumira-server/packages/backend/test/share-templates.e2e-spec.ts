// lumira-server/packages/backend/test/share-templates.e2e-spec.ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import { resetTestDatabase } from './test-db';
import { GET_RATE_LIMIT } from '../src/modules/templates/share-templates.service';

describe('ShareTemplatesController (e2e) — 二维码分享', () => {
  let app: NestFastifyApplication;
  let ownerToken: string;
  let foreignToken: string;
  let rateToken: string;

  // 三个独立设备：owner（创建者）、foreign（非创建者）、rateLimiter（限速专用）
  const ownerDeviceId = '55555555-5555-5555-8555-555555555551';
  const foreignDeviceId = '55555555-5555-5555-8555-555555555552';
  const rateDeviceId = '55555555-5555-5555-8555-555555555553';

  const payload = JSON.stringify({
    format: 'lumira-pptpl',
    meta: { name: '测试模板' },
    composition: {},
    pose: {},
    sceneGuide: {},
    camera: {},
    postProcess: {},
  });

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    // 分享逻辑存储在 Redis（TTL），需要真实 Redis；默认指向本机，与模板 spec 的 DB 默认值做法一致
    process.env.REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
    await resetTestDatabase();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    const register = async (deviceId: string) => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/device/register')
        .send({ deviceId });
      return res.body.token as string;
    };
    ownerToken = await register(ownerDeviceId);
    foreignToken = await register(foreignDeviceId);
    rateToken = await register(rateDeviceId);
  });

  afterAll(async () => {
    await app.close();
  });

  it('创建分享后可按 token 读取，payload 与上传一致', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/v1/templates/share')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ payload, expiresInSeconds: 3600 })
      .expect(201);

    expect(created.body.token).toBeDefined();
    expect(created.body.expiresAt).toBeGreaterThan(Math.floor(Date.now() / 1000));

    const got = await request(app.getHttpServer())
      .get(`/api/v1/templates/share/${created.body.token}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(200);

    expect(got.body.payload).toBe(payload);
    expect(got.body.expiresAt).toBe(created.body.expiresAt);
  });

  it('有效期超过上限(>43200)返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/share')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ payload, expiresInSeconds: 999999 })
      .expect(400);
  });

  it('payload 超过 3MB 返回 400', async () => {
    const huge = 'a'.repeat(3 * 1024 * 1024 + 1);
    await request(app.getHttpServer())
      .post('/api/v1/templates/share')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ payload: huge, expiresInSeconds: 3600 })
      .expect(400);
  });

  it('读取不存在的 token 返回 404', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/templates/share/doesnotexisttoken1234567890')
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(404);
  });

  it('创建者可撤回，撤回后再次读取返回 404', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/v1/templates/share')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ payload, expiresInSeconds: 3600 })
      .expect(201);
    const token = created.body.token as string;

    await request(app.getHttpServer())
      .delete(`/api/v1/templates/share/${token}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(200);
    await request(app.getHttpServer())
      .delete(`/api/v1/templates/share/${token}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(404);
  });

  it('非创建者撤回他人的分享返回 403', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/v1/templates/share')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ payload, expiresInSeconds: 3600 })
      .expect(201);
    const token = created.body.token as string;

    await request(app.getHttpServer())
      .delete(`/api/v1/templates/share/${token}`)
      .set('Authorization', `Bearer ${foreignToken}`)
      .expect(403);
  });

  it('同一设备读取超过 GET_RATE_LIMIT 次返回 429', async () => {
    for (let i = 0; i < GET_RATE_LIMIT; i++) {
      await request(app.getHttpServer())
        .get('/api/v1/templates/share/nonexistentforratelimit000000000')
        .set('Authorization', `Bearer ${rateToken}`)
        .expect(404);
    }
    await request(app.getHttpServer())
      .get('/api/v1/templates/share/nonexistentforratelimit000000000')
      .set('Authorization', `Bearer ${rateToken}`)
      .expect(429);
  });
});