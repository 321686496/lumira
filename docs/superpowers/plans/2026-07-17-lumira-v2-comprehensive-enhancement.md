# 如画 V2 综合增强实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 11 项用户反馈问题，覆盖核心 bug 修复、跨平台对等、场景/模板/拍摄页/照片墙模块增强。

**Architecture:** 按依赖关系分 5 个模块实施（D→A→B→C→E），每模块独立可测试。核心是统一 H5/App-Plus 的滤镜烘焙路径，并在离屏 canvas 上实现完整后期效果。

**Tech Stack:** uni-app 3.0、Vue 3 Composition API、TypeScript、SCSS、uni.createOffscreenCanvas、MediaTrackConstraints

## Global Constraints

- 所有 H5 生效的功能必须同步生效到 Android 与 iOS（不得降级为"仅元数据"或"仅 UI 提示"）
- uni-app 组件规范：`<view>` 替代 `<div>`、`<text>` 替代 `<span>`、`<image>` 替代 `<img>`
- CSS 单位用 rpx 而非 px
- 所有样式（全局和 scoped）只能使用 class 选择器，不可用标签选择器
- App.vue 全局样式必须用纯 CSS（非 SCSS），硬编码颜色值
- 页面级 scoped 样式可用 `<style lang="scss" scoped>`
- 图片资源必须来自 picsum.photos
- 标题栏文本不居中对齐
- 非 tab 页不含 tab bar，tab 页不含设置入口
- 中文回复与代码注释

## File Structure

### 新建文件

| 文件 | 责任 |
|---|---|
| `lumira-app/src/pages/scenes/index.vue` | 独立场景库页面 |
| `lumira-app/src/pages/shootkit/editor.vue` | 组合编辑器 |
| `lumira-app/src/pages/templates/all.vue` | 完整模板列表 |
| `lumira-app/src/composables/useShootingTip.ts` | 贴士算法独立模块 |
| `lumira-app/src/composables/useRecommendation.ts` | 模板推荐算法独立模块 |
| `lumira-app/src/utils/bakeCanvas.ts` | 跨平台 canvas 烘焙公共函数 |

### 修改文件

| 文件 | 改动 |
|---|---|
| `lumira-app/src/App.vue` | bounce 移除配置 + 全局 CSS |
| `lumira-app/src/pages.json` | globalStyle bounce + 新页面注册 |
| `lumira-app/src/composables/useCamera.ts` | captureAppPlus 改造为完整烘焙 |
| `lumira-app/src/utils/captureBake.ts` | 抽取公共函数到 bakeCanvas.ts |
| `lumira-app/src/utils/filterRecipe.ts` | ISO 公式 + 滤镜合法性校验 API |
| `lumira-app/src/pages/capture/index.vue` | 全屏切换 + 底部折叠 + pill 修复 + ISO 应用 + 场景 badge |
| `lumira-app/src/pages/capture/scene-detail.vue` | 加入组合跳转 KitEditor + 标签 add/display |
| `lumira-app/src/pages/capture/scene-manage.vue` | 自定义场景表单增加 TagSelector |
| `lumira-app/src/pages/templates/index.vue` | 改为推荐结构 |
| `lumira-app/src/pages/templates/detail.vue` | 标签 add/display |
| `lumira-app/src/pages/home/index.vue` | 接入动态贴士 + 卡片简化 |
| `lumira-app/src/pages/gallery/index.vue` | 读取真实数据 + 场景分类 |
| `lumira-app/src/pages/gallery/detail.vue` | 归类到场景功能 |
| `lumira-app/src/composables/useSceneManager.ts` | updatePhotoScene + getPhotosGroupedByScene |
| `lumira-app/src/composables/useTemplate.ts` | 整合 useRecommendation |
| `lumira-app/src/composables/useTagManager.ts` | updateSceneTags + updateTemplateTags |
| `lumira-app/src/components/ScenePresetView.vue` | 卡片简化 + 新增 variant="list" |
| `lumira-app/src/components/TagSelector.vue` | 复用，无需改动 |

---

## 模块 D：核心 Bug 修复 + 跨平台对等（最高优先级）

### Task D1: 抽取跨平台 canvas 烘焙公共函数

**Files:**
- Create: `lumira-app/src/utils/bakeCanvas.ts`
- Modify: `lumira-app/src/utils/captureBake.ts`
- Modify: `lumira-app/src/utils/filterRecipe.ts`

**Interfaces:**
- Produces: `bakePhotoForCanvas(canvas, ctx, img, w, h, camera, post, quality): string`
- Produces: `applyFilterFromPost(ctx, w, h, camera, post): void` (降级像素级 filter)
- Produces: `buildCssFilter(camera, post)` 增加 ISO 公式（修改现有）
- Produces: `getGrainStrength(post, iso?)` 增加 iso 参数

- [ ] **Step 1: 在 filterRecipe.ts 中增加 ISO 公式**

修改 `lumira-app/src/utils/filterRecipe.ts` 的 `buildCssFilter`，在 EV/WB/color/systemFilter/lut 之后追加 ISO 逻辑：

```typescript
export function buildCssFilter(
  camera: Partial<CameraParams>,
  post: Partial<PostProcess>
): string {
  const parts: string[] = []
  // ...保留现有 EV/WB/color/systemFilter/lut 逻辑

  // ISO 近似效果（H5 + App-Plus 统一）
  const iso = camera.iso
  if (iso && iso > 200) {
    const brightnessBoost = (iso - 200) / 6400 * 0.3
    if (brightnessBoost > 0) {
      parts.push(`brightness(${1 + brightnessBoost})`)
    }
  }

  return parts.length ? parts.join(' ') : 'none'
}

export function getGrainStrength(
  post: Partial<PostProcess>,
  iso?: number
): number {
  let strength = 0
  if (typeof post.grain === 'number') {
    strength = Math.max(0, Math.min(1, post.grain / 100))
  }
  if (iso && iso > 200) {
    strength += (iso - 200) / 6400 * 0.4
  }
  return Math.min(1, strength)
}
```

- [ ] **Step 2: 创建 bakeCanvas.ts 公共函数**

创建 `lumira-app/src/utils/bakeCanvas.ts`：

```typescript
import type { CameraParams, PostProcess } from '@/types/template'
import {
  buildCssFilter,
  getVignetteStrength,
  getGrainStrength,
  getSharpenStrength,
  getSmoothStrength
} from './filterRecipe'

/**
 * 跨平台 canvas 烘焙核心函数
 * H5 与 App-Plus 共用同一逻辑
 */
export function bakePhotoForCanvas(
  canvas: any,
  ctx: any,
  img: any,
  w: number,
  h: number,
  camera: Partial<CameraParams>,
  post: Partial<PostProcess>,
  quality = 0.92
): string {
  if (!w || !h) {
    throw new Error('源尺寸无效')
  }

  // 1. CSS filter（含 ISO 修正）
  const filterStr = buildCssFilter(camera, post)
  let filterSupported = true
  try {
    ctx.filter = filterStr
  } catch {
    filterSupported = false
  }

  // 2. drawImage
  ctx.drawImage(img, 0, 0, w, h, 0, 0, w, h)
  ctx.filter = 'none'

  // 3. 像素级处理
  const vignette = getVignetteStrength(post)
  const grain = getGrainStrength(post, camera.iso)
  const sharpen = getSharpenStrength(post)
  const smooth = getSmoothStrength(post)

  if (!filterSupported || vignette > 0 || grain > 0 || sharpen > 0 || smooth > 0) {
    const imageData = ctx.getImageData(0, 0, w, h)
    const data = imageData.data

    // 降级：CSS filter 不支持时，应用像素级 filter 近似
    if (!filterSupported) {
      applyFilterFromPost(data, w, h, camera, post)
    }
    if (vignette > 0) applyVignette(data, w, h, vignette)
    if (grain > 0) applyGrain(data, w, h, grain)
    if (sharpen > 0) applySharpen(data, w, h, sharpen)
    if (smooth > 0) applySmooth(data, w, h, smooth)

    ctx.putImageData(imageData, 0, 0)
  }

  // 4. toDataURL
  return canvas.toDataURL('image/jpeg', quality)
}

/** 像素级 filter 近似（ctx.filter 不支持时降级） */
function applyFilterFromPost(
  data: Uint8ClampedArray,
  w: number,
  h: number,
  camera: Partial<CameraParams>,
  post: Partial<PostProcess>
): void {
  const color = post.color || {}
  const brightness = color.brightness ?? 0
  const contrast = color.contrast ?? 0
  const saturation = color.saturation ?? 0
  const temperature = color.temperature ?? 0

  const bFactor = 1 + brightness / 100
  const cFactor = 1 + contrast / 100
  const sFactor = 1 + saturation / 100

  // ISO 修正
  const iso = camera.iso
  const isoBrightness = iso && iso > 200 ? 1 + (iso - 200) / 6400 * 0.3 : 1

  for (let i = 0; i < data.length; i += 4) {
    let r = data[i]
    let g = data[i + 1]
    let b = data[i + 2]

    // 亮度
    r *= bFactor * isoBrightness
    g *= bFactor * isoBrightness
    b *= bFactor * isoBrightness

    // 对比度
    r = (r - 128) * cFactor + 128
    g = (g - 128) * cFactor + 128
    b = (b - 128) * cFactor + 128

    // 饱和度
    const gray = 0.299 * r + 0.587 * g + 0.114 * b
    r = gray + (r - gray) * sFactor
    g = gray + (g - gray) * sFactor
    b = gray + (b - gray) * sFactor

    // 色温（暖色 +r -b，冷色 -r +b）
    const tempShift = temperature / 100
    r += tempShift
    b -= tempShift

    data[i] = clamp(r)
    data[i + 1] = clamp(g)
    data[i + 2] = clamp(b)
  }
}

function applyVignette(data: Uint8ClampedArray, w: number, h: number, strength: number): void {
  const cx = w / 2
  const cy = h / 2
  const maxDist = Math.sqrt(cx * cx + cy * cy)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const dx = x - cx
      const dy = y - cy
      const dist = Math.sqrt(dx * dx + dy * dy)
      const ratio = dist / maxDist
      if (ratio > 0.5) {
        const factor = 1 - (ratio - 0.5) * 2 * strength
        const idx = (y * w + x) * 4
        data[idx] = data[idx] * factor
        data[idx + 1] = data[idx + 1] * factor
        data[idx + 2] = data[idx + 2] * factor
      }
    }
  }
}

function applyGrain(data: Uint8ClampedArray, _w: number, _h: number, strength: number): void {
  const intensity = strength * 30
  for (let i = 0; i < data.length; i += 4) {
    const noise = (Math.random() - 0.5) * intensity
    data[i] = clamp(data[i] + noise)
    data[i + 1] = clamp(data[i + 1] + noise)
    data[i + 2] = clamp(data[i + 2] + noise)
  }
}

function applySharpen(data: Uint8ClampedArray, w: number, h: number, strength: number): void {
  const amount = strength * 2
  const kernel = [0, -amount, 0, -amount, 1 + 4 * amount, -amount, 0, -amount, 0]
  const src = new Uint8ClampedArray(data)
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const idx = (y * w + x) * 4
      for (let c = 0; c < 3; c++) {
        let sum = 0
        for (let ky = 0; ky < 3; ky++) {
          for (let kx = 0; kx < 3; kx++) {
            const px = x + kx - 1
            const py = y + ky - 1
            const pIdx = (py * w + px) * 4 + c
            sum += src[pIdx] * kernel[ky * 3 + kx]
          }
        }
        data[idx + c] = clamp(sum)
      }
    }
  }
}

function applySmooth(data: Uint8ClampedArray, w: number, h: number, strength: number): void {
  const radius = Math.max(1, Math.floor(strength * 3))
  const src = new Uint8ClampedArray(data)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const idx = (y * w + x) * 4
      let r = 0, g = 0, b = 0, count = 0
      for (let dy = -radius; dy <= radius; dy++) {
        for (let dx = -radius; dx <= radius; dx++) {
          const px = x + dx
          const py = y + dy
          if (px >= 0 && px < w && py >= 0 && py < h) {
            const pIdx = (py * w + px) * 4
            r += src[pIdx]
            g += src[pIdx + 1]
            b += src[pIdx + 2]
            count++
          }
        }
      }
      const mix = strength * 0.6
      data[idx] = clamp(src[idx] * (1 - mix) + (r / count) * mix)
      data[idx + 1] = clamp(src[idx + 1] * (1 - mix) + (g / count) * mix)
      data[idx + 2] = clamp(src[idx + 2] * (1 - mix) + (b / count) * mix)
    }
  }
}

function clamp(v: number): number {
  return v < 0 ? 0 : v > 255 ? 255 : v
}
```

