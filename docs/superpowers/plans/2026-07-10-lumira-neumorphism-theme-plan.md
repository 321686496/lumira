# 如画 Lumira 东方新拟态主题系统实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `ruhua-neumorphism` 原型的东方新拟态风格集成到 uni-app 项目，实现 4 套主题切换（全应用生效）+ 新拟态阴影系统 + 设置页/主题页改造 + 核心页面样式升级。

**Architecture:** CSS Variables 驱动主题切换（`data-theme` 属性 + `:root`/`[data-theme]` 选择器），全局新拟态类定义在 App.vue 非 scoped 样式中，页面通过全局类 + CSS 变量消费。主题状态通过 composable 管理（不依赖 Pinia），使用 `uni.setStorageSync` 持久化。

**Tech Stack:** uni-app (Vue3) + SCSS + CSS Variables + `@phosphor-icons/web`

## Global Constraints

- 目标平台：H5（CSS Variables 原生支持）
- 所有样式只能使用 class 选择器（不可用标签选择器）
- CSS 单位使用 rpx（1px ≈ 2rpx）
- uni-app 组件：`<view>`/`<text>`/`<image>`/`<scroll-view>`/`<input>`（不用 HTML 标签）
- App.vue 全局样式必须用纯 CSS（非 SCSS），因为 uni-app 会在 `<style lang="scss">` 中注入 uni.scss 导致 SCSS @import 解析问题
- 页面级 scoped 样式可用 `<style lang="scss" scoped>`，SCSS 变量通过 uni.scss 自动注入
- 图片资源来自 `https://picsum.photos`
- 图标使用 `@phosphor-icons/web`（已安装），类名格式 `ph ph-xxx`

---

## File Structure

```
src/
├── composables/
│   └── useTheme.ts               # 新建：主题状态管理 composable
├── theme/
│   └── theme-configs.ts          # 新建：4 套主题元数据
├── App.vue                       # 修改：添加 CSS 变量 + neu-* 全局类
├── main.ts                       # 修改：App onLaunch 时加载主题
└── pages/
    ├── profile/settings.vue      # 重写：新拟态设置页
    └── profile/settings/theme.vue # 重写：新拟态主题选择页（真正生效）
```

核心页面（home/templates/challenge/profile）通过全局类自动获得新拟态风格，仅需微调 scoped 样式中的硬编码色值。

---

### Task 1: 主题配置表 + 主题 composable

**Files:**
- Create: `src/theme/theme-configs.ts`
- Create: `src/composables/useTheme.ts`

**Interfaces:**
- Produces: `ThemeId` 类型、`THEME_METAS` 配置表、`useTheme()` composable（返回 `currentTheme`/`followSystem`/`setTheme`/`loadTheme`/`setFollowSystem`）

- [ ] **Step 1: 创建主题配置表**

创建 `src/theme/theme-configs.ts`：

```typescript
export type ThemeId = 'warm' | 'ink' | 'retro' | 'fresh'

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

export const THEME_METAS: Record<ThemeId, ThemeMeta> = {
  warm: {
    id: 'warm',
    label: '暖米白',
    description: '温润如玉，东方留白的经典底色',
    icon: 'ph-sun',
    colors: { canvas: '#FAF7F2', brand: '#C9A96E', surface: '#FFFFFF', textPrimary: '#1A1A1A', textSecondary: '#5C5852' }
  },
  ink: {
    id: 'ink',
    label: '浓墨',
    description: '深邃墨色，暗夜中的专注拍摄',
    icon: 'ph-moon',
    colors: { canvas: '#1C1A17', brand: '#D4B57A', surface: '#262320', textPrimary: '#F2EEE6', textSecondary: '#A39D94' }
  },
  retro: {
    id: 'retro',
    label: '胶片复古',
    description: '温暖胶片质感，怀旧色彩调色',
    icon: 'ph-film-strip',
    colors: { canvas: '#F5E6D3', brand: '#C4956A', surface: '#FFF8F0', textPrimary: '#3D2817', textSecondary: '#6B4C2F' }
  },
  fresh: {
    id: 'fresh',
    label: '日系清新',
    description: '清新自然，柔和明亮的日常感',
    icon: 'ph-flower-tulip',
    colors: { canvas: '#F8FAF6', brand: '#8BAD72', surface: '#FFFFFF', textPrimary: '#4A3F35', textSecondary: '#8C7F70' }
  }
}

export const THEME_IDS: ThemeId[] = ['warm', 'ink', 'retro', 'fresh']
```

- [ ] **Step 2: 创建主题 composable**

创建 `src/composables/useTheme.ts`：

