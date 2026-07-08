/**
 * Theme Store 单元测试
 * 验证状态变化、持久化、computed 属性
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useThemeStore } from '@/stores/theme'
import { storageService } from '@/services/storage'
import { THEME_METAS } from '@/theme/theme-configs'

// Mock window.matchMedia（jsdom 默认不实现）
beforeEach(() => {
  window.matchMedia = vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  }))
})

describe('Theme Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    storageService.clearAll()
    // 清除 document.documentElement 上的 data-theme 属性
    document.documentElement.removeAttribute('data-theme')
  })

  describe('初始状态', () => {
    it('currentTheme 默认为 warm', () => {
      const store = useThemeStore()
      expect(store.currentTheme).toBe('warm')
    })

    it('followSystem 默认为 false', () => {
      const store = useThemeStore()
      expect(store.followSystem).toBe(false)
    })

    it('loaded 默认为 false', () => {
      const store = useThemeStore()
      expect(store.loaded).toBe(false)
    })
  })

  describe('computed 属性', () => {
    it('themeMeta 应返回当前主题的完整元数据', () => {
      const store = useThemeStore()
      expect(store.themeMeta).toEqual(THEME_METAS.warm)
    })

    it('layout 应返回当前主题的布局参数', () => {
      const store = useThemeStore()
      expect(store.layout).toEqual(THEME_METAS.warm.layout)
    })

    it('componentVariant 应返回当前主题的组件变体', () => {
      const store = useThemeStore()
      expect(store.componentVariant).toBe('default')
    })

    it('iconStyle 应返回当前主题的图标风格', () => {
      const store = useThemeStore()
      expect(store.iconStyle).toBe('line')
    })

    it('切换到 retro 后 computed 应更新', () => {
      const store = useThemeStore()
      store.currentTheme = 'retro'
      expect(store.componentVariant).toBe('retro')
      expect(store.iconStyle).toBe('handdrawn')
      expect(store.layout.tabBarStyle).toBe('compact')
    })

    it('切换到 fresh 后 computed 应更新', () => {
      const store = useThemeStore()
      store.currentTheme = 'fresh'
      expect(store.componentVariant).toBe('fresh')
      expect(store.layout.templateGridColumns).toBe(1)
      expect(store.layout.cardAspectRatio).toBe('4 / 5')
    })
  })

  describe('setTheme', () => {
    it('应更新 currentTheme', async () => {
      const store = useThemeStore()
      await store.setTheme('ink')
      expect(store.currentTheme).toBe('ink')
    })

    it('应持久化到 storage', async () => {
      const store = useThemeStore()
      await store.setTheme('retro')
      const persisted = await storageService.getSetting('theme')
      expect(persisted).toBe('retro')
    })

    it('应设置 document 的 data-theme 属性', async () => {
      const store = useThemeStore()
      await store.setTheme('ink')
      expect(document.documentElement.getAttribute('data-theme')).toBe('ink')
    })

    it('应设置布局 CSS Variable', async () => {
      const store = useThemeStore()
      await store.setTheme('retro')
      const gridCols = document.documentElement.style.getPropertyValue('--layout-grid-columns')
      const galleryCols = document.documentElement.style.getPropertyValue('--layout-gallery-columns')
      const cardAspect = document.documentElement.style.getPropertyValue('--layout-card-aspect')
      expect(gridCols).toBe('2')
      expect(galleryCols).toBe('2')
      expect(cardAspect).toBe('1 / 1')
    })
  })

  describe('loadTheme', () => {
    it('无存储时应使用默认值 warm', async () => {
      const store = useThemeStore()
      await store.loadTheme()
      expect(store.currentTheme).toBe('warm')
      expect(store.loaded).toBe(true)
    })

    it('有存储时应加载已保存的主题', async () => {
      await storageService.setSetting('theme', 'retro')
      const store = useThemeStore()
      await store.loadTheme()
      expect(store.currentTheme).toBe('retro')
    })

    it('无效的存储值应回退到默认', async () => {
      await storageService.setSetting('theme', 'invalid')
      const store = useThemeStore()
      await store.loadTheme()
      expect(store.currentTheme).toBe('warm')
    })

    it('应加载 followSystem 设置', async () => {
      await storageService.setSetting('followSystemTheme', 'true')
      const store = useThemeStore()
      await store.loadTheme()
      expect(store.followSystem).toBe(true)
    })

    it('应设置 loaded 为 true', async () => {
      const store = useThemeStore()
      await store.loadTheme()
      expect(store.loaded).toBe(true)
    })

    it('应调用 applyTheme 设置 data-theme', async () => {
      await storageService.setSetting('theme', 'fresh')
      const store = useThemeStore()
      await store.loadTheme()
      expect(document.documentElement.getAttribute('data-theme')).toBe('fresh')
    })
  })

  describe('setFollowSystem', () => {
    it('应更新 followSystem 状态', async () => {
      const store = useThemeStore()
      await store.setFollowSystem(true)
      expect(store.followSystem).toBe(true)
    })

    it('应持久化到 storage', async () => {
      const store = useThemeStore()
      await store.setFollowSystem(true)
      const persisted = await storageService.getSetting('followSystemTheme')
      expect(persisted).toBe('true')
    })

    it('关闭时应持久化 false', async () => {
      const store = useThemeStore()
      await store.setFollowSystem(true)
      await store.setFollowSystem(false)
      const persisted = await storageService.getSetting('followSystemTheme')
      expect(persisted).toBe('false')
    })
  })

  describe('applyTheme', () => {
    it('应设置 data-theme 属性', () => {
      const store = useThemeStore()
      store.applyTheme('retro')
      expect(document.documentElement.getAttribute('data-theme')).toBe('retro')
    })

    it('应设置布局 CSS Variable', () => {
      const store = useThemeStore()
      store.applyTheme('fresh')
      const gridCols = document.documentElement.style.getPropertyValue('--layout-grid-columns')
      expect(gridCols).toBe('1')
    })
  })

  describe('syncWithSystem', () => {
    it('应调用 matchMedia', () => {
      const store = useThemeStore()
      store.syncWithSystem()
      expect(window.matchMedia).toHaveBeenCalledWith('(prefers-color-scheme: dark)')
    })

    it('不应抛出异常', () => {
      const store = useThemeStore()
      expect(() => store.syncWithSystem()).not.toThrow()
    })
  })
})
