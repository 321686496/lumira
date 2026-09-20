// lumira-server/packages/backend/src/common/storage/r2-storage.adapter.ts
// Cloudflare R2（S3 兼容）存储实现：直连 R2，零出口带宽。
// 环境变量：R2_ENDPOINT(或 R2_ACCOUNT_ID)、R2_ACCESS_KEY_ID、R2_SECRET_ACCESS_KEY、R2_BUCKET、R2_REGION(默认 auto)。
// R2 无目录语义，deleteByDir 通过 ListObjectsV2 + DeleteObjects 实现。

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

function resolveEndpoint(env: NodeJS.ProcessEnv): string {
  if (env.R2_ENDPOINT) return env.R2_ENDPOINT;
  if (env.R2_ACCOUNT_ID) return `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;
  throw new Error('R2 not configured: set R2_ENDPOINT or R2_ACCOUNT_ID');
}

export class R2StorageAdapter implements StorageAdapter {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor() {
    const endpoint = resolveEndpoint(process.env);
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const bucket = process.env.R2_BUCKET;
    if (!accessKeyId || !secretAccessKey || !bucket) {
      throw new Error('R2 not configured: R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY / R2_BUCKET required');
    }
    this.client = new S3Client({
      region: process.env.R2_REGION || 'auto',
      endpoint,
      credentials: { accessKeyId, secretAccessKey },
      forcePathStyle: true, // R2 + 自定义域名需要
    });
    this.bucket = bucket;
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
      if ((e as { name?: string })?.name === 'NotFound' || (e as { $metadata?: { httpStatusCode?: number } })?.$metadata?.httpStatusCode === 404) {
        return false;
      }
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

function mimeOf(filename: string): string {
  const ext = filename.split('.').pop()?.toLowerCase() ?? '';
  const map: Record<string, string> = {
    jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp',
    gif: 'image/gif', svg: 'image/svg+xml', avif: 'image/avif', bmp: 'image/bmp',
  };
  return map[ext] ?? 'application/octet-stream';
}