# 如画 App UI 风格切换系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 4 套颜色主题基础上，新增 UI 风格切换功能（4 种风格 × 8 套主题任意组合），风格与主题正交独立，通过 `data-theme`（颜色）+ `data-style`（效果）双属性驱动。

**Architecture:** CSS 变量重定义策略 — `data-theme` 控制颜色变量，`data-style` 重定义 `--shadow-*` 变量并新增 `--card-border`/`--card-radius`/`--surface-alpha` 变量。玻璃拟态/女性美学需要 `backdrop-filter`，用定向 CSS 规则覆盖（非纯变量驱动）。状态由 `useTheme` composable 扩展管理（不引入 Pinia），`uni.setStorageSync` 持久化。

**Tech Stack:** uni-app (Vue3) + SCSS + CSS Variables + `@phosphor-icons/web`

## Global Constraints

- 目标平台：H5（CSS Variables 原生支持，`backdrop-filter` 支持）
- 所有样式只能使用 class 选择器（不可用标签选择器）
- CSS 单位使用 rpx（1px ≈ 2rpx）
- uni-app 组件：`<view>`/`<text>`/`<image>`/`<scroll-view>`/`<input>`（不用 HTML 标签）
- App.vue 全局样式必须用纯 CSS（非 SCSS），因为 uni-app 会在 `<style lang="scss">` 中注入 uni.scss 导致 SCSS @import 解析问题
- 页面级 scoped 样式可用 `<style lang="scss" scoped>`，SCSS 变量通过 uni.scss 自动注入
- 图标使用 `@phosphor-icons/web`（已安装），类名格式 `ph ph-xxx`
- 现有 `currentTheme`/`followSystem`/`setTheme`/`loadTheme`/`setFollowSystem` 必须保留不动，不可破坏向后兼容
- 风格切换不影响"跟随系统"行为（系统切换只切主题，不切风格）

## Spec Reference

详见 `docs/superpowers/specs/2026-07-11-ui-style-system-design.md`

---

## File Structure

```
src/
├── theme/
│   └── theme-configs.ts          # 修改：新增 4 主题元数据 + StyleId/STYLE_METAS/STYLE_IDS
├── composables/
│   └── useTheme.ts               # 修改：新增 currentStyle/setStyle/loadStyle/applyStyle
├── App.vue                       # 修改：4 套新主题 CSS 变量 + 4 种风格变量重定义 + 定向覆盖规则
├── uni.scss                      # 修改：新增 4 套主题 SCSS 变量
└── pages/
    └── profile/
        ├── settings.vue          # 修改：新增"风格选择"行
        └── settings/
            └── theme.vue         # 重构：两段式 UI（风格 4 卡 + 主题 8 卡 + 跟随系统）
```

各业务页面（home/templates/challenge/gallery 等）通过 `var(--shadow-*)`/`var(--color-*)` 自动适配，无需逐个修改。

---

### Task 1: 扩展主题配置表 — 新增 4 套女性向颜色主题 + 风格配置

**Files:**
- Modify: `src/theme/theme-configs.ts`

**Interfaces:**
- Produces: 扩展后的 `ThemeId`（含 `'cozy' | 'macaron' | 'morandi' | 'rosegold'`）、新增 `StyleId`/`StyleMeta`/`STYLE_METAS`/`STYLE_IDS`

- [ ] **Step 1: 修改 ThemeId 类型和 THEME_METAS**

打开 `src/theme/theme-configs.ts`，将现有内容替换为：

