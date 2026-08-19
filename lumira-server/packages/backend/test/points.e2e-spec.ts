import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import { resetTestDatabase } from './test-db';

describe('PointsController (e2e)', () => {
  let app: NestFastifyApplication;
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

    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/v1/points/earn type=share → 首次 granted:true 且余额 +2', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'share' })
      .expect(201);
    expect(res.body.granted).toBe(true);
    expect(res.body.delta).toBe(2);
    expect(res.body.balance).toBe(2);
  });

  it('POST /api/v1/points/earn type=share → 当日重复 granted:false 且余额不变', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'share' })
      .expect(201);
    expect(res.body.granted).toBe(false);
    expect(res.body.delta).toBe(0);
    expect(res.body.balance).toBe(2);
  });

  it('POST /api/v1/points/earn type=unknown → 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'not-a-type' })
      .expect(400);
  });
});
