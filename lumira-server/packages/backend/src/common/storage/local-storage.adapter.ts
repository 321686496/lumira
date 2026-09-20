// lumira-server/packages/backend/src/common/storage/local-storage.adapter.ts
// 本地磁盘存储实现（默认）：文件落盘 + 返回相对 storageKey。

import * as fs from 'fs';
import * as path from 'path';
import type { StorageAdapter, StorageCategory } from './storage-adapter.interface';

export class LocalStorageAdapter implements StorageAdapter {
  private readonly uploadRoot: string;

  constructor(uploadRoot = path.resolve(process.env.UPLOAD_DIR || './data/uploads')) {
    this.uploadRoot = uploadRoot;
  }

  /** storageKey `/uploads/{cat}/{id}/{filename}` → 磁盘绝对路径 */
  private toFilePath(storageKey: string): string {
    const rel = storageKey.replace(/^\/uploads/, '').replace(/^\//, '');
    return path.join(this.uploadRoot, ...rel.split('/'));
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

  async readBuffer(storageKey: string): Promise<Buffer> {
    return fs.readFileSync(this.toFilePath(storageKey));
  }

  async exists(storageKey: string): Promise<boolean> {
    return fs.existsSync(this.toFilePath(storageKey));
  }

  async listKeys(prefix = ''): Promise<string[]> {
    const relPrefix = prefix.replace(/^\/uploads/, '').replace(/^\//, '');
    const out: string[] = [];
    const walk = (dir: string, relParts: string[]) => {
      if (!fs.existsSync(dir)) return;
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.isDirectory()) {
          walk(path.join(dir, entry.name), [...relParts, entry.name]);
        } else if (entry.isFile()) {
          const rel = [...relParts, entry.name].join('/');
          if (rel.startsWith(relPrefix)) out.push(`/uploads/${rel}`);
        }
      }
    };
    walk(this.uploadRoot, []);
    return out;
  }
}