- [ ] **Step 3: 重构 captureBake.ts 复用 bakeCanvas**

修改 `lumira-app/src/utils/captureBake.ts`，将 `bakePhoto` 改为复用 `bakePhotoForCanvas`：

```typescript
import { bakePhotoForCanvas } from './bakeCanvas'

export function bakePhoto(input: BakeInput): Promise<BakeResult> {
  return new Promise((resolve, reject) => {
    const { source, sourceWidth, sourceHeight, camera, post, outputWidth = sourceWidth, outputHeight = sourceHeight, quality = 0.92 } = input
    if (!sourceWidth || !sourceHeight) {
      reject(new Error('源尺寸无效'))
      return
    }
    try {
      const canvas = document.createElement('canvas')
      canvas.width = outputWidth
      canvas.height = outputHeight
      const ctx = canvas.getContext('2d')
      if (!ctx) {
        reject(new Error('Canvas 2D context 不可用'))
        return
      }
      const dataUrl = bakePhotoForCanvas(canvas, ctx, source, sourceWidth, sourceHeight, camera, post, quality)
      const size = Math.floor((dataUrl.length - 22) * 3 / 4)
      resolve({ dataUrl, width: outputWidth, height: outputHeight, size })
    } catch (err) {
      reject(err)
    }
  })
}
```

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/utils/bakeCanvas.ts lumira-app/src/utils/captureBake.ts lumira-app/src/utils/filterRecipe.ts
git commit -m "feat: 抽取跨平台 canvas 烘焙公共函数并增加 ISO 公式"
```

---

### Task D2: 改造 useCamera.ts 的 captureAppPlus 调用完整烘焙

**Files:**
- Modify: `lumira-app/src/composables/useCamera.ts`

**Interfaces:**
- Consumes: `bakePhotoForCanvas` from Task D1
- Produces: `captureAppPlus(camera, post)` 返回含效果的 BakeResult

- [ ] **Step 1: 修改 captureAppPlus 接收 camera/post 参数并调用 bakePhotoForCanvas**

修改 `lumira-app/src/composables/useCamera.ts`：

```typescript
// capture 函数中 app-plus/mp 分支改为传参
if (platform === 'app-plus') {
  return await captureAppPlus(camera, post)
}
if (platform === 'mp') {
  return await captureAppPlus(camera, post)
}
```

```typescript
import { bakePhotoForCanvas } from '@/utils/bakeCanvas'
import { buildCssFilter, getVignetteStrength, getGrainStrength, getSharpenStrength, getSmoothStrength } from '@/utils/filterRecipe'

async function captureAppPlus(
  camera: Partial<CameraParams>,
  post: Partial<PostProcess>
): Promise<BakeResult> {
  // 1. takePhoto
  const tempPath = await takePhotoAsync()
  // 2. getImageInfo
  const info = await getImageInfoAsync(tempPath)
  // 3. createOffscreenCanvas
  const canvas = uni.createOffscreenCanvas({ type: '2d', width: info.width, height: info.height })
  const ctx = canvas.getContext('2d')
  // 4. loadImage
  const img = canvas.createImage()
  await loadImageAsync(img, tempPath)
  // 5. bake
  const dataUrl = bakePhotoForCanvas(canvas, ctx, img, info.width, info.height, camera, post, 0.92)
  // 6. return
  const size = Math.floor((dataUrl.length - 22) * 3 / 4)
  return { dataUrl, width: info.width, height: info.height, size }
}

function takePhotoAsync(): Promise<string> {
  return new Promise((resolve, reject) => {
    const ctx = uni.createCameraContext()
    ctx.takePhoto({
      quality: 'high',
      success: (res: { tempImagePath: string; tempThumbPath?: string }) => {
        const tempPath = res.tempImagePath || res.tempThumbPath
        if (!tempPath) {
          reject(new Error('拍照失败：未获取到图片路径'))
          return
        }
        resolve(tempPath)
      },
      fail: (err: { errMsg?: string }) => {
        reject(new Error(`拍照失败: ${err?.errMsg || '未知错误'}`))
      }
    })
  })
}

function getImageInfoAsync(src: string): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    uni.getImageInfo({
      src,
      success: (info) => resolve({ width: info.width, height: info.height }),
      fail: () => reject(new Error('获取图片信息失败'))
    })
  })
}

function loadImageAsync(img: any, src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    img.onload = () => resolve()
    img.onerror = () => reject(new Error('图片加载失败'))
    img.src = src
  })
}
```

- [ ] **Step 2: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 3: 提交**

```bash
git add lumira-app/src/composables/useCamera.ts
git commit -m "fix: App-Plus 拍照调用完整烘焙，后期参数跨平台生效"
```

---

### Task D3: 拍摄页 ISO 实时应用 + 场景滤镜 badge

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`

**Interfaces:**
- Consumes: camera API（已有）
- Produces: ISO 在 H5 通过 MediaTrackConstraints 应用，App-Plus 通过 buildCssFilter 近似（Task D1 已处理）

- [ ] **Step 1: 在 useCamera.ts 的 setFlash 旁新增 setIso 方法**

修改 `lumira-app/src/composables/useCamera.ts`：

```typescript
/**
 * 设置 ISO（H5 通过 MediaTrackConstraints 应用）
 */
function setIso(iso: number): void {
  if (platform === 'h5' && mediaStream) {
    const videoTrack = mediaStream.getVideoTracks()[0]
    if (videoTrack) {
      const capabilities = videoTrack.getCapabilities?.() as MediaTrackCapabilities & { iso?: { min: number; max: number; step: number } }
      if (capabilities?.iso) {
        videoTrack.applyConstraints({
          advanced: [{ iso: Number(iso) } as MediaTrackConstraintSet]
        }).catch(() => {})
      }
    }
  }
  // App-Plus 通过 buildCssFilter 中的 ISO 公式实现视觉效果
}
```

在 return 中加入 `setIso`。

- [ ] **Step 2: capture/index.vue 监听 ISO 变化并调用 setIso**

修改 `lumira-app/src/pages/capture/index.vue`：

```typescript
// 在 watch 区域新增
watch(() => editableTemplate.value?.camera.iso, (iso) => {
  if (iso !== undefined && iso > 0) {
    cameraApi.setIso(iso)
  }
})
```

- [ ] **Step 3: 顶部新增"场景滤镜已套用"badge**

在 template 的 viewfinder 内部、param-pill-bar 上方新增：

```html
<view v-if="activeSceneFilter" class="scene-filter-badge">
  <text class="ph ph-magic-wand"></text>
  <text class="badge-text">{{ activeSceneFilter }}</text>
</view>
```

```typescript
const activeSceneFilter = computed(() => {
  // 从 onLoad 的 scenePreset 参数推导
  if (!activeScenePresetId.value) return ''
  const preset = SCENE_PRESETS.find(p => p.id === activeScenePresetId.value)
  if (!preset || preset.filter.lut === 'none') return ''
  return preset.filter.reason || preset.filter.lut
})
```

```scss
.scene-filter-badge {
  position: absolute;
  top: calc(env(safe-area-inset-top) + 80rpx);
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(12px);
  padding: 8rpx 20rpx;
  border-radius: 9999rpx;
  display: flex;
  align-items: center;
  gap: 8rpx;
  z-index: 20;
}
.scene-filter-badge .badge-text {
  color: #ffffff;
  font-size: 22rpx;
}
```

- [ ] **Step 4: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lumira-app/src/composables/useCamera.ts lumira-app/src/pages/capture/index.vue
git commit -m "feat: ISO 实时应用 + 场景滤镜 badge"
```

---

## 模块 A：平台与体验层

### Task A1: 移除 Android APK 页面 bounce 弹动

**Files:**
- Modify: `lumira-app/src/App.vue`
- Modify: `lumira-app/src/pages.json`

- [ ] **Step 1: App.vue onLaunch 增加 App-Plus bounce 配置**

修改 `lumira-app/src/App.vue` 的 `onLaunch`：

```typescript
onLaunch(() => {
  // #ifdef APP-PLUS
  // 禁用 WebView 的 overscroll 弹性效果
  const currentWebview = plus.webview.currentWebview()
  if (currentWebview) {
    currentWebview.setBounce && currentWebview.setBounce('none')
    currentWebview.setStyle && currentWebview.setStyle({ bounce: 'none' })
  }
  // #endif
})
```

- [ ] **Step 2: pages.json globalStyle 增加 bounce: none**

修改 `lumira-app/src/pages.json` 的 `globalStyle`：

```json
"globalStyle": {
  "bounce": "none",
  "navigationBarTextStyle": "white",
  "navigationBarTitleText": "如画",
  "navigationBarBackgroundColor": "#1C1A17",
  "backgroundColor": "#FAF7F2"
}
```

- [ ] **Step 3: App.vue 全局 CSS 增加 overscroll-behavior**

修改 `lumira-app/src/App.vue` 的 `<style>` 块（全局，非 scoped）：

```scss
/* 全局禁用橡皮筋滚动 */
html, body {
  overscroll-behavior: none;
  -webkit-overflow-scrolling: touch;
  overflow-x: hidden;
}
::-webkit-scrollbar {
  display: none;
}
```

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/App.vue lumira-app/src/pages.json
git commit -m "fix: 移除 Android APK 页面 bounce 弹动效果"
```

---

### Task A2: 拍摄页全屏切换 + 底部折叠 + pill 椭圆修复

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`

- [ ] **Step 1: 新增全屏切换状态与按钮**

修改 `lumira-app/src/pages/capture/index.vue` 的 script：

```typescript
const isFullscreen = ref(false)

