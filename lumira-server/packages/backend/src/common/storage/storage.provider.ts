// lumira-server/packages/backend/src/common/storage/storage.provider.ts
// 存储适配器 DI 提供者：返回「激活存储」代理，每次调用实时解析当前激活存储
// （启动时来自环境变量，后台配置后来自 DB，切换无需重启进程）。

import { StorageAdapter } from './storage-adapter.interface';
import { activeStorageAdapter } from './runtime-storage';
import type { Provider } from '@nestjs/common';

export const STORAGE_ADAPTER = 'STORAGE_ADAPTER';

export const storageAdapterProvider: Provider = {
  provide: STORAGE_ADAPTER,
  useFactory: (): StorageAdapter => activeStorageAdapter,
};