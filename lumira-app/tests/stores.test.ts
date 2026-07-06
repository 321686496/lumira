/**
 * Pinia Store 测试
 * 对应测试文档：
 * - LM-CAP-DATA-021: capture store 状态管理
 * - LM-GAL-DATA-004: gallery store 相册列表加载
 * - LM-TPL-DATA-014: templates store 模板保存
 * - LM-TPL-UI-004: templates store 分类筛选
 * - LM-PRF-DATA-001: 统计数据
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useCaptureStore } from '@/stores/capture'
import { useGalleryStore } from '@/stores/gallery'
import { useTemplatesStore } from '@/stores/templates'
import { useSettingsStore } from '@/stores/settings'
import { storageService } from '@/services/storage'
import { VALID_TEMPLATE_JSON } from './fixtures/templates'

describe('Capture Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('初始状态应正确', () => {
    const store = useCaptureStore()
    expect(store.isActive).toBe(false)
    expect(store.activeTemplateId).toBeNull()
    expect(store.overlaySettings.showComposition).toBe(true)
    expect(store.overlaySettings.opacity).toBe(0.5)
    expect(store.alignmentStatus.isLevel).toBe(true)
  })

  it('setActive 应更新 isActive', () => {
    const store = useCaptureStore()
    store.setActive(true)
    expect(store.isActive).toBe(true)
  })

  it('setActiveTemplate 应更新模板 ID', () => {
    const store = useCaptureStore()
    store.setActiveTemplate('tmpl_001')
    expect(store.activeTemplateId).toBe('tmpl_001')
    expect(store.hasActiveTemplate).toBe(true)
  })

  it('updateOverlaySettings 应合并设置', () => {
    const store = useCaptureStore()
    store.updateOverlaySettings({ opacity: 0.8, showPose: false })
    expect(store.overlaySettings.opacity).toBe(0.8)
    expect(store.overlaySettings.showPose).toBe(false)
    expect(store.overlaySettings.showComposition).toBe(true) // 未修改的保持
  })

  it('setOverlayOpacity 应更新透明度', () => {
    const store = useCaptureStore()
    store.setOverlayOpacity(0.3)
    expect(store.overlaySettings.opacity).toBe(0.3)
  })

  it('updateCameraParameters 应合并参数', () => {
    const store = useCaptureStore()
    store.updateCameraParameters({ evBias: 0.7, iso: 200 })
    expect(store.cameraParameters.evBias).toBe(0.7)
    expect(store.cameraParameters.iso).toBe(200)
  })

  it('resetCameraParameters 应恢复默认', () => {
    const store = useCaptureStore()
    store.updateCameraParameters({ evBias: 1.0 })
    store.resetCameraParameters()
    expect(store.cameraParameters.evBias).toBe(0)
  })

  it('resetState 应重置所有状态', () => {
    const store = useCaptureStore()
    store.setActive(true)
    store.setActiveTemplate('tmpl_001')
    store.updateCameraParameters({ evBias: 2.0 })
    store.resetState()
    expect(store.isActive).toBe(false)
    expect(store.activeTemplateId).toBeNull()
    expect(store.cameraParameters.evBias).toBe(0)
  })
})

describe('Gallery Store', () => {
  beforeEach(async () => {
    setActivePinia(createPinia())
    // 重置存储
    storageService.clearAll()
    await storageService.init()
  })

  it('初始状态应为空', () => {
    const store = useGalleryStore()
    expect(store.photos).toHaveLength(0)
    expect(store.photoCount).toBe(0)
    expect(store.hasPhotos).toBe(false)
  })

  it('addPhoto 应添加照片并返回 ID', async () => {
    const store = useGalleryStore()
    const id = await store.addPhoto({
      templateId: 'tmpl_001',
      imagePath: 'mock://photo.jpg',
      exifJson: '{}',
    })
    expect(id).toBeTruthy()
    expect(store.photos).toHaveLength(1)
    expect(store.photoCount).toBe(1)
  })

  it('loadPhotos 应从存储加载照片列表', async () => {
    await storageService.insertPhoto({
      id: 'p1',
      templateId: null,
      imagePath: 'a.jpg',
      exifJson: '{}',
      createdAt: 1000,
    })
    const store = useGalleryStore()
    await store.loadPhotos()
    expect(store.photos).toHaveLength(1)
    expect(store.photos[0].id).toBe('p1')
  })

  it('deletePhoto 应删除照片', async () => {
    const store = useGalleryStore()
    const id = await store.addPhoto({
      templateId: null,
      imagePath: 'a.jpg',
      exifJson: '{}',
    })
    await store.deletePhoto(id)
    expect(store.photos).toHaveLength(0)
  })

  it('setCurrentPhoto 应更新当前照片 ID', async () => {
    const store = useGalleryStore()
    const id = await store.addPhoto({
      templateId: null,
      imagePath: 'a.jpg',
      exifJson: '{}',
    })
    store.setCurrentPhoto(id)
    expect(store.currentPhotoId).toBe(id)
    expect(store.currentPhoto?.id).toBe(id)
  })

  it('编辑历史应支持 push/pop', () => {
    const store = useGalleryStore()
    const action = { type: 'color' as const, params: { brightness: 0.1 }, timestamp: Date.now() }
    store.pushEditAction(action)
    expect(store.editingHistory).toHaveLength(1)
    const popped = store.popEditAction()
    expect(popped).toEqual(action)
    expect(store.editingHistory).toHaveLength(0)
  })
})

describe('Templates Store', () => {
  beforeEach(async () => {
    setActivePinia(createPinia())
    storageService.clearAll()
    await storageService.init()
  })

  it('初始状态应为空', () => {
    const store = useTemplatesStore()
    expect(store.allTemplates).toHaveLength(0)
    expect(store.templateCount).toBe(0)
    expect(store.currentCategory).toBe('全部')
  })

  it('addTemplate 应添加模板', async () => {
    const store = useTemplatesStore()
    const template = JSON.parse(VALID_TEMPLATE_JSON)
    const id = await store.addTemplate(template, 'builtin')
    expect(id).toBeTruthy()
    expect(store.allTemplates).toHaveLength(1)
    expect(store.builtinTemplates).toHaveLength(1)
  })

  it('loadTemplates 应从存储加载', async () => {
    const template = JSON.parse(VALID_TEMPLATE_JSON)
    await storageService.insertTemplate({
      id: template.meta.id,
      name: template.meta.name,
      source: 'builtin',
      pptplJson: VALID_TEMPLATE_JSON,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    })
    const store = useTemplatesStore()
    await store.loadTemplates()
    expect(store.builtinTemplates).toHaveLength(1)
    expect(store.allTemplates).toHaveLength(1)
  })

  it('setCategory 应更新当前分类', () => {
    const store = useTemplatesStore()
    store.setCategory('人像')
    expect(store.currentCategory).toBe('人像')
  })

  it('setSearchQuery 应更新搜索词', () => {
    const store = useTemplatesStore()
    store.setSearchQuery('日落')
    expect(store.searchQuery).toBe('日落')
  })

  it('deleteTemplate 应删除模板', async () => {
    const store = useTemplatesStore()
    const template = JSON.parse(VALID_TEMPLATE_JSON)
    const id = await store.addTemplate(template, 'created')
    await store.deleteTemplate(id)
    expect(store.allTemplates).toHaveLength(0)
  })

  it('importFromJson 应解析并导入模板', async () => {
    const store = useTemplatesStore()
    const id = await store.importFromJson(VALID_TEMPLATE_JSON)
    expect(id).toBeTruthy()
    expect(store.importedTemplates).toHaveLength(1)
  })

  it('getResolvedTemplate 应返回解析后的模板', async () => {
    const store = useTemplatesStore()
    const template = JSON.parse(VALID_TEMPLATE_JSON)
    const id = await store.addTemplate(template, 'builtin')
    const resolved = await store.getResolvedTemplate(id)
    expect(resolved).not.toBeNull()
    expect(resolved?.meta.id).toBe(template.meta.id)
  })
})

describe('Settings Store', () => {
  beforeEach(async () => {
    setActivePinia(createPinia())
    storageService.clearAll()
    await storageService.init()
  })

  it('loadSettings 应加载默认值', async () => {
    const store = useSettingsStore()
    await store.loadSettings()
    expect(store.loaded).toBe(true)
    expect(store.saveQuality).toBe('high')
    expect(store.defaultGridDisplay).toBe(true)
    expect(store.defaultCamera).toBe('back')
  })

  it('setSaveQuality 应持久化', async () => {
    const store = useSettingsStore()
    await store.setSaveQuality('original')
    expect(store.saveQuality).toBe('original')
    const persisted = await storageService.getSetting('saveQuality')
    expect(persisted).toBe('original')
  })

  it('setDefaultGridDisplay 应持久化', async () => {
    const store = useSettingsStore()
    await store.setDefaultGridDisplay(false)
    expect(store.defaultGridDisplay).toBe(false)
    const persisted = await storageService.getSetting('defaultGridDisplay')
    expect(persisted).toBe('false')
  })

  it('clearCache 应无错误完成', async () => {
    const store = useSettingsStore()
    await expect(store.clearCache()).resolves.toBeUndefined()
  })
})
