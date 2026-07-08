# Lumira v2 Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a multi-theme system for Lumira supporting 4 built-in themes (warm/ink/retro/fresh) with visual layer changes (color/font/shape) driven by CSS Variables, plus component variants (3 TabBar styles) and layout parameterization (section order, grid columns, card aspect ratio).

**Architecture:** CSS Variables driven by `data-theme` attribute on `document.documentElement`. A Pinia setup store (`useThemeStore`) manages theme state, persistence (via `storageService`), and applies the theme. Layout differences are configuration-driven via `THEME_METAS` (a static config table) and exposed as computed properties. TabBar variants use dynamic `<component :is="...">` resolved by a `useTabBarVariant()` composable. All v1 components already consume `var(--xxx)` tokens, so they auto-respond to theme switches with zero changes.

**Tech Stack:** uni-app (Vue 3.4 + Composition API + `<script setup lang="ts">`), TypeScript strict mode, Pinia setup stores (ref/computed auto-unwrap), SCSS + CSS Variables, Vitest (jsdom, `tests/setup.ts` mocks uni-app).

## Global Constraints

- TypeScript strict mode: no `any`, no `@ts-ignore`
- Pinia setup stores: use `store.property` pattern (auto-unwrap); do NOT destructure without `storeToRefs`
- All v1 components already use `var(--xxx)` — zero changes for color/font/radius/shadow theme switching
- Tests live in `lumira-app/tests/` directory (NOT `src/__tests__/`) — vitest.config.ts `include: ['tests/**/*.test.ts']`
- Test baseline: 131 tests passing (before this plan)
- Project root for all npm/npx commands: `d:\app\projects\photo_post\lumira-app`
- uni-app conditional compilation directives: `// #ifdef H5` ... `// #endif` for H5-only code, `// #ifndef H5` ... `// #endif` for non-H5
- TabBar variant shared contract: props `{ current: string; theme?: 'light' | 'dark' }`, emits `{ (e: 'on-switch', key: string): void }`
- Commit message convention: `feat(scope): description`

---

## File Structure

### Files to Create

| Path | Responsibility |
|------|---------------|
| `lumira-app/src/theme/theme-configs.ts` | `ThemeId` type, `ThemeLayout`/`ThemeMeta` interfaces, `THEME_IDS`, `THEME_METAS` config table (4 themes) |
| `lumira-app/src/stores/theme.ts` | `useThemeStore`: state (currentTheme/followSystem/loaded), computed (themeMeta/layout/componentVariant/iconStyle), actions (setTheme/setFollowSystem/loadTheme/applyTheme/syncWithSystem) |
| `lumira-app/src/theme/theme-ink.scss` | `[data-theme="ink"]` token overrides |
| `lumira-app/src/theme/theme-retro.scss` | `[data-theme="retro"]` token overrides |
| `lumira-app/src/theme/theme-fresh.scss` | `[data-theme="fresh"]` token overrides |
| `lumira-app/src/composables/useThemeComponent.ts` | `useTabBarVariant()` composable — maps `tabBarStyle` → component |
| `lumira-app/src/components/tabbar/TabBarFloating.vue` | Floating pill TabBar (warm/ink) — migrated from v1 `FloatingTabBar.vue` |
| `lumira-app/src/components/tabbar/TabBarCompact.vue` | Compact horizontal bar TabBar (retro) |
| `lumira-app/src/components/tabbar/TabBarMinimal.vue` | Minimal line TabBar (fresh) |
| `lumira-app/src/pages/settings/theme.vue` | Theme selection page: 2×2 preview grid + follow-system toggle |
| `lumira-app/tests/themeConfigs.test.ts` | Unit tests for `theme-configs.ts` |
| `lumira-app/tests/themeStore.test.ts` | Unit tests for `useThemeStore` |
| `lumira-app/tests/useThemeComponent.test.ts` | Unit tests for `useTabBarVariant` |
| `lumira-app/tests/tabBarVariants.test.ts` | Component tests for 3 TabBar variants (props/emits contract) |

### Files to Modify

| Path | Changes |
|------|---------|
| `lumira-app/src/theme/tokens.scss` | Add 3 layout CSS Variable defaults (`--layout-grid-columns`, `--layout-gallery-columns`, `--layout-card-aspect`) to `:root` |
| `lumira-app/src/App.vue` | Import 3 new theme SCSS files; call `themeStore.loadTheme()` in `onLaunch` |
| `lumira-app/src/pages.json` | Register `pages/settings/theme` route |
| `lumira-app/src/pages/profile/settings.vue` | Add "主题" row navigating to `/pages/settings/theme` |
| `lumira-app/src/pages/home/index.vue` | Replace hardcoded sections with `v-for` driven by `themeStore.layout.homeSectionOrder`; replace `FloatingTabBar` with dynamic `<component :is="tabBarVariant">` |
| `lumira-app/src/pages/templates/index.vue` | Replace hardcoded grid columns with `var(--layout-grid-columns)` and aspect ratio with `var(--layout-card-aspect)`; replace `FloatingTabBar` with dynamic component |
| `lumira-app/src/pages/gallery/index.vue` | Replace hardcoded `:columns="3"` with theme-driven value; replace `FloatingTabBar` with dynamic component |
| `lumira-app/src/pages/capture/index.vue` | Replace `FloatingTabBar` with dynamic `<component :is="tabBarVariant">` |
| `lumira-app/src/pages/profile/index.vue` | Replace `FloatingTabBar` with dynamic `<component :is="tabBarVariant">` |

> **Note:** The task description mentions `src/pages/editor/index.vue` in Task 12, but this file does not exist in the v1 codebase. Task 12 covers only `capture/index.vue` and `profile/index.vue`. The `pages/templates/editor.vue` page does not use `FloatingTabBar`.

---

## Phase 0: Foundation

### Task 1: Theme Configs (`theme-configs.ts`)

**Files:**
- Create: `lumira-app/src/theme/theme-configs.ts`
- Test: `lumira-app/tests/themeConfigs.test.ts`

**Interfaces:**
- Consumes: nothing
- Produces: `ThemeId` (type), `ThemeLayout` (interface), `ThemeMeta` (interface), `THEME_IDS` (const array), `THEME_METAS` (const record) — consumed by Task 2 (store), Task 4 (composable), Task 8 (theme page)

- [ ] **Step 1: Write the failing test**

Create `lumira-app/tests/themeConfigs.test.ts`:

```typescript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `d:\app\projects\photo_post\lumira-app`):
```bash
npx vitest run tests/themeConfigs.test.ts
```
Expected: FAIL with error `Failed to resolve import "@/theme/theme-configs"` or `module not found`.

- [ ] **Step 3: Write the implementation**

Create `lumira-app/src/theme/theme-configs.ts`:

```typescript
/**
 * 主题配置表
 * 定义 4 套内置主题的元数据与布局参数
 */

/** 主题 ID */
export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh'

/** 主题布局参数 */
export interface ThemeLayout {
  /** 首页区块顺序 */
  homeSectionOrder: string[]
  /** 模板库网格列数 */
  templateGridColumns: number
  /** 相册网格列数 */
  galleryGridColumns: number
  /** 卡片宽高比 */
  cardAspectRatio: string
  /** TabBar 样式 */
  tabBarStyle: 'floating' | 'compact' | 'minimal'
}

/** 主题元数据 */
export interface ThemeMeta {
  /** 主题 ID */
  id: ThemeId
  /** 主题名称（中文） */
  label: string
  /** 主题描述（中文） */
  description: string
  /** 图标风格 */
  iconStyle: 'line' | 'fill' | 'handdrawn'
  /** 组件变体标识 */
  componentVariant: 'default' | 'default-dark' | 'retro' | 'fresh'
  /** 布局参数 */
  layout: ThemeLayout
}

/** 全部主题 ID 列表 */
export const THEME_IDS: ThemeId[] = ['warm', 'ink', 'retro', 'fresh']

