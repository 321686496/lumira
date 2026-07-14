# 拍照页核心功能完善实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构拍照页参数调整体系，新增三种使用模式（模板/自由调参/原相机）、模块化组件、苹果原相机风格参数集与系统内置滤镜。

**Architecture:** 双状态机分离（`rawMode` ref + `applied` computed），三独立组件（ApplyButton/RawModeToggle/FilterPicker/AdvancedSection），类型系统扩展（SystemFilter/LutPreset 扩展/CameraParams 新字段），filterRecipe 扩展支持 systemFilter。

**Tech Stack:** uni-app + Vue 3 + TypeScript + SCSS + Phosphor Icons

## Global Constraints

- 所有页面必须使用 uni-app 组件（`<view>` 替代 `<div>`，`<text>` 替代 `<span>`，`<image>` 替代 `<img>`）
- CSS 单位使用 rpx 替代 px
- 所有样式只能使用 class 选择器，不可使用标签选择器
- 图标使用 Phosphor Icons（`<text class="ph ph-xxx" />`），不使用 emoji
- `<image>` 组件不支持 `:alt` 属性
- SCSS 变量在 template 内联 style 中不生效，需使用具体颜色值或 style 块类
- 所有图像资源来自 picsum.photos
- 标题栏文本不居中
- 设计文档：`docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md`

---

## 文件结构

### 新增文件

| 文件路径 | 职责 |
|---------|------|
| `lumira-app/src/utils/parameterMatch.ts` | 参数匹配判定（isParametersMatchingTemplate + ADJUSTABLE_PARAM_PATHS） |
| `lumira-app/src/utils/emptyTemplate.ts` | 空白模板工厂（createEmptyTemplate） |
| `lumira-app/src/components/AdvancedSection.vue` | 通用折叠容器组件，slot 接收高级参数 |
| `lumira-app/src/components/ApplyButton.vue` | 一键应用按钮组件 |
| `lumira-app/src/components/RawModeToggle.vue` | 原相机↔模板切换按钮组件 |
| `lumira-app/src/components/FilterPicker.vue` | 滤镜选择面板（系统滤镜 + LUT） |

### 修改文件

| 文件路径 | 职责 |
|---------|------|
| `lumira-app/src/types/template.ts` | 类型扩展：SystemFilter/LutPreset 扩展/CameraParams 新字段/PostProcess.systemFilter/Pose.positionX/Y |
| `lumira-app/src/utils/filterRecipe.ts` | SYSTEM_FILTERS 字典 + LUT_FILTERS 扩展 + buildCssFilter 支持 systemFilter |
| `lumira-app/src/components/ParamPanel.vue` | 各 Tab 内 AdvancedSection 折叠区 + 只读参数改可调 + 后期 Tab 滤镜区 + apply-btn 修复 |
| `lumira-app/src/pages/capture/index.vue` | 重构状态机 + 集成新组件 + 死代码清理 |

---

## Task 1: 类型系统扩展

**Files:**
- Modify: `lumira-app/src/types/template.ts`

**Interfaces:**
- Produces: `SystemFilter` 类型、扩展的 `LutPreset` 类型、`CameraParams.lensType/photographicStyle/hdr`、`PostProcess.systemFilter`、`Pose.positionX/positionY`

- [ ] **Step 1: 扩展 LutPreset 类型**

打开 `lumira-app/src/types/template.ts`，将第 38-47 行的 `LutPreset` 类型扩展为 16 种：

```ts
/** 后期 LUT 预设 */
export type LutPreset =
  | 'none'
  | 'cinematic'
  | 'vintage'
  | 'bw'
  | 'warm_film'
  | 'cool_film'
  | 'pastel'
  | 'fuji'
  // 新增 8 种
  | 'portrait'
  | 'japanese'
  | 'cyberpunk'
  | 'sepia_classic'
  | 'mist'
  | 'rouge'
  | 'twilight'
  | 'cyan'
```

- [ ] **Step 2: 新增 SystemFilter 类型**

在 `LutPreset` 类型定义之后追加：

```ts
/** 系统内置滤镜（苹果风格） */
export type SystemFilter =
  | 'none'
  | 'vivid'
  | 'vivid_warm'
  | 'vivid_cool'
  | 'mono'
  | 'silver'
  | 'noir'
```

- [ ] **Step 3: 新增 LensType / PhotographicStyle 类型**

在 `LensSuggestion` 类型定义之后追加：

```ts
/** 镜头类型（仅记录，不真切换硬件） */
export type LensType = '0.5x' | '1x' | '2x' | '3x'

/** 拍照风格（参照苹果原相机） */
export type PhotographicStyle = 'standard' | 'high_contrast' | 'warm' | 'cool' | 'mono'
```

- [ ] **Step 4: 扩展 CameraParams 接口**

将 `CameraParams` 接口（约第 112-128 行）修改为：

```ts
/** 相机参数 */
export interface CameraParams {
  /** EV 值，-3 ~ +3 */
  exposureCompensation: number
  /** ISO 值（auto 时为建议值） */
  iso: number
  /** 快门，如 '1/200'、'1/30' */
  shutterSpeed: string
  whiteBalance: WhiteBalance
  /** 色温 K 值（custom 时使用） */
  whiteBalanceK: number
  flashMode: FlashMode
  focusMode: FocusMode
  /** 镜头类型（仅记录） */
  lensType?: LensType
  /** 拍照风格 */
  photographicStyle?: PhotographicStyle
  /** HDR 开关 */
  hdr?: boolean
  /** @deprecated 改用 lensType */
  lensSuggestion?: LensSuggestion
  /** @deprecated 改用独立滤镜系统 */
  filterPreset?: string
  /** @deprecated 无意义字段 */
  isoMode?: IsoMode
}
```

注意：保留 `lensSuggestion`/`filterPreset`/`isoMode` 为可选 + @deprecated，避免破坏现有 12 个内置模板的数据结构（本阶段不动模板）。

- [ ] **Step 5: 扩展 PostProcess 接口**

在 `PostProcess` 接口（约第 147-170 行）的 `lut` 字段后追加：

```ts
  /** LUT 预设 */
  lut: LutPreset
  /** 系统内置滤镜（苹果风格） */
  systemFilter?: SystemFilter
```

- [ ] **Step 6: 扩展 Pose 接口**

在 `Pose` 接口（约第 99-109 行）的 `position` 字段后追加：

```ts
  /** 归一化位置 0-1 */
  position: { x: number; y: number }
  /** 剪影位置 X 偏移 -100~100（用于精细调整） */
  positionX?: number
  /** 剪影位置 Y 偏移 -100~100 */
  positionY?: number
```

- [ ] **Step 7: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS（无新增错误；现有 12 个模板的字段兼容性已通过 @deprecated 可选字段保证）

- [ ] **Step 8: Commit**

```bash
git add lumira-app/src/types/template.ts
git commit -m "feat(types): 扩展 SystemFilter/LutPreset/CameraParams 类型"
```

---

## Task 2: 滤镜配方系统扩展

**Files:**
- Modify: `lumira-app/src/utils/filterRecipe.ts`

**Interfaces:**
- Consumes: `SystemFilter`, `LutPreset` from Task 1
- Produces: `SYSTEM_FILTERS` 字典、扩展的 `LUT_FILTERS` 字典、`getSystemFilterLabel` 函数、`buildCssFilter` 支持读取 `post.systemFilter`

- [ ] **Step 1: 扩展 LUT_FILTERS 字典**

打开 `lumira-app/src/utils/filterRecipe.ts`，将第 20-36 行的 `LUT_FILTERS` 字典扩展为 16 项：

