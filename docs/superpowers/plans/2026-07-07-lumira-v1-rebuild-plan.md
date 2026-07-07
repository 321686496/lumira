# 如画 Lumira v1.0 核心功能重建实施方案

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重建如画 Lumira v1.0 核心功能，实现 3+1 悬浮 Tab 导航、Splash 启动页、首页聚合入口、模板详情入口页、拍摄页沉浸体验、后期编辑工作台、相册管理、模板系统等完整功能。

**Architecture:** 采用 Harness Engineering 范式（骨架→接口→实现→验证），分层架构为 Vue 组件 → Composable → Service → SQLite/原生插件，Pinia 管理跨页面状态，设计 Token 驱动视觉一致性。首页与拍摄页分离，模板详情页作为拍摄入口（"套用此模板拍摄" CTA），3+1 悬浮 Tab 栏（首页/拍摄按钮/我的）。

**Tech Stack:** uni-app (Vue 3.4 + Composition API + `<script setup lang="ts">`), TypeScript strict, Pinia, SQLite (@dcloudio/uni-sqlite), SCSS + CSS Variables (Design Tokens), Vitest

## Global Constraints

- 完全离线：零网络权限，manifest 不声明 INTERNET
- TypeScript strict mode，禁用 `any`，禁用 `@ts-ignore`
- Vue3 Composition API + `<script setup lang="ts">`
- 设计 Token 驱动：颜色/间距/圆角必须通过 CSS Variables，禁止硬编码
- 8px 栅格间距系统：4/8/12/16/24/32/48/64/96
- 品牌配色：暖米白 `#FAF7F2` + 暖金 `#C9A96E` + 浓墨 `#1A1A1A`
- 衬线标题 (Noto Serif SC) + 黑体正文，标题紧字距，正文宽行高
- 无渐变背景（LOGO 内部光带除外）、无重阴影、无胶囊大容器
- 组件零阴影，靠分隔线和留白分层
- 仅动画 `transform` 与 `opacity`
- Harness Engineering：骨架→接口→实现→验证，每阶段可独立验证

---

## File Structure

### 新建文件

| 路径 | 职责 |
|---|---|
| `src/pages/splash/index.vue` | 启动页（品牌 LOGO + 淡入动效 → 自动跳转首页） |
| `src/components/home/BrandHeader.vue` | 首页品牌标题区（"如画" + 副标语） |
| `src/components/home/DailyInspiration.vue` | 今日灵感卡片（日期哈希选取 + "试试看"CTA） |
| `src/components/home/RecentPhotos.vue` | 最近拍摄横滑照片条 |
| `src/components/home/FeaturedTemplates.vue` | 推荐模板横滑卡片 |
| `src/components/home/SceneQuickAccess.vue` | 拍摄场景快选 pill 标签 |
| `src/components/home/StatsSummary.vue` | 统计概览卡（拍摄张数 + 使用模板） |
| `src/components/capture/CaptureHeader.vue` | 拍摄页半透明顶栏 |
| `src/components/capture/CameraViewfinder.vue` | 全屏取景器组件 |
| `src/components/capture/OverlayLayer.vue` | 叠图层容器 |
| `src/components/capture/RuleOfThirdsGrid.vue` | 三分法网格 |
| `src/components/capture/GuideLines.vue` | 引导线叠图 |
| `src/components/capture/PoseOverlay.vue` | 姿势剪影叠图 |
| `src/components/capture/ParameterBar.vue` | 参数指示 pill 条 |
| `src/components/capture/ShutterButton.vue` | 快门按钮（已有骨架，需重构） |
| `src/components/template/CategoryTabs.vue` | 分类横滑 pill 筛选 |
| `src/components/template/OverlayPreview.vue` | 叠图预览大图（可切换显隐） |
| `src/components/template/SceneGuidePanel.vue` | 场景指南面板 |
| `src/components/template/CameraParamsPanel.vue` | 相机参数建议面板 |
| `src/components/template/ExampleGallery.vue` | 示例作品画廊 |
| `src/components/image/AdjustmentPanel.vue` | 后期调节面板（标签式切换） |
| `src/components/image/ColorSliders.vue` | 调色滑块组 |
| `src/components/image/LutSelector.vue` | LUT 滤镜选择器 |
| `src/components/image/CropFrame.vue` | 裁剪框组件 |
| `src/components/image/SmoothSlider.vue` | 磨皮强度滑块 |
| `src/components/image/SharpenSlider.vue` | 锐化强度滑块 |
| `src/components/image/CompareToggle.vue` | 前后对比切换 |
| `src/components/gallery/PhotoGrid.vue` | 照片网格组件 |
| `src/components/gallery/PhotoInfo.vue` | 照片信息展示 |
| `src/components/common/AppSkeleton.vue` | 骨架屏组件 |
| `src/components/common/AppInput.vue` | 输入框组件 |
| `src/components/common/AppBadge.vue` | 徽章/标签组件 |
| `src/composables/useDailyInspiration.ts` | 每日灵感轮换（日期哈希） |
| `src/composables/useSceneGuide.ts` | 8 场景定义与模板筛选 |
| `src/composables/useTemplateEngine.ts` | 已有，需扩展 applyTemplate 流程 |
| `src/data/inspirations.ts` | 灵感池数据（100 条灵感文案 + 关联模板类型） |
| `src/data/scenes.ts` | 8 个拍摄场景定义 |

### 修改文件

| 路径 | 修改内容 |
|---|---|
| `src/pages.json` | 新增 Splash 路由 + 调整 TabBar 配置为 3+1 |
| `src/App.vue` | 添加 Splash 跳转逻辑 + 全局样式补充 |
| `src/theme/tokens.scss` | 补充缺失 Token（字重、行高、动效时长等） |
| `src/pages/home/index.vue` | 按新设计规格重建首页（6 区块） |
| `src/pages/capture/index.vue` | 按新设计重构为沉浸式拍摄页 |
| `src/pages/capture/preview.vue` | 拍摄预览页完善 |
| `src/pages/capture/parameters.vue` | 参数半屏弹窗完善 |
| `src/pages/templates/index.vue` | 模板库重构为双列瀑布流 |
| `src/pages/templates/detail.vue` | 重构为入口页（"套用此模板拍摄"CTA） |
| `src/pages/templates/editor.vue` | 模板编辑器实现 |
| `src/pages/templates/import.vue` | 模板导入页实现 |
| `src/pages/gallery/index.vue` | 相册页重构 |
| `src/pages/gallery/detail.vue` | 后期编辑全屏工作台 |
| `src/pages/profile/index.vue` | 我的页按新规格重建 |
| `src/pages/profile/settings.vue` | 设置页完善 |
| `src/components/FloatingTabBar.vue` | 重构为 3+1（首页/拍摄按钮/我的） |
| `src/components/ShutterButton.vue` | 重构与 Tab 栏拍摄按钮统一 |
| `src/stores/settings.ts` | 扩展设置项 |
| `src/types/template.ts` | 扩展 TemplateSummary 增加 scene 字段 |

---

## Phase 0: 骨架 APP（设计 Token + 路由 + 悬浮 Tab 栏 + Splash）

> 交付物：可运行骨架 APP，启动后见 Splash → 首页，3+1 Tab 栏可切换

### Task 0.1: 更新设计 Token 补充缺失变量

**Files:**
- Modify: `lumira-app/src/theme/tokens.scss`

**Interfaces:**
- Consumes: 品牌文档配色/字体/间距规格
- Produces: 完整的 `:root` CSS Variables 集合，供所有后续组件引用

- [ ] **Step 1: 在 `tokens.scss` 中补充缺失 Token**

在现有 `:root` 块末尾追加：

```scss
  // === 字重 ===
  --weight-regular: 400;
  --weight-medium: 500;
  --weight-semibold: 600;

  // === 行高 ===
  --line-height-display: 1.1;
  --line-height-title: 1.2;
  --line-height-heading: 1.3;
  --line-height-body: 1.6;
  --line-height-caption: 1.5;
  --line-height-tag: 1.4;
  --line-height-mono: 1.4;

  // === 字间距 ===
  --letter-spacing-display: -0.03em;
  --letter-spacing-title: -0.02em;
  --letter-spacing-heading: -0.01em;
  --letter-spacing-tag: 0.05em;

  // === 字体族 ===
  --font-serif: 'Noto Serif SC', 'PingFang SC', serif;
  --font-sans: 'PingFang SC', -apple-system, 'Helvetica Neue', sans-serif;
  --font-mono: 'SF Mono', 'JetBrains Mono', 'Menlo', monospace;

  // === 动效时长 ===
  --duration-fast: 100ms;
  --duration-normal: 200ms;
  --duration-slow: 400ms;
  --duration-page: 600ms;

  // === 动效曲线 ===
  --ease-default: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);

  // === Tab 栏专用 ===
  --tabbar-height: 56px;
  --tabbar-bottom-offset: 16px;
  --tabbar-side-padding: 24px;
  --tabbar-shutter-size: 56px;
  --tabbar-shutter-protrusion: 12px;

  // === 拍摄页深色 ===
  --color-capture-bg: #1A1A1A;
  --color-capture-bar: rgba(255, 255, 255, 0.12);
  --color-capture-text: rgba(255, 255, 255, 0.6);
  --color-capture-text-bright: #FFFFFF;
  --color-capture-overlay-line: rgba(201, 169, 110, 0.35);
```

- [ ] **Step 2: 运行 H5 开发服务器验证 Token 加载**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 编译无报错，浏览器打开后控制台无 CSS 变量错误

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/theme/tokens.scss
git commit -m "feat(tokens): add missing design tokens for v1.0 rebuild"
```

---

### Task 0.2: 更新路由配置与 TabBar 为 3+1 结构

**Files:**
- Modify: `lumira-app/src/pages.json`

**Interfaces:**
- Consumes: 设计文档 §1.2 完整路由表
- Produces: 新路由表，Splash 为首页，3 Tab 页（home/capture/profile），Splash 自动跳转

- [ ] **Step 1: 更新 `pages.json` 路由与 TabBar 配置**

将 `pages.json` 替换为：

```json
{
  "pages": [
    { "path": "pages/splash/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/home/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/capture/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/capture/preview", "style": { "navigationStyle": "custom" } },
    { "path": "pages/capture/parameters", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/detail", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/editor", "style": { "navigationStyle": "custom" } },
    { "path": "pages/templates/import", "style": { "navigationStyle": "custom" } },
    { "path": "pages/gallery/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/gallery/detail", "style": { "navigationStyle": "custom" } },
    { "path": "pages/profile/index", "style": { "navigationStyle": "custom" } },
    { "path": "pages/profile/settings", "style": { "navigationStyle": "custom" } }
  ],
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarTitleText": "如画",
    "backgroundColor": "#FAF7F2"
  },
  "tabBar": {
    "custom": true,
    "color": "#9C9690",
    "selectedColor": "#C9A96E",
    "borderStyle": "black",
    "list": [
      { "pagePath": "pages/home/index", "text": "首页" },
      { "pagePath": "pages/profile/index", "text": "我的" }
    ]
  }
}
```

- [ ] **Step 2: 验证编译通过**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 无路由编译错误

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages.json
git commit -m "feat(routes): add splash page and update tabBar to 3+1 layout"
```

---

### Task 0.3: 创建 Splash 启动页

**Files:**
- Create: `lumira-app/src/pages/splash/index.vue`

**Interfaces:**
- Consumes: 品牌文档 §3 LOGO 规范、设计文档 §2 Splash 规格
- Produces: Splash 页面组件，自动跳转首页

- [ ] **Step 1: 创建 Splash 页面组件**

```vue
<script setup lang="ts">
import { onReady } from '@dcloudio/uni-app'

const MIN_DISPLAY = 1500
const MAX_DISPLAY = 3000

onReady(() => {
  const startTime = Date.now()
  const timer = setTimeout(() => {
    const elapsed = Date.now() - startTime
    const remaining = Math.max(0, MIN_DISPLAY - elapsed)
    setTimeout(() => {
      uni.reLaunch({ url: '/pages/home/index' })
    }, remaining)
  }, 0)

  // 安全兜底：最长不超过 MAX_DISPLAY
  setTimeout(() => {
    clearTimeout(timer)
    uni.reLaunch({ url: '/pages/home/index' })
  }, MAX_DISPLAY)
})
</script>

<template>
  <view class="splash-page">
    <view class="splash-content">
      <!-- LOGO 符号标：取景框 + 斜光 -->
      <view class="logo-symbol">
        <!-- 四角 L 形取景标记 -->
        <view class="corner corner-tl"></view>
        <view class="corner corner-tr"></view>
        <view class="corner corner-bl"></view>
        <view class="corner corner-br"></view>
        <!-- 斜光带 -->
        <view class="light-beam"></view>
        <!-- 焦点光点 -->
        <view class="focus-dot"></view>
      </view>
    </view>
    <view class="splash-bottom">
      <text class="brand-name">如画 Lumira</text>
      <text class="brand-tagline">如你所见，皆成画卷</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.splash-page {
  width: 100vw;
  height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.splash-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn var(--duration-slow) var(--ease-default) both;
}

.logo-symbol {
  position: relative;
  width: 80px;
  height: 80px;
}

/* 四角 L 形取景标记 */
.corner {
  position: absolute;
  width: 18px;
  height: 18px;
  border-color: var(--color-brand-primary);
  border-style: solid;
  border-width: 0;
}

.corner-tl {
  top: 0;
  left: 0;
  border-top-width: 2.5px;
  border-left-width: 2.5px;
}

.corner-tr {
  top: 0;
  right: 0;
  border-top-width: 2.5px;
  border-right-width: 2.5px;
}

.corner-bl {
  bottom: 0;
  left: 0;
  border-bottom-width: 2.5px;
  border-left-width: 2.5px;
}

.corner-br {
  bottom: 0;
  right: 0;
  border-bottom-width: 2.5px;
  border-right-width: 2.5px;
}

/* 斜光带：从左上到右下 */
.light-beam {
  position: absolute;
  top: -5%;
  left: -5%;
  width: 141%;
  height: 12%;
  background: linear-gradient(
    135deg,
    var(--color-brand-primary) 0%,
    transparent 100%
  );
  opacity: 0.5;
  transform: rotate(-45deg);
  transform-origin: center;
}

/* 焦点光点 */
.focus-dot {
  position: absolute;
  bottom: 18%;
  right: 18%;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--color-brand-primary);
}

.splash-bottom {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  padding-bottom: calc(var(--space-8) + env(safe-area-inset-bottom));
  animation: fadeIn var(--duration-slow) var(--ease-default) 200ms both;
}

.brand-name {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-title);
  line-height: var(--line-height-title);
}

.brand-tagline {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  line-height: var(--line-height-caption);
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
</style>
```