/** 主题配置表 */
export const THEME_METAS: Record<ThemeId, ThemeMeta> = {
  warm: {
    id: 'warm',
    label: '暖米白',
    description: '温暖留白，编辑式质感',
    iconStyle: 'line',
    componentVariant: 'default',
    layout: {
      homeSectionOrder: ['brand', 'inspiration', 'recent', 'featured', 'scene', 'stats'],
      templateGridColumns: 2,
      galleryGridColumns: 3,
      cardAspectRatio: '3 / 4',
      tabBarStyle: 'floating',
    },
  },
  ink: {
    id: 'ink',
    label: '浓墨',
    description: '深色沉浸，夜拍伴侣',
    iconStyle: 'line',
    componentVariant: 'default-dark',
    layout: {
      homeSectionOrder: ['brand', 'inspiration', 'recent', 'featured', 'scene', 'stats'],
      templateGridColumns: 2,
      galleryGridColumns: 3,
      cardAspectRatio: '3 / 4',
      tabBarStyle: 'floating',
    },
  },
  retro: {
    id: 'retro',
    label: '胶片复古',
    description: '暖橘深棕，胶片方格',
    iconStyle: 'handdrawn',
    componentVariant: 'retro',
    layout: {
      homeSectionOrder: ['brand', 'scene', 'featured', 'inspiration', 'recent', 'stats'],
      templateGridColumns: 2,
      galleryGridColumns: 2,
      cardAspectRatio: '1 / 1',
      tabBarStyle: 'compact',
    },
  },
  fresh: {
    id: 'fresh',
    label: '日系清新',
    description: '淡粉米白，杂志呼吸',
    iconStyle: 'line',
    componentVariant: 'fresh',
    layout: {
      homeSectionOrder: ['brand', 'inspiration', 'featured', 'scene', 'recent', 'stats'],
      templateGridColumns: 1,
      galleryGridColumns: 2,
      cardAspectRatio: '4 / 5',
      tabBarStyle: 'minimal',
    },
  },
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx vitest run tests/themeConfigs.test.ts
```
Expected: PASS — all tests green.

- [ ] **Step 5: Run type-check to verify no TypeScript errors**

Run:
```bash
npm run type-check
```
Expected: No errors related to `theme-configs.ts`.

- [ ] **Step 6: Commit**

```bash
git add lumira-app/src/theme/theme-configs.ts lumira-app/tests/themeConfigs.test.ts
git commit -m "feat(theme): add theme-configs with 4 theme metas and layout params"
```

---

### Task 2: Theme Store (`useThemeStore`)

**Files:**
- Create: `lumira-app/src/stores/theme.ts`
- Test: `lumira-app/tests/themeStore.test.ts`

**Interfaces:**
- Consumes: `ThemeId`, `ThemeLayout`, `ThemeMeta`, `THEME_METAS`, `THEME_IDS` from Task 1; `storageService` from `@/services/storage`
- Produces: `useThemeStore` — Pinia store with state (`currentTheme`, `followSystem`, `loaded`), computed (`themeMeta`, `layout`, `componentVariant`, `iconStyle`), actions (`setTheme`, `setFollowSystem`, `loadTheme`, `applyTheme`, `syncWithSystem`) — consumed by Task 4, Task 8, Task 10, Task 11, Task 12, Task 13

- [ ] **Step 1: Write the failing test**

Create `lumira-app/tests/themeStore.test.ts`:

```typescript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx vitest run tests/themeStore.test.ts
```
Expected: FAIL with error `Failed to resolve import "@/stores/theme"`.

- [ ] **Step 3: Write the implementation**

Create `lumira-app/src/stores/theme.ts`:

```typescript
/**
 * 主题状态仓库
 * 管理当前主题、跟随系统、布局参数
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { storageService } from '@/services/storage'
import {
  THEME_METAS,
  THEME_IDS,
  type ThemeId,
  type ThemeMeta,
  type ThemeLayout,
} from '@/theme/theme-configs'

export const useThemeStore = defineStore('theme', () => {
  // === State ===
  const currentTheme = ref<ThemeId>('warm')
  const followSystem = ref(false)
  const loaded = ref(false)

  // === Computed ===
  const themeMeta = computed<ThemeMeta>(() => THEME_METAS[currentTheme.value])
  const layout = computed<ThemeLayout>(() => themeMeta.value.layout)
  const componentVariant = computed(() => themeMeta.value.componentVariant)
  const iconStyle = computed(() => themeMeta.value.iconStyle)

  // === Actions ===
  async function setTheme(id: ThemeId): Promise<void> {
    currentTheme.value = id
    applyTheme(id)
    await storageService.setSetting('theme', id)
  }

  async function setFollowSystem(enabled: boolean): Promise<void> {
    followSystem.value = enabled
    await storageService.setSetting('followSystemTheme', String(enabled))
    if (enabled) syncWithSystem()
  }

  async function loadTheme(): Promise<void> {
    const saved = await storageService.getSetting('theme')
    if (saved && THEME_IDS.includes(saved as ThemeId)) {
      currentTheme.value = saved as ThemeId
    }
    const fs = await storageService.getSetting('followSystemTheme')
    followSystem.value = fs === 'true'
    applyTheme(currentTheme.value)
    if (followSystem.value) syncWithSystem()
    loaded.value = true
  }

  function applyTheme(id: ThemeId): void {
    const meta = THEME_METAS[id]
    // #ifdef H5
    document.documentElement.setAttribute('data-theme', id)
    document.documentElement.style.setProperty(
      '--layout-grid-columns',
      String(meta.layout.templateGridColumns),
    )
    document.documentElement.style.setProperty(
      '--layout-gallery-columns',
      String(meta.layout.galleryGridColumns),
    )
    document.documentElement.style.setProperty(
      '--layout-card-aspect',
      meta.layout.cardAspectRatio,
    )
    // #endif
    // #ifndef H5
    uni.$emit('theme-change', id)
    // #endif
  }

  function syncWithSystem(): void {
    // #ifdef H5
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const handler = (e: MediaQueryListEvent) => {
      if (followSystem.value) {
        setTheme(e.matches ? 'ink' : 'warm')
      }
    }
    mq.addEventListener('change', handler)
    // #endif
  }

  return {
    // state
    currentTheme,
    followSystem,
    loaded,
    // computed
    themeMeta,
    layout,
    componentVariant,
    iconStyle,
    // actions
    setTheme,
    setFollowSystem,
    loadTheme,
    applyTheme,
    syncWithSystem,
  }
})
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx vitest run tests/themeStore.test.ts
```
Expected: PASS — all tests green.

- [ ] **Step 5: Run full test suite to verify no regressions**

Run:
```bash
npm test
```
Expected: All tests pass (baseline 131 + new themeConfigs tests + new themeStore tests).

- [ ] **Step 6: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lumira-app/src/stores/theme.ts lumira-app/tests/themeStore.test.ts
git commit -m "feat(theme): add useThemeStore with persistence and system sync"
```

---

### Task 3: SCSS Theme Files (4 theme token definitions)

**Files:**
- Modify: `lumira-app/src/theme/tokens.scss` (add layout CSS Variable defaults to `:root`)
- Create: `lumira-app/src/theme/theme-ink.scss`
- Create: `lumira-app/src/theme/theme-retro.scss`
- Create: `lumira-app/src/theme/theme-fresh.scss`
- Modify: `lumira-app/src/App.vue` (add 3 new SCSS imports)

**Interfaces:**
- Consumes: nothing (pure CSS)
- Produces: 4 CSS theme definitions (warm via `:root`, ink/retro/fresh via `[data-theme="xxx"]`) — consumed by all pages via CSS Variables

- [ ] **Step 1: Add layout CSS Variable defaults to `tokens.scss`**

Open `lumira-app/src/theme/tokens.scss`. Find the last block before the closing `}`:

```scss
  // === 拍摄页深色 ===
  --color-capture-bg: #1A1A1A;
  --color-capture-bar: rgba(255, 255, 255, 0.12);
  --color-capture-text: rgba(255, 255, 255, 0.6);
  --color-capture-text-bright: #FFFFFF;
  --color-capture-overlay-line: rgba(201, 169, 110, 0.35);
}
```

Replace with (add layout variables before closing `}`):

```scss
  // === 拍摄页深色 ===
  --color-capture-bg: #1A1A1A;
  --color-capture-bar: rgba(255, 255, 255, 0.12);
  --color-capture-text: rgba(255, 255, 255, 0.6);
  --color-capture-text-bright: #FFFFFF;
  --color-capture-overlay-line: rgba(201, 169, 110, 0.35);

  // === 布局参数（v2 主题系统） ===
  --layout-grid-columns: 2;
  --layout-gallery-columns: 3;
  --layout-card-aspect: 3 / 4;
}
```

- [ ] **Step 2: Create `theme-ink.scss`**

Create `lumira-app/src/theme/theme-ink.scss`:

```scss
// theme-ink.scss — 浓墨主题（深色沉浸）
// 对应 spec 2.1/2.2/2.3 ink 列

[data-theme="ink"] {
  // === 配色 ===
  --color-bg-canvas: #1C1A17;
  --color-bg-card: #262320;
  --color-bg-surface: #2E2A26;

  --color-text-primary: #F2EEE6;
  --color-text-secondary: #9C9690;
  --color-text-tertiary: #6B6660;

  --color-brand-primary: #D4B57A;
  --color-brand-secondary: #BFA060;

  --color-danger: #C8625C;
  --color-success: #8A9B6C;

  --color-border: #3A3530;

  --color-tag-gold-bg: #3A3328;
  --color-tag-gold-text: #D4B57A;

  // === 形状 ===
  --radius-button: 6px;
  --radius-card: 12px;

  // === 阴影 ===
  --shadow-card: 0 1px 3px rgba(0, 0, 0, 0.3);

  // === 布局参数 ===
  --layout-grid-columns: 2;
  --layout-gallery-columns: 3;
  --layout-card-aspect: 3 / 4;
}
```

- [ ] **Step 3: Create `theme-retro.scss`**

Create `lumira-app/src/theme/theme-retro.scss`:

```scss
// theme-retro.scss — 胶片复古主题（暖橘深棕，衬线字体）
// 对应 spec 2.1/2.2/2.3 retro 列

[data-theme="retro"] {
  // === 配色 ===
  --color-bg-canvas: #F5E6D3;
  --color-bg-card: #FAF0E0;
  --color-bg-surface: #EDDFC8;

  --color-text-primary: #3D2817;
  --color-text-secondary: #6B4C2F;
  --color-text-tertiary: #9C8060;

  --color-brand-primary: #D4865C;
  --color-brand-secondary: #B06440;

  --color-danger: #A04030;
  --color-success: #6B7B4C;

  --color-border: #E0D0B8;

  --color-tag-gold-bg: #F0E0C8;
  --color-tag-gold-text: #8C5A30;

  // === 字体 ===
  --font-sans: 'Noto Serif SC', 'PingFang SC', serif;

  // === 形状 ===
  --radius-button: 4px;
  --radius-card: 8px;

  // === 阴影 ===
  --shadow-card: 0 2px 6px rgba(60, 40, 20, 0.08);

  // === 布局参数 ===
  --layout-grid-columns: 2;
  --layout-gallery-columns: 2;
  --layout-card-aspect: 1 / 1;
}
```

- [ ] **Step 4: Create `theme-fresh.scss`**

Create `lumira-app/src/theme/theme-fresh.scss`:

```scss
// theme-fresh.scss — 日系清新主题（淡粉米白，杂志呼吸）
// 对应 spec 2.1/2.2/2.3 fresh 列

[data-theme="fresh"] {
  // === 配色 ===
  --color-bg-canvas: #FAF7F2;
  --color-bg-card: #FFFFFF;
  --color-bg-surface: #F5F0EA;

  --color-text-primary: #4A3F35;
  --color-text-secondary: #8C7F70;
  --color-text-tertiary: #B8AEA0;

  --color-brand-primary: #E8B4A0;
  --color-brand-secondary: #D89888;

  --color-danger: #C87878;
  --color-success: #9AAB7C;

  --color-border: #F0E8E0;

  --color-tag-gold-bg: #F8EDE0;
  --color-tag-gold-text: #A07860;

  // === 字体 ===
  --font-serif: 'PingFang SC', -apple-system, sans-serif;

  // === 形状 ===
  --radius-button: 8px;
  --radius-card: 16px;

  // === 阴影 ===
  --shadow-card: 0 1px 4px rgba(180, 160, 140, 0.06);

  // === 布局参数 ===
  --layout-grid-columns: 1;
  --layout-gallery-columns: 2;
  --layout-card-aspect: 4 / 5;
}
```

- [ ] **Step 5: Add SCSS imports to `App.vue`**

Open `lumira-app/src/App.vue`. Find the style import line:

```scss
@import '@/theme/tokens.scss';
```

Replace with:

```scss
@import '@/theme/tokens.scss';
@import '@/theme/theme-ink.scss';
@import '@/theme/theme-retro.scss';
@import '@/theme/theme-fresh.scss';
```

- [ ] **Step 6: Run type-check to verify no errors**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 7: Run build to verify SCSS compiles**

Run:
```bash
npm run build:h5
```
Expected: Build succeeds with no SCSS compilation errors.

- [ ] **Step 8: Commit**

```bash
git add lumira-app/src/theme/tokens.scss lumira-app/src/theme/theme-ink.scss lumira-app/src/theme/theme-retro.scss lumira-app/src/theme/theme-fresh.scss lumira-app/src/App.vue
git commit -m "feat(theme): split tokens.scss into 4 theme files with full token coverage"
```

---

## Phase 1: TabBar Variants

> **Dependency note:** Task 4 (composable) imports the 3 TabBar components created in Tasks 5–7. The composable's unit test uses `vi.mock` to mock the component imports, so the test passes before the components exist. However, `npm run type-check` for the composable source file will fail until Tasks 5–7 are complete. Tasks are presented in numerical order; the type-check gap is closed after Task 7.

### Task 4: Theme Component Composable (`useThemeComponent.ts`)

**Files:**
- Create: `lumira-app/src/composables/useThemeComponent.ts`
- Test: `lumira-app/tests/useThemeComponent.test.ts`

**Interfaces:**
- Consumes: `useThemeStore` from Task 2; `TabBarFloating`, `TabBarCompact`, `TabBarMinimal` from Tasks 5–7 (mocked in test)
- Produces: `useTabBarVariant()` → `ComputedRef<Component>` — consumed by Task 10, Task 11, Task 12

- [ ] **Step 1: Write the failing test**

Create `lumira-app/tests/useThemeComponent.test.ts`:

```typescript
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx vitest run tests/useThemeComponent.test.ts
```
Expected: FAIL with error `Failed to resolve import "@/composables/useThemeComponent"`.

- [ ] **Step 3: Write the implementation**

Create `lumira-app/src/composables/useThemeComponent.ts`:

```typescript
/**
 * 主题组件变体选择 composable
 * 根据当前主题的 tabBarStyle 返回对应的 TabBar 组件
 */
import { computed } from 'vue'
import { useThemeStore } from '@/stores/theme'
import TabBarFloating from '@/components/tabbar/TabBarFloating.vue'
import TabBarCompact from '@/components/tabbar/TabBarCompact.vue'
import TabBarMinimal from '@/components/tabbar/TabBarMinimal.vue'
import type { Component } from 'vue'

const TABBAR_VARIANTS: Record<string, Component> = {
  floating: TabBarFloating,
  compact: TabBarCompact,
  minimal: TabBarMinimal,
}

export function useTabBarVariant() {
  const themeStore = useThemeStore()
  return computed<Component>(() => TABBAR_VARIANTS[themeStore.layout.tabBarStyle])
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx vitest run tests/useThemeComponent.test.ts
```
Expected: PASS — all 5 tests green. (The `vi.mock` calls intercept the component imports, so the test passes even though the component files don't exist yet.)

- [ ] **Step 5: Note on type-check**

> `npm run type-check` will fail on `useThemeComponent.ts` because the 3 TabBar component files don't exist yet. This will be resolved after Tasks 5–7 create the component files. Do NOT run type-check at this step — defer to after Task 7.

- [ ] **Step 6: Commit**

```bash
git add lumira-app/src/composables/useThemeComponent.ts lumira-app/tests/useThemeComponent.test.ts
git commit -m "feat(theme): add useTabBarVariant composable with mock-tested mapping"
```

---

### Task 5: TabBarFloating Component (warm/ink)

**Files:**
- Create: `lumira-app/src/components/tabbar/TabBarFloating.vue`
- Test: `lumira-app/tests/tabBarVariants.test.ts` (create with Floating tests)

**Interfaces:**
- Consumes: nothing (self-contained)
- Produces: `TabBarFloating` Vue component with props `{ current: string; theme?: 'light' | 'dark' }` and emits `{ (e: 'on-switch', key: string): void }` — consumed by Task 4 (composable), Task 10, Task 11, Task 12

- [ ] **Step 1: Write the component test**

Create `lumira-app/tests/tabBarVariants.test.ts`:

```typescript
/**
 * TabBar 变体组件测试
 * 验证 3 个变体共享相同的 props/emits 契约
 */
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import TabBarFloating from '@/components/tabbar/TabBarFloating.vue'

describe('TabBarFloating 组件', () => {
  it('应渲染容器', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    expect(wrapper.find('.tab-bar-floating').exists()).toBe(true)
  })

  it('应渲染 2 个侧边 Tab + 1 个快门', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    expect(wrapper.findAll('.tab-side')).toHaveLength(2)
    expect(wrapper.find('.shutter-btn').exists()).toBe(true)
  })

  it('点击首页 Tab 应触发 on-switch: home', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'profile' } })
    await wrapper.findAll('.tab-side')[0].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['home'])
  })

  it('点击快门应触发 on-switch: capture', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    await wrapper.find('.tab-center').trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['capture'])
  })

  it('点击我的 Tab 应触发 on-switch: profile', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    await wrapper.findAll('.tab-side')[1].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['profile'])
  })

  it('点击当前已选中 Tab 不应触发 on-switch', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    await wrapper.findAll('.tab-side')[0].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeFalsy()
  })

  it('点击快门即使已选中也应触发（center 总是触发）', async () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'capture' } })
    await wrapper.find('.tab-center').trigger('click')
    expect(wrapper.emitted('on-switch')).toBeTruthy()
  })

  it('默认 theme 应为 light', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home' } })
    expect(wrapper.props('theme')).toBe('light')
    expect(wrapper.find('.tab-bar-floating').classes()).toContain('theme-light')
  })

  it('theme=dark 时应有 theme-dark 类', () => {
    const wrapper = mount(TabBarFloating, { props: { current: 'home', theme: 'dark' } })
    expect(wrapper.find('.tab-bar-floating').classes()).toContain('theme-dark')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx vitest run tests/tabBarVariants.test.ts
```
Expected: FAIL with error `Failed to resolve import "@/components/tabbar/TabBarFloating.vue"`.

- [ ] **Step 3: Write the implementation**

Create `lumira-app/src/components/tabbar/TabBarFloating.vue`:

```vue
<script setup lang="ts">
/**
 * 悬浮胶囊 TabBar（warm/ink 主题）
 * 从 v1 FloatingTabBar.vue 迁移，保持相同的 props/emits 契约
 */
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface TabBarFloatingProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<TabBarFloatingProps>(), {
  theme: 'light',
})

const emit = defineEmits<{
  (e: 'on-switch', key: string): void
}>()

const tabs: TabItem[] = [
  { key: 'home', label: '首页', iconChar: '⌂' },
  { key: 'capture', label: '拍摄', iconChar: '◉', center: true },
  { key: 'profile', label: '我的', iconChar: '◍' },
]

const handleSwitch = (key: string) => {
  const tab = tabs.find((t) => t.key === key)
  if (key === props.current && !tab?.center) return
  emit('on-switch', key)
}
</script>

<template>
  <view class="tab-bar-floating" :class="`theme-${theme}`">
    <view class="tab-bar-inner">
      <view
        class="tab-item tab-side"
        :class="{ active: current === 'home' }"
        @click="handleSwitch('home')"
      >
        <text class="tab-icon">{{ tabs[0].iconChar }}</text>
        <text v-if="current === 'home'" class="tab-label">{{ tabs[0].label }}</text>
      </view>

      <view class="tab-center" @click="handleSwitch('capture')">
        <view class="shutter-btn" :class="{ active: current === 'capture' }">
          <view class="shutter-ring"></view>
          <text class="shutter-icon">{{ tabs[1].iconChar }}</text>
        </view>
      </view>

      <view
        class="tab-item tab-side"
        :class="{ active: current === 'profile' }"
        @click="handleSwitch('profile')"
      >
        <text class="tab-icon">{{ tabs[2].iconChar }}</text>
        <text v-if="current === 'profile'" class="tab-label">{{ tabs[2].label }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.tab-bar-floating {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  bottom: calc(var(--tabbar-bottom-offset) + env(safe-area-inset-bottom));
  z-index: 900;
  width: auto;
}

.tab-bar-inner {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  height: var(--tabbar-height);
  padding: 0 var(--space-3);
  border-radius: var(--radius-pill);
  gap: var(--space-6);
  position: relative;

  .theme-light & {
    background: rgba(255, 255, 255, 0.72);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid var(--color-border);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);
  }

  .theme-dark & {
    background: rgba(28, 26, 23, 0.6);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.3);
  }
}

