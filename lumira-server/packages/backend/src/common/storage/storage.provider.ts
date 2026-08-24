// lumira-server/packages/backend/src/common/storage/storage.provider.ts
// 存储适配器 DI 提供者（默认本地磁盘）

import { LocalStorageAdapter } from './local-storage.adapter';
import { StorageAdapter } from './storage-adapter.interface';
import type { Provider } from '@nestjs/common';

export const STORAGE_ADAPTER = 'STORAGE_ADAPTER';

export const storageAdapterProvider: Provider = {
  provide: STORAGE_ADAPTER,
  useFactory: (): StorageAdapter => new LocalStorageAdapter(),
};