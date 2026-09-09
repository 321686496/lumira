// lumira-server/packages/backend/test/ai-analyze.e2e-spec.ts
// AI 识别端点 e2e（Task 5）
// 覆盖：未配置 503（message 含「AI 设置」）/ 缺 image 400 / 非法 mimetype 400 / 无 token 401
// 注意：全程不保存 ai-config（保持未配置状态）；成功识别需真实厂商 API，走手动验收。

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import multipart from '@fastify/multipart';
import { resetTestDatabase } from './test-db';

describe('AiTemplatesController ai-analyze (e2e)', () => {
  let app: NestFastifyApplication;
  const adminToken = 'test-admin-token';

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    process.env.ADMIN_TOKEN = adminToken;
    await resetTestDatabase();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.register(multipart, { limits: { fileSize: 25 * 1024 * 1024, files: 6 } });
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/v1/admin/templates/ai-analyze — 未配置 AI 返回 503 并提示到「AI 设置」', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-analyze')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', 'x')
      .attach('image', Buffer.from('fake-jpeg-bytes'), 'a.jpg')
      .expect(503);

    expect(res.body.message).toContain('AI 设置');
  });

  it('POST /api/v1/admin/templates/ai-analyze — 缺 image 文件返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-analyze')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', 'x')
      .expect(400);

    expect(res.body.message).toContain('image');
  });

  it('POST /api/v1/admin/templates/ai-analyze — 非法 mimetype 返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-analyze')
      .set('Authorization', `Bearer ${adminToken}`)
      .attach('image', Buffer.from('plain text'), 'a.txt')
      .expect(400);

    expect(res.body.message).toContain('jpg/png/webp');
  });

  it('POST /api/v1/admin/templates/ai-analyze — 无 admin token 返回 401', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-analyze')
      .expect(401);
  });
});