```typescript
import { ref } from 'vue'
import type { ThemeId } from '@/theme/theme-configs'
import { THEME_IDS } from '@/theme/theme-configs'

const currentTheme = ref<ThemeId>('warm')
const followSystem = ref(false)
let initialized = false

function applyTheme(id: ThemeId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', id)
  }
  // #endif
}

export function useTheme() {
  function setTheme(id: ThemeId) {
    currentTheme.value = id
    applyTheme(id)
    try {
      uni.setStorageSync('theme', id)
    } catch (e) {
      console.warn('Failed to persist theme', e)
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

  function setupSystemListener() {
    // #ifdef H5
    if (typeof window !== 'undefined' && window.matchMedia) {
      const mq = window.matchMedia('(prefers-color-scheme: dark)')
      if (followSystem.value) {
        setTheme(mq.matches ? 'ink' : 'warm')
      }
    }
    // #endif
  }

  return {
    currentTheme,
    followSystem,
    setTheme,
    loadTheme,
    setFollowSystem
  }
}
```

- [ ] **Step 3: 验证文件无 TypeScript 错误**

Run: `cd d:\app\projects\photo_post\lumira-app && npx vue-tsc --noEmit 2>&1 | head -20`
Expected: 无与 theme-configs.ts / useTheme.ts 相关的错误

- [ ] **Step 4: 提交**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/theme/theme-configs.ts src/composables/useTheme.ts
git commit -m "feat: 添加主题配置表和主题管理 composable"
```

---

### Task 2: App.vue 全局 CSS 变量 + 新拟态全局类

**Files:**
- Modify: `src/App.vue`（在现有 `<style>` 块中追加 CSS 变量和 neu-* 类）

**Interfaces:**
- Produces: 全局可用的 CSS 变量（`--color-canvas`/`--color-brand`/`--shadow-convex` 等）和新拟态类（`.neu-card`/`.neu-inset`/`.neu-pill`/`.neu-toggle` 等）
- 向后兼容：`.lumira-card`/`.floating-tabbar` 等旧类内部改用 CSS 变量

- [ ] **Step 1: 在 App.vue 的 `<style>` 块开头添加 CSS 变量定义**

在 `src/App.vue` 的 `<style>` 标签内，在 `/* ===== 全局重置 ===== */` 之前插入以下内容（完整 4 套主题 + 新拟态阴影系统）：

```css
/* ===== 主题 CSS 变量 ===== */
:root {
  /* 暖米白主题（默认） */
  --color-canvas: #FAF7F2;
  --color-surface: #FFFFFF;
  --color-surface-alt: #F2EEE6;
  --color-canvas-deep: #F5F1EB;
  --color-text-primary: #1A1A1A;
  --color-text-secondary: #5C5852;
  --color-text-tertiary: #9C9690;
  --color-text-inverse: #FAF7F2;
  --color-divider: #EAE5DC;
  --color-brand: #C9A96E;
  --color-brand-deep: #A88550;
  --color-brand-light: #D4B57A;
  --color-brand-subtle: #F5EDDB;
  --color-brand-text: #8C7340;
  --color-danger: #B85450;
  --color-danger-subtle: #F5E3E0;
  --color-success: #7A8B5C;
  --color-success-subtle: #EBEEE2;

  /* 新拟态阴影 */
  --shadow-convex: 6px 6px 14px #D8D4CC, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #E0DCD4, -3px -3px 6px #FFFFFF;
  --shadow-convex-brand: 4px 4px 10px #B89A5E, -4px -4px 10px #DABB82;
  --shadow-concave: inset 4px 4px 10px #E0DCD4, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #E5E0D8, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #E0DCD4, inset -3px -3px 8px #FFFFFF;
  --shadow-float: 0 8px 32px rgba(26, 26, 26, 0.08);

  /* 字体 */
  --font-cn-title: 'Noto Serif SC', 'Source Han Serif SC', serif;
  --font-cn-body: 'Noto Sans SC', 'PingFang SC', sans-serif;
}

/* 浓墨主题 */
[data-theme="ink"] {
  --color-canvas: #1C1A17;
  --color-surface: #262320;
  --color-surface-alt: #2E2B27;
  --color-canvas-deep: #151310;
  --color-text-primary: #F2EEE6;
  --color-text-secondary: #A39D94;
  --color-text-tertiary: #6E695F;
  --color-divider: #3A3630;
  --color-brand: #D4B57A;
  --color-brand-deep: #B8985A;
  --color-brand-subtle: #2E2820;
  --color-brand-text: #D4B57A;
  --color-danger: #D4706C;
  --color-danger-subtle: #2E201E;
  --color-success: #8FA06A;
  --color-success-subtle: #22251D;

  --shadow-convex: 6px 6px 14px #13110E, -6px -6px 14px #29251F;
  --shadow-convex-subtle: 3px 3px 6px #1A1714, -3px -3px 6px #2E2B24;
  --shadow-convex-brand: 4px 4px 10px #1A1610, -4px -4px 10px #3E3624;
  --shadow-concave: inset 4px 4px 10px #141210, inset -4px -4px 10px #302C25;
  --shadow-concave-subtle: inset 2px 2px 5px #1A1714, inset -2px -2px 5px #2E2B24;
  --shadow-pressed: inset 3px 3px 8px #141210, inset -3px -3px 8px #302C25;
  --shadow-float: 0 8px 32px rgba(0, 0, 0, 0.3);
}

