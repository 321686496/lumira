// lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts
// 存储抽象接口：该接口是「每一个应用到图片存储的实体」迁移与校验的根基。

// 'thumbs' 为缩略图派生目录（/uploads/thumbs/{templates|categories}/...），
// 由 ThumbsService 预生成/按需生成后写入激活存储，供客户端直连存储域名取图。
export type StorageCategory = 'templates' | 'categories' | 'banners' | 'feedback' | 'users' | 'thumbs';

export const STORAGE_KEY_PREFIX = '/uploads';

export interface StorageAdapter {
  /** 写入文件，返回相对存储路径（storageKey），如 `/uploads/templates/srv_xxx/cover.jpg` */
  write(category: StorageCategory, id: string, filename: string, buffer: Buffer): Promise<string>;
  /** 删除某实体整个目录 */
  deleteByDir(category: StorageCategory, id: string): Promise<void>;
  /** 读取单个 storageKey 的原始字节（迁移/校验源读取用） */
  readBuffer(storageKey: string): Promise<Buffer>;
  /** 判断单个 storageKey 是否存在（迁移校验用） */
  exists(storageKey: string): Promise<boolean>;
  /** 列出路径前缀下的所有 storageKey（盘/桶扫描，缀 `{STORAGE_KEY_PREFIX}/...`） */
  listKeys(prefix?: string): Promise<string[]>;
}