```ts
/** LUT 预设对应的复合 filter（不含基础调整） */
const LUT_FILTERS: Record<LutPreset, string> = {
  none: '',
  // 电影感：橙青调，高对比
  cinematic: 'contrast(1.15) saturate(0.9) hue-rotate(-8deg) brightness(0.97)',
  // 复古胶片：暖色 + 颗粒感（颗粒另算）
  vintage: 'sepia(0.35) contrast(1.1) brightness(1.05) saturate(0.85)',
  // 黑白
  bw: 'grayscale(1) contrast(1.1)',
  // 暖色胶片
  warm_film: 'sepia(0.2) saturate(1.15) brightness(1.03) hue-rotate(-5deg)',
  // 冷色胶片
  cool_film: 'saturate(0.9) brightness(0.98) hue-rotate(8deg)',
  // 柔色
  pastel: 'contrast(0.92) saturate(0.85) brightness(1.08)',
  // 富士胶片感
  fuji: 'saturate(1.2) contrast(1.05) hue-rotate(-3deg) brightness(1.02)',
  // 新增 8 种
  portrait: 'saturate(1.05) contrast(1.05) brightness(1.03) sepia(0.05)',
  japanese: 'saturate(0.85) contrast(0.92) brightness(1.1) hue-rotate(3deg)',
  cyberpunk: 'saturate(1.4) contrast(1.2) hue-rotate(-15deg) brightness(0.95)',
  sepia_classic: 'sepia(0.7) contrast(1.05) brightness(1.02)',
  mist: 'contrast(0.88) brightness(1.12) saturate(0.9)',
  rouge: 'sepia(0.2) saturate(1.1) hue-rotate(-10deg) brightness(1.02)',
  twilight: 'saturate(1.15) hue-rotate(15deg) contrast(1.05) brightness(0.95)',
  cyan: 'saturate(1.1) hue-rotate(20deg) contrast(1.05) brightness(1.02)'
}
```

- [ ] **Step 2: 新增 SYSTEM_FILTERS 字典**

在 `LUT_FILTERS` 字典之后追加：

```ts
/** 系统内置滤镜（苹果风格）对应的 filter */
export const SYSTEM_FILTERS: Record<SystemFilter, string> = {
  none: '',
  vivid: 'contrast(1.1) saturate(1.25) brightness(1.02)',
  vivid_warm: 'sepia(0.15) saturate(1.2) contrast(1.08) brightness(1.03) hue-rotate(-5deg)',
  vivid_cool: 'saturate(1.15) contrast(1.08) brightness(1.02) hue-rotate(8deg)',
  mono: 'grayscale(1) contrast(1.05)',
  silver: 'grayscale(1) sepia(0.2) contrast(0.95) brightness(1.08)',
  noir: 'grayscale(1) contrast(1.3) brightness(0.95)'
}
```

- [ ] **Step 3: 修改 import 引入 SystemFilter**

将第 17 行的 import 修改为：

```ts
import type { CameraParams, PostProcess, LutPreset, WhiteBalance, SystemFilter } from '@/types/template'
```

- [ ] **Step 4: 修改 buildCssFilter 函数**

将 `buildCssFilter` 函数（约第 65-141 行）末尾的 LUT 应用逻辑之前，新增 systemFilter 应用逻辑。定位到第 132-138 行的 LUT 应用块：

```ts
  // LUT 预设（叠加在基础调整之后）
  const lut = post.lut ?? 'none'
  const lutFilter = LUT_FILTERS[lut] || ''
  if (lutFilter) {
    filters.push(lutFilter)
  }

  return filters.join(' ')
}
```

替换为：

```ts
  // 系统内置滤镜（在 LUT 之前应用，类似苹果原相机滤镜）
  const systemFilter = post.systemFilter ?? 'none'
  const systemFilterStr = SYSTEM_FILTERS[systemFilter] || ''
  if (systemFilterStr) {
    filters.push(systemFilterStr)
  }

  // LUT 预设（叠加在系统滤镜之后）
  const lut = post.lut ?? 'none'
  const lutFilter = LUT_FILTERS[lut] || ''
  if (lutFilter) {
    filters.push(lutFilter)
  }

  return filters.join(' ')
}
```

- [ ] **Step 5: 新增 getSystemFilterLabel 函数**

在文件末尾追加：

```ts
/**
 * 获取系统内置滤镜的显示名称
 */
export function getSystemFilterLabel(filter: SystemFilter): string {
  const map: Record<SystemFilter, string> = {
    none: '原图',
    vivid: '鲜明',
    vivid_warm: '鲜暖色',
    vivid_cool: '鲜冷色',
    mono: '单色',
    silver: '银色调',
    noir: '黑白'
  }
  return map[filter] || '原图'
}

/**
 * 获取所有系统滤镜选项（用于 UI 渲染）
 */
export function getSystemFilterOptions(): { id: SystemFilter; name: string; filter: string }[] {
  return (Object.keys(SYSTEM_FILTERS) as SystemFilter[]).map((id) => ({
    id,
    name: getSystemFilterLabel(id),
    filter: SYSTEM_FILTERS[id]
  }))
}

/**
 * 获取所有 LUT 预设选项（用于 UI 渲染）
 */
export function getLutOptions(): { id: LutPreset; name: string; filter: string }[] {
  return (Object.keys(LUT_FILTERS) as LutPreset[]).map((id) => ({
    id,
    name: getLutLabel(id),
    filter: LUT_FILTERS[id]
  }))
}
```

- [ ] **Step 6: 扩展 getLutLabel 函数**

将 `getLutLabel` 函数（约第 185-197 行）的 map 扩展为 16 项：

```ts
export function getLutLabel(lut: LutPreset): string {
  const map: Record<LutPreset, string> = {
    none: '原图',
    cinematic: '电影感',
    vintage: '复古胶片',
    bw: '黑白',
    warm_film: '暖色胶片',
    cool_film: '冷色胶片',
    pastel: '柔色',
    fuji: '富士感',
    portrait: '人像',
    japanese: '日系',
    cyberpunk: '赛博朋克',
    sepia_classic: '褐调',
    mist: '薄雾',
    rouge: '胭脂',
    twilight: '暮光',
    cyan: '青调'
  }
  return map[lut] || '原图'
}
```

- [ ] **Step 7: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lumira-app/src/utils/filterRecipe.ts
git commit -m "feat(filterRecipe): 扩展 LUT 至 16 项 + 新增 6 种系统滤镜"
```

---

## Task 3: 参数匹配判定工具

**Files:**
- Create: `lumira-app/src/utils/parameterMatch.ts`

**Interfaces:**
- Consumes: `PhotoTemplate` from `@/types/template`
- Produces: `isParametersMatchingTemplate(current, original): boolean`

- [ ] **Step 1: 创建 parameterMatch.ts**

```ts
import type { PhotoTemplate } from '@/types/template'

/**
 * 可调参数路径列表
 * 任何一项与模板原值不一致，applied 即变为 false
 */
const ADJUSTABLE_PARAM_PATHS = [
  // 相机 Tab
  'camera.exposureCompensation',
  'camera.iso',
  'camera.shutterSpeed',
  'camera.whiteBalance',
  'camera.whiteBalanceK',
  'camera.flashMode',
  'camera.focusMode',
  'camera.lensType',
  'camera.photographicStyle',
  'camera.hdr',
  // 构图 Tab
  'composition.overlayType',
  'composition.gridType',
  'composition.aspectRatio',
  'composition.subjectFrame',
  'composition.opacity',
  // 姿势 Tab
  'pose.silhouetteType',
  'pose.positionX',
  'pose.positionY',
  'pose.scale',
  'pose.rotation',
  // 后期 Tab
  'postProcess.systemFilter',
  'postProcess.lut',
  'postProcess.cropRatio',
  'postProcess.color.brightness',
  'postProcess.color.contrast',
  'postProcess.color.saturation',
  'postProcess.color.temperature',
  'postProcess.color.tint',
  'postProcess.smoothStrength',
  'postProcess.sharpen',
  'postProcess.vignette',
  'postProcess.grain'
] as const

