// lumira-server/packages/backend/src/common/storage/uploads.route.ts
// /uploads/* 图片读取路由：跟随「当前激活存储」——后台切换存储（七牛/R2…）后无需重启即生效。
// - 激活=本地：读本地磁盘（与旧 fastifyStatic 静态服务行为一致）
// - 激活=远端：读当前激活存储；远端缺失时回落本地磁盘（迁移过渡期旧文件仍在本地）
// 替代原来写死本地磁盘的 @fastify/static /uploads 注册。

import * as fs from 'fs';
import * as path from 'path';
import type { FastifyInstance } from 'fastify';
import { getActiveId, activeStorageAdapter } from './runtime-storage';
import { mimeOf } from './mime';

const PREFIX = '/uploads/';
/** URL 含类别/id/文件名，基本不可变 → 强缓存（与原静态服务一致） */
const IMMUTABLE_CACHE = 'public, max-age=31536000, immutable';

/** URL 路径 → storageKey（/uploads/{cat}/{id}/{filename}）；非法路径返回 null */
function parseStorageKey(urlPath: string): string | null {
  let key: string;
  try {
    key = decodeURIComponent(urlPath.split('?')[0].split('#')[0]);
  } catch {
    return null; // 非法百分号编码
  }
  if (!key.startsWith(PREFIX) || key.includes('\0')) return null;
  if (key.slice(PREFIX.length).split('/').includes('..')) return null; // 路径穿越
  return key;
}

/** storageKey → 本地磁盘绝对路径；解析结果必须位于 uploadRoot 之内 */
function localFilePath(storageKey: string, uploadRoot: string): string | null {
  const rel = storageKey.slice(PREFIX.length);
  if (!rel) return null;
  const file = path.join(uploadRoot, ...rel.split('/'));
  return file.startsWith(uploadRoot + path.sep) ? file : null;
}

/**
 * 在 fastify 实例上注册 GET /uploads/*。需在 listen 前调用（main.ts bootstrap）。
 * 激活存储为 local 时走本地磁盘；否则先读激活存储、本地磁盘兜底。
 */
export function registerUploadsRoute(app: FastifyInstance, uploadRoot: string): void {
  app.get('/uploads/*', async (request, reply) => {
    const storageKey = parseStorageKey(request.url);
    if (!storageKey) return reply.callNotFound();

    if (getActiveId() !== 'local') {
      try {
        const buf = await activeStorageAdapter.readBuffer(storageKey);
        reply.header('Cache-Control', IMMUTABLE_CACHE);
        return reply.type(mimeOf(storageKey)).send(buf);
      } catch {
        // 远端缺失/读取失败 → 回落本地磁盘（迁移过渡期）
      }
    }

    const file = localFilePath(storageKey, uploadRoot);
    if (!file || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      return reply.callNotFound();
    }
    reply.header('Cache-Control', IMMUTABLE_CACHE);
    return reply.type(mimeOf(storageKey)).send(fs.createReadStream(file));
  });
}