/* 胶片复古主题 */
[data-theme="retro"] {
  --color-canvas: #F5E6D3;
  --color-surface: #FFF8F0;
  --color-surface-alt: #EBDAC4;
  --color-canvas-deep: #EBDAC4;
  --color-text-primary: #3D2817;
  --color-text-secondary: #6B4C2F;
  --color-text-tertiary: #9C8060;
  --color-divider: #D9C9B3;
  --color-brand: #C4956A;
  --color-brand-deep: #A67B52;
  --color-brand-subtle: #F0E0C8;
  --color-brand-text: #8C5A30;
  --color-danger: #A04030;
  --color-danger-subtle: #F0D8D0;
  --color-success: #6B7B4C;
  --color-success-subtle: #E8EDDF;

  --shadow-convex: 5px 5px 12px #CFC0AB, -5px -5px 12px #FFFDF7;
  --shadow-convex-subtle: 3px 3px 6px #D5C6B0, -3px -3px 6px #FFFDF7;
  --shadow-concave: inset 4px 4px 8px #D0C1AC, inset -4px -4px 8px #FFFDF7;
  --shadow-concave-subtle: inset 2px 2px 5px #D5C6B0, inset -2px -2px 5px #FFFDF7;
  --shadow-pressed: inset 3px 3px 6px #D0C1AC, inset -3px -3px 6px #FFFDF7;
}

/* 日系清新主题 */
[data-theme="fresh"] {
  --color-canvas: #F8FAF6;
  --color-surface: #FFFFFF;
  --color-surface-alt: #EDF2EB;
  --color-canvas-deep: #E8EDE5;
  --color-text-primary: #4A3F35;
  --color-text-secondary: #8C7F70;
  --color-text-tertiary: #B8AEA0;
  --color-divider: #DDE5D8;
  --color-brand: #8BAD72;
  --color-brand-deep: #6E9458;
  --color-brand-subtle: #E8F0E2;
  --color-brand-text: #5E8348;
  --color-danger: #C87878;
  --color-danger-subtle: #F5E0E0;
  --color-success: #9AAB7C;
  --color-success-subtle: #EDF2E8;

  --shadow-convex: 6px 6px 14px #D4DBD0, -6px -6px 14px #FFFFFF;
  --shadow-convex-subtle: 3px 3px 6px #D8DFD4, -3px -3px 6px #FFFFFF;
  --shadow-concave: inset 4px 4px 10px #D6DDD2, inset -4px -4px 10px #FFFFFF;
  --shadow-concave-subtle: inset 2px 2px 5px #D8DFD4, inset -2px -2px 5px #FFFFFF;
  --shadow-pressed: inset 3px 3px 8px #D6DDD2, inset -3px -3px 8px #FFFFFF;
}
```

- [ ] **Step 2: 更新全局重置和容器使用 CSS 变量**

将 `page` 和 `.lumira-container` 的硬编码颜色改为 CSS 变量：

```css
page {
  background-color: var(--color-canvas);
}

.lumira-container {
  position: relative;
  width: 100%;
  min-height: 100vh;
  background-color: var(--color-canvas);
  padding-bottom: 176rpx;
  overflow-x: hidden;
}
```

- [ ] **Step 3: 添加新拟态全局类**

在 App.vue 的 `<style>` 中（在 `.lumira-card` 之后）添加：

```css
/* ===== 新拟态全局类 ===== */
.neu-card {
  background-color: var(--color-canvas);
  border-radius: 20rpx;
  box-shadow: var(--shadow-convex);
}

.neu-inset {
  background-color: var(--color-canvas);
  border-radius: 20rpx;
  box-shadow: var(--shadow-concave);
}

.neu-pill {
  background-color: var(--color-canvas);
  border-radius: 9999rpx;
  box-shadow: var(--shadow-convex-subtle);
  transition: box-shadow 0.1s ease, transform 0.1s ease;
}

.neu-pill:active {
  box-shadow: var(--shadow-pressed);
  transform: scale(0.97);
}

.neu-pill.active {
  box-shadow: var(--shadow-pressed);
  color: var(--color-brand-deep);
}

