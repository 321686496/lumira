import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';

describe('DeviceController (e2e)', () => {
  let app: NestFastifyApplication;

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
  });

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
  });

  it('POST /api/v1/device/register — should return existing token for re-registration', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: testDeviceId })
      .expect(201);

    expect(res.body.token).toBeDefined();
    expect(res.body.isNewDevice).toBe(false);
  });

  it('POST /api/v1/device/register — should reject invalid UUID', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: 'not-a-uuid' })
      .expect(400);
  });
});
