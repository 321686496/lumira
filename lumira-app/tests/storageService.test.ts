/**
 * 存储服务测试
 * 对应测试文档：
 * - LM-TPL-DATA-014: 保存模板
 * - LM-GAL-DATA-004: 相册列表加载
 * - LM-GAL-DATA-003: 照片 CRUD
 * - LM-PRF-DATA-001: 统计数据加载
 * - LM-PRF-DATA-008: 清除缓存
 * - LM-SVC-ERR-002: SQLite 读写失败处理
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { StorageServiceMockImpl } from '@/services/storage'
import type { LocalTemplate } from '@/types/template'
import type { LocalPhoto } from '@/types/photo'

describe('StorageService (Mock)', () => {
  let storage: StorageServiceMockImpl

  beforeEach(async () => {
    storage = new StorageServiceMockImpl()
    storage.clearAll()
    await storage.init()
  })

  // === 模板 CRUD ===
  describe('模板 CRUD', () => {
    it('insertTemplate 应成功写入', async () => {
      const template: LocalTemplate = {
        id: 'tmpl_001',
        name: '测试模板',
        source: 'builtin',
        pptplJson: '{}',
        createdAt: Date.now(),
        updatedAt: Date.now(),
      }
      await storage.insertTemplate(template)
      const got = await storage.getTemplate('tmpl_001')
      expect(got).not.toBeNull()
      expect(got?.name).toBe('测试模板')
    })

    it('getTemplate 不存在的 ID 应返回 null', async () => {
      const got = await storage.getTemplate('nonexistent')
      expect(got).toBeNull()
    })

    it('updateTemplate 应更新已有模板', async () => {
      const template: LocalTemplate = {
        id: 'tmpl_002',
        name: '原名',
        source: 'created',
        pptplJson: '{}',
        createdAt: Date.now(),
        updatedAt: Date.now(),
      }
      await storage.insertTemplate(template)
      await storage.updateTemplate({ ...template, name: '新名' })
      const got = await storage.getTemplate('tmpl_002')
      expect(got?.name).toBe('新名')
    })

    it('updateTemplate 不存在的模板应抛出错误', async () => {
      await expect(
        storage.updateTemplate({
          id: 'nonexistent',
          name: 'x',
          source: 'builtin',
          pptplJson: '{}',
          createdAt: 0,
          updatedAt: 0,
        }),
      ).rejects.toThrow('不存在')
    })

    it('deleteTemplate 应删除模板', async () => {
      const template: LocalTemplate = {
        id: 'tmpl_003',
        name: '待删除',
        source: 'builtin',
        pptplJson: '{}',
        createdAt: Date.now(),
        updatedAt: Date.now(),
      }
      await storage.insertTemplate(template)
      await storage.deleteTemplate('tmpl_003')
      const got = await storage.getTemplate('tmpl_003')
      expect(got).toBeNull()
    })

    it('getAllTemplates 应返回所有模板', async () => {
      await storage.insertTemplate({
        id: 't1',
        name: 'A',
        source: 'builtin',
        pptplJson: '{}',
        createdAt: 1,
        updatedAt: 1,
      })
      await storage.insertTemplate({
        id: 't2',
        name: 'B',
        source: 'imported',
        pptplJson: '{}',
        createdAt: 2,
        updatedAt: 2,
      })
      const all = await storage.getAllTemplates()
      expect(all).toHaveLength(2)
    })

    it('getTemplatesBySource 应按来源筛选', async () => {
      await storage.insertTemplate({
        id: 't1',
        name: 'A',
        source: 'builtin',
        pptplJson: '{}',
        createdAt: 1,
        updatedAt: 1,
      })
      await storage.insertTemplate({
        id: 't2',
        name: 'B',
        source: 'imported',
        pptplJson: '{}',
        createdAt: 2,
        updatedAt: 2,
      })
      const builtins = await storage.getTemplatesBySource('builtin')
      expect(builtins).toHaveLength(1)
      expect(builtins[0].name).toBe('A')
    })
  })

  // === 照片 CRUD ===
  describe('照片 CRUD', () => {
    const makePhoto = (id: string, createdAt: number, templateId: string | null = null): LocalPhoto => ({
      id,
      templateId,
      imagePath: `mock://${id}.jpg`,
      exifJson: '{}',
      createdAt,
    })

    it('insertPhoto 应成功写入', async () => {
      await storage.insertPhoto(makePhoto('p1', 1000))
      const got = await storage.getPhoto('p1')
      expect(got).not.toBeNull()
      expect(got?.imagePath).toBe('mock://p1.jpg')
    })

    it('getAllPhotos 应按时间倒序返回', async () => {
      await storage.insertPhoto(makePhoto('p1', 1000))
      await storage.insertPhoto(makePhoto('p2', 3000))
      await storage.insertPhoto(makePhoto('p3', 2000))
      const all = await storage.getAllPhotos()
      expect(all[0].id).toBe('p2')
      expect(all[1].id).toBe('p3')
      expect(all[2].id).toBe('p1')
    })

    it('getPhotosByTemplate 应按模板筛选', async () => {
      await storage.insertPhoto(makePhoto('p1', 1000, 'tmpl_A'))
      await storage.insertPhoto(makePhoto('p2', 2000, 'tmpl_B'))
      await storage.insertPhoto(makePhoto('p3', 3000, 'tmpl_A'))
      const photos = await storage.getPhotosByTemplate('tmpl_A')
      expect(photos).toHaveLength(2)
    })

    it('deletePhoto 应删除照片', async () => {
      await storage.insertPhoto(makePhoto('p1', 1000))
      await storage.deletePhoto('p1')
      const got = await storage.getPhoto('p1')
      expect(got).toBeNull()
    })
  })

  // === 统计 ===
  describe('统计数据 (LM-PRF-DATA-001)', () => {
    it('getPhotoCount 应返回照片总数', async () => {
      await storage.insertPhoto({
        id: 'p1',
        templateId: null,
        imagePath: 'a.jpg',
        exifJson: '{}',
        createdAt: 1,
      })
      await storage.insertPhoto({
        id: 'p2',
        templateId: null,
        imagePath: 'b.jpg',
        exifJson: '{}',
        createdAt: 2,
      })
      const count = await storage.getPhotoCount()
      expect(count).toBe(2)
    })

    it('getTemplateCount 应返回模板总数', async () => {
      await storage.insertTemplate({
        id: 't1',
        name: 'A',
        source: 'builtin',
        pptplJson: '{}',
        createdAt: 1,
        updatedAt: 1,
      })
      const count = await storage.getTemplateCount()
      expect(count).toBe(1)
    })
  })

  // === 设置 ===
  describe('设置存储', () => {
    it('setSetting & getSetting 应读写一致', async () => {
      await storage.setSetting('key1', 'value1')
      const value = await storage.getSetting('key1')
      expect(value).toBe('value1')
    })

    it('未设置的 key 应返回 null', async () => {
      const value = await storage.getSetting('nonexistent')
      expect(value).toBeNull()
    })
  })

  // === 设备 ID ===
  describe('设备 ID', () => {
    it('getDeviceId 应返回非空字符串', async () => {
      const id = await storage.getDeviceId()
      expect(id).toBeTruthy()
      expect(typeof id).toBe('string')
    })

    it('多次调用应返回相同 ID', async () => {
      const id1 = await storage.getDeviceId()
      const id2 = await storage.getDeviceId()
      expect(id1).toBe(id2)
    })
  })

  // === close ===
  describe('close', () => {
    it('应无错误完成', async () => {
      await expect(storage.close()).resolves.toBeUndefined()
    })
  })
})