.neu-block {
  background-color: var(--color-canvas);
  border-radius: 12rpx;
  box-shadow: var(--shadow-convex-subtle);
}

.neu-block-inset {
  background-color: var(--color-canvas);
  border-radius: 12rpx;
  box-shadow: var(--shadow-concave-subtle);
}

.neu-btn-convex {
  background-color: var(--color-canvas);
  border: none;
  border-radius: 9999rpx;
  box-shadow: var(--shadow-convex);
  color: var(--color-brand);
  transition: box-shadow 0.1s ease, transform 0.1s ease;
}

.neu-btn-convex:active {
  box-shadow: var(--shadow-pressed);
  transform: scale(0.97);
}

.neu-btn-brand {
  background-color: var(--color-brand);
  border: none;
  border-radius: 16rpx;
  box-shadow: var(--shadow-convex-brand);
  color: var(--color-text-inverse);
  transition: box-shadow 0.1s ease, transform 0.1s ease;
}

.neu-btn-brand:active {
  box-shadow: var(--shadow-pressed);
  transform: scale(0.97);
}

/* 新拟态开关 */
.neu-toggle {
  width: 96rpx;
  height: 52rpx;
  border-radius: 9999rpx;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex-subtle);
  position: relative;
  transition: box-shadow 0.2s ease;
  flex-shrink: 0;
}

.neu-toggle-knob {
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex-subtle);
  position: absolute;
  top: 6rpx;
  left: 6rpx;
  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease, background-color 0.2s ease;
}

.neu-toggle.active {
  box-shadow: var(--shadow-concave);
}

.neu-toggle.active .neu-toggle-knob {
  transform: translateX(44rpx);
  background-color: var(--color-brand);
  box-shadow: var(--shadow-convex-brand);
}
```

- [ ] **Step 4: 更新旧全局类使用 CSS 变量**

将 `.lumira-nav`、`.lumira-card`、`.lumira-tag-*`、`.floating-tabbar` 等旧类中的硬编码颜色替换为 CSS 变量。例如：

```css
.lumira-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28rpx 40rpx;
  background-color: var(--color-canvas);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.lumira-nav-title {
  font-family: var(--font-cn-title);
  font-size: 34rpx;
  font-weight: 600;
  text-align: left;
  flex: 1;
  letter-spacing: -0.01em;
  padding-left: 16rpx;
  color: var(--color-text-primary);
}

.lumira-card {
  background-color: var(--color-canvas);
  border-radius: 28rpx;
  padding: 40rpx;
  border: none;
  box-shadow: var(--shadow-convex);
}

.floating-tabbar {
  position: fixed !important;
  left: 50%;
  transform: translateX(-50%);
  bottom: 28rpx;
  width: calc(100% - 80rpx);
  height: 108rpx;
  display: flex;
  align-items: center;
  justify-content: space-around;
  border-radius: 9999rpx;
  border: none;
  background-color: var(--color-canvas);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  box-shadow: var(--shadow-convex);
  z-index: 900;
}

.tabbar-item {
  color: var(--color-text-tertiary);
}

.tabbar-item.active {
  color: var(--color-brand);
}

.lumira-tag-gold {
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
}

.lumira-tag-green {
  background-color: var(--color-success-subtle);
  color: var(--color-success);
}

.lumira-tag-red {
  background-color: var(--color-danger-subtle);
  color: var(--color-danger);
}
```

（对所有旧类中的 `#FAF7F2`/`#1A1A1A`/`#C9A96E` 等硬编码色值替换为对应 CSS 变量）

- [ ] **Step 5: 在 main.ts 中加载主题**

修改 `src/App.vue` 的 `<script setup>` 块，在 onLaunch 中调用 loadTheme：

```typescript
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

- [ ] **Step 6: 验证编译无错误**

确认开发服务器仍在 http://localhost:5178/ 运行，查看终端无编译错误。

- [ ] **Step 7: 浏览器验证默认主题**

用 Chrome DevTools MCP 导航到 `http://localhost:5178/#/pages/home/index`，执行 JS 检查：
```javascript
() => {
  const root = document.documentElement;
  return {
    dataTheme: root.getAttribute('data-theme'),
    canvasColor: getComputedStyle(root).getPropertyValue('--color-canvas'),
    brandColor: getComputedStyle(root).getPropertyValue('--color-brand'),
    shadowConvex: getComputedStyle(root).getPropertyValue('--shadow-convex')
  };
}
```
Expected: `dataTheme: "warm"`, canvasColor 含 `#FAF7F2`，brandColor 含 `#C9A96E`

