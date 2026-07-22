import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';

describe('RewardsController (e2e)', () => {
  let app: NestFastifyApplication;
  let inviterToken: string;
  let inviteeToken: string;
  let rewardId: number;

  const inviterDeviceId = '44444444-4444-4444-8444-444444444444';
  const inviteeDeviceId = '55555555-5555-4555-8555-555555555555';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    // 注册设备并触发邀请
    const res1 = await request(app.getHttpServer())
      .post('/api/v1/device/register').send({ deviceId: inviterDeviceId });
    inviterToken = res1.body.token;

    const res2 = await request(app.getHttpServer())
      .post('/api/v1/device/register').send({ deviceId: inviteeDeviceId });
    inviteeToken = res2.body.token;

    // 生成邀请码并激活
    const genRes = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${inviterToken}`);
    const inviteCode = genRes.body.inviteCode;

    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode });
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/rewards — should list unlocked rewards', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/rewards')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.rewards).toHaveLength(1);
    expect(res.body.rewards[0].source).toBe('invite');
    expect(res.body.rewards[0].status).toBe('unlocked');
    rewardId = res.body.rewards[0].id;
  });

  it('POST /api/v1/rewards/:id/claim — should claim reward', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/rewards/${rewardId}/claim`)
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.success).toBe(true);
  });

  it('POST /api/v1/rewards/:id/claim — should reject double claim', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/rewards/${rewardId}/claim`)
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(409);
  });

  it('GET /api/v1/rewards — should show claimed status after claim', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/rewards')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.rewards[0].status).toBe('claimed');
    expect(res.body.rewards[0].claimedAt).not.toBeNull();
  });
});