// 从 localStorage 恢复
const savedFs = uni.getStorageSync('lumira_capture_fullscreen')
if (savedFs === 'true') isFullscreen.value = true

function toggleFullscreen() {
  isFullscreen.value = !isFullscreen.value
  uni.setStorageSync('lumira_capture_fullscreen', String(isFullscreen.value))
}

const captureContainerClass = computed(() => ({
  'capture-container': true,
  'capture-fullscreen': isFullscreen.value,
  'capture-normal': !isFullscreen.value
}))
```

- [ ] **Step 2: 顶部右上角新增全屏切换按钮**

在 template 顶部导航栏区域新增：

```html
<view class="fullscreen-toggle" @click="toggleFullscreen">
  <text :class="isFullscreen ? 'ph ph-frame' : 'ph ph-frame-corners'"></text>
</view>
```

- [ ] **Step 3: 全屏模式 CSS**

修改 `<style lang="scss" scoped>` 块：

```scss
.capture-fullscreen {
  .viewfinder {
    position: fixed;
    inset: 0;
    z-index: 10;
    border-radius: 0;
    margin: 0;
    padding-bottom: 0;
  }
  .param-pill-bar {
    position: fixed;
    top: calc(env(safe-area-inset-top) + 12rpx);
    left: 24rpx;
    right: 24rpx;
    z-index: 20;
    max-width: none;
  }
  .bottom-action-area {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 20;
    background: rgba(0, 0, 0, 0.5);
    backdrop-filter: blur(12px);
    padding-bottom: env(safe-area-inset-bottom);
  }
}

.fullscreen-toggle {
  width: 56rpx;
  height: 56rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.4);
  border-radius: 28rpx;
}
.fullscreen-toggle text {
  font-size: 28rpx;
  color: #ffffff;
}
```

- [ ] **Step 4: 底部操作栏折叠 + 模板/场景横滑**

修改 template：

```html
<view class="bottom-action-area" :class="{ expanded: bottomPanelExpanded }">
  <!-- 快门行 -->
  <view class="shutter-row">
    <view class="last-photo-thumb" @click="goPreview" v-if="lastPhoto">
      <image :src="lastPhoto" class="thumb-img" mode="aspectFill" />
    </view>
    <view class="shutter-btn" @click="onShutter">
      <view class="shutter-inner"></view>
    </view>
    <view class="flip-btn" @click="flipCamera">
      <text class="ph ph-arrows-clockwise"></text>
    </view>
  </view>

  <!-- 折叠面板 -->
  <view v-if="bottomPanelExpanded" class="expandable-panel">
    <view class="panel-section">
      <text class="panel-section-title">🎨 模板</text>
      <scroll-view class="horizontal-scroll" scroll-x>
        <view class="strip-list">
          <view
            v-for="tpl in recentTemplates"
            :key="tpl.id"
            class="strip-item"
            :class="{ active: currentTemplateId === tpl.id }"
            @click="applyTemplate(tpl.id)"
          >
            <image :src="tpl.cover || `https://picsum.photos/seed/${tpl.id}/100/100`" class="strip-img" mode="aspectFill" />
            <text class="strip-name">{{ tpl.meta.name }}</text>
          </view>
        </view>
      </scroll-view>
    </view>
    <view class="panel-section">
      <text class="panel-section-title">📍 场景</text>
      <scroll-view class="horizontal-scroll" scroll-x>
        <view class="strip-list">
          <view
            v-for="scene in sceneStripList"
            :key="scene.id"
            class="strip-item"
            :class="{ active: activeScenePresetId === scene.id }"
            @click="applyScene(scene.id)"
          >
            <image :src="scene.exampleImages[0] || `https://picsum.photos/seed/${scene.id}/100/100`" class="strip-img" mode="aspectFill" />
            <text class="strip-name">{{ scene.name }}</text>
          </view>
        </view>
      </scroll-view>
    </view>
  </view>

  <!-- 折叠按钮 -->
  <view class="toggle-btn" @click="bottomPanelExpanded = !bottomPanelExpanded">
    <text :class="bottomPanelExpanded ? 'ph ph-caret-down' : 'ph ph-caret-up'"></text>
  </view>
</view>
```

```typescript
const bottomPanelExpanded = ref(false)
const sceneStripList = computed(() => SCENE_PRESETS.slice(0, 8))

function applyTemplate(id: string) {
  currentTemplateId.value = id
  pushRecent(id)
}
function applyScene(id: string) {
  activeScenePresetId.value = id
  // 触发场景滤镜应用
  const preset = SCENE_PRESETS.find(p => p.id === id)
  if (preset) {
    const tpl = editableTemplate.value ?? emptyTemplate
    tpl.postProcess.lut = preset.filter.lut
    if (preset.filter.systemFilter) {
      tpl.postProcess.systemFilter = preset.filter.systemFilter
    }
  }
}
```

- [ ] **Step 5: 参数 pill 椭圆修复**

修改 `.param-pill` 样式：

```scss
.param-pill {
  width: 96rpx;
  height: 56rpx;
  padding: 0;
  border-radius: 28rpx;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(12px);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}
.param-pill .pill-label {
  display: none;
}
.param-pill .pill-value {
  font-size: 22rpx;
  color: #ffffff;
  line-height: 1;
  white-space: nowrap;
}
```

修改 `evDisplay` / `wbDisplay` / `isoDisplay`：

```typescript
const evDisplay = computed(() => {
  const ev = activeTemplate.value?.camera.exposureCompensation
  if (ev === undefined || ev === 0) return '0.00'
  return (ev > 0 ? '+' : '') + ev.toFixed(2)
})

const wbDisplay = computed(() => {
  const k = activeTemplate.value?.camera.whiteBalanceK
  return k ? `${Math.round(k)}K` : 'AUTO'
})

const isoDisplay = computed(() => {
  const iso = activeTemplate.value?.camera.iso
  return iso ? `${iso}` : 'AUTO'
})
```

template 中 EV pill 改为：

```html
<view class="param-pill" @click.stop="openPanel('camera')">
  <text class="pill-value">{{ evDisplay }}</text>
</view>
<view class="param-pill" @click.stop="openPanel('camera')">
  <text class="pill-value">{{ wbDisplay }}</text>
</view>
<view class="param-pill" @click.stop="openPanel('camera')">
  <text class="pill-value">{{ isoDisplay }}</text>
</view>
```

- [ ] **Step 6: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add lumira-app/src/pages/capture/index.vue
git commit -m "feat: 拍摄页全屏切换 + 底部折叠 + pill 椭圆修复"
```

---

## 模块 B：场景模块增强

### Task B1: 场景推荐卡片简化

**Files:**
- Modify: `lumira-app/src/components/ScenePresetView.vue`

- [ ] **Step 1: 修改 variant="card" 模板**

移除 vibe/tips/whereToShoot/bestTime 的展示，仅保留 name + description + icon + exampleImages + 照片计数 badge。读取现有文件后定位 card variant 的渲染区域，保留：

```html
<view v-if="variant === 'card'" class="scene-card">
  <image :src="imageSrc || scene.exampleImages[0]" class="card-img" mode="aspectFill" />
  <view class="card-body">
    <view class="card-header">
      <text class="ph card-icon" :class="scene.icon"></text>
      <text class="card-name">{{ scene.name }}</text>
    </view>
    <text class="card-desc">{{ scene.description }}</text>
  </view>
  <view v-if="badgeText" class="card-badge" :class="{ 'badge-brand': badgeBrand }">
    <text class="badge-text">{{ badgeText }}</text>
  </view>
</view>
```

移除 vibe 氛围主标题渲染、tips 列表、whereToShoot/bestTime 渲染。

- [ ] **Step 2: CSS 调整**

`.card-desc` 添加 2 行省略：

```scss
.card-desc {
  font-size: 24rpx;
  color: $color-text-secondary;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
}
```

- [ ] **Step 3: 提交**

```bash
git add lumira-app/src/components/ScenePresetView.vue
git commit -m "feat: 场景推荐卡片简化，仅展示名称+描述+图标"
```

---

### Task B2: 新增场景库独立页面

**Files:**
- Create: `lumira-app/src/pages/scenes/index.vue`
- Modify: `lumira-app/src/pages.json`

- [ ] **Step 1: 创建 pages/scenes/index.vue**

```html
<template>
  <view class="scenes-container">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">场景库</text>
      <view class="lumira-nav-right" @click="onSearch">
        <text class="ph ph-magnifying-glass"></text>
      </view>
    </view>

    <view class="category-bar">
      <scroll-view scroll-x class="category-scroll">
        <view class="category-list">
          <view
            v-for="c in categories"
            :key="c.id"
            class="category-pill"
            :class="{ active: activeCategory === c.id }"
            @click="activeCategory = c.id"
          >
            <text>{{ c.name }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <view class="scenes-grid">
      <view
        v-for="scene in filteredScenes"
        :key="scene.id"
        class="scene-card-wrap"
        @click="goDetail(scene.id)"
      >
        <ScenePresetView
          :scene="scene"
          :image-src="scene.exampleImages[0]"
          variant="list"
          :badge-text="getPhotoCountByScene(scene.id) > 0 ? `${getPhotoCountByScene(scene.id)} 张` : ''"
        />
      </view>
    </view>

    <view class="fab-btn" @click="goCreate">
      <text class="ph ph-plus"></text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'
import ScenePresetView from '@/components/ScenePresetView.vue'
import type { SceneCategory } from '@/types/template'

const { allScenes, getPhotoCountByScene } = useSceneManager()

const categories = [
  { id: 'all' as const, name: '全部' },
  { id: 'light' as const, name: '光线' },
  { id: 'outdoor' as const, name: '室外' },
  { id: 'indoor' as const, name: '室内' },
  { id: 'mood' as const, name: '情绪' }
]

const activeCategory = ref<SceneCategory | 'all'>('all')
const filteredScenes = computed(() => {
  if (activeCategory.value === 'all') return allScenes.value
  return allScenes.value.filter(s => s.category === activeCategory.value)
})

const back = () => uni.navigateBack()
const onSearch = () => uni.showToast({ title: '搜索功能开发中', icon: 'none' })
const goDetail = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-detail?id=${id}` })
const goCreate = () => uni.navigateTo({ url: '/pages/capture/scene-manage?tab=custom' })
</script>

<style lang="scss" scoped>
.scenes-container {
  min-height: 100vh;
  background-color: #FAF7F2;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
}

.nav-back-icon { font-size: 40rpx; color: $color-text-primary; }
.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
  flex: 1;
  padding-left: 16rpx;
  text-align: left;
}
.lumira-nav-right text {
  font-size: 36rpx;
  color: $color-text-primary;
}

.category-bar {
  padding: 16rpx 24rpx;
  background: #FAF7F2;
}
.category-scroll { width: 100%; white-space: nowrap; }
.category-list {
  display: inline-flex;
  gap: 16rpx;
}
.category-pill {
  flex-shrink: 0;
  padding: 12rpx 28rpx;
  border-radius: 9999rpx;
  font-size: 26rpx;
  background: $color-bg-card;
  color: $color-text-secondary;
  display: inline-flex;
  align-items: center;
}
.category-pill.active {
  background: $color-brand;
  color: #ffffff;
}

