# 如画 Lumira v2.0 主题系统设计文档

> 文档版本：v1.0
> 创建日期：2026-07-08
> 文档类型：v2.0 P0 子项目 1 设计规格
> 基础产品：如画 Lumira v1.0（已合并到 master）
> 配套文档：`2026-07-06-lumira-v2-features-design.md` · `2026-07-06-lumira-v2-business-optimization.md`

---

## 0. 概述

### 0.1 目标

为如画 APP 构建多主题切换系统，支持 4 套内置主题，主题间不仅有颜色/字体/形状的视觉层变化，还包含组件变体和布局参数化（首页区块顺序、网格列数、卡片宽高比、TabBar 样式）。

### 0.2 设计原则

| 原则 | 说明 |
|---|---|
| **v1 零破坏** | v1 所有组件已用 `var(--xxx)` 消费 token，主题切换时零改动自动响应 |
| **CSS Variables 驱动** | 通过 `data-theme` 属性切换 CSS Variables，性能最优 |
| **布局参数化** | 布局差异通过配置驱动（非硬编码），组件动态加载 |
| **组件变体最小化** | 仅 TabBar 之类标志性组件做独立变体，其余通过 CSS Variable 适配 |
| **女性向风格** | 4 套主题中的 retro/fresh 专为女性用户设计 |

### 0.3 在 v2 中的位置

本子项目是 v2.0 P0 体验增强层的第 1 个子项目。主题系统因涉及布局参数化，必须先于其他 P0 模块（收藏/标签/手势/精选集）实施，避免后续返工。

---

## 1. 主题 Schema 架构

### 1.1 主题配置层级

```
ThemeConfig
├── colors            颜色层（bg/text/brand/semantic/tag/capture ~26 token）
├── typography        字体层（font-family/size/weight/line-height ~15 token）
├── shape             形状层（radius/shadow ~6 token）
├── motion            动效层（duration/easing ~6 token，各主题共享）
├── iconStyle         图标风格（'line' | 'fill' | 'handdrawn'）
├── layout            布局参数层（新增）
│   ├── homeSectionOrder      首页区块顺序 string[]
│   ├── templateGridColumns   模板库网格列数 number
│   ├── galleryGridColumns    相册网格列数 number
│   ├── cardAspectRatio       卡片宽高比 string
│   └── tabBarStyle           TabBar 样式 'floating' | 'compact' | 'minimal'
└── componentVariant  组件变体标识（'default' | 'default-dark' | 'retro' | 'fresh'）
```

### 1.2 实现方式

#### CSS 层

`tokens.scss` 保留 `:root` 作为暖米白默认主题；新增 3 个主题文件，通过 `[data-theme="xxx"]` 属性选择器覆盖 token：

```scss
// tokens.scss — :root（warm 默认）
:root {
  --color-bg-canvas: #FAF7F2;
  // ... v1 全部 token
}

// theme-ink.scss
[data-theme="ink"] {
  --color-bg-canvas: #1C1A17;
  // ... 覆盖的 token
}

// theme-retro.scss
[data-theme="retro"] {
  --color-bg-canvas: #F5E6D3;
  // ...
}

// theme-fresh.scss
[data-theme="fresh"] {
  --color-bg-canvas: #FAF7F2;
  // ...
}
```

新增布局参数 CSS Variable：

```scss
:root {
  --layout-grid-columns: 2;
  --layout-gallery-columns: 3;
  --layout-card-aspect: 3 / 4;
}
```

#### JS 层

`useThemeStore` 管理当前主题，通过 `document.documentElement.setAttribute('data-theme', themeId)` 切换。布局参数通过 store 的 computed 暴露，组件直接消费。

### 1.3 兼容性

- v1 所有组件已用 `var(--xxx)` 消费 token，**零改动**即可响应颜色/字体/圆角/阴影的主题切换
- 新增的布局参数仅影响需要参数化的页面（首页/模板库/相册/TabBar），其他页面不受影响
- 拍摄页深色 token（`--color-capture-*`）在各主题中保持一致，因为取景器始终为深色沉浸

---

## 2. 四套主题规范

### 2.1 核心颜色对比