```typescript
/**
 * 主题配置表
 * 定义 8 套颜色主题 + 4 种 UI 风格的元数据
 */

export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh' | 'cozy' | 'macaron' | 'morandi' | 'rosegold'

export type StyleId = 'neumorphism' | 'flat' | 'glass' | 'female'

export interface ThemeMeta {
  id: ThemeId
  label: string
  description: string
  icon: string
  colors: {
    canvas: string
    brand: string
    surface: string
    textPrimary: string
    textSecondary: string
  }
}

export interface StyleMeta {
  id: StyleId
  label: string
  description: string
  icon: string
}

export const THEME_METAS: Record<ThemeId, ThemeMeta> = {
  warm: {
    id: 'warm',
    label: '暖米白',
    description: '温润如玉，东方留白的经典底色',
    icon: 'ph-sun',
    colors: {
      canvas: '#FAF7F2',
      brand: '#C9A96E',
      surface: '#FFFFFF',
      textPrimary: '#1A1A1A',
      textSecondary: '#5C5852'
    }
  },
  ink: {
    id: 'ink',
    label: '浓墨',
    description: '深邃墨色，暗夜中的专注拍摄',
    icon: 'ph-moon',
    colors: {
      canvas: '#1C1A17',
      brand: '#D4B57A',
      surface: '#262320',
      textPrimary: '#F2EEE6',
      textSecondary: '#A39D94'
    }
  },
  retro: {
    id: 'retro',
    label: '胶片复古',
    description: '温暖胶片质感，怀旧色彩调色',
    icon: 'ph-film-strip',
    colors: {
      canvas: '#F5E6D3',
      brand: '#C4956A',
      surface: '#FFF8F0',
      textPrimary: '#3D2817',
      textSecondary: '#6B4C2F'
    }
  },
  fresh: {
    id: 'fresh',
    label: '日系清新',
    description: '清新自然，柔和明亮的日常感',
    icon: 'ph-flower-tulip',
    colors: {
      canvas: '#F8FAF6',
      brand: '#8BAD72',
      surface: '#FFFFFF',
      textPrimary: '#4A3F35',
      textSecondary: '#8C7F70'
    }
  },
  cozy: {
    id: 'cozy',
    label: '温馨粉',
    description: '柔粉温暖，温馨治愈的日常',
    icon: 'ph-heart',
    colors: {
      canvas: '#FFF5F5',
      brand: '#E8A0A0',
      surface: '#FFFFFF',
      textPrimary: '#4A3A3A',
      textSecondary: '#8C7070'
    }
  },
  macaron: {
    id: 'macaron',
    label: '马卡龙',
    description: '薄荷糖果，甜美活泼',
    icon: 'ph-ice-cream',
    colors: {
      canvas: '#FFF8F0',
      brand: '#A8D8C8',
      surface: '#FFFFFF',
      textPrimary: '#5A4A4A',
      textSecondary: '#8C7A7A'
    }
  },
  morandi: {
    id: 'morandi',
    label: '莫兰迪',
    description: '灰调优雅，安静内敛',
    icon: 'ph-mountains',
    colors: {
      canvas: '#E8E4E0',
      brand: '#8B9DAF',
      surface: '#F2EFEA',
      textPrimary: '#4A4540',
      textSecondary: '#7A7570'
    }
  },
  rosegold: {
    id: 'rosegold',
    label: '玫瑰金',
    description: '轻奢优雅，玫瑰金质感',
    icon: 'ph-diamond',
    colors: {
      canvas: '#FAF6F2',
      brand: '#C9A0A0',
      surface: '#FFFFFF',
      textPrimary: '#3D2E2A',
      textSecondary: '#6B5450'
    }
  }
}

export const THEME_IDS: ThemeId[] = ['warm', 'ink', 'retro', 'fresh', 'cozy', 'macaron', 'morandi', 'rosegold']

export const STYLE_METAS: Record<StyleId, StyleMeta> = {
  neumorphism: {
    id: 'neumorphism',
    label: '新拟态',
    description: '双向阴影，柔和立体',
    icon: 'ph-circle-half'
  },
  flat: {
    id: 'flat',
    label: '扁平化',
    description: '干净利落，无多余修饰',
    icon: 'ph-square'
  },
  glass: {
    id: 'glass',
    label: '玻璃拟态',
    description: '半透明毛玻璃，通透感',
    icon: 'ph-square-logo'
  },
  female: {
    id: 'female',
    label: '女性美学',
    description: '暖粉弥散，大圆角，呼吸感',
    icon: 'ph-heart'
  }
}

export const STYLE_IDS: StyleId[] = ['neumorphism', 'flat', 'glass', 'female']
```

- [ ] **Step 2: 验证类型导出**

Run: `cd lumira-app && npx tsc --noEmit`
Expected: 无类型错误

- [ ] **Step 3: Commit**

```bash
git add src/theme/theme-configs.ts
git commit -m "feat: extend theme configs with 4 feminine themes and 4 UI styles"
```

---

### Task 2: 扩展 useTheme composable — 新增风格管理

**Files:**
- Modify: `src/composables/useTheme.ts`

**Interfaces:**
- Consumes: `StyleId`/`STYLE_IDS` from Task 1
- Produces: 扩展后的 `useTheme()` 返回值新增 `currentStyle`/`setStyle`/`loadStyle`

- [ ] **Step 1: 修改 useTheme.ts，新增风格管理逻辑**

打开 `src/composables/useTheme.ts`，将现有内容替换为：

```typescript
/**
 * 主题 + 风格管理 composable
 * 管理当前主题（颜色）和风格（效果）状态、持久化、跟随系统
 */
import { ref } from 'vue'
import type { ThemeId, StyleId } from '@/theme/theme-configs'
import { THEME_IDS, STYLE_IDS } from '@/theme/theme-configs'

const currentTheme = ref<ThemeId>('warm')
const currentStyle = ref<StyleId>('neumorphism')
const followSystem = ref(false)
let initialized = false

function applyTheme(id: ThemeId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', id)
  }
  // #endif
}

function applyStyle(id: StyleId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-style', id)
  }
  // #endif
}

let listenerRegistered = false

function setupSystemListener() {
  // #ifdef H5
  if (typeof window !== 'undefined' && window.matchMedia) {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    if (followSystem.value) {
      setTheme(mq.matches ? 'ink' : 'warm')
    }
    if (!listenerRegistered) {
      listenerRegistered = true
      mq.addEventListener('change', (e) => {
        if (followSystem.value) {
          setTheme(e.matches ? 'ink' : 'warm')
        }
      })
    }
  }
  // #endif
}

function setTheme(id: ThemeId) {
  currentTheme.value = id
  applyTheme(id)
  try {
    uni.setStorageSync('theme', id)
  } catch (e) {
    console.warn('Failed to persist theme', e)
  }
}

function setStyle(id: StyleId) {
  currentStyle.value = id
  applyStyle(id)
  try {
    uni.setStorageSync('uiStyle', id)
  } catch (e) {
    console.warn('Failed to persist style', e)
  }
}

function loadTheme() {
  if (initialized) return
  initialized = true
  try {
    const saved = uni.getStorageSync('theme') as ThemeId
    if (saved && THEME_IDS.includes(saved)) {
      currentTheme.value = saved
    }
    const fs = uni.getStorageSync('followSystem')
    followSystem.value = fs === true || fs === 'true'
  } catch (e) {
    console.warn('Failed to load theme', e)
  }
  applyTheme(currentTheme.value)
  if (followSystem.value) {
    setupSystemListener()
  }
}

function loadStyle() {
  try {
    const saved = uni.getStorageSync('uiStyle') as StyleId
    if (saved && STYLE_IDS.includes(saved)) {
      currentStyle.value = saved
    }
  } catch (e) {
    console.warn('Failed to load style', e)
  }
  applyStyle(currentStyle.value)
}

function setFollowSystem(enabled: boolean) {
  followSystem.value = enabled
  try {
    uni.setStorageSync('followSystem', enabled)
  } catch (e) {
    console.warn('Failed to persist followSystem', e)
  }
  if (enabled) {
    setupSystemListener()
  }
}

export function useTheme() {
  return {
    currentTheme,
    currentStyle,
    followSystem,
    setTheme,
    setStyle,
    loadTheme,
    loadStyle,
    setFollowSystem
  }
}
```