.scenes-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  padding: 16rpx 24rpx;
}
.scene-card-wrap { width: 100%; }

.fab-btn {
  position: fixed;
  right: 40rpx;
  bottom: calc(env(safe-area-inset-bottom) + 60rpx);
  width: 96rpx;
  height: 96rpx;
  border-radius: 48rpx;
  background: $color-brand;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(0, 0, 0, 0.15);
}
.fab-btn text {
  font-size: 48rpx;
  color: #ffffff;
}
</style>
```

- [ ] **Step 2: ScenePresetView 新增 variant="list"**

修改 `lumira-app/src/components/ScenePresetView.vue`：

```html
<view v-if="variant === 'list'" class="scene-list-item">
  <image :src="imageSrc || scene.exampleImages[0]" class="list-img" mode="aspectFill" />
  <view class="list-body">
    <text class="list-name">{{ scene.name }}</text>
    <text class="list-desc">{{ scene.description }}</text>
    <view v-if="badgeText" class="list-badge">
      <text>{{ badgeText }}</text>
    </view>
  </view>
</view>
```

```scss
.scene-list-item {
  background: $color-bg-card;
  border-radius: 20rpx;
  overflow: hidden;
}
.list-img {
  width: 100%;
  height: 240rpx;
}
.list-body {
  padding: 16rpx 20rpx;
}
.list-name {
  font-family: 'Noto Serif SC', serif;
  font-size: 28rpx;
  font-weight: 600;
  color: $color-text-primary;
  display: block;
}
.list-desc {
  font-size: 22rpx;
  color: $color-text-secondary;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  margin-top: 4rpx;
}
.list-badge {
  margin-top: 8rpx;
  background: $color-brand-subtle;
  padding: 4rpx 12rpx;
  border-radius: 9999rpx;
  display: inline-block;
}
.list-badge text {
  font-size: 20rpx;
  color: $color-brand-deep;
}
```

- [ ] **Step 3: pages.json 注册新页面**

修改 `lumira-app/src/pages.json` 的 pages 数组：

```json
{
  "path": "pages/scenes/index",
  "style": {
    "navigationStyle": "custom"
  }
}
```

- [ ] **Step 4: 首页/拍摄页新增入口**

修改 `lumira-app/src/pages/home/index.vue`，在场景推荐区标题右侧新增"查看全部 ›"：

```html
<view class="section-header">
  <text class="section-title">场景推荐</text>
  <text class="section-link" @click="goAllScenes">查看全部 ›</text>
</view>
```

```typescript
function goAllScenes() {
  uni.navigateTo({ url: '/pages/scenes/index' })
}
```

- [ ] **Step 5: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lumira-app/src/pages/scenes/index.vue lumira-app/src/components/ScenePresetView.vue lumira-app/src/pages.json lumira-app/src/pages/home/index.vue
git commit -m "feat: 新增独立场景库页面 + ScenePresetView list 变体"
```

---

### Task B3: 新建组合编辑器页面

**Files:**
- Create: `lumira-app/src/pages/shootkit/editor.vue`
- Modify: `lumira-app/src/pages.json`
- Modify: `lumira-app/src/pages/capture/scene-detail.vue`
- Modify: `lumira-app/src/pages/capture/scene-manage.vue`

- [ ] **Step 1: 创建 pages/shootkit/editor.vue**

```html
<template>
  <view class="kit-editor-container">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">{{ isEdit ? '编辑组合' : '新建组合' }}</text>
      <view class="lumira-nav-right" @click="onSave">
        <text class="nav-save">保存</text>
      </view>
    </view>

    <scroll-view scroll-y class="form-scroll">
      <view class="form-section">
        <text class="form-label">组合名称</text>
        <input class="form-input" v-model="kitName" placeholder="给这个组合起个名字" />
      </view>

      <view class="form-section">
        <text class="form-label">绑定场景</text>
        <view class="bound-scene">
          <text class="ph bound-icon" :class="boundScene?.icon"></text>
          <text class="bound-name">{{ boundScene?.name || '未选择' }}</text>
        </view>
      </view>

      <view class="form-section">
        <text class="form-label">选择模板</text>
        <view class="template-grid">
          <view
            v-for="tpl in allTemplates"
            :key="tpl.id"
            class="template-item"
            :class="{ active: selectedTemplateId === tpl.id }"
            @click="selectedTemplateId = tpl.id"
          >
            <image :src="tpl.meta.cover || `https://picsum.photos/seed/${tpl.id}/200/200`" class="tpl-img" mode="aspectFill" />
            <text class="tpl-name">{{ tpl.meta.name }}</text>
          </view>
        </view>
      </view>

      <view class="form-section">
        <text class="form-label">参数覆盖（可选）</text>
        <view class="param-row">
          <text class="param-label">EV</text>
          <slider :value="overrides.camera.exposureCompensation" :min="-3" :max="3" :step="0.05" activeColor="#C9A96E" @change="onEvChange" />
          <text class="param-val">{{ evDisplay }}</text>
        </view>
        <view class="param-row">
          <text class="param-label">WB(K)</text>
          <slider :value="overrides.camera.whiteBalanceK" :min="2000" :max="10000" :step="50" activeColor="#C9A96E" @change="onWbChange" />
          <text class="param-val">{{ overrides.camera.whiteBalanceK || 5500 }}</text>
        </view>
        <view class="param-row">
          <text class="param-label">ISO</text>
          <slider :value="overrides.camera.iso" :min="100" :max="6400" :step="50" activeColor="#C9A96E" @change="onIsoChange" />
          <text class="param-val">{{ overrides.camera.iso || 'AUTO' }}</text>
        </view>
      </view>

      <view v-if="selectedTemplate" class="preview-section">
        <text class="form-label">预览</text>
        <image :src="selectedTemplate.meta.cover" class="preview-img" mode="aspectFill" />
      </view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, reactive } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useShootKit } from '@/composables/useShootKit'
import { useSceneManager } from '@/composables/useSceneManager'
import { useTemplate } from '@/composables/useTemplate'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { CameraParams } from '@/types/template'

const { createKit, updateKit, getKitById } = useShootKit()
const { allScenes } = useSceneManager()
const { getAllTemplates } = useTemplate()

const kitId = ref('')
const sceneId = ref('')
const kitName = ref('')
const selectedTemplateId = ref('')
const overrides = reactive<{ camera: Partial<CameraParams> }>({
  camera: {}
})

const isEdit = computed(() => !!kitId.value)
const allTemplates = computed(() => getAllTemplates())
const boundScene = computed(() => allScenes.value.find(s => s.id === sceneId.value))
const selectedTemplate = computed(() => allTemplates.value.find(t => t.id === selectedTemplateId.value))

const evDisplay = computed(() => {
  const ev = overrides.camera.exposureCompensation
  if (ev === undefined || ev === 0) return '0.00'
  return (ev > 0 ? '+' : '') + ev.toFixed(2)
})

onLoad((options) => {
  if (options?.sceneId) sceneId.value = options.sceneId
  if (options?.id) {
    kitId.value = options.id
    const kit = getKitById(options.id, allTemplates.value)
    if (kit) {
      kitName.value = kit.name
      selectedTemplateId.value = kit.templateId
      sceneId.value = kit.sceneId
      overrides.camera = kit.overrides?.camera || {}
    }
  }
})

function onEvChange(e: any) { overrides.camera.exposureCompensation = e.detail.value }
function onWbChange(e: any) { overrides.camera.whiteBalanceK = e.detail.value }
function onIsoChange(e: any) { overrides.camera.iso = e.detail.value }

const back = () => uni.navigateBack()

function onSave() {
  if (!kitName.value.trim()) {
    uni.showToast({ title: '请填写组合名称', icon: 'none' })
    return
  }
  if (!sceneId.value) {
    uni.showToast({ title: '未绑定场景', icon: 'none' })
    return
  }
  if (!selectedTemplateId.value) {
    uni.showToast({ title: '请选择模板', icon: 'none' })
    return
  }
  const payload = {
    name: kitName.value.trim(),
    sceneId: sceneId.value as any,
    templateId: selectedTemplateId.value,
    overrides: overrides.camera.exposureCompensation || overrides.camera.whiteBalanceK || overrides.camera.iso
      ? { camera: overrides.camera }
      : undefined
  }
  if (isEdit.value) {
    updateKit(kitId.value, payload)
  } else {
    createKit(payload)
  }
  uni.showToast({ title: '保存成功', icon: 'success' })
  setTimeout(() => uni.navigateBack(), 600)
}
</script>

<style lang="scss" scoped>
.kit-editor-container {
  min-height: 100vh;
  background: #FAF7F2;
  display: flex;
  flex-direction: column;
}

.nav-back-icon { font-size: 40rpx; color: $color-text-primary; }
.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
  flex: 1;
  padding-left: 16rpx;
  text-align: left;
}
.nav-save { color: $color-brand; font-size: 28rpx; font-weight: 600; }

.form-scroll { flex: 1; }
.form-section {
  padding: 24rpx;
  border-bottom: 1rpx solid $color-divider;
}
.form-label {
  font-size: 26rpx;
  color: $color-text-secondary;
  display: block;
  margin-bottom: 16rpx;
}
.form-input {
  width: 100%;
  padding: 20rpx;
  background: $color-bg-card;
  border-radius: 12rpx;
  font-size: 28rpx;
  color: $color-text-primary;
}
.bound-scene {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 16rpx 20rpx;
  background: $color-bg-card;
  border-radius: 12rpx;
}
.bound-icon { font-size: 32rpx; color: $color-brand; }
.bound-name { font-size: 28rpx; color: $color-text-primary; }

.template-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
}
.template-item {
  background: $color-bg-card;
  border-radius: 12rpx;
  overflow: hidden;
  border: 3rpx solid transparent;
}
.template-item.active {
  border-color: $color-brand;
}
.tpl-img { width: 100%; height: 160rpx; }
.tpl-name {
  font-size: 22rpx;
  color: $color-text-primary;
  padding: 8rpx;
  display: block;
  text-align: center;
}