| Token | 暖米白 (warm) | 浓墨 (ink) | 胶片复古 (retro) | 日系清新 (fresh) |
|-------|--------------|-----------|-----------------|-----------------|
| `--color-bg-canvas` | #FAF7F2 | #1C1A17 | #F5E6D3 | #FAF7F2 |
| `--color-bg-card` | #FFFFFF | #262320 | #FAF0E0 | #FFFFFF |
| `--color-bg-surface` | #F2EEE6 | #2E2A26 | #EDDFC8 | #F5F0EA |
| `--color-text-primary` | #1A1A1A | #F2EEE6 | #3D2817 | #4A3F35 |
| `--color-text-secondary` | #5C5852 | #9C9690 | #6B4C2F | #8C7F70 |
| `--color-text-tertiary` | #9C9690 | #6B6660 | #9C8060 | #B8AEA0 |
| `--color-brand-primary` | #C9A96E | #D4B57A | #D4865C | #E8B4A0 |
| `--color-brand-secondary` | #A88550 | #BFA060 | #B06440 | #D89888 |
| `--color-danger` | #B85450 | #C8625C | #A04030 | #C87878 |
| `--color-success` | #7A8B5C | #8A9B6C | #6B7B4C | #9AAB7C |
| `--color-border` | #EAE5DC | #3A3530 | #E0D0B8 | #F0E8E0 |
| `--color-tag-gold-bg` | #F5EDDB | #3A3328 | #F0E0C8 | #F8EDE0 |
| `--color-tag-gold-text` | #8C7340 | #D4B57A | #8C5A30 | #A07860 |

### 2.2 字体 / 形状 / 图标

| 维度 | warm | ink | retro | fresh |
|------|------|-----|-------|-------|
| 主字体 `--font-sans` | PingFang SC | PingFang SC | Noto Serif SC（衬线） | PingFang SC（圆体） |
| 标题字体 `--font-serif` | Noto Serif SC | Noto Serif SC | Noto Serif SC | PingFang SC |
| `--radius-button` | 6px | 6px | 4px（方正） | 8px（柔和） |
| `--radius-card` | 12px | 12px | 8px | 16px |
| `--shadow-card` | 0 1px 3px rgba(0,0,0,0.04) | 0 1px 3px rgba(0,0,0,0.3) | 0 2px 6px rgba(60,40,20,0.08) | 0 1px 4px rgba(180,160,140,0.06) |
| 图标风格 `iconStyle` | line | line | handdrawn | line（细线） |
| 组件变体 `componentVariant` | default | default-dark | retro | fresh |

### 2.3 布局参数（UI 变化核心）

| 参数 | warm | ink | retro | fresh |
|------|------|-----|-------|-------|
| 首页区块顺序 | 品牌→灵感→最近→推荐→场景→统计 | 同 warm | 品牌→场景→推荐→灵感→最近→统计 | 品牌→灵感→推荐→场景→最近→统计 |
| 模板库列数 | 2 | 2 | 2 | 1（单列大卡杂志感） |
| 相册列数 | 3 | 3 | 2（胶片方格） | 2（大图呼吸感） |
| 卡片宽高比 | 3:4 | 3:4 | 1:1（方形胶片） | 4:5（竖长柔和） |
| TabBar 样式 | floating（悬浮胶囊） | floating | compact（紧凑横条） | minimal（极简线条） |

### 2.4 设计理念

- **warm（暖米白）**：v1 基线，暖米白+暖金，编辑式留白，平衡通用
- **ink（浓墨）**：深色沉浸，提亮暖金保证对比度，布局不变（仅色温转换），适合夜间/暗光环境
- **retro（胶片复古）**：胶片质感，衬线字体+手绘图标+方形构图+紧凑 TabBar，场景/推荐前置引导探索，暖橘+深棕营造复古胶片氛围
- **fresh（日系清新）**：日系杂志感，单列大卡+大圆角+竖长构图+极简 TabBar，灵感/推荐前置强调阅读感，淡粉+米白营造柔和清新氛围

---

## 3. 运行时机制

### 3.1 useThemeStore