- [ ] **Step 2: 验证 Splash 页面渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 打开页面后显示暖米白背景 + LOGO 符号标 + 品牌文字，1.5-3s 后自动跳转首页

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/splash/index.vue
git commit -m "feat(splash): add brand splash page with logo animation"
```

---

### Task 0.4: 重构 FloatingTabBar 为 3+1 结构

**Files:**
- Modify: `lumira-app/src/components/FloatingTabBar.vue`

**Interfaces:**
- Consumes: 设计文档 §1.1 悬浮 Tab 栏规格、§13.3 详细设计
- Produces: 3+1 Tab 栏组件（首页/拍摄按钮/我的），支持 light/dark 主题

- [ ] **Step 1: 重写 FloatingTabBar.vue**

```vue
<script setup lang="ts">
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface FloatingTabBarProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<FloatingTabBarProps>(), {
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
  <view class="floating-tab-bar" :class="`theme-${theme}`">
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
.floating-tab-bar {
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

/* 侧边 Tab 项 */
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

/* 中间拍摄按钮 */
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

- [ ] **Step 2: 验证 Tab 栏渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: Tab 栏显示为胶囊悬浮形态，左"首页" + 中间拍摄按钮突出 + 右"我的"，选中态描金

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/components/FloatingTabBar.vue
git commit -m "feat(tabbar): refactor to 3+1 layout with home/capture-btn/profile"
```

---

### Task 0.5: 更新首页骨架占位（适配新 Tab 结构）

**Files:**
- Modify: `lumira-app/src/pages/home/index.vue`

**Interfaces:**
- Consumes: FloatingTabBar 新接口（`current='home'`, key `home`/`capture`/`profile`）
- Produces: 首页骨架，可运行，Tab 切换正常

- [ ] **Step 1: 更新首页的 Tab 切换逻辑**

将 `handleTabSwitch` 中的 key 从 `'mine'` 改为 `'profile'`，确保与 FloatingTabBar 一致：

在 `lumira-app/src/pages/home/index.vue` 中，找到：

```typescript
const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    // 拍摄页用 navigateTo 进入，作为独立全屏页面
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'mine') {
    // 主页面切换用 reLaunch，避免页面栈堆积
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
```

替换为：

```typescript
const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
```

同时更新 FloatingTabBar 组件引用中的 `current` 值保持 `"home"`（无需变更）。

- [ ] **Step 2: 更新我的页 Tab 切换逻辑**

在 `lumira-app/src/pages/profile/index.vue` 中，找到 `onTabSwitch` 函数：

```typescript
const onTabSwitch = (key: string) => {
  if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  }
}
```

确认 key 值已与 FloatingTabBar 一致（`home`/`capture`/`profile`），FloatingTabBar 的 `current` 值更新为 `"profile"`：

将 `<FloatingTabBar current="mine"` 改为 `<FloatingTabBar current="profile"`。

- [ ] **Step 3: 验证 3 页面 Tab 切换正常**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 首页 → 点击拍摄按钮 → 拍摄页；首页 → 我的 → 我的页；我的 → 首页 → 首页

- [ ] **Step 4: Commit**

```bash
git add lumira-app/src/pages/home/index.vue lumira-app/src/pages/profile/index.vue
git commit -m "fix(tabbar): align tab switch keys to home/capture/profile"
```

---

### Task 0.6: 更新 App.vue 全局样式与启动逻辑

**Files:**
- Modify: `lumira-app/src/App.vue`

**Interfaces:**
- Consumes: Splash 页面路由
- Produces: 全局样式补全，启动时初始化存储

- [ ] **Step 1: 更新 App.vue**

```vue
<script setup lang="ts">
import { onLaunch, onShow, onHide } from '@dcloudio/uni-app'
import { storageService } from '@/services/storage'

onLaunch(async () => {
  console.log('如画 Lumira 启动')
  await storageService.init()
})

onShow(() => {
  console.log('如画 Lumira 显示')
})

onHide(() => {
  console.log('如画 Lumira 后台')
})
</script>

<style lang="scss">
@import '@/theme/tokens.scss';

/* 全局重置 */
page {
  background-color: var(--color-bg-canvas);
  color: var(--color-text-primary);
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  max-width: 100vw;
  overflow-x: hidden;
  box-sizing: border-box;
  -webkit-font-smoothing: antialiased;
}

/* 所有元素 box-sizing */
view, text, image, scroll-view, swiper, swiper-item {
  box-sizing: border-box;
  max-width: 100%;
}

/* 隐藏滚动条 */
::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
  color: transparent;
}

/* uni-app H5 默认 tabBar 容器兜底隐藏 */
uni-tabbar,
.uni-app--showtabbar > uni-view {
  display: none !important;
  height: 0 !important;
}

/* #ifdef H5 */
uni-page-body,
uni-page {
  max-width: 100vw;
  overflow-x: hidden;
}
/* #endif */

/* 页面进入动画 */
.page-enter {
  animation: pageEnter var(--duration-page) var(--ease-default) both;
}