.param-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-top: 16rpx;
}
.param-label { font-size: 26rpx; color: $color-text-secondary; width: 80rpx; }
.param-row slider { flex: 1; }
.param-val {
  font-size: 26rpx;
  color: $color-text-primary;
  width: 100rpx;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.preview-section { padding: 24rpx; }
.preview-img {
  width: 100%;
  height: 400rpx;
  border-radius: 16rpx;
}
</style>
```

- [ ] **Step 2: 修改 scene-detail.vue 的 goCreateKit**

修改 `lumira-app/src/pages/capture/scene-detail.vue`：

```typescript
function goCreateKit() {
  uni.navigateTo({ url: `/pages/shootkit/editor?sceneId=${sceneId.value}` })
}
```

- [ ] **Step 3: 修改 scene-manage.vue kit tab 新增"新建组合"按钮**

修改 `lumira-app/src/pages/capture/scene-manage.vue` 的 kit tab 区域：

```html
<view v-if="activeTab === 'kit'">
  <view class="kit-empty" v-if="kits.length === 0">
    <text class="ph ph-folder-plus empty-icon"></text>
    <text class="empty-text">还没有组合，去新建一个</text>
  </view>
  <view class="kit-list" v-else>
    <KitCard v-for="k in kits" :key="k.id" :kit="k" @delete="onDeleteKit" />
  </view>
  <view class="kit-create-btn" @click="goCreateKit">
    <text class="ph ph-plus"></text>
    <text>新建组合</text>
  </view>
</view>
```

```typescript
function goCreateKit() {
  uni.navigateTo({ url: '/pages/shootkit/editor' })
}
```

- [ ] **Step 4: useShootKit 新增 getKitById**

修改 `lumira-app/src/composables/useShootKit.ts`，确保有 `getKitById(id, templates)` 方法。如果没有，新增：

```typescript
function getKitById(id: string, templates: PhotoTemplate[]): ShootKitDetail | null {
  const kit = kits.value.find(k => k.id === id)
  if (!kit) return null
  return getKitDetail(id, templates)
}
```

并在 return 中导出。

- [ ] **Step 5: pages.json 注册 shootkit/editor**

修改 `lumira-app/src/pages.json`：

```json
{
  "path": "pages/shootkit/editor",
  "style": {
    "navigationStyle": "custom"
  }
}
```

- [ ] **Step 6: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add lumira-app/src/pages/shootkit/editor.vue lumira-app/src/pages/capture/scene-detail.vue lumira-app/src/pages/capture/scene-manage.vue lumira-app/src/composables/useShootKit.ts lumira-app/src/pages.json
git commit -m "feat: 新建组合编辑器页面 + 加入组合按钮跳转"
```

---

### Task B4: 场景详情页与场景管理表单增加标签 add/display

**Files:**
- Modify: `lumira-app/src/pages/capture/scene-detail.vue`
- Modify: `lumira-app/src/pages/capture/scene-manage.vue`
- Modify: `lumira-app/src/composables/useTagManager.ts`

- [ ] **Step 1: useTagManager 新增 updateSceneTags**

修改 `lumira-app/src/composables/useTagManager.ts`：

```typescript
function updateSceneTags(sceneId: string, tagIds: string[]): void {
  // 调用 useSceneManager 的更新方法
  // 由 useSceneManager 提供 updateCustomScene 的 API
}
```

读取现有 `useTagManager.ts` 后定位导出位置，新增上述方法并在 return 中导出。具体实现需要根据 useSceneManager 是否有 `updateCustomScene(id, partial)` API 决定，如无则新增。

- [ ] **Step 2: scene-detail.vue 增加标签 display + add**

修改 `lumira-app/src/pages/capture/scene-detail.vue`，在描述区域下方新增：

```html
<view class="tag-section">
  <text class="tag-section-title">标签</text>
  <view class="tag-list">
    <text v-for="t in sceneTags" :key="t.id" class="lumira-tag lumira-tag-gold">{{ t.name }}</text>
    <view v-if="canEditTags" class="tag-add-btn" @click="onAddTag">
      <text class="ph ph-plus"></text>
      <text>添加标签</text>
    </view>
  </view>
</view>
```

```typescript
import { useTagManager } from '@/composables/useTagManager'

const { getTagsByIds, toggleTagOnTarget } = useTagManager()

const sceneTags = computed(() => {
  const scene = sceneDetail.value
  if (!scene) return []
  const tagIds = scene.creator === 'user' ? (scene.tagIds || []) : (scene.recommendedTagIds || [])
  return getTagsByIds(tagIds)
})

const canEditTags = computed(() => sceneDetail.value?.creator === 'user')

const tagSelectorVisible = ref(false)

function onAddTag() {
  tagSelectorVisible.value = true
}

function onTagSelectorClose(selectedIds: string[]) {
  tagSelectorVisible.value = false
  if (selectedIds && sceneDetail.value) {
    updateSceneTags(sceneDetail.value.id, selectedIds)
  }
}
```

template 底部增加 TagSelector 弹层：

```html
<TagSelector
  v-if="tagSelectorVisible"
  :visible="tagSelectorVisible"
  :selected-ids="sceneDetail?.tagIds || []"
  type="scene"
  @close="onTagSelectorClose"
/>
```

- [ ] **Step 3: scene-manage.vue 自定义场景表单增加 TagSelector**

修改 `lumira-app/src/pages/capture/scene-manage.vue` 的自定义场景编辑表单，在字段列表末尾增加：

```html
<view class="form-row">
  <text class="form-label">标签</text>
  <view class="tag-selector-row">
    <text v-for="t in getTagsByIds(editForm.tagIds || [])" :key="t.id" class="lumira-tag lumira-tag-gold">{{ t.name }}</text>
    <view class="tag-add-btn" @click="onSceneTagAdd">
      <text class="ph ph-plus"></text>
      <text>添加</text>
    </view>
  </view>
</view>

<TagSelector
  v-if="sceneTagSelectorVisible"
  :visible="sceneTagSelectorVisible"
  :selected-ids="editForm.tagIds || []"
  type="scene"
  @close="onSceneTagSelectorClose"
/>
```

```typescript
const sceneTagSelectorVisible = ref(false)
function onSceneTagAdd() { sceneTagSelectorVisible.value = true }
function onSceneTagSelectorClose(selectedIds: string[]) {
  sceneTagSelectorVisible.value = false
  if (selectedIds) editForm.tagIds = selectedIds
}
```

- [ ] **Step 4: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lumira-app/src/composables/useTagManager.ts lumira-app/src/pages/capture/scene-detail.vue lumira-app/src/pages/capture/scene-manage.vue
git commit -m "feat: 场景详情页与表单增加标签 add/display"
```

---

## 模块 C：模板模块增强

### Task C1: 新增模板推荐算法

**Files:**
- Create: `lumira-app/src/composables/useRecommendation.ts`
- Modify: `lumira-app/src/composables/useTemplate.ts`

- [ ] **Step 1: 创建 useRecommendation.ts**

```typescript
import { computed } from 'vue'
import { useSceneManager } from './useSceneManager'
import { useTemplate, type PhotoTemplate } from './useTemplate'
import { SCENE_PRESETS } from '@/data/scenePresets'

export interface TemplateRecommendation {
  template: PhotoTemplate
  reason: string
  score: number
  source: 'recent_used' | 'scene_match' | 'category_match' | 'system_pick'
}

export function useRecommendation() {
  const { photos, allScenes } = useSceneManager()
  const { getAllTemplates, recentTemplates } = useTemplate()

  // 近 30 天模板使用频次
  const templateUsageCount = computed(() => {
    const counts: Record<string, number> = {}
    const now = Date.now()
    const thirtyDaysAgo = now - 30 * 24 * 60 * 60 * 1000
    photos.value.forEach(p => {
      if (p.templateId && p.createdAt > thirtyDaysAgo) {
        counts[p.templateId] = (counts[p.templateId] || 0) + 1
      }
    })
    return counts
  })

  // 用户最常用分类
  const topCategory = computed(() => {
    const counts: Record<string, number> = {}
    photos.value.forEach(p => {
      if (p.templateId) {
        const tpl = getAllTemplates().find(t => t.id === p.templateId)
        if (tpl?.meta.category) {
          counts[tpl.meta.category] = (counts[tpl.meta.category] || 0) + 1
        }
      }
    })
    let top: string | null = null
    let max = 0
    Object.entries(counts).forEach(([cat, n]) => {
      if (n > max) { max = n; top = cat }
    })
    return top
  })

  // 时间段系统精选
  const systemPick = computed(() => {
    const hour = new Date().getHours()
    if (hour >= 6 && hour < 10) return 'golden_landscape'
    if (hour >= 10 && hour < 16) return 'food_flat_lay'
    if (hour >= 16 && hour < 19) return 'sunset_silhouette'
    if (hour >= 19) return 'night_cityscape'
    return 'soft_portrait'
  })

  function getRecommendedTemplates(limit = 6): TemplateRecommendation[] {
    const all = getAllTemplates()
    const recs: TemplateRecommendation[] = []

    // 1. 近期使用最多的模板（权重 35）
    Object.entries(templateUsageCount.value)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .forEach(([id, count]) => {
        const tpl = all.find(t => t.id === id)
        if (tpl) {
          recs.push({
            template: tpl,
            reason: `你最近经常使用此模板（${count} 次）`,
            score: 35 + count * 2,
            source: 'recent_used'
          })
        }
      })

    // 2. recentTemplates 兜底
    recentTemplates.value.slice(0, 3).forEach((id, idx) => {
      if (!recs.find(r => r.template.id === id)) {
        const tpl = all.find(t => t.id === id)
        if (tpl) {
          recs.push({
            template: tpl,
            reason: '最近使用过',
            score: 30 - idx * 5,
            source: 'recent_used'
          })
        }
      }
    })

    // 3. 当前场景关联模板（权重 25）
    // 找用户最常拍场景的 recommendedTagIds 与模板 tagIds 重合度高的
    const topScene = allScenes.value[0]  // 简化：取第一个
    if (topScene) {
      const sceneTagIds = topScene.recommendedTagIds || []
      all.forEach(tpl => {
        if (recs.find(r => r.template.id === tpl.id)) return
        const overlap = (tpl.meta.tagIds || []).filter(id => sceneTagIds.includes(id)).length
        if (overlap > 0) {
          recs.push({
            template: tpl,
            reason: `与「${topScene.name}」场景匹配`,
            score: 25 + overlap * 3,
            source: 'scene_match'
          })
        }
      })
    }

    // 4. 同分类未使用模板（权重 20）
    if (topCategory.value) {
      const unused = all.filter(t =>
        t.meta.category === topCategory.value &&
        !recs.find(r => r.template.id === t.id)
      )
      unused.slice(0, 2).forEach(tpl => {
        recs.push({
          template: tpl,
          reason: `同分类推荐（你常用 ${topCategory.value}）`,
          score: 20,
          source: 'category_match'
        })
      })
    }

    // 5. 系统精选（权重 20）
    const sysPickTpl = all.find(t => t.id === systemPick.value)
    if (sysPickTpl && !recs.find(r => r.template.id === sysPickTpl.id)) {
      recs.push({
        template: sysPickTpl,
        reason: '根据当前时间段推荐',
        score: 20,
        source: 'system_pick'
      })
    }

    // 排序取 Top N
    recs.sort((a, b) => b.score - a.score)
    return recs.slice(0, limit)
  }

  function getOtherTemplates(excludeIds: string[]): PhotoTemplate[] {
    const all = getAllTemplates()
    return all.filter(t => !excludeIds.includes(t.id))
  }

  // 用户偏好统计
  const userPreference = computed(() => {
    const total = photos.value.length
    const topCat = topCategory.value
    const topCatCount = photos.value.filter(p => {
      const tpl = getAllTemplates().find(t => t.id === p.templateId)
      return tpl?.meta.category === topCat
    }).length
    const percentage = total > 0 ? Math.round((topCatCount / total) * 100) : 0
    return {
      totalPhotos: total,
      topCategory: topCat,
      topCategoryPercentage: percentage
    }
  })

  return {
    getRecommendedTemplates,
    getOtherTemplates,
    userPreference
  }
}
```

- [ ] **Step 2: useTemplate.ts 导出 recentTemplates 与 getAllTemplates**

读取现有 `lumira-app/src/composables/useTemplate.ts`，确保 export 了 `recentTemplates` ref 与 `getAllTemplates` 方法。如已存在则跳过，如未导出 recentTemplates 的 .value 则补全。

- [ ] **Step 3: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/composables/useRecommendation.ts lumira-app/src/composables/useTemplate.ts
git commit -m "feat: 新增模板推荐算法 useRecommendation"
```

---

### Task C2: 模板 tab 页改造为推荐结构 + 新建完整列表页

**Files:**
- Create: `lumira-app/src/pages/templates/all.vue`
- Modify: `lumira-app/src/pages/templates/index.vue`
- Modify: `lumira-app/src/pages.json`

- [ ] **Step 1: 创建 pages/templates/all.vue**

读取现有 `pages/templates/index.vue` 的内容（含三层分类 + TagSelector + "我的"切换逻辑），将其复制到 `pages/templates/all.vue`：

```html
<template>
  <view class="templates-all-container">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">全部模板</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- 原有的三层分类 + TagSelector + "我的"切换 + filteredTemplates grid -->
    <!-- 从原 index.vue 复制过来 -->
  </view>
</template>
```

把原 `templates/index.vue` 的 script 和完整 template 复制过来，仅修改顶部导航为返回按钮。

- [ ] **Step 2: 改造 pages/templates/index.vue 为推荐结构**

```html
<template>
  <view class="templates-container">
    <view class="lumira-nav">
      <text class="nav-title">模板</text>
      <view class="lumira-nav-right" @click="goAll">
        <text class="ph ph-squares-four"></text>
      </view>
    </view>

    <scroll-view scroll-y class="content-scroll">
      <!-- Hero 推荐区 -->
      <view class="hero-section">
        <text class="hero-title">今日为你推荐</text>
        <scroll-view scroll-x class="rec-scroll">
          <view class="rec-list">
            <view
              v-for="rec in recommendations"
              :key="rec.template.id"
              class="rec-card"
              @click="goTemplateDetail(rec.template.id)"
            >
              <image :src="rec.template.meta.cover || `https://picsum.photos/seed/${rec.template.id}/200/280`" class="rec-img" mode="aspectFill" />
              <text class="rec-name">{{ rec.template.meta.name }}</text>
              <text class="rec-reason">{{ rec.reason }}</text>
            </view>
          </view>
        </scroll-view>
      </view>

      <!-- 拍摄偏好 -->
      <view class="pref-section" v-if="userPreference.totalPhotos > 0">
        <text class="section-title">📊 你的拍摄偏好</text>
        <view class="pref-card">
          <text class="pref-text">最常用分类：{{ userPreference.topCategory }} ({{ userPreference.topCategoryPercentage }}%)</text>
        </view>
      </view>

      <!-- 同好推荐 -->
      <view class="other-section">
        <view class="section-header">
          <text class="section-title">更多模板</text>
          <text class="section-link" @click="goAll">查看全部 ›</text>
        </view>
        <view class="other-grid">
          <view
            v-for="tpl in otherTemplates.slice(0, 6)"
            :key="tpl.id"
            class="other-card"
            @click="goTemplateDetail(tpl.id)"
          >
            <image :src="tpl.meta.cover || `https://picsum.photos/seed/${tpl.id}/200/200`" class="other-img" mode="aspectFill" />
            <text class="other-name">{{ tpl.meta.name }}</text>
          </view>
        </view>
      </view>
    </scroll-view>

    <FloatingTabBar active="templates" />
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRecommendation } from '@/composables/useRecommendation'
import FloatingTabBar from '@/components/FloatingTabBar.vue'

