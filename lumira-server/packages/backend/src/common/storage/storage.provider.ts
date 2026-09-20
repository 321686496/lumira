// lumira-server/packages/backend/src/common/storage/storage.provider.ts
// 存储适配器 DI 提供者：默认本地磁盘；`UPLOAD_R2=1` 时切到 Cloudflare R2（写透）。

import { LocalStorageAdapter } from './local-storage.adapter';
import { R2StorageAdapter } from './r2-storage.adapter';
import { StorageAdapter } from './storage-adapter.interface';
import type { Provider } from '@nestjs/common';

export const STORAGE_ADAPTER = 'STORAGE_ADAPTER';

export const storageAdapterProvider: Provider = {
  provide: STORAGE_ADAPTER,
  useFactory: (): StorageAdapter => {
    if (process.env.UPLOAD_R2 === '1' || process.env.UPLOAD_STORAGE === 'r2') {
      return new R2StorageAdapter();
    }
    return new LocalStorageAdapter();
  },
};