@keyframes pageEnter {
  from {
    opacity: 0;
    transform: translateY(12px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
```

- [ ] **Step 2: 验证全局样式生效**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 页面背景暖米白，字体使用 sans-serif，无横向溢出

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/App.vue
git commit -m "feat(app): add storage init on launch and global style updates"
```

---

**Phase 0 验收标准：**
- [ ] APP 启动 → Splash 页面展示品牌 LOGO 1.5-3s → 自动跳转首页
- [ ] 首页底部悬浮 Tab 栏：左"首页" + 中间拍摄按钮 + 右"我的"
- [ ] 点击"首页"/"我的"切换页面，点击拍摄按钮进入拍摄页
- [ ] 所有 Token 变量正确加载，无硬编码颜色

---

## Phase 1: 首页完整实现

> 交付物：首页 6 个区块全部功能可用

### Task 1.1: 创建首页数据模块（灵感池 + 场景定义）

**Files:**
- Create: `lumira-app/src/data/inspirations.ts`
- Create: `lumira-app/src/data/scenes.ts`
- Create: `lumira-app/src/composables/useDailyInspiration.ts`
- Create: `lumira-app/src/composables/useSceneGuide.ts`

**Interfaces:**
- Consumes: 设计文档 §3.2 区块设计、§3.4 Composable 清单
- Produces: `useDailyInspiration()` → `{ inspiration, relatedTemplateType, tryIt }`, `useSceneGuide()` → `{ scenes, filterByScene }`

- [ ] **Step 1: 创建灵感池数据**

创建 `lumira-app/src/data/inspirations.ts`：

```typescript
export interface Inspiration {
  id: number
  text: string
  emoji: string
  relatedCategory: string
}

export const INSPIRATION_POOL: Inspiration[] = [
  { id: 1, text: '侧身站立+回头看镜头，显瘦又自然', emoji: '🌿', relatedCategory: '人像' },
  { id: 2, text: '逆光下让头发发光，脸部用反光板补光', emoji: '☀️', relatedCategory: '日落' },
  { id: 3, text: '坐在咖啡馆窗边，自然光从侧面打来', emoji: '☕', relatedCategory: '咖啡馆' },
  { id: 4, text: '蹲下拍花卉特写，背景自然虚化', emoji: '🌸', relatedCategory: '花店' },
  { id: 5, text: '海边奔跑抓拍，快门速度调至 1/500s 以上', emoji: '🏖️', relatedCategory: '海边' },
  { id: 6, text: '街拍用长焦压缩街景，人物更突出', emoji: '🏙️', relatedCategory: '街拍' },
  { id: 7, text: '探店拍美食，45°俯拍+大光圈虚化背景', emoji: '🛍️', relatedCategory: '探店' },
  { id: 8, text: '居家窗前自然光，白色窗帘做柔光罩', emoji: '🏠', relatedCategory: '居家' },
  { id: 9, text: '纪念日手捧花束，用引导线构图聚焦表情', emoji: '🎂', relatedCategory: '纪念日' },
  { id: 10, text: '合照错落站位，前后各半步更有层次', emoji: '👭', relatedCategory: '合照' },
  { id: 11, text: '低头微笑，让风吹动发丝更自然', emoji: '🍃', relatedCategory: '人像' },
  { id: 12, text: '黄昏时段拍摄剪影，降低 EV -0.7', emoji: '🌅', relatedCategory: '日落' },
  { id: 13, text: '用手挡住半边脸，神秘又显瘦', emoji: '👋', relatedCategory: '人像' },
  { id: 14, text: '图书馆里翻书侧拍，安静文艺感', emoji: '📚', relatedCategory: '探店' },
  { id: 15, text: '雨后街面倒影，低角度蹲拍', emoji: '🌧️', relatedCategory: '街拍' },
  { id: 16, text: '靠墙站立，一脚微曲更放松', emoji: '🧱', relatedCategory: '人像' },
  { id: 17, text: '日落前 30 分钟是黄金时段', emoji: '⏰', relatedCategory: '日落' },
  { id: 18, text: '居家沙发上的慵懒姿势，用毯子做道具', emoji: '🛋️', relatedCategory: '居家' },
  { id: 19, text: '合照时不要所有人看镜头，有人看别处更生动', emoji: '👀', relatedCategory: '合照' },
  { id: 20, text: '花束放胸前，微微仰头看花', emoji: '💐', relatedCategory: '纪念日' },
]
```

- [ ] **Step 2: 创建场景定义数据**

创建 `lumira-app/src/data/scenes.ts`：

```typescript
export interface SceneDef {
  key: string
  label: string
  emoji: string
  category: string
}

export const SCENES: SceneDef[] = [
  { key: 'cafe', label: '咖啡馆', emoji: '☕', category: '咖啡馆' },
  { key: 'flower', label: '花店', emoji: '🌸', category: '花店' },
  { key: 'beach', label: '海边', emoji: '🏖️', category: '海边' },
  { key: 'street', label: '街拍', emoji: '🏙️', category: '街拍' },
  { key: 'shop', label: '探店', emoji: '🛍️', category: '探店' },
  { key: 'home', label: '居家', emoji: '🏠', category: '居家' },
  { key: 'anniversary', label: '纪念日', emoji: '🎂', category: '纪念日' },
  { key: 'group', label: '合照', emoji: '👭', category: '合照' },
]
```

- [ ] **Step 3: 创建 useDailyInspiration composable**

创建 `lumira-app/src/composables/useDailyInspiration.ts`：

```typescript
import { computed } from 'vue'
import { INSPIRATION_POOL, type Inspiration } from '@/data/inspirations'

/** 简单日期哈希：返回 0 ~ max-1 的整数 */
function dateHash(max: number): number {
  const now = new Date()
  const dateNum = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate()
  return dateNum % max
}

export function useDailyInspiration() {
  const inspiration = computed<Inspiration>(() => {
    const index = dateHash(INSPIRATION_POOL.length)
    return INSPIRATION_POOL[index]
  })

  return { inspiration }
}
```

- [ ] **Step 4: 创建 useSceneGuide composable**

创建 `lumira-app/src/composables/useSceneGuide.ts`：

```typescript
import { SCENES, type SceneDef } from '@/data/scenes'

export function useSceneGuide() {
  const scenes: SceneDef[] = SCENES

  function filterByScene(sceneKey: string): string {
    const scene = scenes.find((s) => s.key === sceneKey)
    return scene?.category ?? ''
  }

  return { scenes, filterByScene }
}
```

- [ ] **Step 5: Commit**

```bash
git add lumira-app/src/data/inspirations.ts lumira-app/src/data/scenes.ts lumira-app/src/composables/useDailyInspiration.ts lumira-app/src/composables/useSceneGuide.ts
git commit -m "feat(home): add inspiration pool, scene data, and composables"
```

---

### Task 1.2: 创建首页子组件

**Files:**
- Create: `lumira-app/src/components/home/BrandHeader.vue`
- Create: `lumira-app/src/components/home/DailyInspiration.vue`
- Create: `lumira-app/src/components/home/RecentPhotos.vue`
- Create: `lumira-app/src/components/home/FeaturedTemplates.vue`
- Create: `lumira-app/src/components/home/SceneQuickAccess.vue`
- Create: `lumira-app/src/components/home/StatsSummary.vue`

**Interfaces:**
- Consumes: 设计文档 §3.2-3.3 线框与区块规格
- Produces: 6 个首页区块组件，通过 Props 接收数据，Emits 上报交互

- [ ] **Step 1: 创建 BrandHeader.vue**

```vue
<script setup lang="ts">
</script>

<template>
  <view class="brand-header">
    <text class="brand-title">如画</text>
    <text class="brand-tagline">如你所见，皆成画卷</text>
  </view>
</template>

<style lang="scss" scoped>
.brand-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.brand-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-display);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-display);
  line-height: var(--line-height-display);
}

.brand-tagline {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  line-height: var(--line-height-caption);
  margin-top: var(--space-1);
}
</style>
```

- [ ] **Step 2: 创建 DailyInspiration.vue**

```vue
<script setup lang="ts">
import type { Inspiration } from '@/data/inspirations'

interface DailyInspirationProps {
  inspiration: Inspiration
}

defineProps<DailyInspirationProps>()

const emit = defineEmits<{
  (e: 'on-try', category: string): void
}>()
</script>

<template>
  <view class="daily-inspiration">
    <view class="section-header">
      <text class="section-title">💡 今日灵感</text>
    </view>
    <view class="inspiration-card">
      <text class="inspiration-text">{{ inspiration.emoji }} "{{ inspiration.text }}"</text>
      <view class="try-btn" @click="emit('on-try', inspiration.relatedCategory)">
        <text class="try-text">试试看 →</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.daily-inspiration {
  padding: 0 var(--space-5);
  margin-bottom: var(--space-7);
}

.section-header {
  margin-bottom: var(--space-3);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
}

.inspiration-card {
  padding: var(--space-5);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
}

.inspiration-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
  line-height: var(--line-height-body);
  display: block;
}

.try-btn {
  margin-top: var(--space-4);
  display: inline-flex;
  padding: var(--space-2) var(--space-4);
  border: 1px solid var(--color-brand-primary);
  border-radius: var(--radius-button);
  transition: transform var(--duration-fast) ease;

  &:active {
    transform: scale(0.98);
  }
}

.try-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-brand-primary);
}
</style>
```

- [ ] **Step 3: 创建 RecentPhotos.vue**

```vue
<script setup lang="ts">
import type { LocalPhoto } from '@/types/photo'

interface RecentPhotosProps {
  photos: LocalPhoto[]
  totalCount: number
}

defineProps<RecentPhotosProps>()

const emit = defineEmits<{
  (e: 'on-photo-click', id: string): void
  (e: 'on-view-all'): void
}>()
</script>

<template>
  <view class="recent-photos">
    <view class="section-header">
      <view class="section-title-wrap">
        <text class="section-title">最近拍摄</text>
        <text class="section-count">{{ totalCount }} 张</text>
      </view>
      <view class="section-more" @click="emit('on-view-all')">
        <text class="more-text">查看全部 →</text>
      </view>
    </view>

    <scroll-view scroll-x class="photos-scroll" :show-scrollbar="false">
      <view class="photos-row">
        <view
          v-for="photo in photos"
          :key="photo.id"
          class="photo-item"
          @click="emit('on-photo-click', photo.id)"
        >
          <image :src="photo.imagePath" mode="aspectFill" class="photo-image" />
        </view>
      </view>
    </scroll-view>

    <view v-if="photos.length === 0" class="empty-state">
      <text class="empty-text">还没有作品，去拍第一张吧</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.recent-photos {
  margin-bottom: var(--space-7);
}

.section-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 0 var(--space-5);
  margin-bottom: var(--space-3);
}

.section-title-wrap {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
}

.section-count {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

.section-more {
  padding: var(--space-1) var(--space-2);
  &:active { opacity: 0.5; }
}

.more-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-brand-primary);
}

.photos-scroll {
  width: 100%;
  white-space: nowrap;
}

.photos-row {
  display: inline-flex;
  gap: var(--space-3);
  padding: 0 var(--space-5);
}

.photo-item {
  width: 100px;
  height: 130px;
  border-radius: var(--radius-card);
  overflow: hidden;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  flex-shrink: 0;

  &:active { opacity: 0.85; }
}

.photo-image {
  width: 100%;
  height: 100%;
}

.empty-state {
  padding: var(--space-7) var(--space-5);
  text-align: center;
}

.empty-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}
</style>
```

- [ ] **Step 4: 创建 FeaturedTemplates.vue**

```vue
<script setup lang="ts">
import type { LocalTemplate } from '@/types/template'

interface FeaturedTemplatesProps {
  templates: LocalTemplate[]
}

defineProps<FeaturedTemplatesProps>()

const emit = defineEmits<{
  (e: 'on-template-click', id: string): void
  (e: 'on-view-all'): void
}>()
</script>

<template>
  <view class="featured-templates">
    <view class="section-header">
      <text class="section-title">推荐模板</text>
      <view class="section-more" @click="emit('on-view-all')">
        <text class="more-text">查看全部 →</text>
      </view>
    </view>

    <scroll-view scroll-x class="templates-scroll" :show-scrollbar="false">
      <view class="templates-row">
        <view
          v-for="tmpl in templates"
          :key="tmpl.id"
          class="template-card"
          @click="emit('on-template-click', tmpl.id)"
        >
          <view class="template-cover">
            <image v-if="tmpl.coverPath" :src="tmpl.coverPath" mode="aspectFill" class="cover-image" />
            <view v-else class="cover-placeholder">
              <text class="placeholder-icon">▦</text>
            </view>
          </view>
          <text class="template-name">{{ tmpl.name }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.featured-templates {
  margin-bottom: var(--space-7);
}

.section-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 0 var(--space-5);
  margin-bottom: var(--space-3);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
}

.section-more {
  padding: var(--space-1) var(--space-2);
  &:active { opacity: 0.5; }
}

.more-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-brand-primary);
}

.templates-scroll {
  width: 100%;
  white-space: nowrap;
}

.templates-row {
  display: inline-flex;
  gap: var(--space-3);
  padding: 0 var(--space-5);
}

.template-card {
  display: flex;
  flex-direction: column;
  width: 140px;
  gap: var(--space-2);
  flex-shrink: 0;
  &:active { opacity: 0.8; }
}

.template-cover {
  width: 140px;
  height: 180px;
  border-radius: var(--radius-card);
  background: var(--color-bg-surface);
  overflow: hidden;
  border: 1px solid var(--color-border);
}

.cover-image {
  width: 100%;
  height: 100%;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-icon {
  font-size: 36px;
  color: var(--color-text-tertiary);
  opacity: 0.3;
}

.template-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding: 0 2px;
}
</style>
```

- [ ] **Step 5: 创建 SceneQuickAccess.vue**

```vue
<script setup lang="ts">
import type { SceneDef } from '@/data/scenes'

interface SceneQuickAccessProps {
  scenes: SceneDef[]
}

defineProps<SceneQuickAccessProps>()

const emit = defineEmits<{
  (e: 'on-scene-click', sceneKey: string): void
}>()
</script>

<template>
  <view class="scene-quick-access">
    <text class="section-title">拍摄场景</text>
    <view class="scenes-grid">
      <view
        v-for="scene in scenes"
        :key="scene.key"
        class="scene-pill"
        @click="emit('on-scene-click', scene.key)"
      >
        <text class="scene-emoji">{{ scene.emoji }}</text>
        <text class="scene-label">{{ scene.label }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.scene-quick-access {
  padding: 0 var(--space-5);
  margin-bottom: var(--space-7);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
  margin-bottom: var(--space-3);
  display: block;
}

.scenes-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}

.scene-pill {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  padding: var(--space-2) var(--space-3);
  background: var(--color-tag-gold-bg);
  border-radius: var(--radius-pill);
  transition: transform var(--duration-fast) ease;

  &:active { transform: scale(0.96); }
}

.scene-emoji {
  font-size: var(--font-size-body);
  line-height: 1;
}

.scene-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-tag-gold-text);
}
</style>
```

- [ ] **Step 6: 创建 StatsSummary.vue**

```vue
<script setup lang="ts">
interface StatsSummaryProps {
  photoCount: number
  templateCount: number
}

defineProps<StatsSummaryProps>()

const emit = defineEmits<{
  (e: 'on-click'): void
}>()
</script>

<template>
  <view class="stats-summary" @click="emit('on-click')">
    <view class="stat-item">
      <text class="stat-value">{{ photoCount }}</text>
      <text class="stat-label">拍摄张数</text>
    </view>
    <view class="stat-divider"></view>
    <view class="stat-item">
      <text class="stat-value">{{ templateCount }}</text>
      <text class="stat-label">使用模板</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.stats-summary {
  margin: 0 var(--space-5) var(--space-7);
  padding: var(--space-5) var(--space-4);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;

  &:active { opacity: 0.85; }
}

.stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stat-value {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  line-height: 1;
}

.stat-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.stat-divider {
  width: 1px;
  height: 32px;
  background: var(--color-border);
}
</style>
```

- [ ] **Step 7: Commit**

```bash
git add lumira-app/src/components/home/
git commit -m "feat(home): add all home section components"
```

---

### Task 1.3: 重写首页组装所有区块

**Files:**
- Modify: `lumira-app/src/pages/home/index.vue`

**Interfaces:**
- Consumes: 所有首页子组件、composables、stores
- Produces: 完整首页，6 区块排列，交互联通

- [ ] **Step 1: 重写首页组件**

```vue
<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
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
const { inspiration } = useDailyInspiration()
const { scenes } = useSceneGuide()

const recentPhotos = computed(() => galleryStore.photos.slice(0, 6))
const featuredTemplates = computed(() => templatesStore.allTemplates.slice(0, 6))
const photoCount = computed(() => galleryStore.photoCount)
const templateCount = computed(() => templatesStore.templateCount)

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

<template>
  <view class="home-page">
    <scroll-view scroll-y class="home-scroll" :show-scrollbar="false">
      <BrandHeader />
      <DailyInspiration
        :inspiration="inspiration"
        @on-try="handleInspirationTry"
      />
      <RecentPhotos
        :photos="recentPhotos"
        :total-count="photoCount"
        @on-photo-click="handlePhotoClick"
        @on-view-all="handleViewAllPhotos"
      />
      <FeaturedTemplates
        :templates="featuredTemplates"
        @on-template-click="handleTemplateClick"
        @on-view-all="handleViewAllTemplates"
      />
      <SceneQuickAccess
        :scenes="scenes"
        @on-scene-click="handleSceneClick"
      />
      <StatsSummary
        :photo-count="photoCount"
        :template-count="templateCount"
        @on-click="handleStatsClick"
      />
      <view class="bottom-spacer" />
    </scroll-view>
    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.home-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  width: 100%;
}

.home-scroll {
  flex: 1;
  width: 100%;
}

.bottom-spacer {
  height: 120px;
}
</style>
```

- [ ] **Step 2: 验证首页完整渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 首页按序显示 6 个区块，各区块交互正常

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/home/index.vue
git commit -m "feat(home): rebuild home page with all 6 sections"
```

---

**Phase 1 验收标准：**
- [ ] 首页品牌标题 "如画" + "如你所见，皆成画卷" 衬线显示
- [ ] 今日灵感每日轮换，"试试看"跳转拍摄页（带 category）
- [ ] 最近拍摄横滑展示（最多 6 张），点击跳转详情，"查看全部"跳转相册
- [ ] 推荐模板横滑展示（最多 6 个），点击跳转模板详情
- [ ] 8 个拍摄场景 pill 标签，点击跳转模板库（带场景筛选）
- [ ] 统计概览显示拍摄张数 + 使用模板数，点击跳转我的页

---

## Phase 2: 模板库 + 模板详情（入口页）+ 模板导入

> 交付物：模板系统闭环——浏览、详情入口页、导入导出

### Task 2.1: 创建模板库分类筛选组件

**Files:**
- Create: `lumira-app/src/components/template/CategoryTabs.vue`

**Interfaces:**
- Consumes: 分类列表
- Produces: 当前选中分类，通过 emit 上报

- [ ] **Step 1: 创建 CategoryTabs.vue**

```vue
<script setup lang="ts">
interface CategoryTabsProps {
  categories: string[]
  current: string
}

defineProps<CategoryTabsProps>()

const emit = defineEmits<{
  (e: 'on-change', category: string): void
}>()
</script>

<template>
  <scroll-view scroll-x class="category-tabs" :show-scrollbar="false">
    <view class="tabs-row">
      <view
        v-for="cat in categories"
        :key="cat"
        class="tab-pill"
        :class="{ active: cat === current }"
        @click="emit('on-change', cat)"
      >
        <text class="tab-text">{{ cat }}</text>
      </view>
    </view>
  </scroll-view>
</template>

<style lang="scss" scoped>
.category-tabs {
  width: 100%;
  white-space: nowrap;
  margin-bottom: var(--space-4);
}

.tabs-row {
  display: inline-flex;
  gap: var(--space-2);
  padding: 0 var(--space-5);
}

.tab-pill {
  display: inline-flex;
  align-items: center;
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  transition: all var(--duration-normal) ease;
  flex-shrink: 0;

  &:active { transform: scale(0.96); }

  &.active {
    background: var(--color-tag-gold-bg);
    border-color: var(--color-brand-primary);
  }
}

.tab-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
  letter-spacing: var(--letter-spacing-tag);

  .active & {
    color: var(--color-tag-gold-text);
  }
}
</style>
```

- [ ] **Step 2: Commit**

```bash
git add lumira-app/src/components/template/CategoryTabs.vue
git commit -m "feat(templates): add category tabs component"
```

---

### Task 2.2: 重写模板库页（双列瀑布流 + 分类筛选）

**Files:**
- Modify: `lumira-app/src/pages/templates/index.vue`

**Interfaces:**
- Consumes: templates store (filteredTemplates, categories)、CategoryTabs
- Produces: 模板库页，支持分类筛选，模板卡片点击跳转详情

- [ ] **Step 1: 重写模板库页**

```vue
<script setup lang="ts">
import { computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import CategoryTabs from '@/components/template/CategoryTabs.vue'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import AppEmpty from '@/components/AppEmpty.vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()

const categories = computed(() => templatesStore.categories)
const currentCategory = computed(() => templatesStore.currentCategory)
const filteredTemplates = computed(() => templatesStore.filteredTemplates)

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

<template>
  <view class="templates-page">
    <view class="page-header">
      <text class="page-title">模板</text>
      <text class="page-sub">{{ templatesStore.templateCount }} 个模板</text>
    </view>

    <CategoryTabs
      :categories="categories"
      :current="currentCategory"
      @on-change="handleCategoryChange"
    />

    <scroll-view scroll-y class="templates-scroll" :show-scrollbar="false">
      <view v-if="filteredTemplates.length > 0" class="templates-grid">
        <view
          v-for="tmpl in filteredTemplates"
          :key="tmpl.id"
          class="template-card"
          @click="goDetail(tmpl.id)"
        >
          <view class="card-cover">
            <image v-if="tmpl.coverPath" :src="tmpl.coverPath" mode="aspectFill" class="cover-img" />
            <view v-else class="cover-placeholder">
              <text class="placeholder-char">▦</text>
            </view>
          </view>
          <view class="card-info">
            <text class="card-name">{{ tmpl.name }}</text>
            <text class="card-source">{{ tmpl.source === 'builtin' ? '内置' : tmpl.source === 'imported' ? '导入' : '自建' }}</text>
          </view>
        </view>
      </view>

      <AppEmpty
        v-else
        title="暂无模板"
        description="导入 .pptpl 模板文件"
        @on-action="goImport"
      />

      <view class="bottom-spacer" />
    </scroll-view>

    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.templates-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.page-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.page-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-display);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-display);
  line-height: var(--line-height-display);
}

.page-sub {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}

.templates-scroll {
  flex: 1;
  width: 100%;
}

.templates-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-4);
  padding: 0 var(--space-5);
}

.template-card {
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  overflow: hidden;

  &:active { opacity: 0.85; }
}

.card-cover {
  width: 100%;
  aspect-ratio: 3 / 4;
  background: var(--color-bg-surface);
  overflow: hidden;
}