- [ ] **Step 2: 修改 App.vue 在 onLaunch 中调用 loadStyle**

打开 `src/App.vue`，找到 `<script setup lang="ts">` 块中的 `onLaunch` 部分：

```vue
<script setup lang="ts">
import { onLaunch } from "@dcloudio/uni-app";
import { useTheme } from "@/composables/useTheme";

const { loadTheme } = useTheme();

onLaunch(() => {
  console.log("如画 Lumira App Launch");
  loadTheme();
});
</script>
```

替换为：

```vue
<script setup lang="ts">
import { onLaunch } from "@dcloudio/uni-app";
import { useTheme } from "@/composables/useTheme";

const { loadTheme, loadStyle } = useTheme();

onLaunch(() => {
  console.log("如画 Lumira App Launch");
  loadTheme();
  loadStyle();
});
</script>
```

- [ ] **Step 3: 验证类型**

Run: `cd lumira-app && npx tsc --noEmit`
Expected: 无类型错误

- [ ] **Step 4: Commit**

```bash
git add src/composables/useTheme.ts src/App.vue
git commit -m "feat: add style management to useTheme composable"
```

---

### Task 3: App.vue — 新增 4 套颜色主题 CSS 变量

**Files:**
- Modify: `src/App.vue`（在 `<style>` 块中追加）

**Interfaces:**
- Consumes: Task 1 的主题配色定义
- Produces: `[data-theme="cozy"]`/`[data-theme="macaron"]`/`[data-theme="morandi"]`/`[data-theme="rosegold"]` 的 CSS 变量定义

- [ ] **Step 1: 在 App.vue 的 `<style>` 块中，紧接 `[data-theme="fresh"]` 规则后追加 4 套新主题**

打开 `src/App.vue`，在 `[data-theme="fresh"] { ... }` 规则块结束的 `}` 之后（即 `/* ===== 全局重置（仅 class 选择器） ===== */` 之前），追加：

```css
/* 温馨粉主题 */
[data-theme="cozy"] {
  --color-canvas: #FFF5F5;
  --color-surface: #FFFFFF;
  --color-surface-alt: #FAEDED;
  --color-canvas-deep: #F5EAEA;
  --color-text-primary: #4A3A3A;
  --color-text-secondary: #8C7070;
  --color-text-tertiary: #B89A9A;
  --color-divider: #F0E0E0;
  --color-brand: #E8A0A0;
  --color-brand-deep: #D4858A;
  --color-brand-light: #F0B5B5;
  --color-brand-subtle: #FCE8E8;
  --color-brand-text: #C47070;
  --color-brand-rgb: 232, 160, 160;
  --color-danger: #D47070;
  --color-danger-subtle: #FCE8E8;
  --color-success: #8FB088;
  --color-success-subtle: #EDF2E8;

  --shadow-convex: 6px 6px 14px #F0E0E0, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #F2E2E2, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #D4858A, -4px -4px 10px #F0B5B5;
  --shadow-concave: inset 4px 4px 10px #F0E0E0, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #F2E2E2, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #F0E0E0, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(74, 58, 58, 0.08);
}

/* 马卡龙主题 */
[data-theme="macaron"] {
  --color-canvas: #FFF8F0;
  --color-surface: #FFFFFF;
  --color-surface-alt: #F5F0E8;
  --color-canvas-deep: #F0EAE0;
  --color-text-primary: #5A4A4A;
  --color-text-secondary: #8C7A7A;
  --color-text-tertiary: #B8A8A0;
  --color-divider: #E8E0D5;
  --color-brand: #A8D8C8;
  --color-brand-deep: #8CC5B5;
  --color-brand-light: #C5E8DD;
  --color-brand-subtle: #E0F0EA;
  --color-brand-text: #5E9882;
  --color-brand-rgb: 168, 216, 200;
  --color-danger: #E8A0A0;
  --color-danger-subtle: #FCE8E8;
  --color-success: #A8D8C8;
  --color-success-subtle: #E0F0EA;

  --shadow-convex: 6px 6px 14px #E8E0D5, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #EDE5D8, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #8CC5B5, -4px -4px 10px #C5E8DD;
  --shadow-concave: inset 4px 4px 10px #E8E0D5, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #EDE5D8, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #E8E0D5, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(90, 74, 74, 0.08);
}

/* 莫兰迪主题 */
[data-theme="morandi"] {
  --color-canvas: #E8E4E0;
  --color-surface: #F2EFEA;
  --color-surface-alt: #E0DCD6;
  --color-canvas-deep: #DDD9D3;
  --color-text-primary: #4A4540;
  --color-text-secondary: #7A7570;
  --color-text-tertiary: #A8A29C;
  --color-divider: #D5D0CA;
  --color-brand: #8B9DAF;
  --color-brand-deep: #6B7D8F;
  --color-brand-light: #A8B8C8;
  --color-brand-subtle: #D5DDE5;
  --color-brand-text: #5B6D7F;
  --color-brand-rgb: 139, 157, 175;
  --color-danger: #A88080;
  --color-danger-subtle: #E8DDDD;
  --color-success: #8FA590;
  --color-success-subtle: #DDE5DD;

  --shadow-convex: 6px 6px 14px #D5D0CA, -6px -6px 14px #F2EFEA;
  --shadow-convex-subtle: 3px 3px 6px #D8D3CD, -3px -3px 6px #F2EFEA;
  --shadow-convex-brand: 4px 4px 10px #6B7D8F, -4px -4px 10px #A8B8C8;
  --shadow-concave: inset 4px 4px 10px #D5D0CA, inset -4px -4px 10px #F2EFEA;
  --shadow-concave-subtle: inset 2px 2px 5px #D8D3CD, inset -2px -2px 5px #F2EFEA;
  --shadow-pressed: inset 3px 3px 8px #D5D0CA, inset -3px -3px 8px #F2EFEA;
  --shadow-float: 0 8px 32px rgba(74, 69, 64, 0.08);
}

/* 玫瑰金主题 */
[data-theme="rosegold"] {
  --color-canvas: #FAF6F2;
  --color-surface: #FFFFFF;
  --color-surface-alt: #F5EDE8;
  --color-canvas-deep: #F0E8E2;
  --color-text-primary: #3D2E2A;
  --color-text-secondary: #6B5450;
  --color-text-tertiary: #A89088;
  --color-divider: #E8DDD5;
  --color-brand: #C9A0A0;
  --color-brand-deep: #B08585;
  --color-brand-light: #DDB8B8;
  --color-brand-subtle: #F0E0E0;
  --color-brand-text: #A06868;
  --color-brand-rgb: 201, 160, 160;
  --color-danger: #C47878;
  --color-danger-subtle: #F0E0E0;
  --color-success: #9AB088;
  --color-success-subtle: #E8F0E0;

  --shadow-convex: 6px 6px 14px #E8DDD5, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #EDE2DA, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #B08585, -4px -4px 10px #DDB8B8;
  --shadow-concave: inset 4px 4px 10px #E8DDD5, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #EDE2DA, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #E8DDD5, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(61, 46, 42, 0.08);
}
```