/**
 * 按路径获取对象深层属性值
 * 支持 'a.b.c' 形式
 */
function getPath(obj: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>((acc, key) => {
    if (acc === null || acc === undefined) return undefined
    return (acc as Record<string, unknown>)[key]
  }, obj)
}

/**
 * 判定当前可编辑模板的参数是否与原模板一致
 * 所有可调参数都参与比较，任一不一致返回 false
 */
export function isParametersMatchingTemplate(
  current: PhotoTemplate,
  original: PhotoTemplate
): boolean {
  for (const path of ADJUSTABLE_PARAM_PATHS) {
    const curVal = getPath(current, path)
    const origVal = getPath(original, path)
    // 处理 undefined 与默认值兼容（如 positionX/positionY 可能在旧模板中不存在）
    if (curVal === undefined && origVal === undefined) continue
    if (curVal !== origVal) return false
  }
  return true
}
```

- [ ] **Step 2: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/utils/parameterMatch.ts
git commit -m "feat(utils): 新增参数匹配判定工具"
```

---

## Task 4: 空白模板工厂

**Files:**
- Create: `lumira-app/src/utils/emptyTemplate.ts`

**Interfaces:**
- Consumes: `PhotoTemplate` from `@/types/template`
- Produces: `createEmptyTemplate(): PhotoTemplate`

- [ ] **Step 1: 创建 emptyTemplate.ts**

```ts
import type { PhotoTemplate } from '@/types/template'

/**
 * 创建空白模板（用于自由调参模式）
 * 所有参数为默认值，不产生任何滤镜效果
 */
export function createEmptyTemplate(): PhotoTemplate {
  return {
    meta: {
      id: '__empty__',
      name: '自由调参',
      author: '',
      version: '1.0.0',
      category: 'portrait',
      tags: [],
      price: 0,
      cover: '',
      description: '自由调整相机与后期参数',
      referenceSource: ''
    },
    composition: {
      overlayType: 'none',
      gridType: 'thirds',
      subjectFrame: { x: 0.3, y: 0.3, w: 0.4, h: 0.4 },
      opacity: 1,
      aspectRatio: '3:4',
      description: ''
    },
    pose: {
      silhouette: { type: 'builtin', data: 'none' },
      position: { x: 0.5, y: 0.5 },
      positionX: 0,
      positionY: 0,
      scale: 1,
      rotation: 0,
      description: ''
    },
    camera: {
      exposureCompensation: 0,
      iso: 0,
      shutterSpeed: 'auto',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensType: '1x',
      photographicStyle: 'standard',
      hdr: false
    },
    sceneGuide: {
      lightDirection: '',
      shootingDistance: '',
      background: '',
      props: [],
      bestTime: '',
      tips: []
    },
    postProcess: {
      cropRatio: '3:4',
      color: {
        brightness: 0,
        contrast: 0,
        saturation: 0,
        temperature: 0,
        tint: 0
      },
      smoothStrength: 0,
      sharpen: 0,
      vignette: 0,
      grain: 0,
      lut: 'none',
      systemFilter: 'none'
    }
  }
}
```

- [ ] **Step 2: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/utils/emptyTemplate.ts
git commit -m "feat(utils): 新增空白模板工厂（自由调参模式用）"
```

---

## Task 5: AdvancedSection 折叠容器组件

**Files:**
- Create: `lumira-app/src/components/AdvancedSection.vue`

**Interfaces:**
- Props: `title: string`, `open: boolean`
- Slots: default（接收高级参数控件）
- Emits: `update:open`

- [ ] **Step 1: 创建 AdvancedSection.vue**

```vue
<template>
  <view class="advanced-section">
    <view class="advanced-toggle" @click="toggleOpen">
      <text class="advanced-title">{{ title }}</text>
      <text class="ph advanced-caret" :class="open ? 'ph-caret-up' : 'ph-caret-down'" />
    </view>
    <view v-if="open" class="advanced-content">
      <slot />
    </view>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  title: string
  open: boolean
}>()

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
}>()

const toggleOpen = () => {
  emit('update:open', !props.open)
}
</script>

<style lang="scss" scoped>
.advanced-section {
  margin-top: 16rpx;
  border-top: 1rpx solid rgba(255, 255, 255, 0.08);
  padding-top: 16rpx;
}

.advanced-toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16rpx 20rpx;
  background: rgba(255, 255, 255, 0.04);
  border-radius: 12rpx;
}

.advanced-title {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.75);
  font-weight: 500;
}

.advanced-caret {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.6);
}

.advanced-content {
  padding-top: 16rpx;
}
</style>
```

- [ ] **Step 2: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/components/AdvancedSection.vue
git commit -m "feat(component): 新增 AdvancedSection 折叠容器组件"
```

---

## Task 6: ApplyButton 一键应用按钮组件

**Files:**
- Create: `lumira-app/src/components/ApplyButton.vue`

**Interfaces:**
- Props: `applied: boolean`
- Emits: `apply`（点击未应用时触发，由父组件执行参数重置）

- [ ] **Step 1: 创建 ApplyButton.vue**

```vue
<template>
  <view
    class="apply-pill"
    :class="{ applied }"
    @click.stop="onClick"
  >
    <text class="ph" :class="applied ? 'ph-check' : 'ph-sparkle'" />
    <text class="pill-text">{{ applied ? '已应用' : '一键应用' }}</text>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  applied: boolean
}>()

const emit = defineEmits<{
  (e: 'apply'): void
}>()

const onClick = () => {
  if (props.applied) {
    uni.showToast({ title: '参数已是模板原值', icon: 'none' })
    return
  }
  emit('apply')
}
</script>

<style lang="scss" scoped>
.apply-pill {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 20rpx;
  border-radius: 999rpx;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}

.apply-pill .ph {
  font-size: 26rpx;
  color: #fff;
}

.apply-pill .pill-text {
  font-size: 24rpx;
  color: #fff;
  font-weight: 500;
}

.apply-pill.applied {
  background: rgba(76, 175, 80, 0.85);
}

.apply-pill.applied .ph {
  color: #fff;
}
</style>
```

- [ ] **Step 2: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/components/ApplyButton.vue
git commit -m "feat(component): 新增 ApplyButton 一键应用按钮组件"
```

---

## Task 7: RawModeToggle 原相机切换组件

**Files:**
- Create: `lumira-app/src/components/RawModeToggle.vue`

**Interfaces:**
- Props: `rawMode: boolean`, `hasTemplate: boolean`（决定按钮文案：模板/自由）
- Emits: `update:rawMode`

- [ ] **Step 1: 创建 RawModeToggle.vue**

```vue
<template>
  <view
    class="raw-toggle-pill"
    :class="{ active: rawMode }"
    @click.stop="toggle"
  >
    <text class="ph ph-camera" />
    <text class="pill-text">{{ rawMode ? '原相机' : (hasTemplate ? '模板' : '自由') }}</text>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  rawMode: boolean
  hasTemplate: boolean
}>()

const emit = defineEmits<{
  (e: 'update:rawMode', value: boolean): void
}>()

const toggle = () => {
  emit('update:rawMode', !props.rawMode)
}
</script>

<style lang="scss" scoped>
.raw-toggle-pill {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 20rpx;
  border-radius: 999rpx;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}

.raw-toggle-pill .ph {
  font-size: 26rpx;
  color: #fff;
}

.raw-toggle-pill .pill-text {
  font-size: 24rpx;
  color: #fff;
  font-weight: 500;
}