const { getRecommendedTemplates, getOtherTemplates, userPreference } = useRecommendation()

const recommendations = computed(() => getRecommendedTemplates(4))
const otherTemplates = computed(() => {
  const recIds = recommendations.value.map(r => r.template.id)
  return getOtherTemplates(recIds)
})

function goAll() {
  uni.navigateTo({ url: '/pages/templates/all' })
}

function goTemplateDetail(id: string) {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}
</script>

<style lang="scss" scoped>
.templates-container {
  min-height: 100vh;
  background: #FAF7F2;
  display: flex;
  flex-direction: column;
}

.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
  flex: 1;
  padding-left: 24rpx;
  text-align: left;
}
.lumira-nav-right text {
  font-size: 36rpx;
  color: $color-text-primary;
}

.content-scroll { flex: 1; }

.hero-section { padding: 24rpx; }
.hero-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 36rpx;
  font-weight: 700;
  color: $color-text-primary;
  display: block;
  margin-bottom: 16rpx;
}
.rec-scroll { width: 100%; white-space: nowrap; }
.rec-list { display: inline-flex; gap: 16rpx; padding-bottom: 8rpx; }
.rec-card {
  flex-shrink: 0;
  width: 240rpx;
  background: $color-bg-card;
  border-radius: 16rpx;
  overflow: hidden;
}
.rec-img { width: 100%; height: 320rpx; }
.rec-name {
  font-size: 26rpx;
  font-weight: 600;
  color: $color-text-primary;
  padding: 12rpx 16rpx 4rpx;
  display: block;
}
.rec-reason {
  font-size: 20rpx;
  color: $color-text-secondary;
  padding: 0 16rpx 16rpx;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
}

.pref-section { padding: 16rpx 24rpx; }
.section-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  color: $color-text-primary;
  display: block;
  margin-bottom: 12rpx;
}
.pref-card {
  background: $color-bg-card;
  border-radius: 16rpx;
  padding: 24rpx;
}
.pref-text {
  font-size: 26rpx;
  color: $color-text-secondary;
}

.other-section { padding: 16rpx 24rpx 120rpx; }
.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16rpx;
}
.section-link { color: $color-brand; font-size: 24rpx; }
.other-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 16rpx;
}
.other-card {
  background: $color-bg-card;
  border-radius: 12rpx;
  overflow: hidden;
}
.other-img { width: 100%; height: 200rpx; }
.other-name {
  font-size: 22rpx;
  color: $color-text-primary;
  padding: 8rpx;
  display: block;
  text-align: center;
}
</style>
```

- [ ] **Step 3: pages.json 注册 templates/all**

```json
{
  "path": "pages/templates/all",
  "style": {
    "navigationStyle": "custom"
  }
}
```

- [ ] **Step 4: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lumira-app/src/pages/templates/all.vue lumira-app/src/pages/templates/index.vue lumira-app/src/pages.json
git commit -m "feat: 模板 tab 改为推荐结构 + 新建完整列表页"
```

---

### Task C3: 模板详情页标签 add/display

**Files:**
- Modify: `lumira-app/src/pages/templates/detail.vue`
- Modify: `lumira-app/src/composables/useTagManager.ts`

- [ ] **Step 1: useTagManager 新增 updateTemplateTags**

修改 `lumira-app/src/composables/useTagManager.ts`，新增：

```typescript
function updateTemplateTags(templateId: string, tagIds: string[]): void {
  // 读取 useTemplate 的 saveCustomTemplate
  // 同步更新 template.meta.tagIds
}
```

读取现有实现后定位并完成。

- [ ] **Step 2: 模板详情页增加 tagIds 展示 + 编辑入口**

修改 `lumira-app/src/pages/templates/detail.vue`，在现有 tag-row 区域：

```html
<view class="tag-row">
  <text class="lumira-tag lumira-tag-gold">{{ categoryLabel }}</text>
  <text v-for="tag in template.meta.tags" :key="tag" class="lumira-tag lumira-tag-gold">{{ tag }}</text>
  <text v-for="ut in userTags" :key="ut.id" class="lumira-tag lumira-tag-gold">{{ ut.name }}</text>
  <view v-if="canEditTags" class="tag-add-btn" @click="onAddTag">
    <text class="ph ph-plus"></text>
    <text>添加</text>
  </view>
</view>

<TagSelector
  v-if="tagSelectorVisible"
  :visible="tagSelectorVisible"
  :selected-ids="template.meta.tagIds || []"
  type="template"
  @close="onTagSelectorClose"
/>
```

```typescript
import { useTagManager } from '@/composables/useTagManager'

const { getTagsByIds, updateTemplateTags } = useTagManager()

const userTags = computed(() => getTagsByIds(template.value?.meta.tagIds || []))
const canEditTags = computed(() => template.value?.meta.price === 0 || !!template.value?.meta.custom)
const tagSelectorVisible = ref(false)

function onAddTag() { tagSelectorVisible.value = true }
function onTagSelectorClose(selectedIds: string[]) {
  tagSelectorVisible.value = false
  if (selectedIds && template.value) {
    updateTemplateTags(template.value.id, selectedIds)
  }
}
```

- [ ] **Step 3: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/composables/useTagManager.ts lumira-app/src/pages/templates/detail.vue
git commit -m "feat: 模板详情页增加标签 add/display"
```

---

## 模块 E：数据闭环

### Task E1: 今日拍摄贴士算法化

**Files:**
- Create: `lumira-app/src/composables/useShootingTip.ts`
- Modify: `lumira-app/src/pages/home/index.vue`

- [ ] **Step 1: 创建 useShootingTip.ts**

```typescript
import { computed } from 'vue'
import { useSceneManager } from './useSceneManager'
import { useTemplate } from './useTemplate'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { ScenePresetId, CustomSceneId } from '@/types/template'

export interface ShootingTip {
  text: string
  sub?: string
  sceneName: string
  source: 'recent_scene' | 'recent_template' | 'recent_param' | 'time_match' | 'fallback'
  priority: number
}

const FALLBACK_TIPS: ShootingTip[] = [
  { text: '侧逆光人像：让模特侧向镜头，让自然光从侧面打在脸上，显瘦又自然。', sub: '适合午后窗边或户外树下', sceneName: '通用', source: 'fallback', priority: 5 },
  { text: '黄金时刻：日出后或日落前 1 小时，光线柔和暖黄，适合拍摄人像与风光。', sub: '注意提前踩点', sceneName: '通用', source: 'fallback', priority: 5 },
  { text: '三分构图：将主体放在画面九宫格交叉点上，让画面更平衡有张力。', sub: '适合所有场景', sceneName: '通用', source: 'fallback', priority: 5 },
  { text: '前景遮挡：用花草、树叶、玻璃等作为前景，增加画面层次感。', sub: '适合静物与人像', sceneName: '通用', source: 'fallback', priority: 5 }
]

