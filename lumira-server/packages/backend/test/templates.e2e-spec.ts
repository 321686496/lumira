// lumira-server/packages/backend/test/templates.e2e-spec.ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { DatabaseService } from '../src/database/database.service';
import { userPoints, templatePrices } from '../src/database/schema';
import { eq } from 'drizzle-orm';
import request from 'supertest';
import { resetTestDatabase } from './test-db';

describe('TemplatesController (e2e) — exchange', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  let token: string;

  const deviceId = '44444444-4444-4444-8444-444444444444';

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

    // 注册设备
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;

    // 充值 100 积分
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().insert(userPoints).values({
      deviceId,
      balance: 100,
      totalEarned: 100,
      totalSpent: 0,
      updatedAt: now,
    });
  });

  afterAll(async () => {
    await app.close();
  });

  it('内置模板积分兑换成功，按客户端上报价扣费并记录定价', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'film_vintage', priceCredits: 20 })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.spentCredits).toBe(20);
    expect(res.body.balance).toBe(80);

    // 定价已记录到 template_prices
    const db = dbService.getDb();
    const price = await db.query.templatePrices.findFirst({
      where: (t, { eq }) => eq(t.templateId, 'film_vintage'),
    });
    expect(price?.priceCredits).toBe(20);

    // owned 记录存在
    const owned = await request(app.getHttpServer())
      .get('/api/v1/templates/owned')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(owned.body.templateIds).toContain('film_vintage');
  });

  it('内置模板重复兑换返回 409，且不污染定价记录', async () => {
    // 重复请求上报一个不同的价格，验证 409 后 template_prices 仍为第一次兑换时的定价
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'film_vintage', priceCredits: 999 })
      .expect(409);

    const res = await request(app.getHttpServer())
      .get('/api/v1/templates/prices')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const prices = res.body.prices as Array<{ templateId: string; priceCredits: number }>;
    const price = prices.find((p) => p.templateId === 'film_vintage');
    expect(price?.priceCredits).toBe(20);
  });

  it('内置模板缺少 priceCredits 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'macro_flower' })
      .expect(400);
  });

  it('内置模板 priceCredits 为 0 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'macro_flower', priceCredits: 0 })
      .expect(400);
  });

  it('积分余额不足返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'neon_portrait', priceCredits: 9999 })
      .expect(400);
  });

  it('srv_ 远程模板无定价记录返回 404', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'srv_notexist', priceCredits: 20 })
      .expect(404);
  });

  it('srv_ 远程模板按后端定价扣费，忽略客户端上报价', async () => {
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().insert(templatePrices).values({
      templateId: 'srv_priced',
      priceCredits: 30,
      isActive: 1,
      updatedAt: now,
    });

    const res = await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'srv_priced', priceCredits: 1 })
      .expect(201);

    expect(res.body.spentCredits).toBe(30);
    expect(res.body.balance).toBe(50); // 80 - 30
  });

  it('free_unlock 支付：扣 1 次免费解锁额度，不耗积分', async () => {
    // 授予 2 次免费解锁（邀请里程碑奖励）
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().update(userPoints)
      .set({ freeUnlockCount: 2, updatedAt: now })
      .where(eq(userPoints.deviceId, deviceId));

    const res = await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'neon_portrait', priceCredits: 120, payBy: 'free_unlock' })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.payBy).toBe('free_unlock');
    expect(res.body.spentCredits).toBe(0); // 不耗积分
    expect(res.body.balance).toBeNull(); // free_unlock 不扣积分，balance 字段为空
    expect(res.body.freeUnlockLeft).toBe(1); // 2 - 1

    // 积分余额不变（free_unlock 不消耗积分）
    const bal = await request(app.getHttpServer())
      .get('/api/v1/points/balance')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(bal.body.balance).toBe(50);

    // owned 记录 source=free_unlock
    const owned = await request(app.getHttpServer())
      .get('/api/v1/templates/owned')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(owned.body.templateIds).toContain('neon_portrait');
  });

  it('free_unlock 支付但无免费解锁额度返回 400', async () => {
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().update(userPoints)
      .set({ freeUnlockCount: 0, updatedAt: now })
      .where(eq(userPoints.deviceId, deviceId));

    await request(app.getHttpServer())
      .post('/api/v1/templates/exchange')
      .set('Authorization', `Bearer ${token}`)
      .send({ templateId: 'macro_flower', priceCredits: 80, payBy: 'free_unlock' })
      .expect(400);
  });
});
