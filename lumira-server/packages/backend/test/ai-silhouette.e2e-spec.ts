// lumira-server/packages/backend/test/ai-silhouette.e2e-spec.ts
// 剪影端点 e2e（Task 9）
// 覆盖：缺 image 400 / 非法 mimetype 400 / meta.mode 非法 400 / 无 token 401 /
//       合法请求分支（本机已下载 RMBG 模型 → 断言 200 + base64 非空；否则 → 503「剪影模型未安装」）
// 注意：本端点纯本地计算，不依赖 ai-config；无需构造厂商 mock。

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import multipart from '@fastify/multipart';
import { resetTestDatabase } from './test-db';
import { resolveModelPath } from '../src/modules/ai/silhouette.pipeline';
import * as fs from 'fs';

describe('AiTemplatesController ai-generate-silhouette (e2e)', () => {
  let app: NestFastifyApplication;
  const adminToken = 'test-admin-token';
  const modelExists = fs.existsSync(resolveModelPath());

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

  it('POST /api/v1/admin/templates/ai-generate-silhouette — 缺 image 文件返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-generate-silhouette')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', '{"mode":"sketch"}')
      .expect(400);

    expect(res.body.message).toContain('image');
  });

  it('POST /api/v1/admin/templates/ai-generate-silhouette — 非法 mimetype 返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-generate-silhouette')
      .set('Authorization', `Bearer ${adminToken}`)
      .attach('image', Buffer.from('plain text'), 'a.txt')
      .expect(400);

    expect(res.body.message).toContain('jpg/png/webp');
  });

  it('POST /api/v1/admin/templates/ai-generate-silhouette — meta.mode 非法返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-generate-silhouette')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', '{"mode":"invalid"}')
      .attach('image', Buffer.from('fake-jpeg-bytes'), 'a.jpg')
      .expect(400);

    expect(res.body.message).toContain('mode 非法');
  });

  if (modelExists) {
    it('POST /api/v1/admin/templates/ai-generate-silhouette — 合法请求返回 200 + base64 PNG', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/admin/templates/ai-generate-silhouette')
        .set('Authorization', `Bearer ${adminToken}`)
        .field('meta', '{"mode":"sketch","crop":true}')
        .attach('image', Buffer.from('fake-jpeg-bytes'), 'a.jpg')
        .expect(200);

      expect(res.body.mimeType).toBe('image/png');
      expect(typeof res.body.image).toBe('string');
      expect(res.body.image.length).toBeGreaterThan(0);
      expect(() => Buffer.from(res.body.image, 'base64')).not.toThrow();
    });
  } else {
    it('POST /api/v1/admin/templates/ai-generate-silhouette — 本机未安装模型返回 503', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/admin/templates/ai-generate-silhouette')
        .set('Authorization', `Bearer ${adminToken}`)
        .field('meta', '{"mode":"sketch","crop":true}')
        .attach('image', Buffer.from('fake-jpeg-bytes'), 'a.jpg')
        .expect(503);

      expect(res.body.message).toContain('剪影模型未安装');
    });
  }

  it('POST /api/v1/admin/templates/ai-generate-silhouette — 无 admin token 返回 401', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-generate-silhouette')
      .expect(401);
  });
});