export function useShootingTip() {
  const { photos, allScenes, getPhotosByScene } = useSceneManager()
  const { getAllTemplates, recentTemplates } = useTemplate()

  // 近 30 天场景使用频次
  const sceneUsage = computed(() => {
    const counts: Record<string, number> = {}
    const now = Date.now()
    const thirtyDaysAgo = now - 30 * 24 * 60 * 60 * 1000
    photos.value.forEach(p => {
      if (p.sceneId && p.createdAt > thirtyDaysAgo) {
        counts[p.sceneId] = (counts[p.sceneId] || 0) + 1
      }
    })
    return counts
  })

  const topScene = computed(() => {
    const entries = Object.entries(sceneUsage.value)
    if (entries.length === 0) return null
    entries.sort((a, b) => b[1] - a[1])
    const [id, count] = entries[0]
    const scene = allScenes.value.find(s => s.id === id)
    return scene ? { scene, count } : null
  })

  // 近期参数偏好
  const paramPreference = computed(() => {
    const recent = photos.value.slice(-20)
    let isoSum = 0, evSum = 0, wbSum = 0, count = 0
    recent.forEach(p => {
      const meta = p.metadata || {}
      if (meta.iso) { isoSum += meta.iso; count++ }
      if (meta.exposureCompensation) evSum += meta.exposureCompensation
      if (meta.whiteBalanceK) wbSum += meta.whiteBalanceK
    })
    return {
      avgIso: count > 0 ? isoSum / count : 0,
      avgEv: count > 0 ? evSum / count : 0,
      avgWb: count > 0 ? wbSum / count : 0
    }
  })

  function getShootingTip(): ShootingTip {
    const candidates: ShootingTip[] = []

    // 1. 近期最常用场景的 tips
    if (topScene.value && topScene.value.scene.tips?.length > 0) {
      const tip = topScene.value.scene.tips[Math.floor(Math.random() * topScene.value.scene.tips.length)]
      candidates.push({
        text: tip,
        sub: `— 基于你最近常拍「${topScene.value.scene.name}」`,
        sceneName: topScene.value.scene.name,
        source: 'recent_scene',
        priority: 35
      })
    }

    // 2. 近期最常用模板关联场景的 tips
    const recentTplId = recentTemplates.value[0]
    if (recentTplId) {
      const tpl = getAllTemplates().find(t => t.id === recentTplId)
      if (tpl?.sceneGuide?.presetId) {
        const preset = SCENE_PRESETS.find(p => p.id === tpl.sceneGuide.presetId)
        if (preset?.tips?.length > 0) {
          const tip = preset.tips[Math.floor(Math.random() * preset.tips.length)]
          candidates.push({
            text: tip,
            sub: `— 基于你最近使用「${tpl.meta.name}」模板`,
            sceneName: preset.name,
            source: 'recent_template',
            priority: 25
          })
        }
      }
    }

    // 3. 参数偏好贴士
    if (paramPreference.value.avgIso > 1600) {
      candidates.push({
        text: '你最近常使用高 ISO 拍摄，注意降噪：后期可适当增加磨皮、降低锐度。',
        sub: '— 基于你的拍摄参数习惯',
        sceneName: '通用',
        source: 'recent_param',
        priority: 20
      })
    } else if (paramPreference.value.avgEv > 0.5) {
      candidates.push({
        text: '你最近常过曝拍摄，可尝试稍微降低 EV，保留更多高光细节。',
        sub: '— 基于你的拍摄参数习惯',
        sceneName: '通用',
        source: 'recent_param',
        priority: 20
      })
    }

    // 4. 时间段贴士
    const hour = new Date().getHours()
    if (hour >= 6 && hour < 10) {
      candidates.push({
        text: '清晨黄金时刻：光线柔和暖黄，适合拍人像与风光。',
        sub: '— 当前时段推荐',
        sceneName: '通用',
        source: 'time_match',
        priority: 15
      })
    } else if (hour >= 16 && hour < 19) {
      candidates.push({
        text: '黄昏黄金时刻：日落前 1 小时光线最美，提前踩点。',
        sub: '— 当前时段推荐',
        sceneName: '通用',
        source: 'time_match',
        priority: 15
      })
    } else if (hour >= 19) {
      candidates.push({
        text: '夜景拍摄：使用三脚架或稳定支撑，降低 ISO，延长曝光时间。',
        sub: '— 当前时段推荐',
        sceneName: '通用',
        source: 'time_match',
        priority: 15
      })
    }

    // 5. 兜底
    if (candidates.length === 0) {
      candidates.push(FALLBACK_TIPS[Math.floor(Math.random() * FALLBACK_TIPS.length)])
    }

    // 按 priority 排序 + 随机扰动
    candidates.sort((a, b) => b.priority - a.priority + (Math.random() - 0.5) * 10)
    return candidates[0]
  }

  function getAllCandidateTips(): ShootingTip[] {
    // 返回所有候选，供"换一批"使用
    const tips: ShootingTip[] = []
    if (topScene.value && topScene.value.scene.tips?.length > 0) {
      topScene.value.scene.tips.forEach(t => tips.push({
        text: t,
        sub: `— 基于你最近常拍「${topScene.value!.scene.name}」`,
        sceneName: topScene.value!.scene.name,
        source: 'recent_scene',
        priority: 35
      }))
    }
    FALLBACK_TIPS.forEach(t => tips.push({ ...t }))
    return tips
  }

  function getNextShootingTip(current: ShootingTip): ShootingTip {
    const all = getAllCandidateTips()
    const others = all.filter(t => t.text !== current.text)
    return others.length > 0 ? others[Math.floor(Math.random() * others.length)] : current
  }

  return {
    getShootingTip,
    getNextShootingTip
  }
}
```

- [ ] **Step 2: home/index.vue 接入动态贴士**

修改 `lumira-app/src/pages/home/index.vue`：

```typescript
import { useShootingTip, type ShootingTip } from '@/composables/useShootingTip'

const { getShootingTip, getNextShootingTip } = useShootingTip()
const currentTip = ref<ShootingTip>(getShootingTip())

function refreshTip() {
  currentTip.value = getNextShootingTip(currentTip.value)
}
```

修改 template 中的贴士卡片：

```html
<view class="tip-card">
  <view class="tip-header">
    <text class="tip-title">今日拍摄小贴士</text>
    <view class="tip-refresh" @click="refreshTip">
      <text class="ph ph-arrows-clockwise"></text>
      <text>换一批</text>
    </view>
  </view>
  <text class="tip-text">{{ currentTip.text }}</text>
  <text v-if="currentTip.sub" class="tip-sub">{{ currentTip.sub }}</text>
  <text class="tip-scene">📍 {{ currentTip.sceneName }}</text>
</view>
```

```scss
.tip-refresh {
  display: flex;
  align-items: center;
  gap: 8rpx;
  color: $color-brand;
  font-size: 24rpx;
}
.tip-scene {
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-top: 8rpx;
}
```

- [ ] **Step 3: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/composables/useShootingTip.ts lumira-app/src/pages/home/index.vue
git commit -m "feat: 今日拍摄小贴士算法化，基于用户近期拍摄数据"
```

---

### Task E2: 照片墙读取真实数据 + 场景分类

**Files:**
- Modify: `lumira-app/src/composables/useSceneManager.ts`
- Modify: `lumira-app/src/pages/gallery/index.vue`

- [ ] **Step 1: useSceneManager 新增 updatePhotoScene 与 getPhotosGroupedByScene**

修改 `lumira-app/src/composables/useSceneManager.ts`：

```typescript
function updatePhotoScene(photoId: string, sceneId: ScenePresetId | CustomSceneId | null): void {
  const photo = photos.value.find(p => p.id === photoId)
  if (photo) {
    photo.sceneId = sceneId
    persist()
  }
}

function getPhotosGroupedByScene(): Record<string, LocalPhoto[]> {
  const groups: Record<string, LocalPhoto[]> = {}
  photos.value.forEach(p => {
    const key = p.sceneId || 'uncategorized'
    if (!groups[key]) groups[key] = []
    groups[key].push(p)
  })
  return groups
}
```

在 return 中导出。

- [ ] **Step 2: 重写 gallery/index.vue**

```html
<template>
  <view class="gallery-container">
    <view class="lumira-nav">
      <text class="nav-title">照片墙</text>
    </view>

    <scroll-view scroll-x class="pill-bar">
      <view class="pill-list">
        <view
          v-for="p in pills"
          :key="p.label"
          class="gallery-pill"
          :class="{ active: activeFilter === p.key }"
          @click="activeFilter = p.key"
        >
          <text class="ph pill-icon" :class="p.icon"></text>
          <text class="pill-text">{{ p.label }}</text>
          <text class="pill-count">{{ p.count }}</text>
        </view>
      </view>
    </scroll-view>

    <view v-if="filteredPhotos.length === 0" class="empty-state">
      <text class="ph ph-image empty-icon"></text>
      <text class="empty-text">还没有照片，去拍一张吧</text>
    </view>

    <view v-else class="photo-grid">
      <view
        v-for="photo in filteredPhotos"
        :key="photo.id"
        class="photo-item"
        @click="goDetail(photo.id)"
      >
        <image :src="photo.dataUrl" class="photo-img" mode="aspectFill" />
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useSceneManager } from '@/composables/useSceneManager'

const { photos, getPhotosGroupedByScene, getSceneById } = useSceneManager()

interface Pill {
  label: string
  icon: string
  count: number
  key: string
  sceneId?: string | null
  isFavorite?: boolean
  isUncategorized?: boolean
}

const pills = computed<Pill[]>(() => {
  const groups = getPhotosGroupedByScene()
  const result: Pill[] = [{ label: '全部', icon: 'ph-images-square', count: photos.value.length, key: 'all' }]

  Object.entries(groups).forEach(([key, list]) => {
    if (key === 'uncategorized') {
      result.push({ label: '未分类', icon: 'ph-folder-dashed', count: list.length, key: 'uncategorized', isUncategorized: true })
    } else {
      const scene = getSceneById(key as any)
      if (scene) {
        result.push({ label: scene.name, icon: scene.icon, count: list.length, key: `scene_${key}`, sceneId: key })
      }
    }
  })

  const favorites = photos.value.filter(p => (p as any).isFavorite)
  if (favorites.length > 0) {
    result.push({ label: '收藏', icon: 'ph-heart', count: favorites.length, key: 'favorite', isFavorite: true })
  }

  return result
})

const activeFilter = ref('all')

const filteredPhotos = computed(() => {
  if (activeFilter.value === 'all') return photos.value
  if (activeFilter.value === 'uncategorized') {
    return photos.value.filter(p => !p.sceneId)
  }
  if (activeFilter.value === 'favorite') {
    return photos.value.filter(p => (p as any).isFavorite)
  }
  if (activeFilter.value.startsWith('scene_')) {
    const sceneId = activeFilter.value.replace('scene_', '')
    return photos.value.filter(p => p.sceneId === sceneId)
  }
  return photos.value
})

function goDetail(id: string) {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}
</script>

<style lang="scss" scoped>
.gallery-container {
  min-height: 100vh;
  background: #FAF7F2;
  padding-bottom: calc(env(safe-area-inset-bottom) + 120rpx);
}

.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 36rpx;
  font-weight: 700;
  color: $color-text-primary;
  padding: 24rpx;
  text-align: left;
}

.pill-bar { padding: 0 24rpx; white-space: nowrap; }
.pill-list { display: inline-flex; gap: 12rpx; padding: 8rpx 0; }
.gallery-pill {
  flex-shrink: 0;
  padding: 10rpx 20rpx;
  border-radius: 9999rpx;
  background: $color-bg-card;
  color: $color-text-secondary;
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
}
.gallery-pill.active {
  background: $color-brand;
  color: #ffffff;
}
.pill-icon { font-size: 24rpx; }
.pill-text { font-size: 24rpx; }
.pill-count {
  font-size: 20rpx;
  background: rgba(0, 0, 0, 0.1);
  padding: 2rpx 8rpx;
  border-radius: 9999rpx;
}
.gallery-pill.active .pill-count { background: rgba(255, 255, 255, 0.3); }

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 120rpx 0;
  gap: 16rpx;
}
.empty-icon { font-size: 96rpx; color: $color-text-tertiary; }
.empty-text { font-size: 28rpx; color: $color-text-tertiary; }

.photo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 4rpx;
  padding: 16rpx;
}
.photo-item {
  aspect-ratio: 1;
  border-radius: 8rpx;
  overflow: hidden;
}
.photo-img { width: 100%; height: 100%; }
</style>
```

