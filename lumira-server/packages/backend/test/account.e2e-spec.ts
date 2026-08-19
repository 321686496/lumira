import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { resetTestDatabase } from './test-db';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { accountOtp } from '../src/database/schema';
import { sha256Hex } from '../src/modules/account/hash';

describe('Account (e2e)', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  const deviceId = '550e8400-e29b-41d4-a716-446655441111';
  let token: string;

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    await resetTestDatabase();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
    dbService = moduleRef.get<DatabaseService>(DatabaseService);
    token = (await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId })).body.token as string;
  }, 30000);
  afterAll(async () => { await app.close(); });

  it('recovery-qr 生成并轮换密钥', async () => {
    const r1 = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);
    expect(r1.body.secret).toHaveLength(43);
    expect(r1.body.qrPayload).toContain('lumira://account-recover');
    const r2 = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);
    expect(r2.body.secret).not.toBe(r1.body.secret); // 轮换
  });

  it('recover-by-qr 用密钥取回 deviceId 并作废旧 token', async () => {
    const qr = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .then(r => r.body);
    const rec = await request(app.getHttpServer())
      .post('/api/v1/account/recover-by-qr')
      .send({ secret: qr.secret })
      .expect(201);
    expect(rec.body.deviceId).toBe(deviceId);
    // 旧 token 因 session_epoch 递增而失效
    await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(401);
  });

  it('recover-by-qr 非法密钥返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/account/recover-by-qr')
      .send({ secret: 'wrong-secret-value' })
      .expect(400);
  });

  it('email send-code 与限频', async () => {
    const email = 'user@example.com';
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' })
      .expect(201);
    const r = await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' });
    expect([429, 400]).toContain(r.status);
  });

  it('email bind / recover 成功闭环（直接插已知 OTP）', async () => {
    const email = 'bind@example.com';
    const code = '123456';
    const now = Math.floor(Date.now() / 1000);
    // recover-by-qr 已递增 session_epoch，旧 token 失效；重新注册获取当前 epoch 的新 token
    const fresh = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId })
      .expect(201);
    const freshToken = fresh.body.token as string;

    // bind：先 send-code 也行但拿不到明文；改为直接插入已知 codeHash 的 OTP
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' })
      .expect(201);
    await dbService.getDb().insert(accountOtp).values({
      email, deviceId: null, purpose: 'bind',
      codeHash: sha256Hex(code),
      expiresAt: now + 600, consumedAt: null, attempts: 0, createdAt: now,
    });
    const bind = await request(app.getHttpServer())
      .post('/api/v1/account/email/bind')
      .set('Authorization', `Bearer ${freshToken}`)
      .send({ email, code })
      .expect(201);
    expect(bind.body.success).toBe(true);

    // 同一 code 二次 bind 应因已消费被拒（一次性消费）
    await request(app.getHttpServer())
      .post('/api/v1/account/email/bind')
      .set('Authorization', `Bearer ${freshToken}`)
      .send({ email, code })
      .expect(400);

    // recover：换「同设备」场景——用 email recover 前先 send-code recover
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'recover' })
      .expect(201);
    await dbService.getDb().insert(accountOtp).values({
      email, deviceId: null, purpose: 'recover',
      codeHash: sha256Hex(code),
      expiresAt: now + 600, consumedAt: null, attempts: 0, createdAt: now,
    });
    const rec = await request(app.getHttpServer())
      .post('/api/v1/account/email/recover')
      .send({ email, code })
      .expect(201);
    expect(rec.body.deviceId).toBe(deviceId);
    // 旧 token 已因 epoch 递增失效
    await request(app.getHttpServer())
      .post('/api/v1/account/email/bind')
      .set('Authorization', `Bearer ${freshToken}`)
      .send({ email, code })
      .expect(401);
  });

  it('未绑定邮箱的 recover 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/account/email/recover')
      .send({ email: 'nobody@example.com', code: '123456' })
      .expect(400);
  });
});