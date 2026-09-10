// lumira-server/packages/backend/test/ai-config.e2e-spec.ts
// AI 服务商配置管理 e2e（Task 4）
// 覆盖：空态查询 / 保存脱敏 / apiKey 留空保留原值 / 未启用 503 / 非法 provider 400 / 无 token 401
// 注意：enabled:true 时 POST /test 会发真实网络请求，e2e 中保持未启用来测 503 分支，真实连通性走手动验收。

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import request from 'supertest';
import { resetTestDatabase } from './test-db';

describe('AiConfigController (e2e)', () => {
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
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/admin/ai-config — 初始无配置返回 { configured: false }', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(res.body).toEqual({ configured: false });
  });

  it('PUT /api/v1/admin/ai-config — 首次保存缺 apiKey 返回 400', async () => {
    const res = await request(app.getHttpServer())
      .put('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        provider: 'qwen',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        visionModel: 'qwen-vl-max',
        imageModel: 'qwen-max',
        enabled: true,
      })
      .expect(400);

    expect(res.body.message).toContain('API Key');
  });

  it('PUT /api/v1/admin/ai-config — 保存完整配置返回脱敏视图', async () => {
    const res = await request(app.getHttpServer())
      .put('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        provider: 'qwen',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        apiKey: 'sk-test-123456789',
        visionModel: 'qwen-vl-max',
        imageModel: 'qwen-max',
        enabled: true,
      })
      .expect(200);

    expect(res.body.configured).toBe(true);
    expect(res.body.provider).toBe('qwen');
    expect(res.body.baseUrl).toBe('https://dashscope.aliyuncs.com/compatible-mode/v1');
    // 前 3 + **** + 后 2
    expect(res.body.apiKeyMasked).toBe('sk-****89');
    expect(res.body.visionModel).toBe('qwen-vl-max');
    expect(res.body.imageModel).toBe('qwen-max');
    expect(res.body.textModel).toBe('');
    expect(res.body.effectiveTextModel).toBe('qwen-vl-max');
    expect(res.body.enabled).toBe(true);

    const getRes = await request(app.getHttpServer())
      .get('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(getRes.body.configured).toBe(true);
    expect(getRes.body.apiKeyMasked).toBe('sk-****89');
  });

  it('PUT /api/v1/admin/ai-config — apiKey 传空串保留原值，脱敏结果不变', async () => {
    const res = await request(app.getHttpServer())
      .put('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        provider: 'qwen',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        apiKey: '',
        visionModel: 'qwen-vl-plus',
        imageModel: 'qwen-max',
        enabled: true,
      })
      .expect(200);

    expect(res.body.configured).toBe(true);
    expect(res.body.apiKeyMasked).toBe('sk-****89');
    expect(res.body.visionModel).toBe('qwen-vl-plus');

    const getRes = await request(app.getHttpServer())
      .get('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    expect(getRes.body.apiKeyMasked).toBe('sk-****89');
  });

  it('POST /api/v1/admin/ai-config/test — 未启用时返回 503 并提示到「AI 设置」', async () => {
    // 先停用（enabled:false，避免 test() 发真实网络请求）
    await request(app.getHttpServer())
      .put('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        provider: 'qwen',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        visionModel: 'qwen-vl-plus',
        imageModel: 'qwen-max',
        enabled: false,
      })
      .expect(200);

    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/ai-config/test')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(503);

    expect(res.body.message).toContain('AI 设置');
  });

  it('PUT /api/v1/admin/ai-config — 非法 provider 返回 400', async () => {
    await request(app.getHttpServer())
      .put('/api/v1/admin/ai-config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        provider: 'dify',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        apiKey: 'sk-test-123456789',
        visionModel: 'qwen-vl-max',
        imageModel: 'qwen-max',
        enabled: true,
      })
      .expect(400);
  });

  it('GET /api/v1/admin/ai-config — 无 admin token 返回 401', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/admin/ai-config')
      .expect(401);
  });
});