- [ ] **Step 2: 启动开发服务器验证主题切换**

Run: `cd lumira-app && pnpm dev:h5`
打开浏览器，进入应用，在浏览器控制台执行：

```js
document.documentElement.setAttribute('data-theme', 'cozy')
document.documentElement.setAttribute('data-theme', 'macaron')
document.documentElement.setAttribute('data-theme', 'morandi')
document.documentElement.setAttribute('data-theme', 'rosegold')
```

Expected: 每次执行后页面配色变化，无样式错误

- [ ] **Step 3: Commit**

```bash
git add src/App.vue
git commit -m "feat: add 4 feminine color theme CSS variables"
```

---

### Task 4: App.vue — 新增 4 种风格 CSS 变量重定义

**Files:**
- Modify: `src/App.vue`（在 `<style>` 块中追加）

**Interfaces:**
- Produces: `[data-style="neumorphism"]`/`[data-style="flat"]`/`[data-style="glass"]`/`[data-style="female"]` 的 CSS 变量重定义 + `:root` 新增 `--card-border`/`--card-radius`/`--surface-alpha`

- [ ] **Step 1: 在 `:root` 规则中追加风格基础变量**

打开 `src/App.vue`，找到 `:root { ... }` 规则块（在 `--shadow-float` 和 `/* 字体 */` 之间），追加：

```css
  /* 风格基础变量（新拟态默认值） */
  --card-border: none;
  --card-radius: 28rpx;
  --surface-alpha: 1;
```

位置：在 `--shadow-float: 0 8px 32px rgba(26, 26, 26, 0.08);` 之后，`/* 字体 */` 注释之前。

- [ ] **Step 2: 在 `[data-theme="rosegold"]` 规则之后追加 4 种风格变量重定义**

在 `[data-theme="rosegold"] { ... }` 规则块之后（即 `/* ===== 全局重置（仅 class 选择器） ===== */` 之前），追加：

```css
/* ===== UI 风格变量重定义 ===== */

/* 扁平化风格 */
[data-style="flat"] {
  --shadow-convex: none;
  --shadow-concave: none;
  --shadow-convex-subtle: none;
  --shadow-concave-subtle: none;
  --shadow-pressed: none;
  --shadow-convex-brand: none;
  --shadow-float: none;
  --card-border: 1rpx solid var(--color-divider);
  --card-radius: 20rpx;
  --surface-alpha: 1;
}

/* 玻璃拟态风格 */
[data-style="glass"] {
  --shadow-convex: 0 8px 32px rgba(0,0,0,0.08);
  --shadow-concave: inset 0 2px 8px rgba(0,0,0,0.06);
  --shadow-convex-subtle: 0 4px 16px rgba(0,0,0,0.06);
  --shadow-concave-subtle: inset 0 1px 4px rgba(0,0,0,0.04);
  --shadow-pressed: inset 0 2px 8px rgba(0,0,0,0.08);
  --shadow-convex-brand: 0 8px 24px rgba(var(--color-brand-rgb), 0.3);
  --shadow-float: 0 8px 32px rgba(0,0,0,0.08);
  --card-border: 1rpx solid rgba(255,255,255,0.3);
  --card-radius: 28rpx;
  --surface-alpha: 0.55;
}

/* 女性美学风格 */
[data-style="female"] {
  --shadow-convex: 0 8px 32px rgba(var(--color-brand-rgb), 0.15);
  --shadow-concave: inset 0 2px 8px rgba(var(--color-brand-rgb), 0.08);
  --shadow-convex-subtle: 0 4px 16px rgba(var(--color-brand-rgb), 0.1);
  --shadow-concave-subtle: inset 0 1px 4px rgba(var(--color-brand-rgb), 0.05);
  --shadow-pressed: inset 0 2px 8px rgba(var(--color-brand-rgb), 0.1);
  --shadow-convex-brand: 0 8px 24px rgba(var(--color-brand-rgb), 0.25);
  --shadow-float: 0 8px 32px rgba(var(--color-brand-rgb), 0.12);
  --card-border: none;
  --card-radius: 48rpx;
  --surface-alpha: 0.75;
}
```