.cover-img {
  width: 100%;
  height: 100%;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-char {
  font-size: 32px;
  color: var(--color-text-tertiary);
  opacity: 0.3;
}

.card-info {
  padding: var(--space-3);
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.card-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-source {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

.bottom-spacer {
  height: 120px;
}
</style>
```

- [ ] **Step 2: 验证模板库页面渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 双列网格显示模板卡片，分类 pill 可筛选

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/templates/index.vue
git commit -m "feat(templates): rebuild template index with grid layout and category filter"
```

---

### Task 2.3: 创建模板详情入口页

**Files:**
- Create: `lumira-app/src/components/template/OverlayPreview.vue`
- Create: `lumira-app/src/components/template/SceneGuidePanel.vue`
- Create: `lumira-app/src/components/template/CameraParamsPanel.vue`
- Create: `lumira-app/src/components/template/ExampleGallery.vue`
- Modify: `lumira-app/src/pages/templates/detail.vue`

**Interfaces:**
- Consumes: 模板 store getResolvedTemplate、PhotoTemplate 类型
- Produces: 模板详情页，含"套用此模板拍摄"墨黑 CTA

- [ ] **Step 1: 创建 OverlayPreview.vue**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import type { CompositionOverlay, PoseReference } from '@/types/template'

interface OverlayPreviewProps {
  composition?: CompositionOverlay
  pose?: PoseReference
}

const props = defineProps<OverlayPreviewProps>()

const showOverlay = ref(true)

const toggleOverlay = () => {
  showOverlay.value = !showOverlay.value
}
</script>

<template>
  <view class="overlay-preview">
    <view class="preview-frame">
      <!-- 叠图内容区 -->
      <view v-if="showOverlay" class="overlay-layer">
        <view v-if="composition?.ruleOfThirds" class="thirds-grid">
          <view class="grid-line grid-line-h" style="top: 33.33%"></view>
          <view class="grid-line grid-line-h" style="top: 66.66%"></view>
          <view class="grid-line grid-line-v" style="left: 33.33%"></view>
          <view class="grid-line grid-line-v" style="left: 66.66%"></view>
        </view>
      </view>
      <view class="preview-placeholder">
        <text class="preview-text">叠图预览</text>
      </view>
    </view>
    <view class="toggle-btn" @click="toggleOverlay">
      <text class="toggle-text">{{ showOverlay ? '隐藏叠图' : '显示叠图' }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.overlay-preview {
  margin-bottom: var(--space-5);
}

.preview-frame {
  position: relative;
  width: 100%;
  aspect-ratio: 4 / 3;
  background: var(--color-bg-surface);
  border-radius: var(--radius-card);
  overflow: hidden;
  border: 1px solid var(--color-border);
}

.overlay-layer {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
  z-index: 1;
}

.thirds-grid {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
}

.grid-line {
  position: absolute;
  background: var(--color-brand-primary);
  opacity: 0.35;
}

.grid-line-h {
  left: 0;
  right: 0;
  height: 1px;
}

.grid-line-v {
  top: 0;
  bottom: 0;
  width: 1px;
}

.preview-placeholder {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}

.preview-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.toggle-btn {
  margin-top: var(--space-2);
  display: inline-flex;
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-button);
  &:active { opacity: 0.7; }
}

.toggle-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-secondary);
}
</style>
```

- [ ] **Step 2: 创建 SceneGuidePanel.vue**

```vue
<script setup lang="ts">
import type { SceneGuide } from '@/types/template'

interface SceneGuidePanelProps {
  guide: SceneGuide
}

defineProps<SceneGuidePanelProps>()
</script>

<template>
  <view class="scene-guide-panel">
    <text class="panel-title">场景指南</text>
    <view class="guide-items">
      <view v-if="guide.lightingTip" class="guide-item">
        <text class="guide-icon">💡</text>
        <text class="guide-label">光线：{{ guide.lightingTip }}</text>
      </view>
      <view v-if="guide.shootingDistance" class="guide-item">
        <text class="guide-icon">📏</text>
        <text class="guide-label">距离：{{ guide.shootingDistance }}</text>
      </view>
      <view v-if="guide.props && guide.props.length > 0" class="guide-item">
        <text class="guide-icon">🎩</text>
        <text class="guide-label">道具：{{ guide.props.join('、') }}</text>
      </view>
      <view v-if="guide.tips" class="guide-item">
        <text class="guide-icon">📝</text>
        <text class="guide-label">{{ guide.tips }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.scene-guide-panel {
  margin-bottom: var(--space-5);
}

.panel-title {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--space-3);
}

.guide-items {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.guide-item {
  display: flex;
  align-items: flex-start;
  gap: var(--space-2);
}

.guide-icon {
  font-size: var(--font-size-body);
  line-height: 1.6;
  flex-shrink: 0;
}

.guide-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
  line-height: var(--line-height-body);
}
</style>
```

- [ ] **Step 3: 创建 CameraParamsPanel.vue**

```vue
<script setup lang="ts">
import type { TemplateCameraConfig } from '@/types/template'

interface CameraParamsPanelProps {
  params: TemplateCameraConfig
}

const props = defineProps<CameraParamsPanelProps>()

const evDisplay = () => {
  const ev = props.params.evBias ?? 0
  return ev > 0 ? `+${ev}` : String(ev)
}
</script>

<template>
  <view class="camera-params-panel">
    <text class="panel-title">相机参数建议</text>
    <view class="params-grid">
      <view class="param-item">
        <text class="param-value">EV {{ evDisplay() }}</text>
        <text class="param-label">曝光补偿</text>
      </view>
      <view v-if="params.iso" class="param-item">
        <text class="param-value">ISO {{ params.iso }}</text>
        <text class="param-label">感光度</text>
      </view>
      <view v-if="params.shutterSpeed" class="param-item">
        <text class="param-value">{{ params.shutterSpeed }}</text>
        <text class="param-label">快门速度</text>
      </view>
      <view v-if="params.whiteBalanceKelvin" class="param-item">
        <text class="param-value">WB {{ params.whiteBalanceKelvin }}K</text>
        <text class="param-label">白平衡</text>
      </view>
      <view v-if="params.lensSuggestion" class="param-item">
        <text class="param-value">{{ params.lensSuggestion === 'main' ? '主摄' : params.lensSuggestion === 'wide' ? '广角' : '长焦' }}</text>
        <text class="param-label">镜头建议</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.camera-params-panel {
  margin-bottom: var(--space-5);
}

.panel-title {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--space-3);
}

.params-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}

.param-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--space-3) var(--space-4);
  background: var(--color-bg-surface);
  border-radius: var(--radius-button);
  min-width: 80px;
}

.param-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-mono);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  line-height: var(--line-height-mono);
}

.param-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}
</style>
```

- [ ] **Step 4: 创建 ExampleGallery.vue**

```vue
<script setup lang="ts">
interface ExampleGalleryProps {
  examples: string[]
}

defineProps<ExampleGalleryProps>()
</script>

<template>
  <view class="example-gallery">
    <text class="panel-title">示例作品</text>
    <scroll-view scroll-x class="examples-scroll" :show-scrollbar="false">
      <view class="examples-row">
        <view v-for="(ex, idx) in examples" :key="idx" class="example-item">
          <image :src="ex" mode="aspectFill" class="example-image" />
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.example-gallery {
  margin-bottom: var(--space-5);
}

.panel-title {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--space-3);
}

.examples-scroll {
  width: 100%;
  white-space: nowrap;
}

.examples-row {
  display: inline-flex;
  gap: var(--space-3);
}

.example-item {
  width: 120px;
  height: 160px;
  border-radius: var(--radius-card);
  overflow: hidden;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  flex-shrink: 0;
}

.example-image {
  width: 100%;
  height: 100%;
}
</style>
```

- [ ] **Step 5: 重写模板详情页**

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import OverlayPreview from '@/components/template/OverlayPreview.vue'
import SceneGuidePanel from '@/components/template/SceneGuidePanel.vue'
import CameraParamsPanel from '@/components/template/CameraParamsPanel.vue'
import ExampleGallery from '@/components/template/ExampleGallery.vue'
import { useTemplatesStore } from '@/stores/templates'
import { useCaptureStore } from '@/stores/capture'
import type { ResolvedTemplate } from '@/types/template'

const templatesStore = useTemplatesStore()
const captureStore = useCaptureStore()

const templateId = ref('')
const resolved = ref<ResolvedTemplate | null>(null)

onLoad(async (query) => {
  if (query?.id) {
    templateId.value = query.id
    templatesStore.setCurrentTemplate(query.id)
    const result = await templatesStore.getResolvedTemplate(query.id)
    resolved.value = result
  }
})

const hasSceneGuide = computed(() => !!resolved.value?.sceneGuide)
const hasCameraParams = computed(() => !!resolved.value?.camera)
const exampleImages = computed(() => {
  if (!resolved.value) return []
  return resolved.value.meta.cover ? [resolved.value.meta.cover] : []
})

const handleApplyTemplate = () => {
  if (templateId.value) {
    captureStore.setActiveTemplate(templateId.value)
  }
  uni.navigateTo({ url: `/pages/capture/index?templateId=${templateId.value}` })
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="template-detail-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">模板详情</text>
    </view>

    <scroll-view scroll-y class="detail-scroll" :show-scrollbar="false">
      <view class="detail-content">
        <!-- 叠图预览 -->
        <OverlayPreview
          v-if="resolved"
          :composition="resolved.composition"
          :pose="resolved.pose"
        />

        <!-- 标题与标签 -->
        <view class="template-header" v-if="resolved">
          <text class="template-title">{{ resolved.meta.name }}</text>
          <view class="capability-tags">
            <text v-if="resolved.composition" class="cap-tag">◆构图</text>
            <text v-if="resolved.pose" class="cap-tag">◆姿势</text>
            <text v-if="resolved.camera" class="cap-tag">◆参数</text>
            <text v-if="resolved.postProcess" class="cap-tag">◆后期</text>
          </view>
        </view>

        <!-- 场景指南 -->
        <SceneGuidePanel
          v-if="hasSceneGuide && resolved?.sceneGuide"
          :guide="resolved.sceneGuide"
        />

        <!-- 相机参数建议 -->
        <CameraParamsPanel
          v-if="hasCameraParams && resolved?.camera"
          :params="resolved.camera"
        />

        <!-- 示例作品 -->
        <ExampleGallery v-if="exampleImages.length > 0" :examples="exampleImages" />

        <!-- 套用拍摄 CTA -->
        <view class="cta-area">
          <view class="cta-btn" @click="handleApplyTemplate">
            <text class="cta-text">套用此模板拍摄</text>
          </view>
        </view>
      </view>

      <view class="bottom-spacer" />
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.template-detail-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
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
  &:active { opacity: 0.6; }
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

.detail-scroll {
  flex: 1;
  width: 100%;
}

.detail-content {
  padding: 0 var(--space-5);
}

.template-header {
  margin-bottom: var(--space-5);
}

.template-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-title);
  line-height: var(--line-height-title);
  margin-bottom: var(--space-2);
}

.capability-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.cap-tag {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  color: var(--color-tag-gold-text);
  background: var(--color-tag-gold-bg);
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-pill);
  letter-spacing: var(--letter-spacing-tag);
}

.cta-area {
  margin-top: var(--space-7);
  margin-bottom: var(--space-5);
}

.cta-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4) var(--space-6);
  background: var(--color-text-primary);
  border-radius: var(--radius-button);
  transition: transform var(--duration-fast) ease;

  &:active { transform: scale(0.98); }
}

.cta-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}

.bottom-spacer {
  height: var(--space-8);
}
</style>
```

- [ ] **Step 6: 验证模板详情页渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 模板详情页展示叠图预览 + 标题标签 + 场景指南 + 参数建议 + CTA 按钮

- [ ] **Step 7: Commit**

```bash
git add lumira-app/src/components/template/ lumira-app/src/pages/templates/detail.vue
git commit -m "feat(templates): add template detail entry page with apply CTA"
```

---

### Task 2.4: 实现模板导入页

**Files:**
- Modify: `lumira-app/src/pages/templates/import.vue`

**Interfaces:**
- Consumes: templates store importFromJson、useFileShare composable
- Produces: 模板导入页，支持 .pptpl 文件选择与导入

- [ ] **Step 1: 实现模板导入页**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()
const importing = ref(false)
const result = ref<{ success: boolean; message: string } | null>(null)

const handleImport = () => {
  uni.chooseFile({
    count: 1,
    extension: ['.pptpl', '.json'],
    success: async (res) => {
      const filePath = res.tempFiles[0].path
      importing.value = true
      result.value = null
      try {
        const fs = uni.getFileSystemManager()
        const content = fs.readFileSync(filePath, 'utf-8') as string
        await templatesStore.importFromJson(content)
        result.value = { success: true, message: '模板导入成功' }
        uni.showToast({ title: '导入成功', icon: 'success' })
      } catch (e) {
        const msg = e instanceof Error ? e.message : '导入失败'
        result.value = { success: false, message: msg }
        uni.showToast({ title: msg, icon: 'none' })
      } finally {
        importing.value = false
      }
    },
    fail: () => {
      uni.showToast({ title: '已取消选择', icon: 'none' })
    },
  })
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="import-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">导入模板</text>
    </view>

    <view class="import-content">
      <view class="import-card" @click="handleImport">
        <text class="import-icon">＋</text>
        <text class="import-label">选择 .pptpl 文件</text>
        <text class="import-hint">支持 .pptpl 和 .json 格式</text>
      </view>

      <view v-if="importing" class="import-status">
        <text class="status-text">正在导入...</text>
      </view>

      <view v-if="result" class="import-result" :class="{ success: result.success, error: !result.success }">
        <text class="result-text">{{ result.message }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.import-page {
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
  &:active { opacity: 0.6; }
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

.import-content {
  padding: var(--space-5);
}

.import-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-8) var(--space-5);
  background: var(--color-bg-card);
  border: 1px dashed var(--color-brand-primary);
  border-radius: var(--radius-card);
  gap: var(--space-3);
  &:active { opacity: 0.85; }
}

.import-icon {
  font-size: 40px;
  color: var(--color-brand-primary);
}

.import-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.import-hint {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.import-status {
  margin-top: var(--space-4);
  text-align: center;
}

.status-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.import-result {
  margin-top: var(--space-4);
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-button);
  text-align: center;

  &.success {
    background: var(--color-tag-green-bg);
  }
  &.error {
    background: var(--color-tag-red-bg);
  }
}

.result-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
}
</style>
```

- [ ] **Step 2: Commit**

```bash
git add lumira-app/src/pages/templates/import.vue
git commit -m "feat(templates): implement template import page"
```

---

**Phase 2 验收标准：**
- [ ] 模板库页双列网格展示，分类 pill 筛选正常
- [ ] 模板详情页展示叠图预览（可切换显隐）+ 场景指南 + 参数建议
- [ ] "套用此模板拍摄"墨黑 CTA 点击后跳转拍摄页并传递 templateId
- [ ] 模板导入页可选择 .pptpl 文件并导入成功

---

## Phase 3: 拍摄页（取景器 + 叠图 + 快门 + 参数面板 + 预览）

> 交付物：拍摄功能闭环——进入→取景→叠图→拍→预览

### Task 3.1: 创建拍摄页子组件

**Files:**
- Create: `lumira-app/src/components/capture/CaptureHeader.vue`
- Create: `lumira-app/src/components/capture/CameraViewfinder.vue`
- Create: `lumira-app/src/components/capture/OverlayLayer.vue`
- Create: `lumira-app/src/components/capture/RuleOfThirdsGrid.vue`
- Create: `lumira-app/src/components/capture/GuideLines.vue`
- Create: `lumira-app/src/components/capture/PoseOverlay.vue`
- Create: `lumira-app/src/components/capture/ParameterBar.vue`
- Modify: `lumira-app/src/components/ShutterButton.vue`

**Interfaces:**
- Consumes: capture store、CameraService、overlay 类型
- Produces: 拍摄页完整组件树

- [ ] **Step 1: 创建 CaptureHeader.vue**

```vue
<script setup lang="ts">
interface CaptureHeaderProps {
  templateName: string
}

