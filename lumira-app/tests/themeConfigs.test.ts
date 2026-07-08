/**
 * Theme Configs 单元测试
 * 验证 4 套主题配置的完整性
 */
import { describe, it, expect } from 'vitest'
import {
  THEME_METAS,
  THEME_IDS,
  type ThemeId,
  type ThemeMeta,
  type ThemeLayout,
} from '@/theme/theme-configs'

describe('Theme Configs', () => {
  it('THEME_IDS 应包含 4 套主题', () => {
    expect(THEME_IDS).toHaveLength(4)
    expect(THEME_IDS).toEqual(['warm', 'ink', 'retro', 'fresh'])
  })

  it('THEME_METAS 应包含所有 4 套主题的配置', () => {
    expect(THEME_METAS.warm).toBeDefined()
    expect(THEME_METAS.ink).toBeDefined()
    expect(THEME_METAS.retro).toBeDefined()
    expect(THEME_METAS.fresh).toBeDefined()
  })

  const themeIds: ThemeId[] = ['warm', 'ink', 'retro', 'fresh']

  themeIds.forEach((id) => {
    describe(`主题 ${id}`, () => {
      const meta: ThemeMeta = THEME_METAS[id]

      it('id 应与 key 一致', () => {
        expect(meta.id).toBe(id)
      })

      it('label 应为非空字符串', () => {
        expect(typeof meta.label).toBe('string')
        expect(meta.label.length).toBeGreaterThan(0)
      })

      it('description 应为非空字符串', () => {
        expect(typeof meta.description).toBe('string')
        expect(meta.description.length).toBeGreaterThan(0)
      })

      it('iconStyle 应为有效值', () => {
        expect(['line', 'fill', 'handdrawn']).toContain(meta.iconStyle)
      })

      it('componentVariant 应为有效值', () => {
        expect(['default', 'default-dark', 'retro', 'fresh']).toContain(meta.componentVariant)
      })

      it('layout 应包含完整字段', () => {
        const layout: ThemeLayout = meta.layout
        expect(layout.homeSectionOrder).toBeInstanceOf(Array)
        expect(layout.homeSectionOrder.length).toBeGreaterThan(0)
        expect(typeof layout.templateGridColumns).toBe('number')
        expect(layout.templateGridColumns).toBeGreaterThanOrEqual(1)
        expect(typeof layout.galleryGridColumns).toBe('number')
        expect(layout.galleryGridColumns).toBeGreaterThanOrEqual(1)
        expect(typeof layout.cardAspectRatio).toBe('string')
        expect(layout.cardAspectRatio.length).toBeGreaterThan(0)
        expect(['floating', 'compact', 'minimal']).toContain(layout.tabBarStyle)
      })

      it('homeSectionOrder 应包含全部 6 个区块', () => {
        const order = meta.layout.homeSectionOrder
        expect(order).toHaveLength(6)
        expect(order).toContain('brand')
        expect(order).toContain('inspiration')
        expect(order).toContain('recent')
        expect(order).toContain('featured')
        expect(order).toContain('scene')
        expect(order).toContain('stats')
      })
    })
  })

  it('warm 和 ink 的 homeSectionOrder 应相同', () => {
    expect(THEME_METAS.warm.layout.homeSectionOrder).toEqual(
      THEME_METAS.ink.layout.homeSectionOrder,
    )
  })

  it('retro 的 homeSectionOrder 应将 scene 前置', () => {
    const order = THEME_METAS.retro.layout.homeSectionOrder
    expect(order[0]).toBe('brand')
    expect(order[1]).toBe('scene')
  })

  it('fresh 的 templateGridColumns 应为 1（单列大卡）', () => {
    expect(THEME_METAS.fresh.layout.templateGridColumns).toBe(1)
  })

  it('retro 的 galleryGridColumns 应为 2', () => {
    expect(THEME_METAS.retro.layout.galleryGridColumns).toBe(2)
  })

  it('retro 的 cardAspectRatio 应为 1 / 1', () => {
    expect(THEME_METAS.retro.layout.cardAspectRatio).toBe('1 / 1')
  })

  it('fresh 的 cardAspectRatio 应为 4 / 5', () => {
    expect(THEME_METAS.fresh.layout.cardAspectRatio).toBe('4 / 5')
  })

  it('warm 和 ink 应使用 floating TabBar', () => {
    expect(THEME_METAS.warm.layout.tabBarStyle).toBe('floating')
    expect(THEME_METAS.ink.layout.tabBarStyle).toBe('floating')
  })

  it('retro 应使用 compact TabBar', () => {
    expect(THEME_METAS.retro.layout.tabBarStyle).toBe('compact')
  })

  it('fresh 应使用 minimal TabBar', () => {
    expect(THEME_METAS.fresh.layout.tabBarStyle).toBe('minimal')
  })

  it('retro 的 iconStyle 应为 handdrawn', () => {
    expect(THEME_METAS.retro.iconStyle).toBe('handdrawn')
  })

  it('ink 的 componentVariant 应为 default-dark', () => {
    expect(THEME_METAS.ink.componentVariant).toBe('default-dark')
  })
})
