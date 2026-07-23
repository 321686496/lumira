// lumira-server/packages/backend/test/admin.e2e-spec.ts

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';

describe('AdminController (e2e)', () => {
  let app: NestFastifyApplication;
  const adminToken = 'test-admin-token';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';
    process.env.ADMIN_TOKEN = adminToken;

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    // 注册一个测试设备 + 触发一次邀请，使 stats 有数据
    const inviterId = '66666666-6666-4666-8666-666666666666';
    const inviteeId = '77777777-7777-4777-8777-777777777777';

    const r1 = await request(app.getHttpServer())
      .post('/api/v1/device/register').send({ deviceId: inviterId });
    const r2 = await request(app.getHttpServer())
      .post('/api/v1/device/register').send({ deviceId: inviteeId });

    const genRes = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${r1.body.token}`);
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${r2.body.token}`)
      .send({ inviteCode: genRes.body.inviteCode });
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/admin/stats — should return stats with admin token', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/stats')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.totalDevices).toBe(2);
    expect(res.body.totalInvites).toBe(1);
    expect(res.body.totalRewardUnlocks).toBe(1);
  });

  it('GET /api/v1/admin/stats — should reject without admin token', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/admin/stats')
      .expect(401);
  });

  it('GET /api/v1/admin/stats — should reject with wrong admin token', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/admin/stats')
      .set('Authorization', 'Bearer wrong-token')
      .expect(401);
  });

  it('GET /api/v1/admin/invites — should return invite records', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/invites')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.data).toHaveLength(1);
    expect(res.body.total).toBe(1);
  });

  it('GET /api/v1/admin/invites — should filter total by deviceId', async () => {
    // inviteeId has no invite records as inviter; filtered total must be 0 (not 1)
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/invites?deviceId=77777777-7777-4777-8777-777777777777')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.data).toHaveLength(0);
    expect(res.body.total).toBe(0);
  });

  it('POST /api/v1/admin/redeem-batches — should create a new batch', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/redeem-batches')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        campaignName: '测试活动',
        codes: ['CODE0001', 'CODE0002', 'CODE0003'],
        rewardTier: 1,
        maxUsesPerCode: 1,
      })
      .expect(201);

    expect(res.body.batchId).toBeDefined();
    expect(res.body.totalGenerated).toBe(3);
  });

  it('GET /api/v1/admin/redeem-batches — should list batches', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/redeem-batches')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body).toHaveLength(1);
    expect(res.body[0].campaignName).toBe('测试活动');
  });

  it('GET /api/v1/admin/redeem-batches/:id — should return batch detail with codes', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/redeem-batches/1')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.campaignName).toBe('测试活动');
    expect(res.body.codes).toHaveLength(3);
  });

  it('PATCH /api/v1/admin/redeem-batches/:id — should toggle batch active state', async () => {
    const res = await request(app.getHttpServer())
      .patch('/api/v1/admin/redeem-batches/1')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isActive: false })
      .expect(200);

    expect(res.body.success).toBe(true);

    // Verify the state was actually changed
    const detail = await request(app.getHttpServer())
      .get('/api/v1/admin/redeem-batches/1')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(detail.body.isActive).toBe(0);
  });

  it('GET /api/v1/admin/redeem-batches/:id — should return 404 for non-existent batch', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/admin/redeem-batches/9999')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(404);
  });

  it('PATCH /api/v1/admin/redeem-batches/:id — should return 404 for non-existent batch', async () => {
    await request(app.getHttpServer())
      .patch('/api/v1/admin/redeem-batches/9999')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isActive: true })
      .expect(404);
  });

  it('PATCH /api/v1/admin/redeem-batches/:id — should reject invalid isActive', async () => {
    await request(app.getHttpServer())
      .patch('/api/v1/admin/redeem-batches/1')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ isActive: 'not-a-boolean' })
      .expect(400);
  });

  it('GET /api/v1/admin/rewards — should return reward unlock records', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/rewards')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.data).toHaveLength(1);
    expect(res.body.total).toBe(1);
  });

  it('GET /api/v1/admin/rewards — should filter total by deviceId', async () => {
    // inviteeId has no reward unlocks; filtered total must be 0 (not 1)
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/rewards?deviceId=77777777-7777-4777-8777-777777777777')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body.data).toHaveLength(0);
    expect(res.body.total).toBe(0);
  });
});
