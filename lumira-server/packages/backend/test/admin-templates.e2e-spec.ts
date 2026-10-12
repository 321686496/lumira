// lumira-server/packages/backend/test/admin-templates.e2e-spec.ts
// Admin 模板效果图编辑回归（bug：编辑删除效果图后保存不生效）：
// PATCH meta.images 整列表覆盖 → 删除 / 排序 / 混合新增（data URL 落盘）均按提交持久化。

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import multipart from '@fastify/multipart';
import { AppModule } from '../src/app.module';
import { DatabaseService } from '../src/database/database.service';
import { templateCategories } from '../src/database/schema';
import request from 'supertest';
import { resetTestDatabase } from './test-db';

/** 1x1 透明 PNG（最小合法图片，供 sharp 压缩） */
const PNG_1X1_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
const PNG_1X1 = Buffer.from(PNG_1X1_BASE64, 'base64');
const PNG_DATA_URL = `data:image/png;base64,${PNG_1X1_BASE64}`;

describe('AdminTemplatesController (e2e) — 效果图编辑', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
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
    // main.ts 不在测试启动路径，multipart 需手动注册（与 main.ts 参数一致）
    await app.register(multipart, {
      limits: {
        fileSize: 25 * 1024 * 1024,
        files: 20,
      },
    });
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    dbService = moduleRef.get<DatabaseService>(DatabaseService);

    // 测试分类
    const now = Math.floor(Date.now() / 1000);
    await dbService.getDb().insert(templateCategories).values({
      key: 'test-cat',
      name: '测试分类',
      iconUrl: '',
      createdAt: now,
      updatedAt: now,
    });
  }, 60000);

  afterAll(async () => {
    await app.close();
  }, 30000);

  /** 创建带 2 张效果图的模板，返回详情 */
  async function createTemplateWithTwoImages(): Promise<{ id: string; images: Array<{ url: string }> }> {
    const meta = JSON.stringify({ name: '效果图回归', category: 'test-cat', price: 0 });
    const created = await request(app.getHttpServer())
      .post('/api/v1/admin/templates')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', meta)
      .attach('images', PNG_1X1, { filename: 'a.png', contentType: 'image/png' })
      .attach('images', PNG_1X1, { filename: 'b.png', contentType: 'image/png' })
      .expect(201);
    return { id: created.body.id, images: created.body.images };
  }

  it('创建模板返回 2 张效果图（image_0/image_1）', async () => {
    const { images } = await createTemplateWithTwoImages();
    expect(images).toHaveLength(2);
    expect(images[0].url).toMatch(/image_0\./);
    expect(images[1].url).toMatch(/image_1\./);
  });

  it('PATCH meta.images 子集（删除首图）→ 保存后仅剩 1 张且封面跟随首图', async () => {
    const { id, images } = await createTemplateWithTwoImages();

    // 只保留第二张（对应 admin 表单删除第一张后提交）
    const patched = await request(app.getHttpServer())
      .patch(`/api/v1/admin/templates/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', JSON.stringify({
        name: '效果图回归',
        category: 'test-cat',
        price: 0,
        images: [{ url: images[1].url }],
      }))
      .expect(200);

    expect(patched.body.images).toHaveLength(1);
    expect(patched.body.images[0].url).toMatch(/image_1\./);
    // 封面 = 效果图首张
    expect(patched.body.coverUrl).toMatch(/image_1\./);

    // 重新拉详情确认已持久化（bug 场景：重进仍在）
    const detail = await request(app.getHttpServer())
      .get(`/api/v1/admin/templates/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    expect(detail.body.images).toHaveLength(1);
    expect(detail.body.images[0].url).toMatch(/image_1\./);
  });

  it('PATCH meta.images 混合列表（保留旧图 + data URL 新图）→ 新图落盘转存', async () => {
    const { id, images } = await createTemplateWithTwoImages();

    const patched = await request(app.getHttpServer())
      .patch(`/api/v1/admin/templates/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', JSON.stringify({
        name: '效果图回归',
        category: 'test-cat',
        price: 0,
        images: [{ url: images[1].url }, { url: PNG_DATA_URL }],
      }))
      .expect(200);

    expect(patched.body.images).toHaveLength(2);
    // 旧图 URL 保留
    expect(patched.body.images[0].url).toMatch(/image_1\./);
    // 新图不残留 data URL，已落盘为 image_N.{ext}（命名避开仍引用的 image_1）
    expect(patched.body.images[1].url).not.toMatch(/^data:/);
    expect(patched.body.images[1].url).toMatch(/image_[^/]*\.\w+$/);
    expect(patched.body.images[1].url).not.toMatch(/image_1\./);
    expect(patched.body.coverUrl).not.toMatch(/^data:/);
  });
});