.raw-toggle-pill.active {
  background: rgba(255, 204, 0, 0.9);
}

.raw-toggle-pill.active .ph,
.raw-toggle-pill.active .pill-text {
  color: #181614;
}
</style>
```

- [ ] **Step 2: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/components/RawModeToggle.vue
git commit -m "feat(component): 新增 RawModeToggle 原相机切换组件"
```

---

## Task 8: FilterPicker 滤镜选择面板组件

**Files:**
- Create: `lumira-app/src/components/FilterPicker.vue`

**Interfaces:**
- Props: `visible: boolean`, `currentSystemFilter: SystemFilter`, `currentLut: LutPreset`, `disabled: boolean`（原相机模式下禁用）
- Emits: `update:visible`, `select-system-filter`, `select-lut`

- [ ] **Step 1: 创建 FilterPicker.vue**

```vue
<template>
  <view v-if="visible" class="filter-picker-mask" @click.stop="close">
    <view class="filter-picker" @click.stop>
      <view class="picker-header">
        <text class="picker-title">滤镜</text>
        <view class="picker-close" @click="close">
          <text class="ph ph-x" />
        </view>
      </view>

      <scroll-view scroll-y class="picker-body">
        <!-- 系统滤镜区 -->
        <view class="filter-group">
          <text class="group-title">系统滤镜</text>
          <scroll-view scroll-x class="filter-list">
            <view class="filter-list-inner">
              <view
                v-for="f in systemFilterOptions"
                :key="f.id"
                class="filter-item"
                :class="{ active: currentSystemFilter === f.id }"
                @click="selectSystemFilter(f.id)"
              >
                <view class="filter-thumb" :style="thumbStyle(f.filter)">
                  <image
                    class="thumb-img"
                    src="https://picsum.photos/seed/filter-thumb/120/120"
                    mode="aspectFill"
                  />
                </view>
                <text class="filter-name">{{ f.name }}</text>
              </view>
            </view>
          </scroll-view>
        </view>

        <!-- LUT 预设区 -->
        <view class="filter-group">
          <text class="group-title">LUT 预设</text>
          <scroll-view scroll-x class="filter-list">
            <view class="filter-list-inner">
              <view
                v-for="f in lutOptions"
                :key="f.id"
                class="filter-item"
                :class="{ active: currentLut === f.id }"
                @click="selectLut(f.id)"
              >
                <view class="filter-thumb" :style="thumbStyle(f.filter)">
                  <image
                    class="thumb-img"
                    src="https://picsum.photos/seed/lut-thumb/120/120"
                    mode="aspectFill"
                  />
                </view>
                <text class="filter-name">{{ f.name }}</text>
              </view>
            </view>
          </scroll-view>
        </view>
      </scroll-view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import {
  getSystemFilterOptions,
  getLutOptions
} from '@/utils/filterRecipe'
import type { SystemFilter, LutPreset } from '@/types/template'

const props = defineProps<{
  visible: boolean
  currentSystemFilter: SystemFilter
  currentLut: LutPreset
  disabled: boolean
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'select-system-filter', value: SystemFilter): void
  (e: 'select-lut', value: LutPreset): void
}>()

const systemFilterOptions = computed(() => getSystemFilterOptions())
const lutOptions = computed(() => getLutOptions())

const close = () => {
  emit('update:visible', false)
}

const selectSystemFilter = (id: SystemFilter) => {
  if (props.disabled) {
    uni.showToast({ title: '已切换至原相机模式，请先退出', icon: 'none' })
    return
  }
  emit('select-system-filter', id)
}

const selectLut = (id: LutPreset) => {
  if (props.disabled) {
    uni.showToast({ title: '已切换至原相机模式，请先退出', icon: 'none' })
    return
  }
  emit('select-lut', id)
}

const thumbStyle = (filter: string) => {
  if (!filter) return {}
  return { filter, webkitFilter: filter }
}
</script>

<style lang="scss" scoped>
.filter-picker-mask {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 200;
  display: flex;
  align-items: flex-end;
}

.filter-picker {
  width: 100%;
  max-height: 70vh;
  background: #1a1816;
  border-radius: 32rpx 32rpx 0 0;
  display: flex;
  flex-direction: column;
}

.picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28rpx 32rpx 16rpx;
  border-bottom: 1rpx solid rgba(255, 255, 255, 0.08);
}

.picker-title {
  font-size: 32rpx;
  color: #fff;
  font-weight: 600;
}

.picker-close .ph {
  font-size: 36rpx;
  color: rgba(255, 255, 255, 0.7);
}

.picker-body {
  padding: 16rpx 0 32rpx;
}

.filter-group {
  margin-top: 16rpx;
}

.group-title {
  display: block;
  padding: 0 32rpx 16rpx;
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.6);
  font-weight: 500;
}

.filter-list {
  white-space: nowrap;
}

.filter-list-inner {
  display: inline-flex;
  gap: 16rpx;
  padding: 0 32rpx;
}

.filter-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  width: 120rpx;
}

.filter-thumb {
  width: 120rpx;
  height: 120rpx;
  border-radius: 16rpx;
  overflow: hidden;
  border: 3rpx solid transparent;
}

.filter-item.active .filter-thumb {
  border-color: #ffcc00;
}

.thumb-img {
  width: 100%;
  height: 100%;
}

.filter-name {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.85);
}

.filter-item.active .filter-name {
  color: #ffcc00;
  font-weight: 600;
}
</style>
```

- [ ] **Step 2: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lumira-app/src/components/FilterPicker.vue
git commit -m "feat(component): 新增 FilterPicker 滤镜选择面板组件"
```

---

## Task 9: 重构 capture/index.vue 状态机

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`

**Interfaces:**
- Consumes: `createEmptyTemplate` from Task 4, `isParametersMatchingTemplate` from Task 3, `ApplyButton`/`RawModeToggle`/`FilterPicker` from Tasks 6-8
- Produces: 重构后的 capture 页面支持三种模式（模板/自由调参/原相机）

- [ ] **Step 1: 修改顶部 pill 栏模板（行 83-96）**

将第 83-96 行的 `param-pill_bar` 块替换为（移除 `v-if="currentTemplate"`，集成新组件）：

```vue
      <!-- 顶部参数 pill 栏 -->
      <view class="param-pill-bar" :style="landscapeZoomStyle">
        <view class="param-pill" @click.stop="openPanel('camera')">
          <text class="pill-label">EV</text>
          <text class="pill-value">{{ evDisplay }}</text>
        </view>
        <view class="param-pill" @click.stop="openPanel('camera')">
          <text class="pill-label">WB</text>
          <text class="pill-value">{{ wbDisplay }}</text>
        </view>
        <ApplyButton
          v-if="originalTemplate"
          :applied="applied"
          @apply="onApplyClick"
        />
        <RawModeToggle
          :raw-mode="rawMode"
          :has-template="!!originalTemplate"
          @update:raw-mode="rawMode = $event"
        />
        <view class="param-pill" @click.stop="openFilterPicker">
          <text class="ph ph-funnel" />
          <text class="pill-text">滤镜</text>
        </view>
      </view>
```

- [ ] **Step 2: 修改 ParamPanel 渲染条件（行 140-149）**

将第 140-149 行的 ParamPanel 块替换为（移除 `v-if="editableTemplate"`，使用 `activeTemplate`）：

```vue
    <ParamPanel
      v-if="activeTemplate"
      :template="activeTemplate"
      :visible="panelExpanded"
      :applied="applied"
      :raw-mode="rawMode"
      @close="panelExpanded = false"
      @apply="onApplyClick"
      @update:opacity="onOpacityUpdate"
      @update:template="onTemplateUpdate"
      @select-system-filter="onSelectSystemFilter"
      @select-lut="onSelectLut"
    />

    <FilterPicker
      :visible="filterPickerVisible"
      :current-system-filter="activeTemplate?.postProcess.systemFilter || 'none'"
      :current-lut="activeTemplate?.postProcess.lut || 'none'"
      :disabled="rawMode"
      @update:visible="filterPickerVisible = $event"
      @select-system-filter="onSelectSystemFilter"
      @select-lut="onSelectLut"
    />
```

