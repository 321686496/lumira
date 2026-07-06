/**
 * 本地存储服务
 * 对应 PRD 6 数据模型，使用 SQLite + 文件系统
 * 在测试环境使用内存 Mock 实现
 */
import type { LocalTemplate } from '@/types/template'
import type { LocalPhoto } from '@/types/photo'

/** 本地存储服务接口 */
export interface StorageService {
  // 数据库
  init(): Promise<void>
  close(): Promise<void>

  // 模板 CRUD
  insertTemplate(template: LocalTemplate): Promise<void>
  updateTemplate(template: LocalTemplate): Promise<void>
  deleteTemplate(id: string): Promise<void>
  getTemplate(id: string): Promise<LocalTemplate | null>
  getAllTemplates(): Promise<LocalTemplate[]>
  getTemplatesBySource(source: 'builtin' | 'imported' | 'created'): Promise<LocalTemplate[]>

  // 照片 CRUD
  insertPhoto(photo: LocalPhoto): Promise<void>
  updatePhoto(photo: LocalPhoto): Promise<void>
  deletePhoto(id: string): Promise<void>
  getPhoto(id: string): Promise<LocalPhoto | null>
  getAllPhotos(): Promise<LocalPhoto[]>
  getPhotosByTemplate(templateId: string): Promise<LocalPhoto[]>

  // 统计
  getPhotoCount(): Promise<number>
  getTemplateCount(): Promise<number>
  getFavoriteCount(): Promise<number>

  // 设置
  getSetting(key: string): Promise<string | null>
  setSetting(key: string, value: string): Promise<void>

  // 设备 ID
  getDeviceId(): Promise<string>
}

/**
 * 内存存储 Mock 实现
 * 用于测试环境，模拟 SQLite 行为
 */
export class StorageServiceMockImpl implements StorageService {
  private templates = new Map<string, LocalTemplate>()
  private photos = new Map<string, LocalPhoto>()
  private settings = new Map<string, string>()
  private deviceId: string | null = null
  private initialized = false

  async init(): Promise<void> {
    this.initialized = true
  }

  async close(): Promise<void> {
    this.initialized = false
  }

  /** 清空所有数据（测试用） */
  clearAll(): void {
    this.templates.clear()
    this.photos.clear()
    this.settings.clear()
    this.deviceId = null
  }

  async insertTemplate(template: LocalTemplate): Promise<void> {
    this.templates.set(template.id, { ...template })
  }

  async updateTemplate(template: LocalTemplate): Promise<void> {
    if (!this.templates.has(template.id)) {
      throw new Error(`模板 ${template.id} 不存在`)
    }
    this.templates.set(template.id, { ...template, updatedAt: Date.now() })
  }

  async deleteTemplate(id: string): Promise<void> {
    this.templates.delete(id)
  }

  async getTemplate(id: string): Promise<LocalTemplate | null> {
    const t = this.templates.get(id)
    return t ? { ...t } : null
  }

  async getAllTemplates(): Promise<LocalTemplate[]> {
    return Array.from(this.templates.values()).map((t) => ({ ...t }))
  }

  async getTemplatesBySource(source: 'builtin' | 'imported' | 'created'): Promise<LocalTemplate[]> {
    return Array.from(this.templates.values())
      .filter((t) => t.source === source)
      .map((t) => ({ ...t }))
  }

  async insertPhoto(photo: LocalPhoto): Promise<void> {
    this.photos.set(photo.id, { ...photo })
  }

  async updatePhoto(photo: LocalPhoto): Promise<void> {
    if (!this.photos.has(photo.id)) {
      throw new Error(`照片 ${photo.id} 不存在`)
    }
    this.photos.set(photo.id, { ...photo })
  }

  async deletePhoto(id: string): Promise<void> {
    this.photos.delete(id)
  }

  async getPhoto(id: string): Promise<LocalPhoto | null> {
    const p = this.photos.get(id)
    return p ? { ...p } : null
  }

  async getAllPhotos(): Promise<LocalPhoto[]> {
    return Array.from(this.photos.values())
      .sort((a, b) => b.createdAt - a.createdAt)
      .map((p) => ({ ...p }))
  }

  async getPhotosByTemplate(templateId: string): Promise<LocalPhoto[]> {
    return Array.from(this.photos.values())
      .filter((p) => p.templateId === templateId)
      .sort((a, b) => b.createdAt - a.createdAt)
      .map((p) => ({ ...p }))
  }

  async getPhotoCount(): Promise<number> {
    return this.photos.size
  }

  async getTemplateCount(): Promise<number> {
    return this.templates.size
  }

  async getFavoriteCount(): Promise<number> {
    // Mock：返回 0，实际应查询收藏表
    return 0
  }

  async getSetting(key: string): Promise<string | null> {
    return this.settings.get(key) ?? null
  }

  async setSetting(key: string, value: string): Promise<void> {
    this.settings.set(key, value)
  }

  async getDeviceId(): Promise<string> {
    if (!this.deviceId) {
      this.deviceId = `device_${Date.now().toString(36)}`
    }
    return this.deviceId
  }
}

/** 单例实例 */
export const storageService = new StorageServiceMockImpl()