- [ ] **Step 3: 验证风格切换**

在浏览器控制台执行：

```js
document.documentElement.setAttribute('data-style', 'flat')
document.documentElement.setAttribute('data-style', 'glass')
document.documentElement.setAttribute('data-style', 'female')
document.documentElement.setAttribute('data-style', 'neumorphism')
```

Expected: 卡片阴影/边框随风格变化（扁平化无阴影有边框，玻璃/女性美学阴影变柔和）

- [ ] **Step 4: Commit**

```bash
git add src/App.vue
git commit -m "feat: add 4 UI style CSS variable overrides"
```

---

### Task 5: App.vue — 新增风格定向覆盖规则

**Files:**
- Modify: `src/App.vue`（在 `<style>` 块末尾追加）

**Interfaces:**
- Produces: 玻璃拟态/女性美学的 `backdrop-filter` 规则、扁平化的边框/toggle 规则、女性美学呼吸动画、深色主题适配

- [ ] **Step 1: 在 App.vue `<style>` 块末尾追加定向覆盖规则**

打开 `src/App.vue`，在 `<style>` 块的最后（`.scale-in` 动画类之后、`</style>` 之前），追加：

```css
/* ===== 风格定向覆盖规则 ===== */

/* 玻璃拟态：半透明 + backdrop-filter */
[data-style="glass"] .neu-card,
[data-style="glass"] .lumira-card,
[data-style="glass"] .floating-tabbar,
[data-style="glass"] .lumira-nav {
  background-color: rgba(255, 255, 255, var(--surface-alpha));
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

[data-style="glass"] .neu-card,
[data-style="glass"] .lumira-card {
  border: var(--card-border);
}

/* 女性美学：半透明 + backdrop-filter + 大圆角 */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card,
[data-style="female"] .floating-tabbar,
[data-style="female"] .lumira-nav {
  background-color: rgba(255, 255, 255, var(--surface-alpha));
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

[data-style="female"] .neu-card,
[data-style="female"] .lumira-card {
  border-radius: var(--card-radius);
}

/* 女性美学：所有卡片过渡使用 cubic-bezier */
[data-style="female"] .neu-card,
[data-style="female"] .lumira-card,
[data-style="female"] .neu-btn-convex,
[data-style="female"] .neu-btn-brand,
[data-style="female"] .lumira-btn-brand,
[data-style="female"] .neu-pill {
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

/* 女性美学：按压反馈 scale(0.96) */
[data-style="female"] .neu-card:active,
[data-style="female"] .lumira-card:active,
[data-style="female"] .neu-btn-convex:active,
[data-style="female"] .neu-btn-brand:active {
  transform: scale(0.96);
}

/* 女性美学：呼吸光晕动画 */
@keyframes female-pulse {
  0%, 100% {
    box-shadow: 0 0 0 0 rgba(var(--color-brand-rgb), 0.4);
  }
  50% {
    box-shadow: 0 0 0 8rpx rgba(var(--color-brand-rgb), 0);
  }
}

[data-style="female"] .tabbar-item.active,
[data-style="female"] .tabbar-center {
  animation: female-pulse 2s ease-in-out infinite;
}

/* 扁平化：卡片边框 */
[data-style="flat"] .neu-card,
[data-style="flat"] .lumira-card {
  border: var(--card-border);
}

/* 扁平化：圆角变小 */
[data-style="flat"] .neu-card,
[data-style="flat"] .lumira-card {
  border-radius: var(--card-radius);
}

/* 扁平化：toggle 色块填充 */
[data-style="flat"] .neu-toggle {
  box-shadow: none;
  background-color: var(--color-divider);
}

[data-style="flat"] .neu-toggle.active {
  background-color: var(--color-brand);
  box-shadow: none;
}

[data-style="flat"] .neu-toggle-knob {
  box-shadow: none;
  background-color: #FFFFFF;
}

[data-style="flat"] .neu-toggle.active .neu-toggle-knob {
  background-color: #FFFFFF;
  box-shadow: none;
}

/* 扁平化：去除 neu-block 阴影 */
[data-style="flat"] .neu-block,
[data-style="flat"] .neu-pill,
[data-style="flat"] .neu-btn-convex {
  box-shadow: none;
}

[data-style="flat"] .neu-block-inset,
[data-style="flat"] .neu-inset {
  box-shadow: none;
  background-color: var(--color-surface-alt);
}

/* ===== 深色主题 + 玻璃/女性美学适配 ===== */
[data-theme="ink"][data-style="glass"] .neu-card,
[data-theme="ink"][data-style="glass"] .lumira-card,
[data-theme="ink"][data-style="glass"] .floating-tabbar,
[data-theme="ink"][data-style="glass"] .lumira-nav {
  background-color: rgba(38, 35, 32, 0.55);
  border-color: rgba(255, 255, 255, 0.1);
}

[data-theme="ink"][data-style="female"] .neu-card,
[data-theme="ink"][data-style="female"] .lumira-card,
[data-theme="ink"][data-style="female"] .floating-tabbar,
[data-theme="ink"][data-style="female"] .lumira-nav {
  background-color: rgba(38, 35, 32, 0.75);
}
```