- [ ] **Step 3: 修改 nav-title 显示逻辑（行 11）**

将第 11 行的 nav-title 替换为：

```vue
          <text class="nav-title">{{ navTitle }}</text>
```

- [ ] **Step 4: 修改 script setup imports（行 153-162）**

将第 153-162 行的 script setup 头部替换为：

```ts
<script setup lang="ts">
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { onLoad, onUnload } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import { useCamera } from '@/composables/useCamera'
import { buildCssFilter } from '@/utils/filterRecipe'
import { isParametersMatchingTemplate } from '@/utils/parameterMatch'
import { createEmptyTemplate } from '@/utils/emptyTemplate'
import type { PhotoTemplate, SystemFilter, LutPreset } from '@/types/template'
import CompositionOverlay from '@/components/CompositionOverlay.vue'
import PoseSilhouette from '@/components/PoseSilhouette.vue'
import ParamPanel from '@/components/ParamPanel.vue'
import ApplyButton from '@/components/ApplyButton.vue'
import RawModeToggle from '@/components/RawModeToggle.vue'
import FilterPicker from '@/components/FilterPicker.vue'

const { loadTemplate, recentTemplates, pushRecent, loadRecent } = useTemplate()
const camera = useCamera()

const statusBarHeight = uni.getSystemInfoSync().statusBarHeight || 20
const currentTemplateId = ref('')
const originalTemplate = computed<PhotoTemplate | null>(() =>
  currentTemplateId.value ? loadTemplate(currentTemplateId.value) : null
)
const editableTemplate = ref<PhotoTemplate | null>(null)
const emptyTemplate = createEmptyTemplate()

const panelExpanded = ref(false)
const filterPickerVisible = ref(false)
const rawMode = ref(false)
const flashOn = ref(false)
const isCapturing = ref(false)
const lastPhoto = ref('')

// applied 改为 computed：基于参数匹配判定
const applied = computed(() => {
  if (!originalTemplate.value || !editableTemplate.value) return false
  return isParametersMatchingTemplate(editableTemplate.value, originalTemplate.value)
})

// 当前生效的模板（决定 ParamPanel 显示哪份数据）
const activeTemplate = computed(() => {
  if (rawMode.value) return null
  return editableTemplate.value ?? emptyTemplate
})

// 标题栏显示文本
const navTitle = computed(() => {
  if (rawMode.value) return '原相机'
  if (originalTemplate.value) return originalTemplate.value.meta.name
  return '自由调参'
})
```

- [ ] **Step 5: 删除死代码 activeCamera/activePost（行 261-275）**

将第 261-275 行的 `activeCamera` 和 `activePost` computed 块整段删除（包括注释）。

- [ ] **Step 6: 修改 viewfinderFilterStyle（行 277-286）**

将第 277-286 行的 `viewfinderFilterStyle` computed 替换为：

```ts
// 实时滤镜样式（应用到占位图）
const viewfinderFilterStyle = computed(() => {
  // 原相机模式：无任何滤镜
  if (rawMode.value) return {}
  // 自由调参模式：使用 emptyTemplate
  if (!editableTemplate.value) {
    const filter = buildCssFilter(emptyTemplate.camera, emptyTemplate.postProcess)
    return filter ? { filter, webkitFilter: filter } : {}
  }
  // 模板模式：使用 editableTemplate
  const filter = buildCssFilter(
    editableTemplate.value.camera,
    editableTemplate.value.postProcess
  )
  return filter ? { filter, webkitFilter: filter } : {}
})
```

- [ ] **Step 7: 修改 applyVideoFilter（行 235-244）**

将第 235-244 行的 `applyVideoFilter` 函数替换为：

```ts
// 将 filter 样式应用到 video 元素
function applyVideoFilter() {
  if (!videoRef.value) return
  // 原相机模式：无任何滤镜
  if (rawMode.value) {
    videoRef.value.style.filter = ''
    videoRef.value.style.webkitFilter = ''
    return
  }
  // 自由调参模式：使用 emptyTemplate
  const tpl = editableTemplate.value ?? emptyTemplate
  const filter = buildCssFilter(tpl.camera, tpl.postProcess)
  videoRef.value.style.filter = filter
  videoRef.value.style.webkitFilter = filter
}
```

- [ ] **Step 8: 修改 watch 依赖（行 288-291）**

将第 288-291 行的 watch 替换为：

```ts
// 监听 rawMode / editableTemplate 变化，同步 filter 到 video 元素
watch([rawMode, editableTemplate], () => {
  applyVideoFilter()
}, { deep: true })
```

- [ ] **Step 9: 修改 onUnload（行 340-352）**

将第 340-352 行的 onUnload 替换为（移除 `applied.value = false`，因为 applied 已是 computed）：

```ts
onUnload(() => {
  // 退出时清空当前模板状态
  currentTemplateId.value = ''
  rawMode.value = false
  showTemplate.value = true
  showSilhouette.value = true
  // 释放相机资源
  camera.release()
  if (resizeListener) {
    uni.offWindowResize(resizeListener)
    resizeListener = null
  }
})
```

- [ ] **Step 10: 修改 toggleApply 函数为 onApplyClick（行 397-403）**

将第 397-403 行的 `toggleApply` 函数替换为：

```ts
// 一键应用：把 originalTemplate 深拷贝回 editableTemplate
const onApplyClick = () => {
  if (!originalTemplate.value) return
  if (applied.value) {
    uni.showToast({ title: '参数已是模板原值', icon: 'none' })
    return
  }
  editableTemplate.value = JSON.parse(JSON.stringify(originalTemplate.value))
  // applied 会自动变 true（computed）
}
```

- [ ] **Step 11: 修改 switchTemplate（行 416-420）**

将第 416-420 行的 `switchTemplate` 函数替换为：

```ts
const switchTemplate = (id: string) => {
  currentTemplateId.value = id
  // editableTemplate 通过 watch(originalTemplate) 自动深拷贝
  // applied 自动变 true（参数与原值一致）
  rawMode.value = false  // 切换模板时退出原相机模式
  pushRecent(id)
}
```

- [ ] **Step 12: 修改 onShutter（行 434-466）**

将第 434-466 行的 `onShutter` 函数中第 443-449 行的 cameraParams/postParams 计算替换为：

```ts
    // 拍照：截帧 + 应用所有滤镜 + 烘焙为 dataURL
    let cameraParams: Partial<typeof editableTemplate.value extends null ? never : PhotoTemplate['camera']>
    let postParams: Partial<typeof editableTemplate.value extends null ? never : PhotoTemplate['postProcess']>
    if (rawMode.value) {
      // 原相机模式：拍照无滤镜
      cameraParams = {}
      postParams = {}
    } else {
      const tpl = editableTemplate.value ?? emptyTemplate
      cameraParams = tpl.camera
      postParams = tpl.postProcess
    }

    const result = await camera.capture(cameraParams, postParams)
```

如果上述类型推导报错，简化为：

```ts
    // 拍照：截帧 + 应用所有滤镜 + 烘焙为 dataURL
    let cameraParams: Record<string, unknown>
    let postParams: Record<string, unknown>
    if (rawMode.value) {
      // 原相机模式：拍照无滤镜
      cameraParams = {}
      postParams = {}
    } else {
      const tpl = editableTemplate.value ?? emptyTemplate
      cameraParams = tpl.camera as unknown as Record<string, unknown>
      postParams = tpl.postProcess as unknown as Record<string, unknown>
    }

    const result = await camera.capture(cameraParams, postParams)
```