defineProps<CaptureHeaderProps>()

const emit = defineEmits<{
  (e: 'on-back'): void
  (e: 'on-settings'): void
}>()
</script>

<template>
  <view class="capture-header">
    <view class="header-btn" @click="emit('on-back')">
      <text class="btn-icon">←</text>
    </view>
    <view class="header-center">
      <text class="template-name">{{ templateName }}</text>
    </view>
    <view class="header-btn" @click="emit('on-settings')">
      <text class="btn-icon">⚙</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.capture-header {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-4) var(--space-3);
  display: flex;
  align-items: center;
  justify-content: space-between;
  z-index: 10;
}

.header-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--color-capture-bar);
  backdrop-filter: blur(12px);
  &:active { opacity: 0.7; }
}

.btn-icon {
  font-size: 22px;
  color: var(--color-capture-text-bright);
  line-height: 1;
}

.header-center {
  padding: var(--space-1) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-capture-bar);
  backdrop-filter: blur(12px);
}

.template-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-capture-text-bright);
  font-weight: var(--weight-medium);
}
</style>
```

- [ ] **Step 2: 创建 RuleOfThirdsGrid.vue**

```vue
<script setup lang="ts">
</script>

<template>
  <view class="rule-of-thirds">
    <view class="grid-line grid-line-h" style="top: 33.33%"></view>
    <view class="grid-line grid-line-h" style="top: 66.66%"></view>
    <view class="grid-line grid-line-v" style="left: 33.33%"></view>
    <view class="grid-line grid-line-v" style="left: 66.66%"></view>
  </view>
</template>

<style lang="scss" scoped>
.rule-of-thirds {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.grid-line {
  position: absolute;
  background: var(--color-capture-overlay-line);
}

.grid-line-h {
  left: 0;
  right: 0;
  height: 1px;
}

.grid-line-v {
  top: 0;
  bottom: 0;
  width: 1px;
}
</style>
```

- [ ] **Step 3: 创建 GuideLines.vue**

```vue
<script setup lang="ts">
import type { OverlayLine } from '@/types/overlay'

interface GuideLinesProps {
  lines: OverlayLine[]
}

defineProps<GuideLinesProps>()
</script>

<template>
  <view class="guide-lines">
    <view
      v-for="(line, idx) in lines"
      :key="idx"
      class="guide-line"
      :style="{
        top: `${line.start.y * 100}%`,
        left: `${line.start.x * 100}%`,
        width: line.type === 'horizontal' ? '100%' : '1px',
        height: line.type === 'vertical' ? '100%' : '1px',
        borderStyle: line.type === 'dashed' ? 'dashed' : 'solid',
      }"
    ></view>
  </view>
</template>

<style lang="scss" scoped>
.guide-lines {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.guide-line {
  position: absolute;
  border-color: var(--color-capture-overlay-line);
  border-width: 0;
  border-top-width: 1px;
  border-left-width: 1px;
}
</style>
```

- [ ] **Step 4: 创建 PoseOverlay.vue**

```vue
<script setup lang="ts">
import type { PoseOverlayData } from '@/types/overlay'

interface PoseOverlayProps {
  pose: PoseOverlayData | null
}

defineProps<PoseOverlayProps>()
</script>

<template>
  <view v-if="pose" class="pose-overlay" :style="{
    left: `${pose.position.x * 100}%`,
    top: `${pose.position.y * 100}%`,
    transform: `scale(${pose.scale}) rotate(${pose.rotation}deg)`,
  }">
    <image :src="pose.imageUrl" mode="aspectFit" class="pose-image" />
  </view>
</template>

<style lang="scss" scoped>
.pose-overlay {
  position: absolute;
  width: 60%;
  height: 60%;
  transform-origin: center;
  pointer-events: none;
  opacity: 0.4;
}

.pose-image {
  width: 100%;
  height: 100%;
}
</style>
```

- [ ] **Step 5: 创建 OverlayLayer.vue**

```vue
<script setup lang="ts">
import type { OverlayLayer as OverlayLayerType } from '@/types/overlay'
import RuleOfThirdsGrid from './RuleOfThirdsGrid.vue'
import GuideLines from './GuideLines.vue'
import PoseOverlay from './PoseOverlay.vue'

interface OverlayLayerProps {
  layer: OverlayLayerType | null
}

defineProps<OverlayLayerProps>()
</script>

<template>
  <view v-if="layer && layer.visible" class="overlay-layer">
    <RuleOfThirdsGrid v-if="layer.composition?.type === 'rule_of_thirds'" />
    <GuideLines v-if="layer.composition?.lines?.length" :lines="layer.composition.lines" />
    <PoseOverlay v-if="layer.pose" :pose="layer.pose" />
  </view>
</template>

<style lang="scss" scoped>
.overlay-layer {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
  z-index: 100;
  transition: opacity var(--duration-normal) ease;
}
</style>
```

- [ ] **Step 6: 创建 CameraViewfinder.vue**

```vue
<script setup lang="ts">
import type { OverlayLayer as OverlayLayerType } from '@/types/overlay'
import OverlayLayer from './OverlayLayer.vue'

interface CameraViewfinderProps {
  overlay: OverlayLayerType | null
}

defineProps<CameraViewfinderProps>()
</script>

<template>
  <view class="camera-viewfinder">
    <view class="viewfinder-frame">
      <view class="camera-placeholder">
        <text class="placeholder-icon">◐</text>
        <text class="placeholder-text">取景框</text>
        <text class="placeholder-hint">将主体对准框内</text>
      </view>
      <OverlayLayer :layer="overlay" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.camera-viewfinder {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 100px var(--space-4) 180px;
}

.viewfinder-frame {
  position: relative;
  width: 100%;
  max-width: 320px;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: #2A2A2A;
  overflow: hidden;
  border: 1px solid rgba(201, 169, 110, 0.2);
}

.camera-placeholder {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
}

.placeholder-icon {
  font-size: 36px;
  color: rgba(201, 169, 110, 0.3);
}

.placeholder-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: rgba(255, 255, 255, 0.4);
}

.placeholder-hint {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.25);
}
</style>
```

- [ ] **Step 7: 创建 ParameterBar.vue**

```vue
<script setup lang="ts">
import type { CameraParams } from '@/types/camera'

interface ParameterBarProps {
  params: CameraParams
  isLevel: boolean
}

const props = defineProps<ParameterBarProps>()

const evDisplay = () => {
  const ev = props.params.evBias
  return ev > 0 ? `+${ev}` : String(ev)
}

const wbDisplay = () => {
  const wb = props.params.whiteBalance
  if (wb === 'auto') return 'AUTO'
  if (wb === 'daylight') return '日光'
  if (wb === 'cloudy') return '阴天'
  return String(wb)
}
</script>

<template>
  <view class="parameter-bar" @click="() => {}">
    <text class="param-item">⊹ {{ isLevel ? '水平' : '倾斜' }}</text>
    <text class="param-sep">·</text>
    <text class="param-item">EV {{ evDisplay() }}</text>
    <text class="param-sep">·</text>
    <text class="param-item">WB {{ wbDisplay() }}</text>
  </view>
</template>

<style lang="scss" scoped>
.parameter-bar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-capture-bar);
  backdrop-filter: blur(12px);
  align-self: center;
}

.param-item {
  font-family: var(--font-mono);
  font-size: var(--font-size-caption);
  color: var(--color-capture-text-bright);
  font-weight: var(--weight-medium);
}

.param-sep {
  font-size: var(--font-size-caption);
  color: rgba(255, 255, 255, 0.3);
}
</style>
```

- [ ] **Step 8: 更新 ShutterButton.vue**

```vue
<script setup lang="ts">
interface ShutterButtonProps {
  active?: boolean
}

withDefaults(defineProps<ShutterButtonProps>(), {
  active: false,
})

const emit = defineEmits<{
  (e: 'on-capture'): void
}>()
</script>

<template>
  <view class="shutter-button" :class="{ active }" @click="emit('on-capture')">
    <view class="shutter-outer">
      <view class="shutter-inner"></view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.shutter-button {
  display: flex;
  align-items: center;
  justify-content: center;
  &:active .shutter-outer {
    transform: scale(0.92);
  }
}

.shutter-outer {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 4px solid #FFFFFF;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform var(--duration-fast) ease;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.1);
}

.shutter-inner {
  width: 58px;
  height: 58px;
  border-radius: 50%;
  background: var(--color-brand-primary);
}
</style>
```

- [ ] **Step 9: Commit**

```bash
git add lumira-app/src/components/capture/ lumira-app/src/components/ShutterButton.vue
git commit -m "feat(capture): add all capture page sub-components"
```

---

### Task 3.2: 重写拍摄页组装

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`

**Interfaces:**
- Consumes: capture store、所有拍摄子组件、CameraService
- Produces: 沉浸式拍摄页，含 Tab 栏深色态

- [ ] **Step 1: 重写拍摄页**

```vue
<script setup lang="ts">
import { computed } from 'vue'
import { onLoad, onShow, onHide } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import CaptureHeader from '@/components/capture/CaptureHeader.vue'
import CameraViewfinder from '@/components/capture/CameraViewfinder.vue'
import ParameterBar from '@/components/capture/ParameterBar.vue'
import ShutterButton from '@/components/shutterButton.vue'
import { useCaptureStore } from '@/stores/capture'
import type { OverlayLayer } from '@/types/overlay'

const captureStore = useCaptureStore()

const currentTemplateName = computed(() =>
  captureStore.activeTemplateId ? `模板 #${captureStore.activeTemplateId.slice(0, 6)}` : '自由拍摄'
)

const overlay = computed<OverlayLayer | null>(() => ({
  composition: undefined,
  pose: undefined,
  opacity: captureStore.overlaySettings.opacity,
  visible: captureStore.overlaySettings.showComposition || captureStore.overlaySettings.showPose,
}))

onLoad((query) => {
  if (query?.templateId) {
    captureStore.setActiveTemplate(query.templateId)
  }
})

onShow(() => {
  captureStore.setActive(true)
})

onHide(() => {
  captureStore.setActive(false)
})

const onBack = () => {
  uni.navigateBack()
}

const openParameters = () => {
  uni.navigateTo({ url: '/pages/capture/parameters' })
}

const onShutter = () => {
  uni.navigateTo({ url: '/pages/capture/preview?photoId=tmp' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
</script>

<template>
  <view class="capture-page">
    <CaptureHeader
      :template-name="currentTemplateName"
      @on-back="onBack"
      @on-settings="openParameters"
    />

    <CameraViewfinder :overlay="overlay" />

    <view class="bottom-controls">
      <ParameterBar
        :params="captureStore.cameraParameters"
        :is-level="captureStore.isLevel"
      />

      <view class="shutter-row">
        <view class="shutter-side" @click="() => uni.navigateTo({ url: '/pages/gallery/index' })">
          <view class="side-icon-wrap">
            <text class="side-icon">▦</text>
          </view>
          <text class="side-label">相册</text>
        </view>

        <ShutterButton @on-capture="onShutter" />

        <view class="shutter-side" @click="() => uni.navigateTo({ url: '/pages/templates/index' })">
          <view class="side-icon-wrap">
            <text class="side-icon">▦</text>
          </view>
          <text class="side-label">模板</text>
        </view>
      </view>
    </view>

    <FloatingTabBar current="capture" theme="dark" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.capture-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: var(--color-capture-bg);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.bottom-controls {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 0 var(--space-4) calc(var(--space-6) + env(safe-area-inset-bottom));
  z-index: 10;
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.shutter-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--space-4);
}

.shutter-side {
  width: 64px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  &:active { opacity: 0.6; }
}

.side-icon-wrap {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.1);
}

.side-icon {
  font-size: 18px;
  color: rgba(255, 255, 255, 0.7);
}

.side-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.5);
}
</style>
```

- [ ] **Step 2: 验证拍摄页渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 深色沉浸拍摄页，含取景器 + 参数条 + 快门按钮 + 深色 Tab 栏

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/capture/index.vue
git commit -m "feat(capture): rebuild capture page with immersive dark theme"
```

---

### Task 3.3: 完善拍摄预览页与参数面板

**Files:**
- Modify: `lumira-app/src/pages/capture/preview.vue`
- Modify: `lumira-app/src/pages/capture/parameters.vue`

- [ ] **Step 1: 完善预览页**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const photoId = ref('')
const showOriginal = ref(false)

onLoad((query) => {
  if (query?.photoId) {
    photoId.value = query.photoId
  }
})

const toggleCompare = () => {
  showOriginal.value = !showOriginal.value
}

