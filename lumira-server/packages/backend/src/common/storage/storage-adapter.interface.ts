// lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts
// 存储抽象接口：后续可切换 S3/OSS 等实现，业务只依赖此接口

export type StorageCategory = 'templates' | 'categories';

export const STORAGE_KEY_PREFIX = '/uploads';

export interface StorageAdapter {
  /** 写入文件，返回相对存储路径（storageKey），如 `/uploads/templates/srv_xxx/cover.jpg` */
  write(category: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string>;
  /** 删除某实体整个目录 */
  deleteByDir(category: StorageCategory, id: string): Promise<void>;
}