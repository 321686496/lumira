import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { DatabaseService } from '../src/database/database.service';
import { redemptionCodeBatches, redemptionCodes } from '../src/database/schema';
import request from 'supertest';

describe('RedeemController (e2e)', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  let token: string;

  const deviceId = '33333333-3333-4333-8333-333333333333';
  const testCode = 'TESTCODE1';

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

    dbService = moduleRef.get<DatabaseService>(DatabaseService);

    // 注册设备
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;

    // 插入测试兑换码数据
    const db = dbService.getDb();
    await db.insert(redemptionCodeBatches).values({
      batchId: 1,
      campaignName: '测试活动',
      rewardPoints: 50,
      rewardTemplates: '[]',
      maxUsesPerCode: 1,
      totalGenerated: 1,
      totalUsed: 0,
      isActive: 1,
      createdAt: Math.floor(Date.now() / 1000),
    });
    await db.insert(redemptionCodes).values({
      code: testCode,
      batchId: 1,
      usedCount: 0,
      maxUses: 1,
    });
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/v1/redeem — should redeem valid code', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .set('Authorization', `Bearer ${token}`)
      .send({ code: testCode })
      .expect(201);

    expect(res.body.batchId).toBe(1);
    expect(res.body.campaignName).toBe('测试活动');
    expect(res.body.rewardPoints).toBe(50);
    expect(res.body.balance).toBe(50);
    expect(res.body.rewardTemplates).toEqual([]);
  });

  it('POST /api/v1/redeem — should reject already used code', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .set('Authorization', `Bearer ${token}`)
      .send({ code: testCode })
      .expect(409);
  });

  it('POST /api/v1/redeem — should reject non-existent code', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .set('Authorization', `Bearer ${token}`)
      .send({ code: 'NOTEXIST' })
      .expect(404);
  });

  it('POST /api/v1/redeem — without auth should return 401', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .send({ code: testCode })
      .expect(401);
  });
});
