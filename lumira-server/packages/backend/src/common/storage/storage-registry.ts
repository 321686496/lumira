// lumira-server/packages/backend/src/common/storage/storage-registry.ts
// 存储厂商注册表：id → 适配器工厂；并解析「当前激活存储」。
// 支持 local / r2（Cloudflare）/ aliyun（OSS）/ tencent（COS）——均为 S3 兼容。
// 约定：迁移时 source=「当前激活存储」，dest=本次可选的 target。

import { LocalStorageAdapter } from './local-storage.adapter';
import { S3StorageAdapter, S3Config } from './s3-storage.adapter';
import type { StorageAdapter } from './storage-adapter.interface';

export const STORAGE_IDS = ['local', 'r2', 'aliyun', 'tencent', 'qiniu'] as const;
export type StorageId = (typeof STORAGE_IDS)[number];

/** 读取某厂商前缀对应的 S3 配置（如 R2_、ALIYUN_OSS_、TENCENT_COS_） */
function readS3Config(prefix: string, env: NodeJS.ProcessEnv): S3Config {
  const endpoint =
    env[`${prefix}_ENDPOINT`] ||
    (prefix === 'R2' && env.R2_ACCOUNT_ID ? `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com` : '') ||
    '';
  return {
    endpoint,
    accessKeyId: env[`${prefix}_ACCESS_KEY_ID`] || '',
    secretAccessKey: env[`${prefix}_SECRET_ACCESS_KEY`] || '',
    bucket: env[`${prefix}_BUCKET`] || '',
    region: env[`${prefix}_REGION`] || 'auto',
  };
}

/** 由厂商 id 构建适配器实例（source / dest 各自独立配置） */
export function buildStorageAdapter(id: StorageId, env: NodeJS.ProcessEnv = process.env): StorageAdapter {
  switch (id) {
    case 'local':
      return new LocalStorageAdapter();
    case 'r2':
      return new S3StorageAdapter(readS3Config('R2', env));
    case 'aliyun':
      return new S3StorageAdapter(readS3Config('ALIYUN_OSS', env));
    case 'tencent':
      return new S3StorageAdapter(readS3Config('TENCENT_COS', env));
    case 'qiniu':
      return new S3StorageAdapter(readS3Config('QINIU', env)); // 七牛 Kodo（S3 兼容，endpoint 如 s3-cn-east-1.qiniucs.com）
    default:
      throw new Error(`未知存储厂商：${id}`);
  }
}

/**
 * 解析「当前激活存储」：即新文件当前写入的位置 / 历史文件所在的位置。
 * 由环境变量决定：优先 `UPLOAD_STORAGE`（local|r2|aliyun|tencent），其次 `UPLOAD_R2=1`（兼容旧配置），缺省 local。
 * 切厂时更新该配置即可，迁移依据它确定 source，不再写死本地。
 */
export function resolveActiveStorageId(env: NodeJS.ProcessEnv = process.env): StorageId {
  const v = env.UPLOAD_STORAGE;
  if (v && (STORAGE_IDS as readonly string[]).includes(v)) return v as StorageId;
  if (env.UPLOAD_R2 === '1') return 'r2';
  return 'local';
}