- [ ] **Step 3: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/composables/useSceneManager.ts lumira-app/src/pages/gallery/index.vue
git commit -m "feat: 照片墙读取真实数据 + 动态场景分类 pills"
```

---

### Task E3: 照片详情页"归类到场景"功能

**Files:**
- Modify: `lumira-app/src/pages/gallery/detail.vue`

- [ ] **Step 1: 读取现有 gallery/detail.vue，新增"场景：xxx [更换 ›]"行**

读取文件后定位照片信息区域，新增：

```html
<view class="info-row" @click="onChangeScene">
  <text class="info-label">📍 场景</text>
  <view class="info-value-row">
    <text class="info-value">{{ currentSceneName || '未分类' }}</text>
    <text class="ph ph-caret-right change-arrow"></text>
  </view>
</view>
```

- [ ] **Step 2: 新增场景选择 sheet**

```html
<view v-if="sceneSelectorVisible" class="scene-selector-mask" @click="sceneSelectorVisible = false">
  <view class="scene-selector-sheet" @click.stop>
    <text class="selector-title">归类到场景</text>
    <scroll-view scroll-y class="selector-list">
      <view class="selector-item" @click="onSelectScene(null)">
        <text>不归类（未分类）</text>
      </view>
      <view
        v-for="s in allScenes"
        :key="s.id"
        class="selector-item"
        :class="{ active: photo?.sceneId === s.id }"
        @click="onSelectScene(s.id)"
      >
        <text class="ph selector-icon" :class="s.icon"></text>
        <text>{{ s.name }}</text>
      </view>
    </scroll-view>
  </view>
</view>
```

```typescript
import { useSceneManager } from '@/composables/useSceneManager'

const { photos, updatePhotoScene, allScenes } = useSceneManager()

const photoId = ref('')
const photo = computed(() => photos.value.find(p => p.id === photoId.value))

const currentSceneName = computed(() => {
  if (!photo.value?.sceneId) return ''
  const scene = allScenes.value.find(s => s.id === photo.value!.sceneId)
  return scene?.name || ''
})

const sceneSelectorVisible = ref(false)

function onChangeScene() { sceneSelectorVisible.value = true }

function onSelectScene(sceneId: string | null) {
  if (photo.value) {
    updatePhotoScene(photo.value.id, sceneId as any)
    sceneSelectorVisible.value = false
    uni.showToast({ title: '已更新', icon: 'success' })
  }
}
```

```scss
.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 24rpx;
  background: $color-bg-card;
  border-bottom: 1rpx solid $color-divider;
}
.info-label { font-size: 26rpx; color: $color-text-secondary; }
.info-value-row { display: flex; align-items: center; gap: 8rpx; }
.info-value { font-size: 26rpx; color: $color-text-primary; }
.change-arrow { font-size: 24rpx; color: $color-text-tertiary; }

.scene-selector-mask {
  position: fixed; inset: 0; z-index: 999;
  background: rgba(0, 0, 0, 0.5);
  display: flex; align-items: flex-end;
}
.scene-selector-sheet {
  width: 100%; max-height: 70vh;
  background: #ffffff;
  border-radius: 32rpx 32rpx 0 0;
  padding: 32rpx;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
}
.selector-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
  display: block;
  margin-bottom: 24rpx;
}
.selector-list { max-height: 50vh; }
.selector-item {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 24rpx;
  border-radius: 12rpx;
  font-size: 28rpx;
  color: $color-text-primary;
}
.selector-item.active {
  background: $color-brand-subtle;
  color: $color-brand-deep;
}
.selector-icon { font-size: 32rpx; }
```

- [ ] **Step 3: 验证 type-check**

Run: `npm run type-check`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add lumira-app/src/pages/gallery/detail.vue
git commit -m "feat: 照片详情页新增归类到场景功能"
```

---

## 模块 F：文档同步

### Task F1: 同步更新设计文档

**Files:**
- Modify: `docs/superpowers/specs/2026-07-16-scene-management-design.md`
- Modify: `docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md`
- Modify: `docs/superpowers/specs/2026-07-11-template-system-and-capture-guide-design.md`
- Modify: `docs/superpowers/specs/2026-07-03-lumira-prd.md`

- [ ] **Step 1: 场景管理设计文档同步**

在 `2026-07-16-scene-management-design.md` 末尾追加 V2 增强章节：

```markdown
## V2 增强章节（2026-07-17）

### 场景标签系统
- 场景详情页支持标签 add/display
- 预设场景使用 recommendedTagIds（只读）
- 自定义场景使用 tagIds（可增删）
- 通过 useTagManager.updateSceneTags 统一管理

### 独立场景库页面
- 新增 /pages/scenes/index.vue
- 从多入口跳转（首页、拍摄页、个人中心）
- 分类 tab + grid 2 列展示
- 复用 ScenePresetView variant="list"

### 滤镜合法性校验
- 场景引用的 systemFilter 必须是 SYSTEM_FILTERS 中存在的
- scene-detail 渲染前调用 isFilterRegistered 校验
- 未注册则降级为 'none' 并提示

### 组合编辑器
- 新增 /pages/shootkit/editor.vue
- scene-detail"加入组合"按钮跳转到此页
- 支持选择模板 + 参数覆盖（EV/WB/ISO）
```

- [ ] **Step 2: 拍摄页增强设计文档同步**

在 `2026-07-14-capture-page-enhancement-design.md` 末尾追加：

```markdown
## V2 增强章节（2026-07-17）

### 全屏拍摄切换
- 顶部新增全屏切换按钮（ph-frame-corners / ph-frame）
- 全屏模式：取景器 fixed inset:0，参数栏与操作栏 fixed 半透明叠加
- 状态持久化到 localStorage

### 底部操作栏折叠
- 新增 bottomPanelExpanded 状态
- 展开时显示模板/场景横滑条
- 折叠按钮切换 caret-up / caret-down

### 参数 pill 椭圆修复
- 改为固定尺寸 width:96rpx height:56rpx
- font-variant-numeric: tabular-nums 等宽数字
- EV 显示 2 位小数，WB 整数+K，ISO 显示数值或 AUTO

### ISO 跨平台对等
- H5: MediaTrackConstraints.advanced: [{ iso }]
- App-Plus: buildCssFilter 增加 ISO 公式（brightness + grain 增强）
- setIso 方法封装跨平台逻辑

### 后期参数跨平台烘焙
- useCamera.captureAppPlus 改造为完整烘焙流程
- 使用 uni.createOffscreenCanvas
- 调用 bakePhotoForCanvas 公共函数
- ctx.filter 不支持时降级到 applyFilterFromPost 像素级实现
```

- [ ] **Step 3: 模板系统设计文档同步**

在 `2026-07-11-template-system-and-capture-guide-design.md` 末尾追加：

```markdown
## V2 增强章节（2026-07-17）

### 模板推荐机制
- 新增 useRecommendation composable
- 综合多因素加权：近期使用频次(35%) + 场景匹配(25%) + 同分类(20%) + 系统精选(20%)
- TemplateRecommendation 返回 template + reason + score + source

### 模板 tab 改造
- /pages/templates/index.vue 改为推荐结构
- Hero 推荐区 + 拍摄偏好 + 更多模板
- /pages/templates/all.vue 承载完整列表（原 index.vue 逻辑）

### 模板详情页标签
- 同时展示 meta.tags（旧）与 meta.tagIds（新）
- 通过 useTagManager.updateTemplateTags 更新
- TagSelector 组件复用
```

- [ ] **Step 4: PRD 文档同步**

在 `2026-07-03-lumira-prd.md` 末尾追加：

```markdown
## V2 增强章节（2026-07-17）

### 照片墙分类与场景关联
- 照片墙读取 useSceneManager.photos（移除硬编码数据）
- 动态生成分类 pills：全部 | 各场景 | 未分类 | 收藏
- 照片详情页支持"归类到场景"功能
- 拍照后未选场景的照片归"未分类"

### 今日拍摄贴士算法化
- 新增 useShootingTip composable
- 综合多因素：近期场景(35%) + 近期模板(25%) + 参数偏好(20%) + 时间段(15%) + 兜底(5%)
- "换一批"从候选池中随机抽取不同的贴士

### 页面 bounce 移除
- App-Plus: plus.webview.setBounce('none')
- pages.json globalStyle: bounce: "none"
- 全局 CSS: overscroll-behavior: none

### 场景推荐卡片简化
- 移除 vibe/tips/whereToShoot/bestTime 展示
- 仅保留 name + description + icon + 照片计数 badge
```

- [ ] **Step 5: 提交**

```bash
git add docs/superpowers/specs/2026-07-16-scene-management-design.md docs/superpowers/specs/2026-07-14-capture-page-enhancement-design.md docs/superpowers/specs/2026-07-11-template-system-and-capture-guide-design.md docs/superpowers/specs/2026-07-03-lumira-prd.md
git commit -m "docs: 同步 V2 综合增强设计到相关 spec 文档"
```

---

## Self-Review 检查清单

| Spec 需求 | 对应 Task |
|---|---|
| 1. bounce 移除 | A1 |
| 2. 场景卡片简化 | B1 |
| 3. 加入组合→KitEditor | B3 |
| 3. 使用此场景拍摄套用滤镜 | D3（场景滤镜 badge）+ 现有已实现 |
| 3. 滤镜合法性 | Spec 2.3 已说明（scene-manage 限制下拉选，不在 Plan 增加 task） |
| 4. 独立场景页 | B2 |
| 5. 场景标签 add/display | B4 |
| 5. 模板标签 add/display | C3 |
| 6. 模板推荐 | C1 + C2 |
| 7. 贴士算法化 | E1 |
| 8. 全屏切换 | A2 |
| 8. 底部折叠 | A2 |
| 8. pill 椭圆修复 | A2 |
| 8. 小数 2 位 | A2 |
| 9. ISO 效果 | D1（公式）+ D3（H5 应用） |
| 10. 后期参数生效 | D1 + D2（跨平台烘焙） |
| 11. 照片墙分类 | E2 + E3 |

无遗漏。类型一致性已检查（`bakePhotoForCanvas`、`useRecommendation`、`useShootingTip`、`updatePhotoScene` 等命名前后一致）。
