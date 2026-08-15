import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import { resetTestDatabase } from './test-db';

describe('InviteController (e2e)', () => {
  let app: NestFastifyApplication;
  let inviterToken: string;
  let inviteeToken: string;

  const inviterDeviceId = '11111111-1111-4111-8111-111111111111';
  const inviteeDeviceId = '22222222-2222-4222-8222-222222222222';

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

    // 注册两个设备
    const res1 = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: inviterDeviceId });
    inviterToken = res1.body.token;

    const res2 = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: inviteeDeviceId });
    inviteeToken = res2.body.token;
  });

  afterAll(async () => {
    await app.close();
  });

  let inviteCode: string;

  it('POST /api/v1/invite/generate — should generate invite code', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(201);

    expect(res.body.inviteCode).toBeDefined();
    expect(res.body.inviteCode).toHaveLength(6);
    inviteCode = res.body.inviteCode;
  });

  it('POST /api/v1/invite/generate — should return same code on second call', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(201);

    expect(res.body.inviteCode).toBe(inviteCode);
  });

  it('POST /api/v1/invite/activate — should activate invite successfully', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode, channel: 'direct' })
      .expect(201);

    expect(res.body.inviterDeviceId).toBe(inviterDeviceId);
    expect(res.body.tierReached).toBe(1); // 首次邀请达成阶梯 1
    expect(res.body.rewards).not.toBeNull();
  });

  it('POST /api/v1/invite/activate — should reject duplicate activation', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode })
      .expect(409);
  });

  it('POST /api/v1/invite/activate — should reject self-invite', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviterToken}`)
      .send({ inviteCode })
      .expect(400);
  });

  it('POST /api/v1/invite/activate — should reject invalid code', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode: 'INVALID' })
      .expect(400);
  });

  it('GET /api/v1/invite/stats — should return invite stats', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/invite/stats')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.totalInvites).toBe(1);
    expect(res.body.currentTier).toBe(1);
    expect(res.body.unlockedRewards).toHaveLength(1);
  });

  it('GET /api/v1/invite/stats — without auth should return 401', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/invite/stats')
      .expect(401);
  });
});