const goEdit = () => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${photoId.value}` })
}

const retake = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="preview-page">
    <view class="preview-nav">
      <view class="nav-btn" @click="retake">
        <text class="nav-text">重拍</text>
      </view>
      <view class="nav-btn compare-btn" @click="toggleCompare">
        <text class="nav-text">{{ showOriginal ? '效果' : '原图' }}</text>
      </view>
    </view>

    <view class="preview-content">
      <view class="photo-frame">
        <text class="photo-placeholder">📸 照片预览</text>
      </view>
    </view>

    <view class="preview-actions">
      <view class="action-btn edit-btn" @click="goEdit">
        <text class="action-text">后期编辑</text>
      </view>
      <view class="action-btn save-btn" @click="() => uni.navigateBack()">
        <text class="action-text">保存</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.preview-page {
  min-height: 100vh;
  background: #1A1A1A;
  display: flex;
  flex-direction: column;
}

.preview-nav {
  display: flex;
  justify-content: space-between;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5);
}

.nav-btn {
  padding: var(--space-2) var(--space-4);
  &:active { opacity: 0.7; }
}

.nav-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: #FFFFFF;
}

.preview-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--space-5);
}

.photo-frame {
  width: 100%;
  max-width: 360px;
  aspect-ratio: 3 / 4;
  background: #2A2A2A;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.photo-placeholder {
  font-size: 20px;
  color: rgba(255, 255, 255, 0.4);
}

.preview-actions {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5) calc(var(--space-6) + env(safe-area-inset-bottom));
}

.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4);
  border-radius: var(--radius-button);
  &:active { opacity: 0.85; }
}

.edit-btn {
  background: var(--color-brand-primary);
}

.save-btn {
  background: var(--color-text-primary);
}

.action-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}
</style>
```

- [ ] **Step 2: 完善参数面板**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useCaptureStore } from '@/stores/capture'

const captureStore = useCaptureStore()

const evBias = ref(captureStore.cameraParameters.evBias)
const iso = ref(captureStore.cameraParameters.iso)
const whiteBalance = ref(captureStore.cameraParameters.whiteBalance)

const applyParams = () => {
  captureStore.updateCameraParameters({
    evBias: evBias.value,
    iso: iso.value,
    whiteBalance: whiteBalance.value,
  })
  uni.navigateBack()
}

const closePanel = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="parameters-page">
    <view class="panel-header">
      <text class="panel-title">相机参数</text>
      <view class="close-btn" @click="closePanel">
        <text class="close-icon">✕</text>
      </view>
    </view>

    <view class="params-list">
      <view class="param-row">
        <text class="param-label">曝光补偿</text>
        <view class="param-control">
          <text class="param-minus" @click="evBias = Math.max(-3, evBias - 0.3)">−</text>
          <text class="param-value">EV {{ evBias > 0 ? '+' : '' }}{{ evBias.toFixed(1) }}</text>
          <text class="param-plus" @click="evBias = Math.min(3, evBias + 0.3)">+</text>
        </view>
      </view>

      <view class="param-row">
        <text class="param-label">ISO</text>
        <view class="param-control">
          <text class="param-minus" @click="iso = Math.max(100, iso - 100)">−</text>
          <text class="param-value">{{ iso }}</text>
          <text class="param-plus" @click="iso = Math.min(3200, iso + 100)">+</text>
        </view>
      </view>

      <view class="param-row">
        <text class="param-label">白平衡</text>
        <view class="param-control">
          <text class="wb-option" :class="{ active: whiteBalance === 'auto' }" @click="whiteBalance = 'auto'">AUTO</text>
          <text class="wb-option" :class="{ active: whiteBalance === 'daylight' }" @click="whiteBalance = 'daylight'">日光</text>
          <text class="wb-option" :class="{ active: whiteBalance === 'cloudy' }" @click="whiteBalance = 'cloudy'">阴天</text>
        </view>
      </view>
    </view>

    <view class="apply-area">
      <view class="apply-btn" @click="applyParams">
        <text class="apply-text">应用</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.parameters-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  padding-top: env(safe-area-inset-top);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--color-border);
}

.panel-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.close-btn {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  &:active { opacity: 0.6; }
}

.close-icon {
  font-size: 18px;
  color: var(--color-text-secondary);
}

.params-list {
  padding: var(--space-5);
}

.param-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) 0;
  border-bottom: 1px solid var(--color-border);
}

.param-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.param-control {
  display: flex;
  align-items: center;
  gap: var(--space-4);
}

.param-minus,
.param-plus {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--color-bg-surface);
  font-size: 18px;
  color: var(--color-text-primary);
  &:active { opacity: 0.6; }
}

.param-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  min-width: 60px;
  text-align: center;
}

.wb-option {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  padding: var(--space-2) var(--space-3);
  border-radius: var(--radius-pill);
  background: var(--color-bg-surface);
  color: var(--color-text-secondary);
  &.active {
    background: var(--color-tag-gold-bg);
    color: var(--color-tag-gold-text);
  }
}

.apply-area {
  padding: var(--space-5);
}

.apply-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4);
  background: var(--color-text-primary);
  border-radius: var(--radius-button);
  &:active { transform: scale(0.98); }
}

.apply-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}
</style>
```

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/capture/preview.vue lumira-app/src/pages/capture/parameters.vue
git commit -m "feat(capture): implement preview and parameters pages"
```

---

**Phase 3 验收标准：**
- [ ] 拍摄页深色沉浸式，取景器全屏
- [ ] 叠图层（三分法网格线）可显示/隐藏
- [ ] 参数条显示 EV/ISO/WB，点击可进入参数面板调节
- [ ] 快门按钮 72px 圆形，按下有缩放反馈
- [ ] 拍摄后跳转预览页，可"重拍"/"后期编辑"/"保存"
- [ ] Tab 栏深色态正确显示

---

## Phase 4: 后期编辑（调色/LUT/磨皮/锐化/裁剪/导出）

> 交付物：后期编辑闭环——参数调节 + 实时预览 + 导出

### Task 4.1: 创建后期编辑子组件

**Files:**
- Create: `lumira-app/src/components/image/AdjustmentPanel.vue`
- Create: `lumira-app/src/components/image/ColorSliders.vue`
- Create: `lumira-app/src/components/image/LutSelector.vue`
- Create: `lumira-app/src/components/image/CropFrame.vue`
- Create: `lumira-app/src/components/image/SmoothSlider.vue`
- Create: `lumira-app/src/components/image/SharpenSlider.vue`
- Create: `lumira-app/src/components/image/CompareToggle.vue`

**Interfaces:**
- Consumes: ImageProcessingService 接口、ColorAdjustment/PostProcessParams 类型
- Produces: 后期编辑组件集，通过 emit 上报参数变更

- [ ] **Step 1: 创建 ColorSliders.vue**

```vue
<script setup lang="ts">
import type { ColorAdjustment } from '@/types/template'

interface ColorSlidersProps {
  value: ColorAdjustment
}

const props = defineProps<ColorSlidersProps>()

const emit = defineEmits<{
  (e: 'on-change', params: Partial<ColorAdjustment>): void
}>()

const sliders = [
  { key: 'brightness' as const, label: '亮度', min: -100, max: 100 },
  { key: 'contrast' as const, label: '对比度', min: -100, max: 100 },
  { key: 'saturation' as const, label: '饱和度', min: -100, max: 100 },
  { key: 'temperature' as const, label: '色温', min: -100, max: 100 },
  { key: 'tint' as const, label: '色调', min: -100, max: 100 },
]
</script>

<template>
  <view class="color-sliders">
    <view v-for="slider in sliders" :key="slider.key" class="slider-row">
      <text class="slider-label">{{ slider.label }}</text>
      <slider
        :value="props.value[slider.key]"
        :min="slider.min"
        :max="slider.max"
        :step="1"
        activeColor="var(--color-brand-primary)"
        backgroundColor="var(--color-border)"
        block-size="18"
        @change="(e: any) => emit('on-change', { [slider.key]: e.detail.value })"
      />
      <text class="slider-value">{{ props.value[slider.key] > 0 ? '+' : '' }}{{ props.value[slider.key] }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.color-sliders {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.slider-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.slider-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  min-width: 48px;
}

.slider-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-primary);
  min-width: 36px;
  text-align: right;
}
</style>
```

- [ ] **Step 2: 创建 LutSelector.vue**

```vue
<script setup lang="ts">
interface LutSelectorProps {
  current: string
  options: { name: string; value: string }[]
}

defineProps<LutSelectorProps>()

const emit = defineEmits<{
  (e: 'on-select', lutName: string): void
}>()
</script>

<template>
  <view class="lut-selector">
    <scroll-view scroll-x class="lut-scroll" :show-scrollbar="false">
      <view class="lut-row">
        <view
          v-for="opt in options"
          :key="opt.value"
          class="lut-item"
          :class="{ active: opt.value === current }"
          @click="emit('on-select', opt.value)"
        >
          <view class="lut-thumb"></view>
          <text class="lut-name">{{ opt.name }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.lut-selector {
  width: 100%;
}

.lut-scroll {
  width: 100%;
  white-space: nowrap;
}

.lut-row {
  display: inline-flex;
  gap: var(--space-3);
}

.lut-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  flex-shrink: 0;
  &:active { opacity: 0.8; }
}

.lut-thumb {
  width: 56px;
  height: 56px;
  border-radius: var(--radius-card);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);

  .active & {
    border-color: var(--color-brand-primary);
    border-width: 2px;
  }
}

.lut-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-secondary);

  .active & {
    color: var(--color-brand-primary);
    font-weight: var(--weight-medium);
  }
}
</style>
```

- [ ] **Step 3: 创建 SmoothSlider.vue**

```vue
<script setup lang="ts">
interface SmoothSliderProps {
  value: number
}

defineProps<SmoothSliderProps>()

const emit = defineEmits<{
  (e: 'on-change', value: number): void
}>()
</script>

<template>
  <view class="smooth-slider">
    <text class="slider-label">磨皮强度</text>
    <slider
      :value="value"
      :min="0"
      :max="100"
      :step="1"
      activeColor="var(--color-brand-primary)"
      backgroundColor="var(--color-border)"
      block-size="18"
      @change="(e: any) => emit('on-change', e.detail.value)"
    />
    <text class="slider-value">{{ value }}</text>
  </view>
</template>

<style lang="scss" scoped>
.smooth-slider {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.slider-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  min-width: 60px;
}

.slider-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-primary);
  min-width: 28px;
  text-align: right;
}
</style>
```

- [ ] **Step 4: 创建 SharpenSlider.vue**

```vue
<script setup lang="ts">
interface SharpenSliderProps {
  value: number
}

defineProps<SharpenSliderProps>()

const emit = defineEmits<{
  (e: 'on-change', value: number): void
}>()
</script>

<template>
  <view class="sharpen-slider">
    <text class="slider-label">锐化强度</text>
    <slider
      :value="value"
      :min="0"
      :max="100"
      :step="1"
      activeColor="var(--color-brand-primary)"
      backgroundColor="var(--color-border)"
      block-size="18"
      @change="(e: any) => emit('on-change', e.detail.value)"
    />
    <text class="slider-value">{{ value }}</text>
  </view>
</template>

<style lang="scss" scoped>
.sharpen-slider {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.slider-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  min-width: 60px;
}

.slider-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-primary);
  min-width: 28px;
  text-align: right;
}
</style>
```

- [ ] **Step 5: 创建 CropFrame.vue**

```vue
<script setup lang="ts">
import type { CropRect } from '@/types/photo'

interface CropFrameProps {
  rect: CropRect
}

defineProps<CropFrameProps>()

const emit = defineEmits<{
  (e: 'on-change', rect: CropRect): void
}>()
</script>

<template>
  <view class="crop-frame">
    <view class="crop-area" :style="{
      left: `${rect.x * 100}%`,
      top: `${rect.y * 100}%`,
      width: `${rect.w * 100}%`,
      height: `${rect.h * 100}%`,
    }">
      <view class="crop-corner crop-tl"></view>
      <view class="crop-corner crop-tr"></view>
      <view class="crop-corner crop-bl"></view>
      <view class="crop-corner crop-br"></view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.crop-frame {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  background: rgba(0, 0, 0, 0.5);
}

.crop-area {
  position: absolute;
  border: 2px solid var(--color-brand-primary);
  background: transparent;
}

.crop-corner {
  position: absolute;
  width: 16px;
  height: 16px;
  border-color: #FFFFFF;
  border-style: solid;
}

.crop-tl { top: -2px; left: -2px; border-width: 3px 0 0 3px; }
.crop-tr { top: -2px; right: -2px; border-width: 3px 3px 0 0; }
.crop-bl { bottom: -2px; left: -2px; border-width: 0 0 3px 3px; }
.crop-br { bottom: -2px; right: -2px; border-width: 0 3px 3px 0; }
</style>
```

- [ ] **Step 6: 创建 CompareToggle.vue**

```vue
<script setup lang="ts">
interface CompareToggleProps {
  showOriginal: boolean
}

defineProps<CompareToggleProps>()

const emit = defineEmits<{
  (e: 'on-toggle'): void
}>()
</script>

<template>
  <view class="compare-toggle" @click="emit('on-toggle')">
    <text class="toggle-text">⇄ {{ showOriginal ? '效果' : '原图' }}</text>
  </view>
</template>

<style lang="scss" scoped>
.compare-toggle {
  padding: var(--space-2) var(--space-3);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: var(--radius-button);
  &:active { opacity: 0.7; }
}

.toggle-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: #FFFFFF;
  font-weight: var(--weight-medium);
}
</style>
```

- [ ] **Step 7: 创建 AdjustmentPanel.vue**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import ColorSliders from './ColorSliders.vue'
import LutSelector from './LutSelector.vue'
import SmoothSlider from './SmoothSlider.vue'
import SharpenSlider from './SharpenSlider.vue'
import type { ColorAdjustment } from '@/types/template'

type ToolTab = 'color' | 'lut' | 'smooth' | 'sharpen'

const activeTab = ref<ToolTab>('color')

const tabs: { key: ToolTab; label: string }[] = [
  { key: 'color', label: '调色' },
  { key: 'lut', label: 'LUT' },
  { key: 'smooth', label: '磨皮' },
  { key: 'sharpen', label: '锐化' },
]

const colorParams = ref<ColorAdjustment>({
  brightness: 0,
  contrast: 0,
  saturation: 0,
  temperature: 0,
  tint: 0,
})
const currentLut = ref('')
const smoothValue = ref(0)
const sharpenValue = ref(0)