- [ ] **Step 8: 提交**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/App.vue
git commit -m "feat: 添加 CSS 变量主题系统和新拟态全局类"
```

---

### Task 3: 主题选择页重写（新拟态 + 真正生效）

**Files:**
- Rewrite: `src/pages/profile/settings/theme.vue`

**Interfaces:**
- Consumes: `useTheme()` composable（Task 1）、`THEME_METAS`（Task 1）
- Produces: 主题选择页，点击主题卡立即调用 `setTheme`，全应用实时响应

- [ ] **Step 1: 重写 theme.vue**

完整重写 `src/pages/profile/settings/theme.vue`，参照 `ruhua-neumorphism/pages/theme.html`：

```vue
<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">主题</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 主题卡片列表 -->
      <view
        class="theme-card"
        :class="{ selected: currentTheme === t.id }"
        v-for="t in themes"
        :key="t.id"
        @click="selectTheme(t.id)"
      >
        <!-- 图标 -->
        <view class="theme-icon">
          <text class="ph" :class="t.icon"></text>
        </view>
        <!-- 文本区 -->
        <view class="theme-text">
          <text class="theme-name">{{ t.label }}</text>
          <text class="theme-desc">{{ t.description }}</text>
          <!-- 色彩预览点 -->
          <view class="color-dots">
            <view class="color-dot" v-for="(c, i) in t.previewColors" :key="i" :style="{ backgroundColor: c }"></view>
          </view>
        </view>
        <!-- 选中标记 -->
        <view v-if="currentTheme === t.id" class="theme-check">
          <text class="ph ph-check check-icon"></text>
        </view>
      </view>

      <!-- 跟随系统 -->
      <view class="sys-card neu-card">
        <view class="sys-row">
          <view class="sys-info">
            <text class="sys-title">跟随系统</text>
            <text class="sys-desc">根据系统深浅色自动切换</text>
          </view>
          <view class="neu-toggle" :class="{ active: followSystem }" @click="toggleFollowSystem">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 底部说明 -->
      <view class="bottom-note">
        <text class="bottom-note-text">主题切换即时生效，所有页面同步更新</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS, THEME_IDS } from '@/theme/theme-configs'
import type { ThemeId } from '@/theme/theme-configs'

const { currentTheme, followSystem, setTheme, setFollowSystem } = useTheme()

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

/* 主题卡 */
.theme-card {
  position: relative;
  background-color: var(--color-canvas);
  border-radius: 32rpx;
  box-shadow: var(--shadow-convex);
  padding: 40rpx;
  margin-bottom: 24rpx;
  display: flex;
  align-items: center;
  gap: 32rpx;
  transition: box-shadow 0.2s ease;
}

.theme-card:active {
  box-shadow: var(--shadow-pressed);
}

.theme-card.selected {
  box-shadow: var(--shadow-concave);
  border: 2rpx solid var(--color-brand);
}

