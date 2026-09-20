// lumira-server/packages/backend/src/common/storage/storage.provider.ts
// 存储适配器 DI 提供者：按「当前激活存储」动态解析（local / r2 / aliyun / tencent）。

import { StorageAdapter } from './storage-adapter.interface';
import { buildStorageAdapter, resolveActiveStorageId } from './storage-registry';
import type { Provider } from '@nestjs/common';

export const STORAGE_ADAPTER = 'STORAGE_ADAPTER';

export const storageAdapterProvider: Provider = {
  provide: STORAGE_ADAPTER,
  useFactory: (): StorageAdapter => buildStorageAdapter(resolveActiveStorageId()),
};