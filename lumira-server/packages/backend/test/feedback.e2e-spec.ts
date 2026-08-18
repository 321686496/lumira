// lumira-server/packages/backend/test/feedback.e2e-spec.ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { DatabaseService } from '../src/database/database.service';
import request from 'supertest';
import multipart from '@fastify/multipart';
import { resetTestDatabase } from './test-db';

describe('Feedback (e2e)', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  let token: string;

  const deviceId = '99999999-9999-4999-8999-999999999999';

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
    await app.register(multipart, { limits: { fileSize: 25 * 1024 * 1024, files: 6 } });
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
    dbService = moduleRef.get<DatabaseService>(DatabaseService);

    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;
  });

  afterAll(async () => {
    await app.close();
  });

  it('提交反馈（带 1 张截图）成功，并写入单条记录', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/feedback')
      .set('Authorization', `Bearer ${token}`)
      .field('type', 'template')
      .field('content', '想要更多日系清新场景模板')
      .field('contact', 'h15575712021')
      .attach('screenshots', Buffer.from('fake-image-bytes'), 'snap.png')
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.id).toContain('fb_');

    const row = await dbService.getDb().query.feedbacks.findFirst({
      where: (f, { eq }) => eq(f.deviceId, deviceId),
    });
    expect(row?.type).toBe('template');
    expect(row?.content).toBe('想要更多日系清新场景模板');
    expect(row?.contact).toBe('h15575712021');
    expect(row?.status).toBe('pending');
    const urls = JSON.parse(row!.screenshotsJson) as string[];
    expect(urls.length).toBe(1);
    expect(urls[0]).toContain('/uploads/feedback/');
  });

  it('缺少 content 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/feedback')
      .set('Authorization', `Bearer ${token}`)
      .field('type', 'bug')
      .expect(400);
  });

  it('非法 type 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/feedback')
      .set('Authorization', `Bearer ${token}`)
      .field('type', 'bogus')
      .field('content', 'xx')
      .expect(400);
  });

  it('未携带 token 返回 401', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/feedback')
      .field('type', 'bug')
      .field('content', 'xx')
      .expect(401);
  });

  it('Admin 列表可筛选并标记已处理', async () => {
    const { id } = await request(app.getHttpServer())
      .post('/api/v1/feedback')
      .set('Authorization', `Bearer ${token}`)
      .field('type', 'feature')
      .field('content', '希望支持 RAW 导出')
      .then((r) => r.body);

    const list = await request(app.getHttpServer())
      .get('/api/v1/admin/feedbacks?type=feature')
      .set('Authorization', `Bearer ${process.env.ADMIN_TOKEN || 'dev-admin-token'}`)
      .expect(200);
    expect(list.body.total).toBeGreaterThanOrEqual(1);
    const found = list.body.data.find((x: { id: string }) => x.id === id);
    expect(found.type).toBe('feature');

    const updated = await request(app.getHttpServer())
      .patch(`/api/v1/admin/feedbacks/${id}`)
      .set('Authorization', `Bearer ${process.env.ADMIN_TOKEN || 'dev-admin-token'}`)
      .send({ status: 'handled' })
      .expect(200);
    expect(updated.body.status).toBe('handled');

    const row = await dbService.getDb().query.feedbacks.findFirst({
      where: (f, { eq }) => eq(f.id, id),
    });
    expect(row?.status).toBe('handled');
  });
});