.tab-item {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  padding: 0 var(--space-3);
  height: 44px;
  border-radius: var(--radius-pill);
  transition: transform var(--duration-normal) var(--ease-default);
  min-width: 44px;

  .theme-light & {
    color: var(--color-text-tertiary);
  }

  .theme-dark & {
    color: rgba(255, 255, 255, 0.5);
  }

  &.active {
    transform: scale(1.08);
    color: var(--color-brand-primary);
  }

  &:active {
    transform: scale(0.94);
  }
}

.tab-icon {
  font-size: 20px;
  line-height: 1;
}

.tab-label {
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  line-height: 1;
  color: var(--color-brand-primary);
}

.tab-center {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 60px;
  height: var(--tabbar-height);
  flex-shrink: 0;
}

.shutter-btn {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: var(--tabbar-shutter-size);
  height: var(--tabbar-shutter-size);
  margin-top: calc(var(--tabbar-shutter-protrusion) * -1);
  border-radius: 50%;
  background: var(--color-brand-primary);
  border: 2px solid var(--color-bg-canvas);
  transition: transform var(--duration-fast) ease, box-shadow var(--duration-fast) ease;

  .theme-dark & {
    border-color: var(--color-capture-bg);
  }

  &.active {
    transform: scale(0.92);
  }

  &:active {
    transform: scale(0.92);
  }
}