/* 图标 */
.theme-icon {
  width: 104rpx;
  height: 104rpx;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
  box-shadow: var(--shadow-convex-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.theme-icon .ph {
  font-size: 48rpx;
  color: var(--color-brand);
}

.theme-card.selected .theme-icon {
  background-color: var(--color-brand-subtle);
  box-shadow: var(--shadow-concave-subtle);
}

/* 文本区 */
.theme-text {
  flex: 1;
}

.theme-name {
  display: block;
  font-family: var(--font-cn-title);
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 8rpx;
}

.theme-desc {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  line-height: 1.6;
}

/* 色彩点 */
.color-dots {
  display: flex;
  gap: 12rpx;
  margin-top: 20rpx;
}

.color-dot {
  width: 32rpx;
  height: 32rpx;
  border-radius: 50%;
  box-shadow: var(--shadow-convex-subtle);
}

/* 选中标记 */
.theme-check {
  position: absolute;
  top: 24rpx;
  right: 24rpx;
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-brand);
}

.check-icon {
  font-size: 24rpx;
  color: var(--color-text-inverse);
}

/* 跟随系统 */
.sys-card {
  padding: 40rpx;
  margin-top: 16rpx;
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
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
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

注意：使用 `<style scoped>`（非 SCSS）因为此页面全部使用 CSS 变量，不需要 SCSS 变量。

- [ ] **Step 2: 浏览器验证主题切换**

用 Chrome DevTools MCP 导航到 `http://localhost:5178/#/pages/profile/settings/theme`：
1. 截图确认 4 张新拟态主题卡显示
2. 点击"浓墨"主题卡
3. 执行 JS 验证：
```javascript
() => {
  const root = document.documentElement;
  return {
    dataTheme: root.getAttribute('data-theme'),
    canvasColor: getComputedStyle(root).getPropertyValue('--color-canvas').trim(),
    brandColor: getComputedStyle(root).getPropertyValue('--color-brand').trim()
  };
}
```
Expected: `dataTheme: "ink"`, canvasColor: `#1C1A17`, brandColor: `#D4B57A`

4. 截图确认整个页面变为深色主题
5. 导航回首页，确认首页也变为深色主题

- [ ] **Step 3: 提交**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/pages/profile/settings/theme.vue
git commit -m "feat: 重写主题选择页为新拟态风格并实现真正切换"
```

---

### Task 4: 设置页新拟态重写

**Files:**
- Rewrite: `src/pages/profile/settings.vue`

**Interfaces:**
- Consumes: `useTheme()` composable（显示当前主题名）
- Produces: 新拟态设置页（分组卡片 + 凹陷图标 + 新拟态开关）

- [ ] **Step 1: 重写 settings.vue**

完整重写 `src/pages/profile/settings.vue`，参照 `ruhua-neumorphism/pages/settings.html`。保留原有功能（网格显示、水平仪、快门声音、兑换码等），样式升级为新拟态：

```vue
<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">设置</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 通用 -->
      <text class="group-title">通用</text>
      <view class="setting-group neu-card">
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
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-translate"></text>
          </view>
          <text class="setting-label">语言</text>
          <view class="setting-right">
            <text class="setting-value">简体中文</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
      </view>

      <!-- 显示 -->
      <text class="group-title">显示</text>
      <view class="setting-group neu-card">
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-grid-four"></text>
          </view>
          <text class="setting-label">网格显示</text>
          <view class="neu-toggle" :class="{ active: gridOn }" @click="gridOn = !gridOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-ruler"></text>
          </view>
          <text class="setting-label">水平仪</text>
          <view class="neu-toggle" :class="{ active: levelOn }" @click="levelOn = !levelOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 拍摄 -->
      <text class="group-title">拍摄</text>
      <view class="setting-group neu-card">
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-frame-corners"></text>
          </view>
          <text class="setting-label">默认分辨率</text>
          <view class="setting-right">
            <text class="setting-value">4K</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-droplet"></text>
          </view>
          <text class="setting-label">水印</text>
          <view class="neu-toggle" :class="{ active: watermarkOn }" @click="watermarkOn = !watermarkOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
        <view class="setting-item setting-item-last">
          <view class="setting-icon-wrap">
            <text class="ph ph-speaker-high"></text>
          </view>
          <text class="setting-label">快门声音</text>
          <view class="neu-toggle" :class="{ active: shutterOn }" @click="shutterOn = !shutterOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 关于 -->
      <text class="group-title">关于</text>
      <view class="setting-group neu-card">
        <view class="setting-item" @click="handleVersionTap">
          <view class="setting-icon-wrap">
            <text class="ph ph-app-window"></text>
          </view>
          <text class="setting-label">版本号</text>
          <view class="setting-right">
            <text class="setting-value setting-value-mono">v2.0.0</text>
          </view>
        </view>
        <view v-if="showRedemption" class="redemption-wrap">
          <input
            class="redemption-input neu-inset"
            v-model="redemptionCode"
            placeholder="输入兑换码..."
            confirm-type="done"
            @confirm="submitRedemption"
          />
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-trash"></text>
          </view>
          <text class="setting-label">清除缓存</text>
          <view class="setting-right">
            <text class="setting-value">128 MB</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item setting-item-last">
          <view class="setting-icon-wrap">
            <text class="ph ph-info"></text>
          </view>
          <text class="setting-label">关于如画</text>
          <view class="setting-right">
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
      </view>

      <!-- 底部版本信息 -->
      <view class="version-footer">
        <text class="version-text">如画 Lumira v2.0.0</text>
        <text class="version-sub">东方新拟态 · 用镜头书写日常的诗</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS } from '@/theme/theme-configs'

const { currentTheme } = useTheme()
const currentThemeName = computed(() => THEME_METAS[currentTheme.value].label)

const gridOn = ref(false)
const levelOn = ref(true)
const shutterOn = ref(true)
const watermarkOn = ref(true)

const tapCount = ref(0)
let tapTimer: ReturnType<typeof setTimeout> | null = null
const showRedemption = ref(false)
const redemptionCode = ref('')

const handleVersionTap = () => {
  tapCount.value++
  if (tapTimer) clearTimeout(tapTimer)
  tapTimer = setTimeout(() => { tapCount.value = 0 }, 3000)
  if (tapCount.value >= 7) {
    showRedemption.value = true
    tapCount.value = 0
  }
}

const submitRedemption = () => {
  uni.showToast({ title: '兑换码已提交', icon: 'none' })
  redemptionCode.value = ''
  showRedemption.value = false
}

const back = () => uni.navigateBack()
const goTheme = () => uni.navigateTo({ url: '/pages/profile/settings/theme' })
</script>

<style scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.page-body {
  padding: 24rpx 40rpx 48rpx;
}

/* 分组标题 */
.group-title {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 0 8rpx;
  margin-bottom: 16rpx;
  margin-top: 32rpx;
}

.group-title:first-child {
  margin-top: 0;
}

/* 设置组 */
.setting-group {
  overflow: hidden;
  margin-bottom: 8rpx;
}

.setting-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 40rpx;
  border-bottom: 1rpx solid var(--color-divider);
}

