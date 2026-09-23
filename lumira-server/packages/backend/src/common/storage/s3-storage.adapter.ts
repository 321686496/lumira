// lumira-server/packages/backend/src/common/storage/s3-storage.adapter.ts
// 通用 S3 兼容存储适配器（R2 / 阿里云 OSS / 腾讯云 COS / MinIO 等均走此实现）。
// 通过构造参数注入 endpoint/凭证/bucket，因此**同一进程可同时持有多个厂商实例**
// （迁移时 source 与 dest 各自独立配置）。

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  DeleteObjectsCommand,
} from '@aws-sdk/client-s3';
import type { StorageAdapter, StorageCategory } from './storage-adapter.interface';
import { storageKeyToR2Key, r2KeyToStorageKey } from './storage-key';

export interface S3Config {
  /** S3 endpoint，如 `https://<account>.r2.cloudflarestorage.com` */
  endpoint: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  region?: string;
}

export class S3StorageAdapter implements StorageAdapter {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(config: S3Config) {
    if (!config.endpoint || !config.accessKeyId || !config.secretAccessKey || !config.bucket) {
      throw new Error(`S3 存储配置不完整：需 endpoint/accessKeyId/secretAccessKey/bucket`);
    }
    this.client = new S3Client({
      region: config.region || 'auto',
      endpoint: normalizeEndpoint(config.endpoint),
      credentials: { accessKeyId: config.accessKeyId, secretAccessKey: config.secretAccessKey },
      forcePathStyle: true, // R2 / 自定义域名需要
    });
    this.bucket = config.bucket;
  }

  async write(category: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string> {
    const storageKey = `/uploads/${category}/${id}/${filename}`;
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: storageKeyToR2Key(storageKey),
        Body: buffer,
        ContentType: mimeOf(filename),
      }),
    );
    return storageKey;
  }

  async deleteByDir(category: StorageCategory, id: string): Promise<void> {
    const prefix = `uploads/${category}/${id}/`;
    const keys: string[] = [];
    let token: string | undefined;
    do {
      const res = await this.client.send(
        new ListObjectsV2Command({ Bucket: this.bucket, Prefix: prefix, ContinuationToken: token }),
      );
      for (const obj of res.Contents ?? []) if (obj.Key) keys.push(obj.Key);
      token = res.IsTruncated ? res.NextContinuationToken : undefined;
    } while (token);
    if (keys.length === 0) return;
    await this.client.send(
      new DeleteObjectsCommand({
        Bucket: this.bucket,
        Delete: { Objects: keys.map((Key) => ({ Key })) },
      }),
    );
  }

  async readBuffer(storageKey: string): Promise<Buffer> {
    const res = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: storageKeyToR2Key(storageKey) }),
    );
    return Buffer.from(await res.Body!.transformToByteArray());
  }

  async exists(storageKey: string): Promise<boolean> {
    try {
      await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: storageKeyToR2Key(storageKey) }),
      );
      return true;
    } catch (e) {
      const name = (e as { name?: string })?.name;
      const code = (e as { $metadata?: { httpStatusCode?: number } })?.$metadata?.httpStatusCode;
      if (name === 'NotFound' || name === 'NoSuchKey' || code === 404) return false;
      throw e;
    }
  }

  async listKeys(prefix = ''): Promise<string[]> {
    const r2prefix = storageKeyToR2Key(prefix);
    const keys: string[] = [];
    let token: string | undefined;
    do {
      const res = await this.client.send(
        new ListObjectsV2Command({ Bucket: this.bucket, Prefix: r2prefix, ContinuationToken: token }),
      );
      for (const obj of res.Contents ?? []) if (obj.Key) keys.push(r2KeyToStorageKey(obj.Key));
      token = res.IsTruncated ? res.NextContinuationToken : undefined;
    } while (token);
    return keys;
  }
}

function normalizeEndpoint(raw: string): string {
  const t = raw.trim().replace(/\/+$/, '');
  return /^https?:\/\//i.test(t) ? t : `https://${t}`;
}

function mimeOf(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  const map: Record<string, string> = {
    jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp',
    gif: 'image/gif', svg: 'image/svg+xml', avif: 'image/avif', bmp: 'image/bmp',
  };
  return map[ext] ?? 'application/octet-stream';
}