```typescript
// src/stores/theme.ts
type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh'

interface ThemeLayout {
  homeSectionOrder: string[]
  templateGridColumns: number
  galleryGridColumns: number
  cardAspectRatio: string
  tabBarStyle: 'floating' | 'compact' | 'minimal'
}

interface ThemeMeta {
  id: ThemeId
  label: string
  description: string
  iconStyle: 'line' | 'fill' | 'handdrawn'
  componentVariant: 'default' | 'default-dark' | 'retro' | 'fresh'
  layout: ThemeLayout
}

export const useThemeStore = defineStore('theme', () => {
  const currentTheme = ref<ThemeId>('warm')
  const followSystem = ref(false)
  const loaded = ref(false)

  const themeMeta = computed<ThemeMeta>(() => THEME_METAS[currentTheme.value])
  const layout = computed<ThemeLayout>(() => themeMeta.value.layout)
  const componentVariant = computed(() => themeMeta.value.componentVariant)
  const iconStyle = computed(() => themeMeta.value.iconStyle)

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
    if (saved && THEME_IDS.includes(saved)) currentTheme.value = saved as ThemeId
    const fs = await storageService.getSetting('followSystemTheme')
    followSystem.value = fs === 'true'
    applyTheme(currentTheme.value)
    if (followSystem.value) syncWithSystem()
    loaded.value = true
  }

  function applyTheme(id: ThemeId): void {
    // #ifdef H5
    document.documentElement.setAttribute('data-theme', id)
    // #endif
    // #ifndef H5
    // APP/小程序：通过事件总线通知页面更新 CSS Variable
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
    currentTheme, followSystem, loaded,
    themeMeta, layout, componentVariant, iconStyle,
    setTheme, setFollowSystem, loadTheme, applyTheme, syncWithSystem,
  }
})
```

### 3.2 主题配置表

```typescript
// src/theme/theme-configs.ts
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

### 3.3 组件变体机制

**策略**：动态组件 + 变体映射表，仅标志性组件做独立变体。

#### 首批变体组件：TabBar

```
src/components/tabbar/
├── TabBarFloating.vue    # warm/ink 用（v1 FloatingTabBar 迁移）
├── TabBarCompact.vue     # retro 用（紧凑横条，无悬浮）
└── TabBarMinimal.vue     # fresh 用（极简线条，仅图标+细线）
```

#### 变体选择 composable

```typescript
// src/composables/useThemeComponent.ts
import TabBarFloating from '@/components/tabbar/TabBarFloating.vue'
import TabBarCompact from '@/components/tabbar/TabBarCompact.vue'
import TabBarMinimal from '@/components/tabbar/TabBarMinimal.vue'

const TABBAR_VARIANTS = {
  floating: TabBarFloating,
  compact: TabBarCompact,
  minimal: TabBarMinimal,
}

export function useTabBarVariant() {
  const { layout } = useThemeStore()
  return computed(() => TABBAR_VARIANTS[layout.value.tabBarStyle])
}
```

#### 页面消费

```vue
<script setup lang="ts">
import { useTabBarVariant } from '@/composables/useThemeComponent'

const TabBarComponent = useTabBarVariant()
</script>

<template>
  <component :is="TabBarComponent" :current="current" @on-switch="handleTabSwitch" />
</template>
```

**非变体组件**：卡片圆角/宽高比/网格列数通过 CSS Variable 传递，不需要独立组件。

### 3.4 布局参数化实现

#### 首页区块顺序

```vue
<!-- src/pages/home/index.vue -->
<script setup lang="ts">
import { useThemeStore } from '@/stores/theme'
import BrandHeader from '@/components/home/BrandHeader.vue'
import DailyInspiration from '@/components/home/DailyInspiration.vue'
import RecentPhotos from '@/components/home/RecentPhotos.vue'
import FeaturedTemplates from '@/components/home/FeaturedTemplates.vue'
import SceneQuickAccess from '@/components/home/SceneQuickAccess.vue'
import StatsSummary from '@/components/home/StatsSummary.vue'

const { layout } = useThemeStore()

const sectionMap = {
  brand: BrandHeader,
  inspiration: DailyInspiration,
  recent: RecentPhotos,
  featured: FeaturedTemplates,
  scene: SceneQuickAccess,
  stats: StatsSummary,
}

const sectionProps = computed(() => ({
  brand: {},
  inspiration: { inspiration: dailyInspiration.value },
  recent: { photos: recentPhotos.value, totalCount: photoCount.value },
  featured: { templates: featuredTemplates.value },
  scene: { scenes },
  stats: { photoCount: photoCount.value, templateCount: templateCount.value },
}))
</script>