.shutter-ring {
  position: absolute;
  top: -5px;
  left: -5px;
  right: -5px;
  bottom: -5px;
  border-radius: 50%;
  border: 1px solid var(--color-brand-primary);
  opacity: 0.25;
}

.shutter-icon {
  font-size: 24px;
  line-height: 1;
  color: #FFFFFF;
}
</style>
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx vitest run tests/tabBarVariants.test.ts
```
Expected: PASS — all TabBarFloating tests green.

- [ ] **Step 5: Commit**

```bash
git add lumira-app/src/components/tabbar/TabBarFloating.vue lumira-app/tests/tabBarVariants.test.ts
git commit -m "feat(tabbar): add TabBarFloating component migrated from v1 FloatingTabBar"
```

---

### Task 6: TabBarCompact Component (retro)

**Files:**
- Create: `lumira-app/src/components/tabbar/TabBarCompact.vue`
- Test: `lumira-app/tests/tabBarVariants.test.ts` (append Compact tests)

**Interfaces:**
- Consumes: nothing (self-contained)
- Produces: `TabBarCompact` Vue component with same props/emits contract as `TabBarFloating` — consumed by Task 4 (composable), Task 10, Task 11, Task 12

- [ ] **Step 1: Append Compact tests to `tabBarVariants.test.ts`**

Open `lumira-app/tests/tabBarVariants.test.ts`. Add the following import at the top (after the existing TabBarFloating import):

```typescript
import TabBarCompact from '@/components/tabbar/TabBarCompact.vue'
```

Append this test block at the end of the file:

```typescript
describe('TabBarCompact 组件', () => {
  it('应渲染容器', () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'home' } })
    expect(wrapper.find('.tab-bar-compact').exists()).toBe(true)
  })

  it('应渲染 3 个 Tab（无快门突出）', () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'home' } })
    expect(wrapper.findAll('.compact-tab')).toHaveLength(3)
  })

  it('点击首页 Tab 应触发 on-switch: home', async () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'profile' } })
    await wrapper.findAll('.compact-tab')[0].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['home'])
  })

  it('点击拍摄 Tab 应触发 on-switch: capture', async () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'home' } })
    await wrapper.findAll('.compact-tab')[1].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['capture'])
  })

  it('点击我的 Tab 应触发 on-switch: profile', async () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'home' } })
    await wrapper.findAll('.compact-tab')[2].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['profile'])
  })

  it('点击当前已选中 Tab 不应触发 on-switch', async () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'home' } })
    await wrapper.findAll('.compact-tab')[0].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeFalsy()
  })

  it('点击拍摄 Tab 即使已选中也应触发', async () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'capture' } })
    await wrapper.findAll('.compact-tab')[1].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeTruthy()
  })

  it('默认 theme 应为 light', () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'home' } })
    expect(wrapper.props('theme')).toBe('light')
  })

  it('当前 Tab 应有 active 类', () => {
    const wrapper = mount(TabBarCompact, { props: { current: 'capture' } })
    const tabs = wrapper.findAll('.compact-tab')
    expect(tabs[0].classes()).not.toContain('active')
    expect(tabs[1].classes()).toContain('active')
    expect(tabs[2].classes()).not.toContain('active')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx vitest run tests/tabBarVariants.test.ts
```
Expected: FAIL with error `Failed to resolve import "@/components/tabbar/TabBarCompact.vue"`.

- [ ] **Step 3: Write the implementation**

Create `lumira-app/src/components/tabbar/TabBarCompact.vue`:

```vue
<script setup lang="ts">
/**
 * 紧凑横条 TabBar（retro 主题）
 * 无悬浮、无快门突出、方正扁平设计
 * 与 TabBarFloating 共享相同的 props/emits 契约
 */
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface TabBarCompactProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<TabBarCompactProps>(), {
  theme: 'light',
})

const emit = defineEmits<{
  (e: 'on-switch', key: string): void
}>()

const tabs: TabItem[] = [
  { key: 'home', label: '首页', iconChar: '⌂' },
  { key: 'capture', label: '拍摄', iconChar: '◉', center: true },
  { key: 'profile', label: '我的', iconChar: '◍' },
]

const handleSwitch = (key: string) => {
  const tab = tabs.find((t) => t.key === key)
  if (key === props.current && !tab?.center) return
  emit('on-switch', key)
}
</script>

<template>
  <view class="tab-bar-compact" :class="`theme-${theme}`">
    <view
      v-for="tab in tabs"
      :key="tab.key"
      class="compact-tab"
      :class="{ active: current === tab.key, 'is-center': tab.center }"
      @click="handleSwitch(tab.key)"
    >
      <view class="compact-icon-wrap">
        <text class="compact-icon">{{ tab.iconChar }}</text>
      </view>
      <text class="compact-label">{{ tab.label }}</text>
      <view v-if="current === tab.key" class="compact-indicator" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.tab-bar-compact {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  bottom: env(safe-area-inset-bottom);
  z-index: 900;
  display: flex;
  height: calc(var(--tabbar-height) + env(safe-area-inset-bottom));
  padding-bottom: env(safe-area-inset-bottom);

  .theme-light & {
    background: var(--color-bg-card);
    border-top: 1px solid var(--color-border);
  }

  .theme-dark & {
    background: var(--color-bg-card-dark);
    border-top: 1px solid rgba(255, 255, 255, 0.08);
  }
}

.compact-tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  padding: var(--space-1) 0;
  position: relative;

  .theme-light & {
    color: var(--color-text-tertiary);
  }

  .theme-dark & {
    color: rgba(255, 255, 255, 0.4);
  }

  &.active {
    color: var(--color-brand-primary);
  }

  &:active {
    opacity: 0.7;
  }
}