- [ ] **Step 2: 验证定向规则生效**

在浏览器控制台执行组合测试：

```js
// 玻璃拟态 + 暖米白
document.documentElement.setAttribute('data-style', 'glass')
document.documentElement.setAttribute('data-theme', 'warm')

// 女性美学 + 玫瑰金
document.documentElement.setAttribute('data-style', 'female')
document.documentElement.setAttribute('data-theme', 'rosegold')

// 扁平化 + 莫兰迪
document.documentElement.setAttribute('data-style', 'flat')
document.documentElement.setAttribute('data-theme', 'morandi')

// 深色 + 玻璃拟态
document.documentElement.setAttribute('data-style', 'glass')
document.documentElement.setAttribute('data-theme', 'ink')
```

Expected: 每种组合视觉合理，无样式冲突

- [ ] **Step 3: Commit**

```bash
git add src/App.vue
git commit -m "feat: add style-specific CSS override rules"
```

---

### Task 6: 重构主题页 — 两段式 UI（风格 + 主题）

**Files:**
- Modify: `src/pages/profile/settings/theme.vue`（完整重写 template + script + style）

**Interfaces:**
- Consumes: `useTheme()`（含 `currentStyle`/`setStyle`）、`STYLE_METAS`/`STYLE_IDS`/`THEME_METAS`/`THEME_IDS`

- [ ] **Step 1: 重写 theme.vue 完整内容**

将 `src/pages/profile/settings/theme.vue` 完整替换为：