- [ ] **Step 13: 新增滤镜选择处理函数与 onTemplateUpdate 兼容性**

在 `onTemplateUpdate` 函数（行 412-414）之后追加：

```ts
// FilterPicker 选择系统滤镜
const onSelectSystemFilter = (filter: SystemFilter) => {
  const target = editableTemplate.value ?? emptyTemplate
  target.postProcess.systemFilter = filter
  if (!editableTemplate.value) {
    // 自由调参模式下，emptyTemplate 是模块级单例，需要触发响应式
    editableTemplate.value = JSON.parse(JSON.stringify(emptyTemplate))
  }
}

// FilterPicker 选择 LUT
const onSelectLut = (lut: LutPreset) => {
  const target = editableTemplate.value ?? emptyTemplate
  target.postProcess.lut = lut
  if (!editableTemplate.value) {
    editableTemplate.value = JSON.parse(JSON.stringify(emptyTemplate))
  }
}

const openFilterPicker = () => {
  if (rawMode.value) {
    uni.showToast({ title: '已切换至原相机模式，请先退出', icon: 'none' })
    return
  }
  filterPickerVisible.value = true
}
```

- [ ] **Step 14: 修改 evDisplay / wbDisplay 兼容自由调参模式（行 373-382）**

将第 373-382 行的 `evDisplay` 和 `wbDisplay` computed 替换为：

```ts
const evDisplay = computed(() => {
  const tpl = activeTemplate.value
  const ev = tpl?.camera.exposureCompensation
  if (ev === undefined || ev === 0) return '0'
  return ev > 0 ? `+${ev}` : `${ev}`
})

const wbDisplay = computed(() => {
  const tpl = activeTemplate.value
  const k = tpl?.camera.whiteBalanceK
  return k ? `${k}K` : '5500K'
})
```

- [ ] **Step 15: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 16: 启动开发服务器人工验证**

Run: `cd lumira-app && npm run dev:h5`
Expected:
1. 直接访问 `/pages/capture/index`（无 templateId）：ParamPanel 和 pill 栏可见可调
2. 标题栏显示"自由调参"
3. 点击"原相机"按钮，预览立即无滤镜，标题栏显示"原相机"
4. 点击"滤镜"按钮，FilterPicker 弹出
5. 从 template-strip 点击任意模板，标题栏显示模板名，参数默认应用

- [ ] **Step 17: Commit**

```bash
git add lumira-app/src/pages/capture/index.vue
git commit -m "feat(capture): 重构状态机支持三种模式（模板/自由调参/原相机）"
```

---

## Task 10: 重构 ParamPanel.vue 增加高级参数与滤镜区

**Files:**
- Modify: `lumira-app/src/components/ParamPanel.vue`

**Interfaces:**
- Consumes: `AdvancedSection` from Task 5, 扩展的类型 from Task 1, `getSystemFilterOptions`/`getLutOptions` from Task 2
- 新增 props: `rawMode: boolean`
- 新增 emits: `select-system-filter`, `select-lut`

- [ ] **Step 1: 修改 props 和 emits（行 500-511）**

将第 500-511 行的 props/emits 块替换为：

```ts
const props = defineProps<{
  template: PhotoTemplate
  visible: boolean
  applied: boolean
  rawMode: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'apply'): void
  (e: 'update:opacity', value: number): void
  (e: 'update:template', template: PhotoTemplate): void
  (e: 'select-system-filter', value: SystemFilter): void
  (e: 'select-lut', value: LutPreset): void
}>()
```

- [ ] **Step 2: 修改 import（行 498）**

将第 498 行的 import 替换为：

```ts
import { ref, computed } from 'vue'
import type { PhotoTemplate, WhiteBalance, FlashMode, FocusMode, LutPreset, SystemFilter, LensType, PhotographicStyle } from '@/types/template'
import { getSystemFilterOptions, getLutOptions } from '@/utils/filterRecipe'
import AdvancedSection from '@/components/AdvancedSection.vue'
```

- [ ] **Step 3: 修改底部 apply-btn 修复点击逻辑（行 482-491）**

将第 482-491 行的 `apply-btn` 块替换为（移除 `!applied &&` 短路）：

```vue
      <!-- 底部一键应用按钮 -->
      <view class="panel-footer">
        <view
          class="apply-btn"
          :class="{ 'is-applied': applied }"
          @click="onApplyClick"
        >
          <text class="ph" :class="applied ? 'ph-check-circle' : 'ph-sparkle'" />
          <text>{{ applied ? '已应用模板参数' : '一键应用模板参数' }}</text>
        </view>
      </view>
```

- [ ] **Step 4: 在 script 中新增 onApplyClick 与高级参数状态**

在 `activeTab` 定义（行 521）之后追加：

```ts
// 各 Tab 高级参数折叠状态
const advancedOpen = ref<Record<string, boolean>>({
  camera: false,
  composition: false,
  pose: false,
  post: false
})

const onApplyClick = () => {
  if (props.applied) {
    uni.showToast({ title: '参数已是模板原值', icon: 'none' })
    return
  }
  emit('apply')
}

// 选项列表
const shutterSpeedOptions = [
  { value: 'auto', label: 'Auto' },
  { value: '1/2000', label: '1/2000' },
  { value: '1/1000', label: '1/1000' },
  { value: '1/500', label: '1/500' },
  { value: '1/250', label: '1/250' },
  { value: '1/125', label: '1/125' },
  { value: '1/60', label: '1/60' },
  { value: '1/30', label: '1/30' },
  { value: '1/15', label: '1/15' },
  { value: '1/8', label: '1/8' },
  { value: '1/4', label: '1/4' },
  { value: '1/2', label: '1/2' },
  { value: '1"', label: '1"' },
  { value: '2"', label: '2"' },
  { value: '5"', label: '5"' },
  { value: '10"', label: '10"' },
  { value: '30"', label: '30"' }
]

const lensTypeOptions: { value: LensType; label: string }[] = [
  { value: '0.5x', label: '0.5x' },
  { value: '1x', label: '1x' },
  { value: '2x', label: '2x' },
  { value: '3x', label: '3x' }
]

const photographicStyleOptions: { value: PhotographicStyle; label: string }[] = [
  { value: 'standard', label: '标准' },
  { value: 'high_contrast', label: '高对比' },
  { value: 'warm', label: '暖色调' },
  { value: 'cool', label: '冷色调' },
  { value: 'mono', label: '单色' }
]

const overlayTypeOptions = [
  { value: 'rule_of_thirds', label: '三分法' },
  { value: 'golden_ratio', label: '黄金比例' },
  { value: 'diagonal', label: '对角线' },
  { value: 'grid', label: '网格' },
  { value: 'leading_lines', label: '引导线' },
  { value: 'center', label: '居中' },
  { value: 'none', label: '无' }
]

const gridTypeOptions = [
  { value: 'thirds', label: '三分' },
  { value: 'quarters', label: '四分' },
  { value: 'golden_spiral', label: '黄金螺旋' }
]

const aspectRatioOptions = [
  { value: '4:3', label: '4:3' },
  { value: '1:1', label: '1:1' },
  { value: '16:9', label: '16:9' },
  { value: '3:4', label: '3:4' }
]

const cropRatioOptions = [
  { value: '3:4', label: '3:4' },
  { value: '1:1', label: '1:1' },
  { value: '4:3', label: '4:3' },
  { value: '16:9', label: '16:9' }
]

const systemFilterOptions = computed(() => getSystemFilterOptions())
const lutOptions = computed(() => getLutOptions())

// 更新参数通用方法
const updateCamera = (key: string, value: unknown) => {
  if (props.rawMode) return
  ;(props.template.camera as Record<string, unknown>)[key] = value
  emit('update:template', props.template)
}

const updateComposition = (key: string, value: unknown) => {
  if (props.rawMode) return
  ;(props.template.composition as Record<string, unknown>)[key] = value
  emit('update:template', props.template)
}

const updatePose = (key: string, value: unknown) => {
  if (props.rawMode) return
  ;(props.template.pose as Record<string, unknown>)[key] = value
  emit('update:template', props.template)
}

const updatePost = (key: string, value: unknown) => {
  if (props.rawMode) return
  ;(props.template.postProcess as Record<string, unknown>)[key] = value
  emit('update:template', props.template)
}

const onSelectSystemFilter = (id: SystemFilter) => {
  emit('select-system-filter', id)
}

const onSelectLut = (id: LutPreset) => {
  emit('select-lut', id)
}
```