.compact-icon-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
}

.compact-icon {
  font-size: 20px;
  line-height: 1;
}

.compact-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  line-height: 1;
}

.compact-indicator {
  position: absolute;
  bottom: var(--space-1);
  width: 20px;
  height: 2px;
  border-radius: 1px;
  background: var(--color-brand-primary);
}

.is-center {
  .compact-icon-wrap {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 1.5px solid var(--color-brand-primary);
  }

  .compact-icon {
    font-size: 18px;
    color: var(--color-brand-primary);
  }
}
</style>
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx vitest run tests/tabBarVariants.test.ts
```
Expected: PASS — all TabBarFloating + TabBarCompact tests green.

- [ ] **Step 5: Commit**

```bash
git add lumira-app/src/components/tabbar/TabBarCompact.vue lumira-app/tests/tabBarVariants.test.ts
git commit -m "feat(tabbar): add TabBarCompact component for retro theme"
```

---

### Task 7: TabBarMinimal Component (fresh)

**Files:**
- Create: `lumira-app/src/components/tabbar/TabBarMinimal.vue`
- Test: `lumira-app/tests/tabBarVariants.test.ts` (append Minimal tests)

**Interfaces:**
- Consumes: nothing (self-contained)
- Produces: `TabBarMinimal` Vue component with same props/emits contract — consumed by Task 4 (composable), Task 10, Task 11, Task 12

- [ ] **Step 1: Append Minimal tests to `tabBarVariants.test.ts`**

Open `lumira-app/tests/tabBarVariants.test.ts`. Add the following import at the top (after the TabBarCompact import):

```typescript
import TabBarMinimal from '@/components/tabbar/TabBarMinimal.vue'
```

Append this test block at the end of the file:

```typescript
describe('TabBarMinimal 组件', () => {
  it('应渲染容器', () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    expect(wrapper.find('.tab-bar-minimal').exists()).toBe(true)
  })

  it('应渲染 3 个 Tab', () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    expect(wrapper.findAll('.minimal-tab')).toHaveLength(3)
  })

  it('点击首页 Tab 应触发 on-switch: home', async () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'profile' } })
    await wrapper.findAll('.minimal-tab')[0].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['home'])
  })

  it('点击拍摄 Tab 应触发 on-switch: capture', async () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    await wrapper.findAll('.minimal-tab')[1].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['capture'])
  })

  it('点击我的 Tab 应触发 on-switch: profile', async () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    await wrapper.findAll('.minimal-tab')[2].trigger('click')
    expect(wrapper.emitted('on-switch')![0]).toEqual(['profile'])
  })

  it('点击当前已选中 Tab 不应触发 on-switch', async () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    await wrapper.findAll('.minimal-tab')[0].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeFalsy()
  })

  it('点击拍摄 Tab 即使已选中也应触发', async () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'capture' } })
    await wrapper.findAll('.minimal-tab')[1].trigger('click')
    expect(wrapper.emitted('on-switch')).toBeTruthy()
  })

  it('默认 theme 应为 light', () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    expect(wrapper.props('theme')).toBe('light')
  })

  it('当前 Tab 应有 active 类和下划线', () => {
    const wrapper = mount(TabBarMinimal, { props: { current: 'home' } })
    const tabs = wrapper.findAll('.minimal-tab')
    expect(tabs[0].classes()).toContain('active')
    expect(tabs[0].find('.minimal-underline').exists()).toBe(true)
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
npx vitest run tests/tabBarVariants.test.ts
```
Expected: FAIL with error `Failed to resolve import "@/components/tabbar/TabBarMinimal.vue"`.

- [ ] **Step 3: Write the implementation**

Create `lumira-app/src/components/tabbar/TabBarMinimal.vue`:

```vue
<script setup lang="ts">
/**
 * 极简线条 TabBar（fresh 主题）
 * 仅图标 + 细线下划线指示器，无快门突出
 * 与 TabBarFloating 共享相同的 props/emits 契约
 */
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface TabBarMinimalProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<TabBarMinimalProps>(), {
  theme: 'light',
})

const emit = defineEmits<{
  (e: 'on-switch', key: string): void
}>()

const tabs: TabItem[] = [
  { key: 'home', label: '首页', iconChar: '⌂' },
  { key: 'capture', label: '拍摄', iconChar: '◉', center: true },
  { key: 'profile', label: '我的', iconChar: '◍' },
]

const handleSwitch = (key: string) => {
  const tab = tabs.find((t) => t.key === key)
  if (key === props.current && !tab?.center) return
  emit('on-switch', key)
}
</script>

<template>
  <view class="tab-bar-minimal" :class="`theme-${theme}`">
    <view class="minimal-inner">
      <view
        v-for="tab in tabs"
        :key="tab.key"
        class="minimal-tab"
        :class="{ active: current === tab.key, 'is-center': tab.center }"
        @click="handleSwitch(tab.key)"
      >
        <text class="minimal-icon">{{ tab.iconChar }}</text>
        <view v-if="current === tab.key" class="minimal-underline" />
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.tab-bar-minimal {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  bottom: calc(var(--tabbar-bottom-offset) + env(safe-area-inset-bottom));
  z-index: 900;
}

.minimal-inner {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: var(--space-7);
  height: var(--tabbar-height);
  padding: 0 var(--space-5);

  .theme-light & {
    background: transparent;
  }

  .theme-dark & {
    background: transparent;
  }
}

.minimal-tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  width: 44px;
  height: 44px;
  position: relative;

  .theme-light & {
    color: var(--color-text-tertiary);
  }

  .theme-dark & {
    color: rgba(255, 255, 255, 0.4);
  }

  &.active {
    color: var(--color-brand-primary);
  }

  &:active {
    opacity: 0.6;
  }
}

.minimal-icon {
  font-size: 22px;
  line-height: 1;
}

.minimal-underline {
  position: absolute;
  bottom: 2px;
  width: 16px;
  height: 1.5px;
  border-radius: 1px;
  background: var(--color-brand-primary);
}

.is-center {
  .minimal-icon {
    font-size: 26px;
  }
}
</style>
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
npx vitest run tests/tabBarVariants.test.ts
```
Expected: PASS — all TabBarFloating + TabBarCompact + TabBarMinimal tests green.

- [ ] **Step 5: Run type-check to verify all TabBar components and composable type-check**

Run:
```bash
npm run type-check
```
Expected: No errors. (This also resolves the Task 4 type-check gap — `useThemeComponent.ts` can now resolve all 3 component imports.)

- [ ] **Step 6: Run full test suite**

Run:
```bash
npm test
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add lumira-app/src/components/tabbar/TabBarMinimal.vue lumira-app/tests/tabBarVariants.test.ts
git commit -m "feat(tabbar): add TabBarMinimal component for fresh theme"
```

---

## Phase 2: Theme Switching UI

### Task 8: Theme Selection Page

**Files:**
- Create: `lumira-app/src/pages/settings/theme.vue`
- Modify: `lumira-app/src/pages.json` (register route)

**Interfaces:**
- Consumes: `useThemeStore` from Task 2; `ThemeId` from Task 1
- Produces: `/pages/settings/theme` route — consumed by Task 9 (settings page navigation)

- [ ] **Step 1: Register the route in `pages.json`**

Open `lumira-app/src/pages.json`. Find the `pages` array. Add the new route after the `pages/profile/settings` entry. The current end of the pages array:

```json
    { "path": "pages/profile/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/profile/settings", "style": { "navigationStyle": "custom" } }
  ],
```

Replace with:

```json
    { "path": "pages/profile/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/profile/settings", "style": { "navigationStyle": "custom" } },
    { "path": "pages/settings/theme", "style": { "navigationStyle": "custom" } }
  ],