<template>
  <view class="home-page">
    <component
      v-for="sectionId in layout.homeSectionOrder"
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
    <component :is="tabBarVariant" current="home" @on-switch="handleTabSwitch" />
  </view>
</template>
```

#### 模板库 / 相册网格列数

```scss
// 通过 CSS Variable 驱动
.template-grid {
  display: grid;
  grid-template-columns: repeat(var(--layout-grid-columns, 2), 1fr);
  gap: var(--space-3);
}

.gallery-grid {
  display: grid;
  grid-template-columns: repeat(var(--layout-gallery-columns, 3), 1fr);
  gap: var(--space-2);
}
```

```typescript
// useThemeStore applyTheme 中同步更新布局 CSS Variable
function applyTheme(id: ThemeId): void {
  const meta = THEME_METAS[id]
  // #ifdef H5
  document.documentElement.setAttribute('data-theme', id)
  document.documentElement.style.setProperty('--layout-grid-columns', String(meta.layout.templateGridColumns))
  document.documentElement.style.setProperty('--layout-gallery-columns', String(meta.layout.galleryGridColumns))
  document.documentElement.style.setProperty('--layout-card-aspect', meta.layout.cardAspectRatio)
  // #endif
}
```

---

## 4. 主题切换 UI

### 4.1 入口

设置页新增「主题」行，位于顶部显示设置之后：

```
设置页
├── 主题                    →  跳转 /pages/settings/theme
├── 网格显示
├── 水平仪
├── ...
```

### 4.2 主题选择页

**路由**：`/pages/settings/theme`

**布局**：4 张主题预览卡（2×2 网格）

```
┌─────────────────────────────────┐
│  ←  主题选择                     │
├─────────────────────────────────┤
│                                 │
│  ┌───────────┐  ┌───────────┐  │
│  │  暖米白    │  │  浓墨     │  │
│  │  [预览]    │  │  [预览]   │  │
│  │  温暖留白  │  │  深色沉浸 │  │
│  └───────────┘  └───────────┘  │
│                                 │
│  ┌───────────┐  ┌───────────┐  │
│  │ 胶片复古   │  │ 日系清新  │  │
│  │  [预览]    │  │  [预览]   │  │
│  │  暖橘深棕  │  │  淡粉米白 │  │
│  └───────────┘  └───────────┘  │
│                                 │
│  ─────────────────────────────  │
│  跟随系统                  [ ]  │
│  （仅浅色/深色自动切换）         │
│                                 │
└─────────────────────────────────┘
```

**预览卡设计**：
- 背景：该主题的 bg-canvas 色
- 顶部色条：该主题的 brand-primary 色
- 中部：3 行示例文字（用 text-primary/secondary/tertiary 色）
- 底部：mini TabBar 缩略（floating/compact/minimal 三种形态示意）
- 当前主题：右上角暖金勾选标记 ✓
- 点击：立即切换 data-theme，所有预览卡实时更新颜色

**跟随系统开关**：
- 开启后，仅 warm ↔ ink 自动切换（跟随系统浅色/深色）
- retro/fresh 为风格化主题，不参与系统跟随
- 开启跟随系统时，手动选择 retro/fresh 会关闭跟随系统

---

## 5. 各页面适配清单

| 页面 | 适配内容 | 工作量 | 说明 |
|------|---------|--------|------|
| 所有页面 | CSS Variables 自动响应 | 零改动 | v1 已用 var(--xxx) |
| 首页 | 区块顺序参数化 + 动态组件 + TabBar 变体 | 中 | v-for + sectionMap |
| 模板库 | 网格列数 CSS Variable + TabBar 变体 | 小 | --layout-grid-columns |
| 相册 | 网格列数 CSS Variable + TabBar 变体 | 小 | --layout-gallery-columns |
| 拍摄页 | TabBar 变体（深色态） | 小 | 仅 TabBar 组件替换 |
| 后期编辑 | TabBar 变体 | 小 | |
| 模板详情 | 卡片宽高比 CSS Variable | 小 | --layout-card-aspect |
| 设置页 | 新增主题入口 | 小 | |
| 主题选择页 | 新建页面 | 中 | 4 张预览卡 + 跟随系统 |
| App.vue | 初始化加载主题 | 小 | loadTheme() |
| tokens.scss | 拆分为 4 套主题定义 | 中 | :root + 3 个 [data-theme] |

---

## 6. 文件结构

```
src/
├── theme/
│   ├── tokens.scss           # :root 默认（warm）+ 布局 CSS Variable 默认值
│   ├── theme-ink.scss        # [data-theme="ink"] token 覆盖
│   ├── theme-retro.scss      # [data-theme="retro"] token 覆盖
│   ├── theme-fresh.scss      # [data-theme="fresh"] token 覆盖
│   └── theme-configs.ts      # ThemeMeta + THEME_METAS 配置表
├── stores/
│   └── theme.ts              # useThemeStore
├── composables/
│   └── useThemeComponent.ts  # useTabBarVariant 等变体选择
├── components/
│   ├── tabbar/
│   │   ├── TabBarFloating.vue    # warm/ink 用（v1 FloatingTabBar 迁移）
│   │   ├── TabBarCompact.vue     # retro 用
│   │   └── TabBarMinimal.vue     # fresh 用
│   └── FloatingTabBar.vue        # 保留为兼容 wrapper（可选）
├── pages/
│   ├── home/index.vue            # 适配区块顺序参数化
│   ├── templates/index.vue       # 适配网格列数
│   ├── gallery/index.vue         # 适配网格列数
│   ├── capture/index.vue         # 适配 TabBar 变体
│   ├── editor/index.vue          # 适配 TabBar 变体
│   ├── profile/index.vue         # 适配 TabBar 变体
│   └── settings/
│       ├── index.vue             # 新增主题入口
│       └── theme.vue             # 新建：主题选择页
└── App.vue                       # 初始化 loadTheme()
```

---

## 7. 兼容性说明

### 7.1 v1 组件零破坏

v1 所有组件已使用 `var(--xxx)` 消费设计 token。主题切换时，CSS Variables 值变化会自动传播到所有组件，**无需修改任何 v1 组件**。

### 7.2 拍摄页深色 token

拍摄页的 `--color-capture-*` token 在所有主题中保持一致（取景器始终深色沉浸），不随主题变化。

### 7.3 跨平台兼容

- **H5**：`document.documentElement.setAttribute('data-theme', id)` 直接生效
- **APP/小程序**：通过 `uni.$emit('theme-change')` 事件总线通知页面，页面在 `onThemeChange` 中手动更新根容器的 style 属性（uni-app 小程序不支持 `:root` 属性选择器）
- **跟随系统**：H5 使用 `matchMedia('(prefers-color-scheme: dark)')`；APP 使用 `uni.getSystemInfoSync().theme` + `uni.onThemeChange()`

### 7.4 性能

- CSS Variables 切换由浏览器原生处理，性能最优（无 JS 重渲染）
- 布局参数变化（如网格列数）会触发 reflow，但仅在主题切换时发生一次，可接受
- 主题切换动画：仅过渡 `background-color` 和 `color`，时长 200ms

---

## 8. 测试策略

### 8.1 单元测试

- `useThemeStore`：setTheme/loadTheme/followSystem 的状态变化与持久化
- `theme-configs.ts`：4 套主题配置的完整性（所有字段非空）
- `useTabBarVariant`：变体映射正确性

### 8.2 集成测试

- 主题切换后，首页区块顺序正确变化
- 主题切换后，模板库/相册网格列数正确变化
- 主题切换后，TabBar 组件正确替换
- 跟随系统模式下，prefers-color-scheme 变化触发 warm↔ink 切换

### 8.3 视觉回归

- 4 套主题下，所有页面截图对比
- 重点检查：颜色对比度（WCAG AA）、字体可读性、卡片宽高比、TabBar 形态

---

## 9. 未覆盖范围（后续子项目）

本子项目仅覆盖主题系统。以下 P0 功能在后续子项目实施：

- **子项目 2**：数据层扩展 + 照片收藏 + 心情/场景标签
- **子项目 3**：体验增强（手势/批量/反馈）+ 精选集

主题系统的布局参数化已为后续模块预留扩展点（如收藏相关的 UI 可通过 CSS Variable 适配各主题）。