- [ ] **Step 5: 在相机 Tab 末尾增加 AdvancedSection（找到相机 Tab 的 `</view>` 结束前插入）**

定位 ParamPanel.vue 相机 Tab 的最后一个参数后（约第 152 行 `</scroll-view>` 前），追加：

```vue
            <AdvancedSection
              title="高级参数"
              :open="advancedOpen.camera"
              @update:open="advancedOpen.camera = $event"
            >
              <!-- 快门速度 -->
              <view class="param-row">
                <text class="param-label">快门速度</text>
                <scroll-view scroll-x class="pill-list">
                  <view class="pill-list-inner">
                    <view
                      v-for="opt in shutterSpeedOptions"
                      :key="opt.value"
                      class="pill"
                      :class="{ active: template.camera.shutterSpeed === opt.value }"
                      @click="updateCamera('shutterSpeed', opt.value)"
                    >
                      <text>{{ opt.label }}</text>
                    </view>
                  </view>
                </scroll-view>
              </view>

              <!-- 镜头切换 -->
              <view class="param-row">
                <text class="param-label">镜头</text>
                <view class="pill-list-inline">
                  <view
                    v-for="opt in lensTypeOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: (template.camera.lensType || '1x') === opt.value }"
                    @click="updateCamera('lensType', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </view>

              <!-- 拍照风格 -->
              <view class="param-row">
                <text class="param-label">拍照风格</text>
                <view class="pill-list-inline">
                  <view
                    v-for="opt in photographicStyleOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: (template.camera.photographicStyle || 'standard') === opt.value }"
                    @click="updateCamera('photographicStyle', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </view>

              <!-- HDR -->
              <view class="param-row">
                <text class="param-label">HDR</text>
                <view class="switch-row">
                  <switch
                    :checked="template.camera.hdr || false"
                    @change="updateCamera('hdr', $event.detail.value)"
                  />
                </view>
              </view>
            </AdvancedSection>
```

- [ ] **Step 6: 在构图 Tab 末尾增加 AdvancedSection**

定位构图 Tab 末尾，追加：

```vue
            <AdvancedSection
              title="高级参数"
              :open="advancedOpen.composition"
              @update:open="advancedOpen.composition = $event"
            >
              <view class="param-row">
                <text class="param-label">构图类型</text>
                <view class="pill-list-inline">
                  <view
                    v-for="opt in overlayTypeOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: template.composition.overlayType === opt.value }"
                    @click="updateComposition('overlayType', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </view>

              <view class="param-row">
                <text class="param-label">网格细分</text>
                <view class="pill-list-inline">
                  <view
                    v-for="opt in gridTypeOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: (template.composition.gridType || 'thirds') === opt.value }"
                    @click="updateComposition('gridType', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </view>

              <view class="param-row">
                <text class="param-label">宽高比</text>
                <view class="pill-list-inline">
                  <view
                    v-for="opt in aspectRatioOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: template.composition.aspectRatio === opt.value }"
                    @click="updateComposition('aspectRatio', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </view>

              <view class="param-row">
                <text class="param-label">主体建议框</text>
                <view class="switch-row">
                  <switch
                    :checked="!!template.composition.subjectFrame"
                    @change="updateComposition('subjectFrame', $event.detail.value ? { x: 0.3, y: 0.3, w: 0.4, h: 0.4 } : null)"
                  />
                </view>
              </view>
            </AdvancedSection>
```

- [ ] **Step 7: 在姿势 Tab 末尾增加 AdvancedSection**

定位姿势 Tab 末尾，追加：

```vue
            <AdvancedSection
              title="高级参数"
              :open="advancedOpen.pose"
              @update:open="advancedOpen.pose = $event"
            >
              <view class="param-row">
                <text class="param-label">位置 X</text>
                <slider
                  :value="template.pose.positionX || 0"
                  :min="-100"
                  :max="100"
                  :step="1"
                  @changing="updatePose('positionX', $event.detail.value)"
                  @change="updatePose('positionX', $event.detail.value)"
                />
              </view>

              <view class="param-row">
                <text class="param-label">位置 Y</text>
                <slider
                  :value="template.pose.positionY || 0"
                  :min="-100"
                  :max="100"
                  :step="1"
                  @changing="updatePose('positionY', $event.detail.value)"
                  @change="updatePose('positionY', $event.detail.value)"
                />
              </view>
            </AdvancedSection>
```

- [ ] **Step 8: 在后期 Tab 增加系统滤镜区、扩展 LUT 区与高级参数**

定位后期 Tab 开头（LUT 区之前），追加系统滤镜区：

```vue
            <!-- 系统滤镜区 -->
            <view class="filter-section">
              <text class="section-title">系统滤镜</text>
              <scroll-view scroll-x class="filter-list">
                <view class="filter-list-inner">
                  <view
                    v-for="f in systemFilterOptions"
                    :key="f.id"
                    class="filter-item"
                    :class="{ active: (template.postProcess.systemFilter || 'none') === f.id }"
                    @click="onSelectSystemFilter(f.id)"
                  >
                    <view class="filter-thumb" :style="thumbStyle(f.filter)">
                      <image
                        class="thumb-img"
                        src="https://picsum.photos/seed/param-sys-filter/120/120"
                        mode="aspectFill"
                      />
                    </view>
                    <text class="filter-name">{{ f.name }}</text>
                  </view>
                </view>
              </scroll-view>
            </view>
```

将原有的 LUT pill 区块改为横向滚动缩略图列表（参考系统滤镜区结构，使用 `lutOptions`）。

在后期 Tab 末尾增加 AdvancedSection（含色温/色调/磨皮/裁剪比）：

```vue
            <AdvancedSection
              title="高级参数"
              :open="advancedOpen.post"
              @update:open="advancedOpen.post = $event"
            >
              <view class="param-row">
                <text class="param-label">裁剪比</text>
                <view class="pill-list-inline">
                  <view
                    v-for="opt in cropRatioOptions"
                    :key="opt.value"
                    class="pill"
                    :class="{ active: template.postProcess.cropRatio === opt.value }"
                    @click="updatePost('cropRatio', opt.value)"
                  >
                    <text>{{ opt.label }}</text>
                  </view>
                </view>
              </view>
            </AdvancedSection>
```

注意：色温/色调/磨皮原本就在后期 Tab 中（slider 形式），按设计文档应"移入高级"。如果原本就在主区显示，将其从主区移除，在 AdvancedSection 中重新放置（保持原有 slider 控件代码）。

- [ ] **Step 9: 新增 thumbStyle 工具函数**

在 script 末尾追加：

```ts
const thumbStyle = (filter: string) => {
  if (!filter) return {}
  return { filter, webkitFilter: filter }
}
```

- [ ] **Step 10: 新增 rawMode 灰化样式**

