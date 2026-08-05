import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';

describe('ProfileController (e2e)', () => {
  let app: NestFastifyApplication;
  const testDeviceId = 'profile-e2e-device-0001';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => app.close());

  const register = () => request(app.getHttpServer())
    .post('/api/v1/device/register')
    .send({ deviceId: testDeviceId });

  it('GET /api/v1/profile returns default profile after register', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    const res = await request(app.getHttpServer())
      .get('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.username).toBe(reg.body.profile.username);
    expect(res.body.avatarSeed).toBe(reg.body.profile.avatarSeed);
  });

  it('GET /api/v1/profile rejects without token', async () => {
    await request(app.getHttpServer()).get('/api/v1/profile').expect(401);
  });

  it('PATCH /api/v1/profile updates username and avatarSeed', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    const res = await request(app.getHttpServer())
      .patch('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: '新昵称', avatarSeed: 'lumira-avatar-03' })
      .expect(200);
    expect(res.body.username).toBe('新昵称');
    expect(res.body.avatarSeed).toBe('lumira-avatar-03');
  });

  it('PATCH /api/v1/profile rejects empty username', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    await request(app.getHttpServer())
      .patch('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: '' })
      .expect(400);
  });

  it('PATCH /api/v1/profile rejects username longer than 20 chars', async () => {
    const reg = await register().expect(201);
    const token = reg.body.token as string;
    await request(app.getHttpServer())
      .patch('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: '啊'.repeat(21) })
      .expect(400);
  });
});
