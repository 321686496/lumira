// lumira-server/packages/backend/src/main.ts

import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import * as path from 'path';
import * as fs from 'fs';
import multipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import { AppModule } from './app.module';

// Production fail-fast: refuse to boot if security env vars are missing or still
// set to their dev defaults. Dev fallbacks remain in the guards/modules for tests/dev.
if (process.env.NODE_ENV === 'production') {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'dev-secret-change-me') {
    console.error('FATAL: JWT_SECRET must be set to a non-default value in production');
    process.exit(1);
  }
  if (!process.env.ADMIN_TOKEN || process.env.ADMIN_TOKEN === 'dev-admin-token') {
    console.error('FATAL: ADMIN_TOKEN must be set to a non-default value in production');
    process.exit(1);
  }
}

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({
      trustProxy: true,
      // 整个请求体上限（multipart 请求总大小：多文件 + 表单字段 + 开销）。
      // 默认 1MB 会导致多文件/大文件上传被 Fastify 核心拒绝（413）。
      bodyLimit: 32 * 1024 * 1024,
    }),
  );

  app.setGlobalPrefix('api/v1');

  // CORS
  const corsOrigin = process.env.CORS_ORIGIN || '*';
  app.enableCors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(','),
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // 注册 multipart 插件
  // - fileSize 25MB：.pptpl 内嵌 base64 封面图/剪影，文件常达 5-15MB；单文件上限放宽到 25MB
  // - 图片（cover/silhouette）的 5MB 上限在 admin-templates.service 中按字段校验并返回明确错误
  // - files 6：cover + silhouette + pptpl + icon + 预留
  await app.register(multipart, {
    limits: {
      fileSize: 25 * 1024 * 1024,
      files: 6,
    },
  });

  // 注册静态资源服务（spec 3.5：prefix 不含全局 /api/v1 前缀）
  // 访问路径：${BACKEND_BASE_URL}/uploads/templates/{id}/cover.{ext}
  const uploadRoot = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
  if (!fs.existsSync(uploadRoot)) {
    fs.mkdirSync(uploadRoot, { recursive: true });
  }
  await app.register(fastifyStatic, {
    root: uploadRoot,
    prefix: '/uploads/',
  });

  const port = parseInt(process.env.PORT || '3000', 10);
  await app.listen(port, '0.0.0.0');
  console.log(`Lumira server running on port ${port}`);
}

bootstrap();