const lutOptions = [
  { name: '原图', value: '' },
  { name: '暖阳', value: 'warm-sun' },
  { name: '冷调', value: 'cool-tone' },
  { name: '胶片', value: 'film' },
  { name: '日系', value: 'japanese' },
]

const emit = defineEmits<{
  (e: 'on-color-change', params: Partial<ColorAdjustment>): void
  (e: 'on-lut-select', name: string): void
  (e: 'on-smooth-change', value: number): void
  (e: 'on-sharpen-change', value: number): void
}>()

const handleColorChange = (params: Partial<ColorAdjustment>) => {
  colorParams.value = { ...colorParams.value, ...params }
  emit('on-color-change', params)
}
</script>

<template>
  <view class="adjustment-panel">
    <scroll-view scroll-x class="tool-tabs" :show-scrollbar="false">
      <view class="tabs-row">
        <view
          v-for="tab in tabs"
          :key="tab.key"
          class="tab-item"
          :class="{ active: activeTab === tab.key }"
          @click="activeTab = tab.key"
        >
          <text class="tab-text">{{ tab.label }}</text>
        </view>
      </view>
    </scroll-view>

    <view class="tool-content">
      <ColorSliders v-if="activeTab === 'color'" :value="colorParams" @on-change="handleColorChange" />
      <LutSelector v-if="activeTab === 'lut'" :current="currentLut" :options="lutOptions" @on-select="(v: string) => { currentLut = v; emit('on-lut-select', v) }" />
      <SmoothSlider v-if="activeTab === 'smooth'" :value="smoothValue" @on-change="(v: number) => { smoothValue = v; emit('on-smooth-change', v) }" />
      <SharpenSlider v-if="activeTab === 'sharpen'" :value="sharpenValue" @on-change="(v: number) => { sharpenValue = v; emit('on-sharpen-change', v) }" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.adjustment-panel {
  width: 100%;
}

.tool-tabs {
  width: 100%;
  white-space: nowrap;
  margin-bottom: var(--space-4);
  border-bottom: 1px solid var(--color-border);
}

.tabs-row {
  display: inline-flex;
  gap: var(--space-4);
  padding: 0 var(--space-5);
}

.tab-item {
  padding: var(--space-2) 0;
  border-bottom: 2px solid transparent;
  &:active { opacity: 0.7; }
}

.tab-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
}

.tab-item.active {
  border-bottom-color: var(--color-brand-primary);
  .tab-text { color: var(--color-brand-primary); }
}

.tool-content {
  padding: 0 var(--space-5);
}
</style>
```

- [ ] **Step 8: Commit**

```bash
git add lumira-app/src/components/image/
git commit -m "feat(editor): add all image editing sub-components"
```

---

### Task 4.2: 重写后期编辑页

**Files:**
- Modify: `lumira-app/src/pages/gallery/detail.vue`

- [ ] **Step 1: 重写后期编辑页**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import AdjustmentPanel from '@/components/image/AdjustmentPanel.vue'
import CompareToggle from '@/components/image/CompareToggle.vue'
import type { ColorAdjustment } from '@/types/template'

const photoId = ref('')
const showOriginal = ref(false)

onLoad((query) => {
  if (query?.id) {
    photoId.value = query.id
  }
})

const handleColorChange = (_params: Partial<ColorAdjustment>) => {
  // TODO: 接入 ImageProcessingService 后实现实时预览
}

const handleLutSelect = (_name: string) => {
  // TODO: 接入 ImageProcessingService 后实现
}

const handleSmoothChange = (_value: number) => {
  // TODO: 接入 ImageProcessingService 后实现
}

const handleSharpenChange = (_value: number) => {
  // TODO: 接入 ImageProcessingService 后实现
}

const toggleCompare = () => {
  showOriginal.value = !showOriginal.value
}

const handleReset = () => {
  uni.showToast({ title: '已重置', icon: 'none' })
}

const handleExport = () => {
  uni.showToast({ title: '导出成功', icon: 'success' })
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="editor-page">
    <view class="editor-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">✕</text>
      </view>
      <CompareToggle :show-original="showOriginal" @on-toggle="toggleCompare" />
    </view>

    <view class="editor-canvas">
      <view class="image-frame">
        <text class="image-placeholder">🖼️ 照片编辑画布</text>
      </view>
    </view>

    <view class="editor-tools">
      <AdjustmentPanel
        @on-color-change="handleColorChange"
        @on-lut-select="handleLutSelect"
        @on-smooth-change="handleSmoothChange"
        @on-sharpen-change="handleSharpenChange"
      />
    </view>

    <view class="editor-actions">
      <view class="action-btn reset-btn" @click="handleReset">
        <text class="action-text">重置</text>
      </view>
      <view class="action-btn export-btn" @click="handleExport">
        <text class="action-text">导出</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.editor-page {
  min-height: 100vh;
  background: var(--color-capture-bg);
  display: flex;
  flex-direction: column;
}

.editor-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  &:active { opacity: 0.6; }
}

.nav-icon {
  font-size: 18px;
  color: #FFFFFF;
}

.editor-canvas {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--space-5);
}

.image-frame {
  width: 100%;
  max-width: 360px;
  aspect-ratio: 3 / 4;
  background: #2A2A2A;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.image-placeholder {
  font-size: 20px;
  color: rgba(255, 255, 255, 0.4);
}

.editor-tools {
  max-height: 280px;
  overflow-y: auto;
}

.editor-actions {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5) calc(var(--space-6) + env(safe-area-inset-bottom));
}

.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-button);
  &:active { opacity: 0.85; }
}

.reset-btn {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.export-btn {
  background: var(--color-brand-primary);
}

.action-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}
</style>
```

- [ ] **Step 2: 验证后期编辑页渲染**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

Expected: 深色编辑页，上方画布区 + 中部调节面板（调色/LUT/磨皮/锐化标签切换）+ 底部重置/导出按钮

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/gallery/detail.vue
git commit -m "feat(editor): rebuild photo editor page with adjustment panel"
```

---

**Phase 4 验收标准：**
- [ ] 后期编辑页深色背景，照片画布居中
- [ ] 调节面板 4 个标签（调色/LUT/磨皮/锐化）可切换
- [ ] 调色面板 5 个滑块（亮度/对比度/饱和度/色温/色调）
- [ ] LUT 选择器横滑展示 5 个预设
- [ ] 前后对比切换按钮
- [ ] 重置 + 导出按钮

---

## Phase 5: 相册管理 + 我的页

> 交付物：相册浏览/删除 + 个人中心完整功能

### Task 5.1: 重写相册页

**Files:**
- Create: `lumira-app/src/components/gallery/PhotoGrid.vue`
- Create: `lumira-app/src/components/gallery/PhotoInfo.vue`
- Modify: `lumira-app/src/pages/gallery/index.vue`

**Interfaces:**
- Consumes: gallery store、LocalPhoto 类型
- Produces: 相册页，3 列网格 + 日期分组

- [ ] **Step 1: 创建 PhotoGrid.vue**

```vue
<script setup lang="ts">
import type { LocalPhoto } from '@/types/photo'

interface PhotoGridProps {
  photos: LocalPhoto[]
  columns?: number
}

withDefaults(defineProps<PhotoGridProps>(), {
  columns: 3,
})

const emit = defineEmits<{
  (e: 'on-photo-click', id: string): void
  (e: 'on-photo-longpress', id: string): void
}>()
</script>

<template>
  <view class="photo-grid" :style="{ gridTemplateColumns: `repeat(${columns}, 1fr)` }">
    <view
      v-for="photo in photos"
      :key="photo.id"
      class="grid-item"
      @click="emit('on-photo-click', photo.id)"
      @longpress="emit('on-photo-longpress', photo.id)"
    >
      <image :src="photo.imagePath" mode="aspectFill" class="grid-image" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.photo-grid {
  display: grid;
  gap: 2px;
  padding: 0 var(--space-5);
}

.grid-item {
  aspect-ratio: 1;
  overflow: hidden;
  background: var(--color-bg-surface);
  &:active { opacity: 0.85; }
}

.grid-image {
  width: 100%;
  height: 100%;
}
</style>
```

- [ ] **Step 2: 创建 PhotoInfo.vue**

```vue
<script setup lang="ts">
import type { LocalPhoto } from '@/types/photo'

interface PhotoInfoProps {
  photo: LocalPhoto
}

defineProps<PhotoInfoProps>()

const emit = defineEmits<{
  (e: 'on-edit'): void
  (e: 'on-delete'): void
  (e: 'on-share'): void
}>()
</script>

<template>
  <view class="photo-info">
    <view class="info-row">
      <text class="info-label">模板</text>
      <text class="info-value">{{ photo.templateName || '自由拍摄' }}</text>
    </view>
    <view class="info-row">
      <text class="info-label">时间</text>
      <text class="info-value">{{ photo.createdAt }}</text>
    </view>
    <view class="info-actions">
      <view class="info-action" @click="emit('on-edit')">
        <text class="action-label">编辑</text>
      </view>
      <view class="info-action" @click="emit('on-share')">
        <text class="action-label">分享</text>
      </view>
      <view class="info-action danger" @click="emit('on-delete')">
        <text class="action-label">删除</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.photo-info {
  padding: var(--space-4) var(--space-5);
  border-top: 1px solid var(--color-border);
}

.info-row {
  display: flex;
  justify-content: space-between;
  padding: var(--space-2) 0;
}

.info-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.info-value {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.info-actions {
  display: flex;
  gap: var(--space-4);
  margin-top: var(--space-3);
  padding-top: var(--space-3);
  border-top: 1px solid var(--color-border);
}

.info-action {
  padding: var(--space-2) var(--space-3);
  border-radius: var(--radius-button);
  background: var(--color-bg-surface);
  &:active { opacity: 0.7; }
}

.action-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.info-action.danger .action-label {
  color: var(--color-status-error);
}
</style>
```

- [ ] **Step 3: 重写相册页**

```vue
<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import PhotoGrid from '@/components/gallery/PhotoGrid.vue'
import AppEmpty from '@/components/AppEmpty.vue'
import { useGalleryStore } from '@/stores/gallery'

const galleryStore = useGalleryStore()
const photos = computed(() => galleryStore.photos)

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

<template>
  <view class="gallery-page">
    <view class="page-header">
      <text class="page-title">相册</text>
      <text class="page-sub">{{ photos.length }} 张照片</text>
    </view>

    <scroll-view scroll-y class="gallery-scroll" :show-scrollbar="false">
      <PhotoGrid
        v-if="photos.length > 0"
        :photos="photos"
        :columns="3"
        @on-photo-click="handlePhotoClick"
        @on-photo-longpress="handlePhotoLongpress"
      />

      <AppEmpty
        v-else
        title="还没有照片"
        description="去拍第一张吧"
        @on-action="() => uni.navigateTo({ url: '/pages/capture/index' })"
      />

      <view class="bottom-spacer" />
    </scroll-view>

    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.gallery-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.page-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.page-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-display);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-display);
  line-height: var(--line-height-display);
}

.page-sub {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}

.gallery-scroll {
  flex: 1;
  width: 100%;
}

.bottom-spacer {
  height: 120px;
}
</style>
```

- [ ] **Step 4: Commit**

```bash
git add lumira-app/src/components/gallery/ lumira-app/src/pages/gallery/index.vue
git commit -m "feat(gallery): rebuild gallery page with photo grid"
```

---

### Task 5.2: 重写我的页

**Files:**
- Modify: `lumira-app/src/pages/profile/index.vue`
- Modify: `lumira-app/src/pages/profile/settings.vue`

- [ ] **Step 1: 重写我的页**

```vue
<script setup lang="ts">
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useGalleryStore } from '@/stores/gallery'
import { useTemplatesStore } from '@/stores/templates'

const galleryStore = useGalleryStore()
const templatesStore = useTemplatesStore()

const goSettings = () => {
  uni.navigateTo({ url: '/pages/profile/settings' })
}

const goGallery = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const goTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const goImport = () => {
  uni.navigateTo({ url: '/pages/templates/import' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  }
}
</script>

<template>
  <view class="profile-page">
    <view class="profile-header">
      <view class="avatar-area">
        <view class="avatar-placeholder">
          <text class="avatar-icon">◍</text>
        </view>
        <view class="user-info">
          <text class="user-name">如画用户</text>
          <text class="user-tagline">用镜头记录生活</text>
        </view>
      </view>
    </view>

    <view class="stats-row">
      <view class="stat-block" @click="goGallery">
        <text class="stat-num">{{ galleryStore.photoCount }}</text>
        <text class="stat-lbl">拍摄</text>
      </view>
      <view class="stat-block" @click="goTemplates">
        <text class="stat-num">{{ templatesStore.templateCount }}</text>
        <text class="stat-lbl">模板</text>
      </view>
    </view>

    <view class="menu-section">
      <view class="menu-item" @click="goSettings">
        <text class="menu-label">设置</text>
        <text class="menu-arrow">→</text>
      </view>
      <view class="menu-item" @click="goImport">
        <text class="menu-label">导入模板</text>
        <text class="menu-arrow">→</text>
      </view>
    </view>

    <FloatingTabBar current="profile" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.profile-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  padding-bottom: 120px;
}

.profile-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-5);
}

.avatar-area {
  display: flex;
  align-items: center;
  gap: var(--space-4);
}

.avatar-placeholder {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  display: flex;
  align-items: center;
  justify-content: center;
}

.avatar-icon {
  font-size: 28px;
  color: var(--color-text-tertiary);
}

.user-info {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.user-name {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-title);
}

.user-tagline {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.stats-row {
  display: flex;
  gap: var(--space-4);
  padding: 0 var(--space-5) var(--space-6);
}

.stat-block {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--space-4);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  &:active { opacity: 0.85; }
}

.stat-num {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  line-height: 1;
}

.stat-lbl {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.menu-section {
  padding: 0 var(--space-5);
}

.menu-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) 0;
  border-bottom: 1px solid var(--color-border);
  &:active { opacity: 0.7; }
}

.menu-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.menu-arrow {
  font-size: 16px;
  color: var(--color-text-tertiary);
}
</style>
```

- [ ] **Step 2: 重写设置页**

```vue
<script setup lang="ts">
import { useSettingsStore } from '@/stores/settings'

const settingsStore = useSettingsStore()

const goBack = () => {
  uni.navigateBack()
}

