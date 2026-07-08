/**
 * useThemeComponent 单元测试
 * 验证 useTabBarVariant 的变体映射逻辑
 */
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useThemeStore } from '@/stores/theme'

// Mock 三个 TabBar 组件（文件在 Task 5-7 创建，mock 使测试独立运行）
vi.mock('@/components/tabbar/TabBarFloating.vue', () => ({
  default: { name: 'TabBarFloating' },
}))
vi.mock('@/components/tabbar/TabBarCompact.vue', () => ({
  default: { name: 'TabBarCompact' },
}))
vi.mock('@/components/tabbar/TabBarMinimal.vue', () => ({
  default: { name: 'TabBarMinimal' },
}))

// 必须在 mock 声明之后导入被测模块
import { useTabBarVariant } from '@/composables/useThemeComponent'

describe('useTabBarVariant', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('warm 主题应返回 TabBarFloating 组件', () => {
    const store = useThemeStore()
    store.currentTheme = 'warm'
    const variant = useTabBarVariant()
    expect(variant.value).toEqual({ name: 'TabBarFloating' })
  })

  it('ink 主题应返回 TabBarFloating 组件', () => {
    const store = useThemeStore()
    store.currentTheme = 'ink'
    const variant = useTabBarVariant()
    expect(variant.value).toEqual({ name: 'TabBarFloating' })
  })

  it('retro 主题应返回 TabBarCompact 组件', () => {
    const store = useThemeStore()
    store.currentTheme = 'retro'
    const variant = useTabBarVariant()
    expect(variant.value).toEqual({ name: 'TabBarCompact' })
  })

  it('fresh 主题应返回 TabBarMinimal 组件', () => {
    const store = useThemeStore()
    store.currentTheme = 'fresh'
    const variant = useTabBarVariant()
    expect(variant.value).toEqual({ name: 'TabBarMinimal' })
  })

  it('切换主题后 variant 应响应式更新', () => {
    const store = useThemeStore()
    store.currentTheme = 'warm'
    const variant = useTabBarVariant()
    expect(variant.value).toEqual({ name: 'TabBarFloating' })

    store.currentTheme = 'retro'
    expect(variant.value).toEqual({ name: 'TabBarCompact' })

    store.currentTheme = 'fresh'
    expect(variant.value).toEqual({ name: 'TabBarMinimal' })
  })
})
