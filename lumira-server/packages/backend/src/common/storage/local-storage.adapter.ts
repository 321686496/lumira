// lumira-server/packages/backend/src/common/storage/local-storage.adapter.ts
// 本地磁盘存储实现（默认）：文件落盘 + 返回相对 storageKey

import * as fs from 'fs';
import * as path from 'path';
import type { StorageAdapter, StorageCategory } from './storage-adapter.interface';

export class LocalStorageAdapter implements StorageAdapter {
  private readonly uploadRoot: string;

  constructor(uploadRoot = path.resolve(process.env.UPLOAD_DIR || './data/uploads')) {
    this.uploadRoot = uploadRoot;
  }

  async write(category: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string> {
    const dir = path.join(this.uploadRoot, category, id);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, filename), buffer);
    return `/uploads/${category}/${id}/${filename}`;
  }

  async deleteByDir(category: StorageCategory, id: string): Promise<void> {
    const dir = path.join(this.uploadRoot, category, id);
    if (fs.existsSync(dir)) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  }
}