```

- [ ] **Step 2: Write the theme selection page**

Create `lumira-app/src/pages/settings/theme.vue`:

```vue
<script setup lang="ts">
/**
 * 主题选择页
 * 4 张主题预览卡（2×2 网格）+ 跟随系统开关
 */
import { computed } from 'vue'
import { useThemeStore } from '@/stores/theme'
import type { ThemeId } from '@/theme/theme-configs'

interface ThemePreview {
  id: ThemeId
  label: string
  description: string
  layoutDesc: string
  tabBarStyle: 'floating' | 'compact' | 'minimal'
  colors: {
    bgCanvas: string
    bgCard: string
    brandPrimary: string
    textPrimary: string
    textSecondary: string
    textTertiary: string
  }
}

const themeStore = useThemeStore()

const themePreviews: ThemePreview[] = [
  {
    id: 'warm',
    label: '暖米白',
    description: '温暖留白，编辑式质感',
    layoutDesc: '悬浮 TabBar · 2 列网格',
    tabBarStyle: 'floating',
    colors: {
      bgCanvas: '#FAF7F2',
      bgCard: '#FFFFFF',
      brandPrimary: '#C9A96E',
      textPrimary: '#1A1A1A',
      textSecondary: '#5C5852',
      textTertiary: '#9C9690',
    },
  },
  {
    id: 'ink',
    label: '浓墨',
    description: '深色沉浸，夜拍伴侣',
    layoutDesc: '悬浮 TabBar · 2 列网格',
    tabBarStyle: 'floating',
    colors: {
      bgCanvas: '#1C1A17',
      bgCard: '#262320',
      brandPrimary: '#D4B57A',
      textPrimary: '#F2EEE6',
      textSecondary: '#9C9690',
      textTertiary: '#6B6660',
    },
  },
  {
    id: 'retro',
    label: '胶片复古',
    description: '暖橘深棕，胶片方格',
    layoutDesc: '紧凑 TabBar · 方形构图',
    tabBarStyle: 'compact',
    colors: {
      bgCanvas: '#F5E6D3',
      bgCard: '#FAF0E0',
      brandPrimary: '#D4865C',
      textPrimary: '#3D2817',
      textSecondary: '#6B4C2F',
      textTertiary: '#9C8060',
    },
  },
  {
    id: 'fresh',
    label: '日系清新',
    description: '淡粉米白，杂志呼吸',
    layoutDesc: '极简 TabBar · 单列大卡',
    tabBarStyle: 'minimal',
    colors: {
      bgCanvas: '#FAF7F2',
      bgCard: '#FFFFFF',
      brandPrimary: '#E8B4A0',
      textPrimary: '#4A3F35',
      textSecondary: '#8C7F70',
      textTertiary: '#B8AEA0',
    },
  },
]

const currentTheme = computed(() => themeStore.currentTheme)
const followSystem = computed(() => themeStore.followSystem)

const isStylizedTheme = (id: ThemeId): boolean => id === 'retro' || id === 'fresh'

const selectTheme = async (id: ThemeId) => {
  // 选择 retro/fresh 时，若跟随系统已开启则关闭
  if (isStylizedTheme(id) && themeStore.followSystem) {
    await themeStore.setFollowSystem(false)
  }
  await themeStore.setTheme(id)
}

const toggleFollowSystem = async (enabled: boolean) => {
  if (enabled) {
    // 开启跟随系统时，若当前为 retro/fresh 则切换到 warm/ink
    const current = themeStore.currentTheme
    if (isStylizedTheme(current)) {
      // #ifdef H5
      const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      await themeStore.setTheme(isDark ? 'ink' : 'warm')
      // #endif
      // #ifndef H5
      await themeStore.setTheme('warm')
      // #endif
    }
  }
  await themeStore.setFollowSystem(enabled)
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="theme-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">主题选择</text>
    </view>

    <view class="theme-grid">
      <view
        v-for="preview in themePreviews"
        :key="preview.id"
        class="preview-card"
        :class="{ active: preview.id === currentTheme }"
        :style="{ background: preview.colors.bgCanvas }"
        @click="selectTheme(preview.id)"
      >
        <view class="card-top-bar" :style="{ background: preview.colors.brandPrimary }" />

        <view class="card-body" :style="{ background: preview.colors.bgCard }">
          <text class="card-label" :style="{ color: preview.colors.textPrimary }">
            {{ preview.label }}
          </text>
          <text class="card-desc" :style="{ color: preview.colors.textSecondary }">
            {{ preview.description }}
          </text>
          <text class="card-desc" :style="{ color: preview.colors.textTertiary }">
            {{ preview.layoutDesc }}
          </text>
        </view>

        <view class="card-tabbar-preview">
          <view class="mini-tabbar" :class="`style-${preview.tabBarStyle}`">
            <view class="mini-tab-icon" :style="{ background: preview.colors.textTertiary }" />
            <view
              class="mini-shutter"
              :style="{
                background: preview.colors.brandPrimary,
                borderColor: preview.colors.bgCard,
              }"
            />
            <view class="mini-tab-icon" :style="{ background: preview.colors.textTertiary }" />
          </view>
        </view>

        <view v-if="preview.id === currentTheme" class="check-mark">
          <text class="check-icon">✓</text>
        </view>
      </view>
    </view>

    <view class="follow-system-section">
      <view class="setting-row">
        <view class="setting-text">
          <text class="setting-label">跟随系统</text>
          <text class="setting-hint">仅浅色/深色自动切换</text>
        </view>
        <switch
          :checked="followSystem"
          color="var(--color-brand-primary)"
          @change="toggleFollowSystem($event.detail.value)"
        />
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.theme-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
}

.page-nav {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;

  &:active {
    opacity: 0.6;
  }
}

.nav-icon {
  font-size: 22px;
  color: var(--color-text-primary);
}

.nav-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.theme-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-4);
  padding: var(--space-3) var(--space-5);
}

.preview-card {
  position: relative;
  border-radius: var(--radius-card);
  overflow: hidden;
  border: 2px solid transparent;
  transition: border-color var(--duration-normal) var(--ease-default);

  &.active {
    border-color: var(--color-brand-primary);
  }

  &:active {
    opacity: 0.9;
  }
}

.card-top-bar {
  height: 4px;
  width: 100%;
}

.card-body {
  padding: var(--space-3);
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.card-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-semibold);
  line-height: 1.2;
}

.card-desc {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  line-height: 1.3;
}

.card-tabbar-preview {
  padding: var(--space-2) var(--space-3) var(--space-3);
}

.mini-tabbar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  height: 24px;

  &.style-floating {
    background: rgba(255, 255, 255, 0.5);
    border-radius: var(--radius-pill);
    padding: 0 var(--space-2);
  }

  &.style-compact {
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    padding-top: var(--space-1);
  }

  &.style-minimal {
    background: transparent;
  }
}

.mini-tab-icon {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  opacity: 0.5;
}

.mini-shutter {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 1.5px solid transparent;
}

.style-floating {
  .mini-shutter {
    margin-top: -4px;
  }
}

.style-compact {
  .mini-shutter {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    border-width: 1px;
  }
}

.style-minimal {
  .mini-shutter {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: transparent !important;
    border-width: 1px;
  }
}

.check-mark {
  position: absolute;
  top: var(--space-2);
  right: var(--space-2);
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: var(--color-brand-primary);
  display: flex;
  align-items: center;
  justify-content: center;
}

.check-icon {
  font-size: 14px;
  color: #FFFFFF;
  font-weight: bold;
  line-height: 1;
}

.follow-system-section {
  padding: var(--space-5) var(--space-5) 0;
  margin-top: var(--space-3);
  border-top: 1px solid var(--color-border);
}

.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) 0;
}

.setting-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.setting-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.setting-hint {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}
</style>
```

- [ ] **Step 3: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 4: Run build to verify page compiles**

Run:
```bash
npm run build:h5
```
Expected: Build succeeds.

- [ ] **Step 5: Run full test suite to verify no regressions**

Run:
```bash
npm test
```
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add lumira-app/src/pages/settings/theme.vue lumira-app/src/pages.json
git commit -m "feat(theme): add theme selection page with 2x2 preview grid"
```

---

### Task 9: Add Theme Entry in Settings Page

**Files:**
- Modify: `lumira-app/src/pages/profile/settings.vue`

**Interfaces:**
- Consumes: `/pages/settings/theme` route from Task 8
- Produces: "主题" navigation row in settings page

- [ ] **Step 1: Add theme navigation row**

Open `lumira-app/src/pages/profile/settings.vue`. Find the script section and add a navigation handler after `clearCache`:

The current script ends with:

```typescript
const clearCache = () => {
  uni.showModal({
    title: '清除缓存',
    content: '确定清除所有缓存数据？',
    success: (res) => {
      if (res.confirm) {
        uni.showToast({ title: '已清除', icon: 'success' })
      }
    },
  })
}
</script>
```