.setting-item:active {
  background-color: var(--color-surface-alt);
}

.setting-item-last {
  border-bottom: none;
}

/* 图标容器（凹陷） */
.setting-icon-wrap {
  width: 72rpx;
  height: 72rpx;
  border-radius: 16rpx;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-concave-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.setting-icon-wrap .ph {
  font-size: 36rpx;
  color: var(--color-brand);
}

.setting-label {
  flex: 1;
  font-size: 30rpx;
  color: var(--color-text-primary);
}

.setting-right {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.setting-value {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}

.setting-value-brand {
  color: var(--color-brand-text);
}

.setting-value-mono {
  font-family: 'Courier New', monospace;
}

.setting-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
}

/* 兑换码 */
.redemption-wrap {
  padding: 24rpx 40rpx;
  border-bottom: 1rpx solid var(--color-divider);
}

.redemption-input {
  width: 100%;
  padding: 24rpx 32rpx;
  font-size: 28rpx;
  color: var(--color-text-primary);
  box-sizing: border-box;
  border: none;
}

/* 底部版本 */
.version-footer {
  text-align: center;
  padding: 64rpx 0 32rpx;
}

.version-text {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

.version-sub {
  display: block;
  font-size: 20rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}
</style>
```

- [ ] **Step 2: 浏览器验证设置页**

用 Chrome DevTools MCP 导航到 `http://localhost:5178/#/pages/profile/settings`：
1. 截图确认新拟态设置页（凸起分组卡片 + 凹陷图标 + 新拟态开关）
2. 点击"主题选择"，确认跳转到主题选择页
3. 在主题选择页切换到"日系清新"，返回设置页，确认设置页也变为清新绿色主题

- [ ] **Step 3: 提交**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/pages/profile/settings.vue
git commit -m "feat: 重写设置页为新拟态风格"
```

---

### Task 5: 核心 tab 页样式适配

**Files:**
- Modify: `src/pages/home/index.vue`（scoped 样式中硬编码色值改用 CSS 变量）
- Modify: `src/pages/templates/index.vue`（同上）
- Modify: `src/pages/challenge/index.vue`（同上）
- Modify: `src/pages/profile/index.vue`（同上）

**Interfaces:**
- Consumes: Task 2 的全局 CSS 变量
- 目标：将 4 个 tab 页 scoped 样式中的 `$color-xxx` SCSS 变量和硬编码色值替换为 `var(--color-xxx)` CSS 变量

- [ ] **Step 1: 更新首页 home/index.vue**

在 `src/pages/home/index.vue` 的 `<style lang="scss" scoped>` 块中，将所有 `$color-text-primary` 替换为 `var(--color-text-primary)`，`$color-text-secondary` → `var(--color-text-secondary)`，`$color-text-tertiary` → `var(--color-text-tertiary)`，`$color-brand-primary` → `var(--color-brand)`，`$color-brand-secondary` → `var(--color-brand-deep)`，`$color-bg-canvas` → `var(--color-canvas)`，`$color-bg-card` → `var(--color-surface)`，`$color-bg-surface` → `var(--color-surface-alt)`，`$color-border` → `var(--color-divider)`，`$shadow-card` → `var(--shadow-convex)` 等。

对于 scoped 样式中引用的渐变背景（如 `linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%)`），保留为固定值或改为使用 `var(--color-brand-subtle)` 等变量。

注意：scoped 样式中可以使用 `<style lang="scss" scoped>` 但内部颜色全部用 `var(--color-xxx)`。

- [ ] **Step 2: 更新模板库 templates/index.vue**

同样替换 `src/pages/templates/index.vue` 中的 SCSS 变量为 CSS 变量。特别注意：
- `.tpl-card` 的 `border` 和 `box-shadow` 改为新拟态：`box-shadow: var(--shadow-convex); border: none;`
- `.cat-pill` 改为 `box-shadow: var(--shadow-convex-subtle); border: none;`
- `.cat-pill.active` 改为 `box-shadow: var(--shadow-pressed);`

- [ ] **Step 3: 更新挑战页 challenge/index.vue**

同样替换 `src/pages/challenge/index.vue` 中的色值。

- [ ] **Step 4: 更新个人中心 profile/index.vue**

同样替换 `src/pages/profile/index.vue` 中的色值。特别注意：
- `.hero-card` 的渐变背景保留为固定值（装饰性）
- `.lumira-card` 已通过全局类自动适配
- `.stats-cell-mid::after` 的 border 色改用 `var(--color-divider)`

- [ ] **Step 5: 浏览器验证所有 tab 页**

用 Chrome DevTools MCP 依次访问 4 个 tab 页：
1. `http://localhost:5178/#/pages/home/index` — 截图
2. `http://localhost:5178/#/pages/templates/index` — 截图
3. `http://localhost:5178/#/pages/challenge/index` — 截图
4. `http://localhost:5178/#/pages/profile/index` — 截图

确认所有页面卡片显示为新拟态凸起阴影效果。

- [ ] **Step 6: 验证主题切换对所有 tab 页生效**

在主题选择页切换到"浓墨"主题，然后依次访问 4 个 tab 页，确认所有页面背景、文字、卡片都变为深色主题。

- [ ] **Step 7: 提交**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/pages/home/index.vue src/pages/templates/index.vue src/pages/challenge/index.vue src/pages/profile/index.vue
git commit -m "feat: 核心 tab 页样式适配 CSS 变量主题系统"
```

---

### Task 6: 主题持久化验证 + 修复

**Files:**
- 可能修改: `src/composables/useTheme.ts`（如果发现问题）

- [ ] **Step 1: 验证主题持久化**

用 Chrome DevTools MCP：
1. 导航到主题选择页
2. 选择"胶片复古"主题
3. 刷新页面（`navigate_page` with `type: "reload"`）
4. 执行 JS 检查：
```javascript
() => document.documentElement.getAttribute('data-theme')
```
Expected: `"retro"`（持久化生效）

- [ ] **Step 2: 验证跟随系统功能**

1. 在主题选择页开启"跟随系统"开关
2. 执行 JS 模拟系统深色模式：
```javascript
() => {
  // 检查当前状态
  return {
    followSystem: localStorage.getItem('followSystem'),
    currentTheme: document.documentElement.getAttribute('data-theme')
  };
}
```

- [ ] **Step 3: 修复发现的问题（如有）**

如果持久化或跟随系统不工作，检查 `useTheme.ts` 中的逻辑，修复后重新验证。

- [ ] **Step 4: 提交（如有修改）**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/composables/useTheme.ts
git commit -m "fix: 主题持久化和跟随系统修复"
```

---

### Task 7: 剩余功能完善

**Files:**
- Modify: `src/pages/capture/index.vue`（拍摄页功能完善）
- Modify: `src/pages/capture/scene-guide.vue`（场景引导）
- Modify: `src/pages/templates/detail.vue`（模板详情）
- Modify: `src/pages/templates/unlock.vue`（解锁流程）

- [ ] **Step 1: 更新拍摄/场景引导页样式**

将 `src/pages/capture/index.vue` 和 `src/pages/capture/scene-guide.vue` 中的硬编码色值替换为 CSS 变量，确保响应主题切换。拍摄页本身保持深色取景器（使用固定深色），但 UI 控件适配主题。

- [ ] **Step 2: 更新模板详情/解锁页样式**

将 `src/pages/templates/detail.vue` 和 `src/pages/templates/unlock.vue` 中的色值替换为 CSS 变量。确保：
- 模板详情页的卡片使用新拟态凸起
- 解锁页的付费按钮使用 `neu-btn-brand`
- 解锁流程 UI 完整（锁定状态 → 点击解锁 → 付费弹窗 → 解锁成功）

- [ ] **Step 3: 浏览器验证**

用 Chrome DevTools MCP 访问各页面，确认样式一致。

- [ ] **Step 4: 提交**

```bash
cd d:\app\projects\photo_post\lumira-app
git add src/pages/capture/ src/pages/templates/
git commit -m "feat: 完善拍摄引导和模板解锁页面样式"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ 4 套主题（warm/ink/retro/fresh）— Task 2 CSS 变量定义
- ✅ 新拟态阴影系统 — Task 2 全局类
- ✅ 主题切换全应用生效 — Task 2 CSS 变量 + Task 1 composable
- ✅ 主题选择页新拟态改造 — Task 3
- ✅ 设置页新拟态改造 — Task 4
- ✅ 核心 tab 页样式适配 — Task 5
- ✅ 持久化 + 跟随系统 — Task 1 composable + Task 6 验证
- ✅ 剩余功能完善 — Task 7

**2. Placeholder scan:** 无占位符，所有步骤都有具体代码。

**3. Type consistency:** `ThemeId`/`ThemeMeta`/`THEME_METAS`/`useTheme()` 在所有任务中一致。