```vue
<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">主题与风格</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- UI 风格选择 -->
      <text class="section-title">UI 风格</text>
      <view class="style-grid">
        <view
          class="style-card"
          :class="{ selected: currentStyle === s.id }"
          v-for="s in styles"
          :key="s.id"
          @click="selectStyle(s.id)"
        >
          <view class="style-preview" :class="'preview-' + s.id">
            <view class="preview-card"></view>
            <view class="preview-circle"></view>
          </view>
          <view class="style-info">
            <text class="style-name">{{ s.label }}</text>
            <text class="style-desc">{{ s.description }}</text>
          </view>
          <view v-if="currentStyle === s.id" class="style-check">
            <text class="ph ph-check check-icon"></text>
          </view>
        </view>
      </view>

      <!-- 颜色主题选择 -->
      <text class="section-title">颜色主题</text>
      <view class="theme-grid">
        <view
          class="theme-card"
          :class="{ selected: currentTheme === t.id }"
          v-for="t in themes"
          :key="t.id"
          @click="selectTheme(t.id)"
        >
          <view class="theme-swatch" :style="{ backgroundColor: t.colors.canvas }">
            <view class="swatch-brand" :style="{ backgroundColor: t.colors.brand }"></view>
          </view>
          <view class="theme-info">
            <text class="theme-name">{{ t.label }}</text>
            <view class="color-dots">
              <view class="color-dot" v-for="(c, i) in t.previewColors" :key="i" :style="{ backgroundColor: c }"></view>
            </view>
          </view>
          <view v-if="currentTheme === t.id" class="theme-check">
            <text class="ph ph-check check-icon"></text>
          </view>
        </view>
      </view>

      <!-- 跟随系统 -->
      <view class="sys-card neu-card">
        <view class="sys-row">
          <view class="sys-info">
            <text class="sys-title">跟随系统</text>
            <text class="sys-desc">根据系统深浅色自动切换主题（仅影响颜色，不影响风格）</text>
          </view>
          <view class="neu-toggle" :class="{ active: followSystem }" @click="toggleFollowSystem">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 底部说明 -->
      <view class="bottom-note">
        <text class="bottom-note-text">风格与主题可任意组合，切换即时生效</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS, THEME_IDS, STYLE_METAS, STYLE_IDS } from '@/theme/theme-configs'
import type { ThemeId, StyleId } from '@/theme/theme-configs'

const { currentTheme, currentStyle, followSystem, setTheme, setStyle, setFollowSystem } = useTheme()

const styles = computed(() => STYLE_IDS.map(id => STYLE_METAS[id]))

const themes = computed(() => THEME_IDS.map(id => {
  const meta = THEME_METAS[id]
  return {
    ...meta,
    previewColors: [
      meta.colors.canvas,
      meta.colors.brand,
      meta.colors.textPrimary,
      meta.colors.textSecondary
    ]
  }
}))

const selectStyle = (id: StyleId) => {
  setStyle(id)
  uni.showToast({ title: `已切换至${STYLE_METAS[id].label}风格`, icon: 'none', duration: 1000 })
}

const selectTheme = (id: ThemeId) => {
  setTheme(id)
  uni.showToast({ title: `已切换至${THEME_METAS[id].label}`, icon: 'none', duration: 1000 })
}

const toggleFollowSystem = () => {
  setFollowSystem(!followSystem.value)
}

const back = () => uni.navigateBack()
</script>

<style scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.page-body {
  padding: 24rpx 40rpx 48rpx;
}

/* 区块标题 */
.section-title {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 0 8rpx;
  margin-bottom: 16rpx;
  margin-top: 32rpx;
}

.section-title:first-child {
  margin-top: 0;
}

/* ===== 风格网格 ===== */
.style-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  margin-bottom: 8rpx;
}

.style-card {
  position: relative;
  background-color: var(--color-canvas);
  border-radius: 32rpx;
  box-shadow: var(--shadow-convex);
  padding: 32rpx;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.style-card:active {
  transform: scale(0.97);
}

.style-card.selected {
  box-shadow: var(--shadow-concave);
  border: 2rpx solid var(--color-brand);
}

/* 风格预览区 */
.style-preview {
  height: 120rpx;
  border-radius: 16rpx;
  background-color: var(--color-surface-alt);
  position: relative;
  overflow: hidden;
  margin-bottom: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.preview-card {
  width: 80rpx;
  height: 56rpx;
  border-radius: 8rpx;
  background-color: var(--color-surface);
}

.preview-circle {
  position: absolute;
  right: 16rpx;
  bottom: 16rpx;
  width: 32rpx;
  height: 32rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
}

/* 每种风格的预览样式 */
.preview-neumorphism .preview-card {
  box-shadow: 3px 3px 6px rgba(0,0,0,0.1), -3px -3px 6px rgba(255,255,255,0.8);
}

.preview-flat .preview-card {
  border: 1rpx solid var(--color-divider);
  box-shadow: none;
}

.preview-flat .preview-circle {
  box-shadow: none;
}

.preview-glass {
  background: linear-gradient(135deg, var(--color-brand-subtle) 0%, var(--color-surface-alt) 100%);
}

.preview-glass .preview-card {
  background-color: rgba(255, 255, 255, 0.55);
  backdrop-filter: blur(8px);
  border: 1rpx solid rgba(255,255,255,0.3);
  box-shadow: 0 4px 16px rgba(0,0,0,0.08);
}

.preview-female .preview-card {
  background-color: rgba(255, 255, 255, 0.75);
  backdrop-filter: blur(8px);
  border-radius: 24rpx;
  box-shadow: 0 4px 16px rgba(var(--color-brand-rgb), 0.15);
}

.preview-female .preview-circle {
  box-shadow: 0 0 0 4rpx rgba(var(--color-brand-rgb), 0.3);
  animation: female-pulse 2s ease-in-out infinite;
}

.style-info {
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.style-name {
  font-family: var(--font-cn-title);
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.style-desc {
  font-size: 20rpx;
  color: var(--color-text-tertiary);
  line-height: 1.5;
}

.style-check {
  position: absolute;
  top: 16rpx;
  right: 16rpx;
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-brand);
}

/* ===== 主题网格 ===== */
.theme-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  margin-bottom: 8rpx;
}

.theme-card {
  position: relative;
  background-color: var(--color-canvas);
  border-radius: 24rpx;
  box-shadow: var(--shadow-convex-subtle);
  padding: 24rpx;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
  overflow: hidden;
}

.theme-card:active {
  transform: scale(0.97);
}

.theme-card.selected {
  box-shadow: var(--shadow-concave);
  border: 2rpx solid var(--color-brand);
}

.theme-swatch {
  height: 96rpx;
  border-radius: 16rpx;
  margin-bottom: 16rpx;
  position: relative;
  overflow: hidden;
}

.swatch-brand {
  position: absolute;
  right: 16rpx;
  bottom: 16rpx;
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
}

.theme-info {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.theme-name {
  font-family: var(--font-cn-title);
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.color-dots {
  display: flex;
  gap: 8rpx;
}

.color-dot {
  width: 20rpx;
  height: 20rpx;
  border-radius: 50%;
}

.theme-check {
  position: absolute;
  top: 16rpx;
  right: 16rpx;
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-brand);
}

/* 通用选中图标 */
.check-icon {
  font-size: 22rpx;
  color: var(--color-text-inverse);
}

/* ===== 跟随系统 ===== */
.sys-card {
  padding: 32rpx;
  margin-top: 24rpx;
}

.sys-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sys-info {
  flex: 1;
}

.sys-title {
  display: block;
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.sys-desc {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
  line-height: 1.5;
}

/* 底部说明 */
.bottom-note {
  text-align: center;
  padding: 48rpx 0;
}

.bottom-note-text {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  line-height: 1.8;
}
</style>
```

- [ ] **Step 2: 验证页面渲染**

启动开发服务器，进入"设置 → 主题与风格"页面：
- 上半部分显示 4 张风格卡片（2×2 网格），每张有风格预览效果
- 下半部分显示 8 张主题卡片（2×4 网格），每张有色彩预览
- 底部有"跟随系统"开关

Run: `cd lumira-app && pnpm dev:h5`

- [ ] **Step 3: 验证风格切换功能**

点击不同风格卡片，确认：
- 选中标记正确显示
- 切换后整个应用立即应用新风格
- Toast 提示"已切换至 XXX 风格"

- [ ] **Step 4: 验证主题切换功能**

点击不同主题卡片，确认：
- 选中标记正确显示
- 切换后整个应用立即应用新颜色
- Toast 提示"已切换至 XXX"

- [ ] **Step 5: Commit**

```bash
git add src/pages/profile/settings/theme.vue
git commit -m "feat: redesign theme page with style + theme two-section UI"
```

---

### Task 7: 修改设置页 — 新增"风格选择"行

**Files:**
- Modify: `src/pages/profile/settings.vue`

**Interfaces:**
- Consumes: `useTheme()`（含 `currentStyle`）、`STYLE_METAS`

- [ ] **Step 1: 修改 settings.vue script，引入风格相关**

打开 `src/pages/profile/settings.vue`，找到 `<script setup lang="ts">` 部分：

```typescript
import { ref, computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS } from '@/theme/theme-configs'

const { currentTheme } = useTheme()
const currentThemeName = computed(() => THEME_METAS[currentTheme.value].label)
```

替换为：

