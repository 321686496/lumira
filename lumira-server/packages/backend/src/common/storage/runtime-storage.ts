// lumira-server/packages/backend/src/common/storage/runtime-storage.ts
// 存储「运行时状态」：进程内缓存当前激活存储 + 各厂商适配器 + 图片公网 URL。
// 启动时以环境变量为种子；启动后由 StorageConfigService 从 DB 加载覆盖（后台可改）。
// 之所以用模块级状态而非 DB 直读：buildAssetUrl 是自由函数、DI 在构造期同步，二者都需要同步取值。

import { buildStorageAdapter, resolveActiveStorageId, StorageId } from './storage-registry';
import type { StorageAdapter, StorageCategory } from './storage-adapter.interface';

let activeId: StorageId = resolveActiveStorageId();
let publicUrl =
  process.env.STORAGE_PUBLIC_URL || process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';

const adapters = new Map<StorageId, StorageAdapter>();
adapters.set(activeId, buildStorageAdapter(activeId)); // 以 env 默认构建激活适配器作为兜底

export function seedAdapter(id: StorageId, adapter: StorageAdapter): void {
  adapters.set(id, adapter);
}

export function getAdapter(id: StorageId): StorageAdapter {
  let a = adapters.get(id);
  if (!a) {
    a = buildStorageAdapter(id); // 未在 DB 配置时回退 env 构建
    adapters.set(id, a);
  }
  return a;
}

export function setRuntimeConfig(nextActiveId: StorageId, nextPublicUrl: string): void {
  activeId = nextActiveId;
  if (nextPublicUrl) publicUrl = nextPublicUrl;
  adapters.set(nextActiveId, getRuntimeActiveAdapterFallback(nextActiveId));
}

export function getActiveId(): StorageId {
  return activeId;
}

export function getActivePublicUrl(): string {
  return publicUrl || process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
}

function getRuntimeActiveAdapterFallback(id: StorageId): StorageAdapter {
  const existing = adapters.get(id);
  return existing ?? buildStorageAdapter(id);
}

/** 供 DI 注入的激活适配器代理：每次调用实时取「当前激活存储」，切换后无需重启即生效 */
export const activeStorageAdapter: StorageAdapter = {
  write(c: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string> {
    return getAdapter(getActiveId()).write(c, id, filename, buffer);
  },
  deleteByDir(c: StorageCategory, id: string): Promise<void> {
    return getAdapter(getActiveId()).deleteByDir(c, id);
  },
  readBuffer(storageKey: string): Promise<Buffer> {
    return getAdapter(getActiveId()).readBuffer(storageKey);
  },
  exists(storageKey: string): Promise<boolean> {
    return getAdapter(getActiveId()).exists(storageKey);
  },
  listKeys(prefix = ''): Promise<string[]> {
    return getAdapter(getActiveId()).listKeys(prefix);
  },
};