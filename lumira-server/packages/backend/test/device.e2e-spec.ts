import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import { resetTestDatabase } from './test-db';
import { DatabaseService } from '../src/database/database.service';
import { devices as devicesTable } from '../src/database/schema';
import { eq } from 'drizzle-orm';

describe('DeviceController (e2e)', () => {
  let app: NestFastifyApplication;
  let dbService!: DatabaseService;

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    await resetTestDatabase();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
    dbService = moduleRef.get<DatabaseService>(DatabaseService);
  }, 30000);

  afterAll(async () => {
    await app.close();
  });

  const testDeviceId = '550e8400-e29b-41d4-a716-446655440000';

  it('POST /api/v1/device/register — should register a new device', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: testDeviceId })
      .expect(201);

    expect(res.body.token).toBeDefined();
    expect(res.body.isNewDevice).toBe(true);
    expect(res.body.profile).toBeDefined();
    expect(res.body.profile.username).toBeTruthy();
    expect(res.body.profile.avatarSeed).toBeTruthy();
  });

  it('POST /api/v1/device/register — should return existing token for re-registration', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: testDeviceId })
      .expect(201);

    expect(res.body.token).toBeDefined();
    expect(res.body.isNewDevice).toBe(false);
    expect(res.body.profile).toBeDefined();
  });

  it('POST /api/v1/device/register — should reject deviceId shorter than 8 chars', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: 'short' })
      .expect(400);
  });

  it('PATCH /api/v1/device/info — should reject without token', async () => {
    await request(app.getHttpServer())
      .patch('/api/v1/device/info')
      .send({ platform: 'android', osVersion: '13 (API 33)', deviceModel: 'Xiaomi 13', appVersion: '1.0.0' })
      .expect(401);
  });

  it('PATCH /api/v1/device/info — should update device info with token', async () => {
    const reg = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: testDeviceId })
      .expect(201);
    const token = reg.body.token as string;

    const res = await request(app.getHttpServer())
      .patch('/api/v1/device/info')
      .set('Authorization', `Bearer ${token}`)
      .send({ platform: 'harmonyos', osVersion: '5.0 (API 18)', deviceModel: 'HUAWEI Mate 60 Pro', appVersion: '1.0.0' })
      .expect(200);

    expect(res.body).toEqual({ success: true });
  });

  it('PATCH /api/v1/device/info — should return 401 with invalid token', async () => {
    await request(app.getHttpServer())
      .patch('/api/v1/device/info')
      .set('Authorization', 'Bearer invalid-token')
      .send({ platform: 'android' })
      .expect(401);
  });

  it('PATCH /api/v1/device/info — should 401 after session_epoch changes', async () => {
    const devId = '11111111-1111-4111-8111-111111111101';
    const reg = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: devId })
      .expect(201);
    const token = reg.body.token as string;
    // 基线：旧 token 先能通过
    await request(app.getHttpServer())
      .patch('/api/v1/device/info')
      .set('Authorization', `Bearer ${token}`)
      .send({ platform: 'android' })
      .expect(200);

    // 模拟账号找回：递增 session_epoch
    await dbService.getDb().update(devicesTable)
      .set({ sessionEpoch: 1 })
      .where(eq(devicesTable.deviceId, devId));

    // 旧 epoch=0 的 token 应失效
    await request(app.getHttpServer())
      .patch('/api/v1/device/info')
      .set('Authorization', `Bearer ${token}`)
      .send({ platform: 'android' })
      .expect(401);

    // 重新注册拿到 epoch=1 新 token 后恢复通过
    const reg2 = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: devId })
      .expect(201);
    await request(app.getHttpServer())
      .patch('/api/v1/device/info')
      .set('Authorization', `Bearer ${reg2.body.token}`)
      .send({ platform: 'harmonyos' })
      .expect(200);
  });
});