Replace with:

```typescript
const clearCache = () => {
  uni.showModal({
    title: '清除缓存',
    content: '确定清除所有缓存数据？',
    success: (res) => {
      if (res.confirm) {
        uni.showToast({ title: '已清除', icon: 'success' })
      }
    },
  })
}

const goTheme = () => {
  uni.navigateTo({ url: '/pages/settings/theme' })
}
</script>
```

- [ ] **Step 2: Add the theme row in the template**

In the same file, find the template's settings list. The current list:

```html
    <view class="settings-list">
      <view class="setting-row">
        <text class="setting-label">取景器网格</text>
        <switch :checked="settingsStore.settings.showGrid" @change="toggleGrid" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row">
        <text class="setting-label">水平仪</text>
        <switch :checked="settingsStore.settings.showLevelIndicator" @change="toggleLevel" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row">
        <text class="setting-label">快门声音</text>
        <switch :checked="settingsStore.settings.shutterSound" @change="toggleSound" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row" @click="clearCache">
        <text class="setting-label">清除缓存</text>
        <text class="setting-arrow">→</text>
      </view>
    </view>
```

Replace with (add theme row as the first item):

```html
    <view class="settings-list">
      <view class="setting-row" @click="goTheme">
        <text class="setting-label">主题</text>
        <text class="setting-arrow">→</text>
      </view>
      <view class="setting-row">
        <text class="setting-label">取景器网格</text>
        <switch :checked="settingsStore.settings.showGrid" @change="toggleGrid" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row">
        <text class="setting-label">水平仪</text>
        <switch :checked="settingsStore.settings.showLevelIndicator" @change="toggleLevel" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row">
        <text class="setting-label">快门声音</text>
        <switch :checked="settingsStore.settings.shutterSound" @change="toggleSound" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row" @click="clearCache">
        <text class="setting-label">清除缓存</text>
        <text class="setting-arrow">→</text>
      </view>
    </view>
```

- [ ] **Step 3: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 4: Run full test suite**

Run:
```bash
npm test
```
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lumira-app/src/pages/profile/settings.vue
git commit -m "feat(settings): add theme entry row navigating to theme selection"
```

---

## Phase 3: Page Adaptation

### Task 10: Home Page Adaptation

**Files:**
- Modify: `lumira-app/src/pages/home/index.vue`

**Interfaces:**
- Consumes: `useThemeStore` from Task 2; `useTabBarVariant` from Task 4
- Produces: Home page with parameterized section order and dynamic TabBar

- [ ] **Step 1: Rewrite the home page script**

Open `lumira-app/src/pages/home/index.vue`. Replace the entire `<script setup lang="ts">` block with:

```typescript
<script setup lang="ts">
import { computed } from 'vue'
import type { Component } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useThemeStore } from '@/stores/theme'
import { useTabBarVariant } from '@/composables/useThemeComponent'
import BrandHeader from '@/components/home/BrandHeader.vue'
import DailyInspiration from '@/components/home/DailyInspiration.vue'
import RecentPhotos from '@/components/home/RecentPhotos.vue'
import FeaturedTemplates from '@/components/home/FeaturedTemplates.vue'
import SceneQuickAccess from '@/components/home/SceneQuickAccess.vue'
import StatsSummary from '@/components/home/StatsSummary.vue'
import { useTemplatesStore } from '@/stores/templates'
import { useGalleryStore } from '@/stores/gallery'
import { useDailyInspiration } from '@/composables/useDailyInspiration'
import { useSceneGuide } from '@/composables/useSceneGuide'

const templatesStore = useTemplatesStore()
const galleryStore = useGalleryStore()
const themeStore = useThemeStore()
const { inspiration } = useDailyInspiration()
const { scenes } = useSceneGuide()

const recentPhotos = computed(() => galleryStore.photos.slice(0, 6))
const featuredTemplates = computed(() => templatesStore.allTemplates.slice(0, 6))
const photoCount = computed(() => galleryStore.photoCount)
const templateCount = computed(() => templatesStore.templateCount)

const tabBarVariant = useTabBarVariant()

const sectionMap: Record<string, Component> = {
  brand: BrandHeader,
  inspiration: DailyInspiration,
  recent: RecentPhotos,
  featured: FeaturedTemplates,
  scene: SceneQuickAccess,
  stats: StatsSummary,
}

const sectionProps = computed<Record<string, Record<string, unknown>>>(() => ({
  brand: {},
  inspiration: { inspiration: inspiration.value },
  recent: { photos: recentPhotos.value, totalCount: photoCount.value },
  featured: { templates: featuredTemplates.value },
  scene: { scenes },
  stats: { photoCount: photoCount.value, templateCount: templateCount.value },
}))

onShow(() => {
  templatesStore.loadTemplates()
  galleryStore.loadPhotos()
})

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}

const handleInspirationTry = (category: string) => {
  uni.navigateTo({ url: `/pages/capture/index?category=${encodeURIComponent(category)}` })
}

const handlePhotoClick = (id: string) => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}

const handleViewAllPhotos = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const handleTemplateClick = (id: string) => {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}

const handleViewAllTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const handleSceneClick = (sceneKey: string) => {
  const scene = scenes.find((s) => s.key === sceneKey)
  if (scene) {
    uni.navigateTo({ url: `/pages/templates/index?category=${encodeURIComponent(scene.category)}` })
  }
}

const handleStatsClick = () => {
  uni.redirectTo({ url: '/pages/profile/index' })
}
</script>
```

- [ ] **Step 2: Rewrite the home page template**

In the same file, replace the `<template>` block with:

```html
<template>
  <view class="home-page">
    <scroll-view scroll-y class="home-scroll" :show-scrollbar="false">
      <component
        v-for="sectionId in themeStore.layout.homeSectionOrder"
        :key="sectionId"
        :is="sectionMap[sectionId]"
        v-bind="sectionProps[sectionId]"
        @on-try="handleInspirationTry"
        @on-photo-click="handlePhotoClick"
        @on-view-all="handleViewAllPhotos"
        @on-template-click="handleTemplateClick"
        @on-view-all-templates="handleViewAllTemplates"
        @on-scene-click="handleSceneClick"
        @on-click="handleStatsClick"
      />
      <view class="bottom-spacer" />
    </scroll-view>
    <component :is="tabBarVariant" current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>
```

- [ ] **Step 3: Verify the style block is unchanged**

The `<style lang="scss" scoped>` block should remain as-is (it already uses `var(--color-bg-canvas)`). No changes needed.

- [ ] **Step 4: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 5: Run full test suite**

Run:
```bash
npm test
```
Expected: All tests pass.

- [ ] **Step 6: Run build to verify page compiles**

Run:
```bash
npm run build:h5
```
Expected: Build succeeds.

- [ ] **Step 7: Commit**

```bash
git add lumira-app/src/pages/home/index.vue
git commit -m "feat(home): parameterize section order and use dynamic TabBar variant"
```

---

### Task 11: Templates & Gallery Page Adaptation

**Files:**
- Modify: `lumira-app/src/pages/templates/index.vue`
- Modify: `lumira-app/src/pages/gallery/index.vue`

**Interfaces:**
- Consumes: `useThemeStore` from Task 2; `useTabBarVariant` from Task 4
- Produces: Templates page with CSS Variable-driven grid; Gallery page with theme-driven columns

- [ ] **Step 1: Modify templates page script**

Open `lumira-app/src/pages/templates/index.vue`. Replace the `<script setup lang="ts">` block with:

```typescript
<script setup lang="ts">
import { computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import CategoryTabs from '@/components/template/CategoryTabs.vue'
import { useTabBarVariant } from '@/composables/useThemeComponent'
import AppEmpty from '@/components/AppEmpty.vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()

const categories = computed(() => templatesStore.categories)
const currentCategory = computed(() => templatesStore.currentCategory)
const filteredTemplates = computed(() => templatesStore.filteredTemplates)

const tabBarVariant = useTabBarVariant()

let urlCategory = ''

onLoad((query) => {
  if (query?.category) {
    urlCategory = decodeURIComponent(query.category)
    templatesStore.setCategory(urlCategory)
  }
})

onShow(() => {
  templatesStore.loadTemplates()
})

const handleCategoryChange = (category: string) => {
  templatesStore.setCategory(category)
}

const goDetail = (id: string) => {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}

const goImport = () => {
  uni.navigateTo({ url: '/pages/templates/import' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
</script>
```

- [ ] **Step 2: Modify templates page template**

In the same file, replace the `<FloatingTabBar>` usage in the template. Find:

```html
    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
```

Replace with:

```html
    <component :is="tabBarVariant" current="home" theme="light" @on-switch="handleTabSwitch" />
```

- [ ] **Step 3: Modify templates page SCSS for CSS Variable grid**

In the same file, find the `.templates-grid` and `.card-cover` styles:

```scss
.templates-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-4);
  padding: 0 var(--space-5);
}
```

Replace `grid-template-columns: repeat(2, 1fr)` with `grid-template-columns: repeat(var(--layout-grid-columns, 2), 1fr)`:

```scss
.templates-grid {
  display: grid;
  grid-template-columns: repeat(var(--layout-grid-columns, 2), 1fr);
  gap: var(--space-4);
  padding: 0 var(--space-5);
}
```

Then find the `.card-cover` style:

```scss
.card-cover {
  width: 100%;
  aspect-ratio: 3 / 4;
  background: var(--color-bg-surface);
  overflow: hidden;
}
```

Replace `aspect-ratio: 3 / 4` with `aspect-ratio: var(--layout-card-aspect, 3 / 4)`:

```scss
.card-cover {
  width: 100%;
  aspect-ratio: var(--layout-card-aspect, 3 / 4);
  background: var(--color-bg-surface);
  overflow: hidden;
}
```

- [ ] **Step 4: Modify gallery page script**

Open `lumira-app/src/pages/gallery/index.vue`. Replace the `<script setup lang="ts">` block with:

```typescript
<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useThemeStore } from '@/stores/theme'
import { useTabBarVariant } from '@/composables/useThemeComponent'
import PhotoGrid from '@/components/gallery/PhotoGrid.vue'
import AppEmpty from '@/components/AppEmpty.vue'
import { useGalleryStore } from '@/stores/gallery'

const galleryStore = useGalleryStore()
const themeStore = useThemeStore()
const photos = computed(() => galleryStore.photos)

const galleryColumns = computed(() => themeStore.layout.galleryGridColumns)
const tabBarVariant = useTabBarVariant()

onShow(() => {
  galleryStore.loadPhotos()
})

const handlePhotoClick = (id: string) => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}