在 ParamPanel.vue 的 `<style lang="scss" scoped>` 块末尾追加：

```scss
/* 原相机模式下参数控件灰化 */
.raw-mode-disabled .pill,
.raw-mode-disabled .slider,
.raw-mode-disabled switch {
  opacity: 0.5;
  pointer-events: none;
}

.filter-section {
  margin-top: 16rpx;
}

.section-title {
  display: block;
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.6);
  font-weight: 500;
  margin-bottom: 12rpx;
}

.filter-list {
  white-space: nowrap;
}

.filter-list-inner {
  display: inline-flex;
  gap: 16rpx;
  padding: 0 4rpx;
}

.filter-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  width: 120rpx;
}

.filter-thumb {
  width: 120rpx;
  height: 120rpx;
  border-radius: 16rpx;
  overflow: hidden;
  border: 3rpx solid transparent;
}

.filter-item.active .filter-thumb {
  border-color: #ffcc00;
}

.thumb-img {
  width: 100%;
  height: 100%;
}

.filter-name {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.85);
}

.filter-item.active .filter-name {
  color: #ffcc00;
  font-weight: 600;
}

.pill-list-inline {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
}

.switch-row {
  display: flex;
  justify-content: flex-end;
}
```

并在根容器 `<view class="param-panel">` 添加动态 class：

```vue
<view class="param-panel" :class="{ 'raw-mode-disabled': rawMode }">
```

- [ ] **Step 11: 运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS

- [ ] **Step 12: 启动开发服务器人工验证**

Run: `cd lumira-app && npm run dev:h5`
Expected:
1. 直接进入拍照页，ParamPanel 可见，所有 Tab 可切换
2. 相机 Tab 高级参数折叠区可展开，含快门/镜头/拍照风格/HDR
3. 构图 Tab 高级参数含构图类型/网格/宽高比/主体框
4. 姿势 Tab 高级参数含位置 X/Y
5. 后期 Tab 含系统滤镜区 + LUT 区 + 高级参数（裁剪比）
6. 切换到原相机模式，参数控件灰化
7. 调整任一参数，"一键应用"按钮从"已应用"变"一键应用"

- [ ] **Step 13: Commit**

```bash
git add lumira-app/src/components/ParamPanel.vue
git commit -m "feat(ParamPanel): 增加 AdvancedSection 折叠区 + 系统滤镜区 + 修复 apply-btn"
```

---

## Task 11: 集成验证与最终测试

**Files:**
- 无新增修改，仅人工验收

- [ ] **Step 1: 完整运行类型检查**

Run: `cd lumira-app && npx vue-tsc --noEmit`
Expected: PASS（零错误）

- [ ] **Step 2: 启动开发服务器**

Run: `cd lumira-app && npm run dev:h5`

- [ ] **Step 3: 逐项验收（按设计文档第十节验收标准）**

逐条核对：
1. ✅ 自由调参模式：直接进入 `/pages/capture/index`，ParamPanel 与 pill 栏可见可调
2. ✅ 模板模式：通过 templateId 进入，参数默认为模板值，applied=true
3. ✅ 参数偏离：调整任一可调参数后，applied 自动变 false
4. ✅ 一键应用：点击未应用按钮，参数重置为模板原值，applied 变 true
5. ✅ 原相机切换：点击"原相机"按钮，预览立即无滤镜；再次点击恢复
6. ✅ 原相机模式 UI：ParamPanel 控件灰化但可见
7. ✅ 高级参数：各 Tab 内"高级参数"折叠区可展开
8. ✅ 系统滤镜：顶部"滤镜"按钮点击弹出面板，含 6 种苹果风格 + 16 种 LUT；后期 Tab 也有完整列表
9. ✅ 滤镜应用：选中滤镜后预览实时变化，拍照导出应用对应滤镜
10. ✅ 死代码清理：activeCamera/activePost 已删除，toggleApply 假重置已移除

- [ ] **Step 4: 最终 Commit**

```bash
git commit --allow-empty -m "chore: 拍照页核心功能完善集成验证通过"
```

---

## Self-Review

### 1. Spec coverage 检查

| 设计文档章节 | 对应 Task | 状态 |
|-------------|----------|------|
| §3 架构总览（三模式 + 双状态机） | Task 9 | ✅ |
| §3.3 组件树（4 新组件） | Tasks 5-8 | ✅ |
| §3.4 死代码清理 | Task 9 Step 5/10 | ✅ |
| §4.1 相机 Tab 参数（快门/镜头/拍照风格/HDR） | Task 10 Step 5 | ✅ |
| §4.2 构图 Tab 参数 | Task 10 Step 6 | ✅ |
| §4.3 姿势 Tab 参数（positionX/Y） | Task 10 Step 7 | ✅ |
| §4.4 后期 Tab 参数（systemFilter + LUT 扩展 + 裁剪比） | Task 10 Step 8 | ✅ |
| §5.1 系统滤镜 6 种 | Task 2 Step 2 | ✅ |
| §5.2 LUT 扩展至 16 种 | Task 2 Step 1 | ✅ |
| §5.3 类型扩展 | Task 1 | ✅ |
| §5.4 滤镜叠加规则（systemFilter 在 LUT 之前） | Task 2 Step 4 | ✅ |
| §6.1 状态字段（rawMode/applied computed） | Task 9 Step 4 | ✅ |
| §6.2 参数匹配判定 | Task 3 | ✅ |
| §6.3 三种模式渲染逻辑修复 | Task 9 Steps 6-8/12 | ✅ |
| §6.4 一键应用逻辑 | Task 9 Step 10 | ✅ |
| §6.5 切换模板时重置 rawMode | Task 9 Step 11 | ✅ |
| §7.1 顶部 pill 栏（ApplyButton/RawModeToggle/FilterPicker） | Task 9 Step 1 | ✅ |
| §7.2 AdvancedSection 折叠区 | Task 10 Steps 5-8 | ✅ |
| §7.3 后期 Tab 滤镜区 | Task 10 Step 8 | ✅ |
| §7.4 自由调参模式 UI（移除 v-if） | Task 9 Step 2 | ✅ |
| §7.5 原相机模式 UI 灰化 | Task 10 Step 10 | ✅ |

### 2. Placeholder 扫描

- 无 "TBD" / "TODO" / "fill in details"
- 所有代码块均包含完整实现
- 所有命令均含 expected 输出

### 3. Type consistency 检查

- `SystemFilter` 类型在 Task 1 定义，Tasks 2/8/10 使用一致
- `LutPreset` 扩展在 Task 1 定义，Tasks 2/8/10 使用一致
- `createEmptyTemplate()` 在 Task 4 定义，Task 9 使用
- `isParametersMatchingTemplate()` 在 Task 3 定义，Task 9 使用
- `ApplyButton`/`RawModeToggle`/`FilterPicker`/`AdvancedSection` 在 Tasks 5-8 定义，Tasks 9/10 使用
- `onApplyClick` 函数名在 Task 9 Step 10 与 Task 10 Step 4 中一致
- `onSelectSystemFilter`/`onSelectLut` 在 Task 9 Step 13 与 Task 10 Step 4 一致

类型一致性通过。

### 4. 已知遗留

- Task 10 Step 8 中"将原有 LUT pill 区块改为横向滚动缩略图列表"是描述性指令，未提供完整代码（因原 ParamPanel.vue 的 LUT 区代码未读取完整）。执行时需读取 ParamPanel.vue 行 302-478 后再具体修改。已在步骤中明确说明参考结构。
- Task 10 Step 8 中"色温/色调/磨皮移入高级"是描述性指令，执行时需根据当前 ParamPanel.vue 实际结构移动 slider 控件代码。

这两处在执行时需要读取实际代码后才能给出精确 edit，已在步骤中明确指引。