```typescript
import { ref, computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS, STYLE_METAS } from '@/theme/theme-configs'

const { currentTheme, currentStyle } = useTheme()
const currentThemeName = computed(() => THEME_METAS[currentTheme.value].label)
const currentStyleName = computed(() => STYLE_METAS[currentStyle.value].label)
```

- [ ] **Step 2: 在 template 中"主题选择"行之后新增"风格选择"行**

找到现有"主题选择"行的 `</view>` 结束标签之后（即"语言"行之前），新增一行：

```html
        <view class="setting-item" @click="goTheme">
          <view class="setting-icon-wrap">
            <text class="ph ph-palette"></text>
          </view>
          <text class="setting-label">主题选择</text>
          <view class="setting-right">
            <text class="setting-value setting-value-brand">{{ currentThemeName }}</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item" @click="goTheme">
          <view class="setting-icon-wrap">
            <text class="ph ph-shapes"></text>
          </view>
          <text class="setting-label">风格选择</text>
          <view class="setting-right">
            <text class="setting-value setting-value-brand">{{ currentStyleName }}</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
```

注意：新增的"风格选择"行也跳转到同一个 `/pages/profile/settings/theme` 页面（该页面已重构为两段式）。

- [ ] **Step 3: 验证设置页显示**

刷新应用，进入"设置"页面：
- "通用"分组下应显示"主题选择"和"风格选择"两行
- "风格选择"行显示当前风格名（如"新拟态"）
- 图标为 `ph-shapes`

- [ ] **Step 4: 验证跳转**

点击"风格选择"行，确认跳转到主题与风格页面。

- [ ] **Step 5: Commit**

```bash
git add src/pages/profile/settings.vue
git commit -m "feat: add style selection entry in settings page"
```

---

### Task 8: 验收测试 — 风格 × 主题组合矩阵

**Files:**
- 无文件修改，仅手动验证

- [ ] **Step 1: 启动应用**

Run: `cd lumira-app && pnpm dev:h5`

- [ ] **Step 2: 验收风格切换**

进入"设置 → 主题与风格"，依次点击 4 种风格：

| 风格 | 预期效果 |
|------|---------|
| 新拟态 | 双向凸/凹阴影，实色卡片，28rpx 圆角 |
| 扁平化 | 无阴影，细边框，20rpx 圆角，toggle 色块填充 |
| 玻璃拟态 | 半透明卡片 + 模糊背景，柔和环境光阴影 |
| 女性美学 | 暖粉弥散阴影，48rpx 大圆角，导航呼吸光晕 |

- [ ] **Step 3: 验收主题切换**

依次点击 8 套主题，确认配色变化：
- 暖米白（默认）、浓墨（深色）、胶片复古、日系清新（现有 4 套）
- 温馨粉、马卡龙、莫兰迪、玫瑰金（新增 4 套）

- [ ] **Step 4: 验收组合矩阵**

至少测试以下 4 种组合：
1. 浓墨 + 玻璃拟态 → 深色半透明卡片
2. 玫瑰金 + 女性美学 → 暖粉阴影 + 大圆角
3. 莫兰迪 + 扁平化 → 灰调 + 细边框
4. 温馨粉 + 新拟态 → 柔粉 + 双向阴影

- [ ] **Step 5: 验收持久化**

切换风格和主题后：
1. 刷新页面
2. 确认风格和主题恢复到上次选择

- [ ] **Step 6: 验收跟随系统**

开启"跟随系统"：
1. 切换系统深浅色，确认主题自动切换（浓墨 ↔ 暖米白）
2. 确认风格保持不变（不随系统切换）

- [ ] **Step 7: 最终 Commit（如有修复）**

如有任何修复，提交：

```bash
git add -A
git commit -m "fix: address issues found during acceptance testing"
```

---

## Self-Review

**Spec coverage:**
- ✅ 4 种 UI 风格（新拟态/扁平化/玻璃拟态/女性美学）— Task 4, 5
- ✅ 8 套颜色主题（4 现有 + 4 新增）— Task 1, 3
- ✅ 两层正交系统（data-theme + data-style）— Task 2, 4
- ✅ useTheme composable 扩展 — Task 2
- ✅ 设置页"风格选择"入口 — Task 7
- ✅ 主题页两段式重构 — Task 6
- ✅ 玻璃拟态 backdrop-filter 定向规则 — Task 5
- ✅ 女性美学呼吸光晕 + 大圆角 — Task 5
- ✅ 扁平化 toggle 色块填充 — Task 5
- ✅ 深色主题 + 玻璃/女性美学适配 — Task 5
- ✅ 持久化 — Task 2
- ✅ 验收标准全覆盖 — Task 8

**Placeholder scan:** 无 TBD/TODO，所有步骤含完整代码。

**Type consistency:**
- `ThemeId` / `StyleId` 类型贯穿 Task 1→2→6→7 ✅
- `STYLE_METAS` / `STYLE_IDS` / `THEME_METAS` / `THEME_IDS` 命名一致 ✅
- `useTheme()` 返回值 `currentTheme`/`currentStyle`/`setTheme`/`setStyle` 在所有任务中一致 ✅
- `loadStyle()` 在 App.vue onLaunch 中调用（Task 2 Step 2）✅

**Implementation notes:**
- 现有 `THEME_METAS` 中现有 4 套主题的 `colors` 字段保留不动（被主题页预览使用）
- 新增 4 套主题也包含 `colors` 字段（Task 1 中已包含）
- `data-style` 默认不设置时，`:root` 的 `--card-border: none`/`--card-radius: 28rpx`/`--surface-alpha: 1` 保证向后兼容（Task 4 Step 1）