const handlePhotoLongpress = (id: string) => {
  uni.showActionSheet({
    itemList: ['删除'],
    success: (res) => {
      if (res.tapIndex === 0) {
        uni.showModal({
          title: '确认删除',
          content: '删除后无法恢复',
          success: (modalRes) => {
            if (modalRes.confirm) {
              galleryStore.deletePhoto(id)
            }
          },
        })
      }
    },
  })
}

const goToCapture = () => {
  uni.navigateTo({ url: '/pages/capture/index' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
</script>
```

- [ ] **Step 5: Modify gallery page template**

In the same file, replace the `<PhotoGrid>` and `<FloatingTabBar>` usage. Find:

```html
      <PhotoGrid
        v-if="photos.length > 0"
        :photos="photos"
        :columns="3"
        @on-photo-click="handlePhotoClick"
        @on-photo-longpress="handlePhotoLongpress"
      />
```

Replace `:columns="3"` with `:columns="galleryColumns"`:

```html
      <PhotoGrid
        v-if="photos.length > 0"
        :photos="photos"
        :columns="galleryColumns"
        @on-photo-click="handlePhotoClick"
        @on-photo-longpress="handlePhotoLongpress"
      />
```

Then find:

```html
    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
```

Replace with:

```html
    <component :is="tabBarVariant" current="home" theme="light" @on-switch="handleTabSwitch" />
```

- [ ] **Step 6: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 7: Run full test suite**

Run:
```bash
npm test
```
Expected: All tests pass.

- [ ] **Step 8: Run build**

Run:
```bash
npm run build:h5
```
Expected: Build succeeds.

- [ ] **Step 9: Commit**

```bash
git add lumira-app/src/pages/templates/index.vue lumira-app/src/pages/gallery/index.vue
git commit -m "feat(pages): parameterize grid columns and use dynamic TabBar in templates/gallery"
```

---

### Task 12: Capture & Profile Page TabBar Adaptation

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`
- Modify: `lumira-app/src/pages/profile/index.vue`

> **Note:** The task description mentions `src/pages/editor/index.vue`, but this file does not exist in the v1 codebase. Only `capture/index.vue` and `profile/index.vue` are modified here.

**Interfaces:**
- Consumes: `useTabBarVariant` from Task 4
- Produces: Capture and profile pages with dynamic TabBar

- [ ] **Step 1: Modify capture page script — replace FloatingTabBar import**

Open `lumira-app/src/pages/capture/index.vue`. Find the import line:

```typescript
import FloatingTabBar from '@/components/FloatingTabBar.vue'
```

Replace with:

```typescript
import { useTabBarVariant } from '@/composables/useThemeComponent'
```

Then add the composable call. Find the line after `const captureStore = useCaptureStore()`:

```typescript
const captureStore = useCaptureStore()
```

Add after it:

```typescript
const tabBarVariant = useTabBarVariant()
```

- [ ] **Step 2: Modify capture page template**

In the same file, find the `<FloatingTabBar>` usage (around line 103):

```html
    <FloatingTabBar current="capture" theme="dark" @on-switch="handleTabSwitch" />
```

Replace with:

```html
    <component :is="tabBarVariant" current="capture" theme="dark" @on-switch="handleTabSwitch" />
```

- [ ] **Step 3: Modify profile page script — replace FloatingTabBar import**

Open `lumira-app/src/pages/profile/index.vue`. Find the import line:

```typescript
import FloatingTabBar from '@/components/FloatingTabBar.vue'
```

Replace with:

```typescript
import { useTabBarVariant } from '@/composables/useThemeComponent'
```

Then find the line after the store setup:

```typescript
const templatesStore = useTemplatesStore()
```

Add after it:

```typescript
const tabBarVariant = useTabBarVariant()
```

- [ ] **Step 4: Modify profile page template**

In the same file, find the `<FloatingTabBar>` usage (around line 70):

```html
    <FloatingTabBar current="profile" theme="light" @on-switch="handleTabSwitch" />
```

Replace with:

```html
    <component :is="tabBarVariant" current="profile" theme="light" @on-switch="handleTabSwitch" />
```

- [ ] **Step 5: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 6: Run full test suite**

Run:
```bash
npm test
```
Expected: All tests pass.

- [ ] **Step 7: Run build**

Run:
```bash
npm run build:h5
```
Expected: Build succeeds.

- [ ] **Step 8: Commit**

```bash
git add lumira-app/src/pages/capture/index.vue lumira-app/src/pages/profile/index.vue
git commit -m "feat(pages): replace FloatingTabBar with dynamic variant in capture/profile"
```

---

## Phase 4: Integration

### Task 13: App.vue Initialization & Final Verification

**Files:**
- Modify: `lumira-app/src/App.vue`

**Interfaces:**
- Consumes: `useThemeStore` from Task 2
- Produces: Theme loaded on app launch; full system verified

- [ ] **Step 1: Add theme store import and loadTheme call in App.vue**

Open `lumira-app/src/App.vue`. Replace the entire `<script setup lang="ts">` block with:

```typescript
<script setup lang="ts">
import { onLaunch, onShow, onHide } from '@dcloudio/uni-app'
import { storageService } from '@/services/storage'
import { useThemeStore } from '@/stores/theme'

onLaunch(async () => {
  console.log('如画 Lumira 启动')
  await storageService.init()
  const themeStore = useThemeStore()
  await themeStore.loadTheme()
})

onShow(() => {
  console.log('如画 Lumira 显示')
})

onHide(() => {
  console.log('如画 Lumira 后台')
})
</script>
```

- [ ] **Step 2: Verify the style block already has theme imports**

Confirm the `<style lang="scss">` block already imports all 4 theme files (from Task 3 Step 5). It should look like:

```scss
@import '@/theme/tokens.scss';
@import '@/theme/theme-ink.scss';
@import '@/theme/theme-retro.scss';
@import '@/theme/theme-fresh.scss';
```

If not, add the missing imports.

- [ ] **Step 3: Run type-check**

Run:
```bash
npm run type-check
```
Expected: No errors.

- [ ] **Step 4: Run full test suite**

Run:
```bash
npm test
```
Expected: All tests pass. Expected count: baseline 131 + themeConfigs (~25) + themeStore (~25) + useThemeComponent (5) + tabBarVariants (~27) = approximately 213 tests. (Exact count depends on baseline; all must pass.)

- [ ] **Step 5: Run production build**

Run:
```bash
npm run build:h5
```
Expected: Build succeeds with no errors or warnings related to theme system.

- [ ] **Step 6: Verify no remaining direct FloatingTabBar imports in pages**

Run:
```bash
npx vitest run
```
Then manually verify: search for `FloatingTabBar` in `lumira-app/src/pages/` — should only appear in the legacy `lumira-app/src/components/FloatingTabBar.vue` file (kept for backward compatibility with existing tests), not in any page.

- [ ] **Step 7: Commit**

```bash
git add lumira-app/src/App.vue
git commit -m "feat(app): initialize theme on launch via themeStore.loadTheme()"
```

---

## Self-Review

<!-- The human reviewer will complete this section. Leave empty. -->

---