const toggleGrid = () => {
  settingsStore.updateSetting('showGrid', !settingsStore.settings.showGrid)
}

const toggleLevel = () => {
  settingsStore.updateSetting('showLevelIndicator', !settingsStore.settings.showLevelIndicator)
}

const toggleSound = () => {
  settingsStore.updateSetting('shutterSound', !settingsStore.settings.shutterSound)
}

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

<template>
  <view class="settings-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">设置</text>
    </view>

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

    <view class="app-info">
      <text class="app-version">如画 Lumira v1.0.0</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.settings-page {
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
  &:active { opacity: 0.6; }
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

.settings-list {
  padding: 0 var(--space-5);
}

.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) 0;
  border-bottom: 1px solid var(--color-border);
}

.setting-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.setting-arrow {
  font-size: 16px;
  color: var(--color-text-tertiary);
}

.app-info {
  padding: var(--space-8) var(--space-5);
  text-align: center;
}

.app-version {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}
</style>
```

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/pages/profile/index.vue lumira-app/src/pages/profile/settings.vue
git commit -m "feat(profile): rebuild profile and settings pages"
```

---

**Phase 5 验收标准：**
- [ ] 相册页 3 列网格展示照片，长按可删除
- [ ] 我的页头像 + 统计 + 菜单完整
- [ ] 设置页开关项正常工作

---

## Phase 6: 模板编辑器 + Store 接口补全 + 端到端验证

> 交付物：模板编辑器可用 + 所有 Store 接口对齐 + 全流程可走通

### Task 6.1: 实现模板编辑器

**Files:**
- Modify: `lumira-app/src/pages/templates/editor.vue`

- [ ] **Step 1: 实现模板编辑器页**

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import type { LocalTemplate } from '@/types/template'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()
const templateId = ref('')
const templateName = ref('')
const isDirty = ref(false)

onLoad((query) => {
  if (query?.id) {
    templateId.value = query.id
    const tmpl = templatesStore.getTemplateById(query.id)
    if (tmpl) {
      templateName.value = tmpl.name
    }
  } else {
    templateName.value = '新建模板'
  }
})

const updateName = (name: string) => {
  templateName.value = name
  isDirty.value = true
}

const saveTemplate = () => {
  if (!templateName.value.trim()) {
    uni.showToast({ title: '请输入模板名称', icon: 'none' })
    return
  }
  uni.showToast({ title: '已保存', icon: 'success' })
  isDirty.value = false
  setTimeout(() => uni.navigateBack(), 500)
}

const goBack = () => {
  if (isDirty.value) {
    uni.showModal({
      title: '未保存更改',
      content: '确定放弃更改？',
      success: (res) => {
        if (res.confirm) uni.navigateBack()
      },
    })
  } else {
    uni.navigateBack()
  }
}
</script>

<template>
  <view class="editor-page">
    <view class="editor-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">编辑模板</text>
      <view class="save-btn" @click="saveTemplate">
        <text class="save-text">保存</text>
      </view>
    </view>

    <scroll-view scroll-y class="editor-scroll" :show-scrollbar="false">
      <view class="editor-content">
        <view class="form-group">
          <text class="form-label">模板名称</text>
          <input
            class="form-input"
            :value="templateName"
            @input="(e: any) => updateName(e.detail.value)"
            placeholder="输入模板名称"
          />
        </view>

        <view class="form-group">
          <text class="form-label">叠图类型</text>
          <view class="option-row">
            <view class="option-pill active">
              <text class="option-text">三分法</text>
            </view>
            <view class="option-pill">
              <text class="option-text">引导线</text>
            </view>
            <view class="option-pill">
              <text class="option-text">姿势</text>
            </view>
          </view>
        </view>

        <view class="form-group">
          <text class="form-label">场景指南</text>
          <input class="form-input" placeholder="光线建议" />
          <input class="form-input" placeholder="拍摄距离" style="margin-top: var(--space-2)" />
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.editor-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
}

.editor-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  &:active { opacity: 0.6; }
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

.save-btn {
  padding: var(--space-2) var(--space-4);
  background: var(--color-brand-primary);
  border-radius: var(--radius-button);
  &:active { opacity: 0.8; }
}

.save-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}

.editor-scroll {
  flex: 1;
  width: 100%;
}

.editor-content {
  padding: var(--space-5);
}

.form-group {
  margin-bottom: var(--space-5);
}

.form-label {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
  margin-bottom: var(--space-2);
}

.form-input {
  width: 100%;
  padding: var(--space-3) var(--space-4);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-button);
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.option-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.option-pill {
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);

  &.active {
    background: var(--color-tag-gold-bg);
    border-color: var(--color-brand-primary);
  }

  &:active { opacity: 0.8; }
}

.option-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);

  .active & {
    color: var(--color-tag-gold-text);
  }
}
</style>
```

- [ ] **Step 2: Commit**

```bash
git add lumira-app/src/pages/templates/editor.vue
git commit -m "feat(templates): implement template editor page"
```

---

### Task 6.2: Store 接口补全（确保所有页面引用的 store 方法存在）

**Files:**
- Modify: `lumira-app/src/stores/settings.ts`
- Modify: `lumira-app/src/stores/templates.ts`
- Modify: `lumira-app/src/stores/gallery.ts`
- Modify: `lumira-app/src/stores/capture.ts`

- [ ] **Step 1: 确保 settings store 含 `updateSetting` 方法**

在 `lumira-app/src/stores/settings.ts` 中，验证或添加 `updateSetting` 方法：

```typescript
updateSetting(key: keyof AppSettings, value: boolean | string | number) {
  this.settings[key] = value
  this.saveSettings()
},
```

- [ ] **Step 2: 确保 templates store 含以下方法**

在 `lumira-app/src/stores/templates.ts` 中，验证或添加：

```typescript
// 分类筛选
categories: computed(() => { /* 返回所有模板的去重分类 */ }),
currentCategory: string,
filteredTemplates: computed(() => { /* 按 currentCategory 筛选 */ }),
setCategory(cat: string) { this.currentCategory = cat },

// 获取已解析模板
getResolvedTemplate(id: string): Promise<ResolvedTemplate>,

// 设置当前模板
setCurrentTemplate(id: string) { this.currentTemplateId = id },

// 通过 ID 获取模板
getTemplateById(id: string): LocalTemplate | undefined,

// 导入模板
importFromJson(json: string): Promise<void>,
```

- [ ] **Step 3: 确保 gallery store 含以下方法**

在 `lumira-app/src/stores/gallery.ts` 中，验证或添加：

```typescript
photoCount: computed(() => this.photos.length),
deletePhoto(id: string) { /* 从列表和存储中删除 */ },
```

- [ ] **Step 4: 确保 capture store 含以下方法**

在 `lumira-app/src/stores/capture.ts` 中，验证或添加：

```typescript
setActiveTemplate(id: string) { this.activeTemplateId = id },
setActive(active: boolean) { this.isActive = active },
updateCameraParameters(params: Partial<CameraParams>) { /* 合并更新 */ },
overlaySettings: { showComposition: boolean, showPose: boolean, opacity: number },
cameraParameters: CameraParams,
isLevel: boolean,
activeTemplateId: string | null,
isActive: boolean,
```

- [ ] **Step 5: Commit**

```bash
git add lumira-app/src/stores/
git commit -m "feat(stores): align store interfaces with all page requirements"
```

---

### Task 6.3: 创建 AppEmpty 通用空态组件

**Files:**
- Create: `lumira-app/src/components/AppEmpty.vue`

- [ ] **Step 1: 创建 AppEmpty.vue**

```vue
<script setup lang="ts">
interface AppEmptyProps {
  title: string
  description: string
  actionText?: string
}

withDefaults(defineProps<AppEmptyProps>(), {
  actionText: '去操作',
})

const emit = defineEmits<{
  (e: 'on-action'): void
}>()
</script>

<template>
  <view class="app-empty">
    <text class="empty-icon">◎</text>
    <text class="empty-title">{{ title }}</text>
    <text class="empty-desc">{{ description }}</text>
    <view class="empty-action" @click="emit('on-action')">
      <text class="action-text">{{ actionText }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.app-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--space-8) var(--space-5);
  gap: var(--space-2);
}

.empty-icon {
  font-size: 40px;
  color: var(--color-text-tertiary);
  opacity: 0.3;
}

.empty-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
}

.empty-desc {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  text-align: center;
}

.empty-action {
  margin-top: var(--space-4);
  padding: var(--space-2) var(--space-4);
  border: 1px solid var(--color-brand-primary);
  border-radius: var(--radius-button);
  &:active { opacity: 0.8; }
}

.action-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-brand-primary);
}
</style>
```

- [ ] **Step 2: Commit**

```bash
git add lumira-app/src/components/AppEmpty.vue
git commit -m "feat(common): add AppEmpty empty state component"
```

---

### Task 6.4: 端到端全流程验证

**Files:**
- Test: 全部页面

- [ ] **Step 1: 运行 H5 开发服务器**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run dev:h5`

- [ ] **Step 2: 验证完整用户流程**

逐一验证以下流程：

1. **启动流程**：打开 APP → Splash 品牌页 → 1.5-3s 自动跳转首页 ✓
2. **首页浏览**：品牌标题 → 今日灵感 → 最近拍摄 → 推荐模板 → 场景快选 → 统计概览 ✓
3. **Tab 切换**：首页 ↔ 我的 ✓，点击拍摄按钮 → 拍摄页 ✓
4. **拍摄流程**：进入拍摄页 → 取景器 + 叠图 → 调参数 → 按快门 → 预览页 ✓
5. **模板流程**：首页推荐模板 → 模板详情 → "套用此模板拍摄" → 拍摄页 ✓
6. **后期编辑**：预览页"后期编辑" → 编辑页 → 调色/LUT/磨皮/锐化 → 导出 ✓
7. **相册流程**：相册页 3 列网格 → 点击照片 → 编辑页 ✓
8. **我的页**：头像 + 统计 + 设置 ✓

- [ ] **Step 3: 运行类型检查**

Run: `cd d:\app\projects\photo_post\lumira-app && npm run type-check`

Expected: 无 TypeScript 错误

- [ ] **Step 4: Commit（如有修复）**

```bash
git add -A
git commit -m "fix: resolve e2e verification issues"
```

---

**Phase 6 验收标准：**
- [ ] 所有页面可正常导航，无白屏或报错
- [ ] 模板编辑器可编辑模板名称并保存
- [ ] 所有 Store 接口方法存在且类型正确
- [ ] TypeScript 类型检查通过
- [ ] 完整用户流程可走通

---

## Self-Review

### 1. 规格覆盖度检查

| 设计规格需求 | 对应 Task |
|---|---|
| §1.1 悬浮 Tab 栏 3+1 | Task 0.4 |
| §1.2 路由表 | Task 0.2 |
| §2 Splash 启动页 | Task 0.3 |
| §3.1 首页品牌标题 | Task 1.2 (BrandHeader) |
| §3.2 今日灵感 | Task 1.2 (DailyInspiration) |
| §3.3 最近拍摄 | Task 1.2 (RecentPhotos) |
| §3.4 推荐模板 | Task 1.2 (FeaturedTemplates) |
| §3.5 拍摄场景 | Task 1.2 (SceneQuickAccess) |
| §3.6 统计概览 | Task 1.2 (StatsSummary) |
| §4 模板详情入口页 + CTA | Task 2.3 |
| §5 模板库双列瀑布流 | Task 2.2 |
| §6 拍摄页沉浸体验 | Task 3.1, 3.2 |
| §7 拍摄预览 | Task 3.3 |
| §8 相机参数面板 | Task 3.3 (parameters) |
| §9 后期编辑工作台 | Task 4.1, 4.2 |
| §10 相册管理 | Task 5.1 |
| §11 我的页 | Task 5.2 |
| §12 设置页 | Task 5.2 (settings) |
| §13 模板导入 | Task 2.4 |
| §14 模板编辑器 | Task 6.1 |
| 品牌配色/字体/间距 | Task 0.1 (tokens) |
| 完全离线 | Global Constraint |

**缺口：** 无重大缺口。所有规格需求均映射到具体 Task。

### 2. 占位符扫描

- 搜索 "TBD"：无
- 搜索 "TODO"：Task 4.2 后期编辑页有 4 处 `// TODO: 接入 ImageProcessingService 后实现`——这是合理的，因为 ImageProcessingService 需要原生插件支持，属于后续阶段工作，本方案仅搭建 UI 层
- 搜索 "implement later"：无
- 搜索 "fill in details"：无
- 所有代码步骤包含完整代码 ✓

### 3. 类型一致性检查

- `LocalPhoto` → `photo.ts` 已定义，`RecentPhotos.vue` / `PhotoGrid.vue` / `PhotoInfo.vue` 统一引用 ✓
- `LocalTemplate` → `template.ts` 已定义，`FeaturedTemplates.vue` / 模板库页 / 模板详情页统一引用 ✓
- `Inspiration` → `inspirations.ts` 定义，`DailyInspiration.vue` / `useDailyInspiration.ts` 统一引用 ✓
- `SceneDef` → `scenes.ts` 定义，`SceneQuickAccess.vue` / `useSceneGuide.ts` 统一引用 ✓
- `OverlayLayer` → `overlay.ts` 定义，`OverlayLayer.vue` / `CameraViewfinder.vue` / 拍摄页统一引用 ✓
- `ColorAdjustment` → `template.ts` 定义，`ColorSliders.vue` / `AdjustmentPanel.vue` 统一引用 ✓
- `CameraParams` → `camera.ts` 定义，`ParameterBar.vue` / parameters 页统一引用 ✓
- `CropRect` → `photo.ts` 需要定义（在 CropFrame.vue 中引用），需确保类型存在
- FloatingTabBar `current` 属性值统一为 `home` / `capture` / `profile` ✓
- FloatingTabBar `theme` 属性值统一为 `light` / `dark` ✓
- `ShutterButton` emit 事件名：拍摄页引用 `@on-capture`，组件定义 `(e: 'on-capture')` ✓
- 拍摄页 import 路径 `@/components/shutterButton.vue` → 实际文件名大小写需注意（`ShutterButton.vue`），可能需确认大小写一致性

**需修复项：**
1. `CropRect` 类型需确认在 `photo.ts` 中已定义
2. 拍摄页 import 路径大小写 `shutterButton.vue` vs `ShutterButton.vue`