# 拍摄/预览/场景功能完整对齐与增强 — 设计文档

**日期**：2026-07-14
**作者**：协同设计
**参考来源**：千问分享《苹果原相机参数设置全解析》
**前置工作**：2026-07-14-capture-page-enhancement-design.md（已完成）

## 1. 背景与目标

### 1.1 背景

经过 2026-07-14 第一轮拍摄页增强（AdvancedSection/ApplyButton/RawModeToggle/FilterPicker 4 个组件 + 11 个 Task），拍摄页 ParamPanel 已具备基础参数调整能力。但与苹果原相机参数清单对比后，发现以下问题：

1. **拍摄页 ParamPanel 缺失多项相机/后期参数**：人像光圈、夜景模式、Live Photo、网格开关、AE/AF 锁定、镜头校正；后期缺高光/阴影/黑点/清晰度/自然饱和度/鲜明度
2. **场景 Tab 仅只读展示**：无法切换场景预设，无法一键应用场景对应的相机/后期参数
3. **preview-template.vue 与 ParamPanel 严重不一致**：12 项差异（系统滤镜区/快门速度/镜头类型/拍照风格/HDR/构图参数/姿势 Tab/场景 Tab/LUT 数量/白平衡选项/高级折叠区/颗粒滑块）
4. **preview.vue 后期处理页缺失编辑能力**：只能选心情/场景标签，无 EXIF 卡片、无对比图、无参数编辑
5. **scene-guide.vue 场景数据硬编码**：场景→模板映射不全（仅 4 个），场景无结构化参数，无场景 CRUD

### 1.2 目标

- 补全拍摄页 ParamPanel 的相机参数（6 项）与后期参数（6 项）
- 重构场景 Tab：参数化 + 10 个内置场景预设 + 一键应用
- 对齐 preview-template.vue 与拍摄页一致（复用 ParamPanel）
- 改造 preview.vue 为完整后期处理页（EXIF + 对比 + 编辑）
- 重构 scene-guide.vue：场景数据驱动 + 完整映射 + 场景预设应用

### 1.3 非目标

- 不实现真实的相机硬件控制（aperture/nightMode 等仍为元数据记录）
- 不实现 Live Photo 的多帧捕获与回放（仅记录开关状态）
- 不实现相册批量调色（拷贝/粘贴编辑参数）
- 不实现场景的云端同步（CRUD 仅本地）

## 2. 架构方案

### 2.1 方案选择：ParamPanel 单组件复用

**选择方案 A**：ParamPanel 作为单一编辑组件，通过 `mode` prop 适配三种使用场景：

| 使用页面 | mode | 显示的 Tab |
|---|---|---|
| capture/index.vue | `full`（默认） | 相机/构图/场景/姿势/后期 |
| capture/preview-template.vue | `full` | 全部 5 个 Tab |
| capture/preview.vue | `post-only` | 仅后期 Tab |

**优点**：
- 单一维护点，永远不会有 12 项不一致问题
- 新增参数只需改一处
- 三页 UI 风格统一

**关键约束**：
- ParamPanel 必须保持现有 props/事件契约向后兼容（capture/index.vue 现有调用不变）
- `mode='post-only'` 时仅渲染后期 Tab，隐藏 Tab 切换栏

### 2.2 整体数据流

```
ScenePreset (data/scenePresets.ts)
    ↓ 用户在 ParamPanel 场景 Tab 选择
    ↓ "一键应用" 触发 applyScenePreset
    ↓
ParamPanel emit('update:template', newTemplate)
    ↓
父页面（capture/preview-template/preview）接收
    ↓
editableTemplate.value = newTemplate
    ↓
buildCssFilter(camera, post) 重新计算
    ↓
video / image 实时滤镜更新
```

## 3. 类型系统扩展

### 3.1 `CameraParams` 新增字段

```typescript
export interface CameraParams {
  // 现有字段保留...
  exposureCompensation: number
  iso: number
  shutterSpeed: string
  whiteBalance: WhiteBalance
  whiteBalanceK: number
  flashMode: FlashMode
  focusMode: FocusMode
  lensType?: LensType
  photographicStyle?: PhotographicStyle
  hdr?: boolean
  
  // ===== 新增 6 项 =====
  /** 人像模式光圈 f 值，1.4 / 1.8 / 2.0 / 2.8 / 4 / 5.6 / 8 / 11 / 16；null 表示非人像模式 */
  aperture?: number | null
  /** 夜景模式开关 */
  nightMode?: boolean
  /** 夜景曝光时间（秒），1-30，仅 nightMode=true 时有意义 */
  nightExposureTime?: number
  /** Live Photo 实况照片开关 */
  livePhoto?: boolean
  /** 网格辅助线开关 */
  gridEnabled?: boolean
  /** AE/AF 锁定状态 */
  aeAfLock?: boolean
  /** 镜头校正开关（超广角畸变修正） */
  lensCorrection?: boolean
}
```

### 3.2 `PostProcess.color` 新增字段

```typescript
export interface PostProcessColor {
  // 现有
  brightness: number
  contrast: number
  saturation: number
  temperature: number
  tint: number
  
  // ===== 新增 6 项（苹果相册编辑参数对齐）=====
  // 注：设为可选以保证现有 13 个模板数据向后兼容；访问处统一用 `?? 0`
  /** 高光 -100~100（负值压暗高光，正值提亮高光） */
  highlights?: number
  /** 阴影 -100~100（负值压暗阴影，正值提亮阴影） */
  shadows?: number
  /** 黑点 0-100（黑场深度） */
  blackPoint?: number
  /** 清晰度 -100~100（中间调对比度） */
  clarity?: number
  /** 自然饱和度 -100~100（智能饱和度，肤色保护） */
  vibrance?: number
  /** 鲜明度 -100~100（亮部饱和度+亮度组合） */
  brilliance?: number
}
```

### 3.3 `SceneGuide` 结构化重构

```typescript
export type ScenePresetId =
  | 'cafe' | 'street' | 'beach' | 'macro'
  | 'night' | 'food' | 'home' | 'sunset'
  | 'forest' | 'indoor'

export interface SceneGuide {
  // 现有保留（人类可读字符串）
  lightDirection: string
  shootingDistance: string
  background: string
  props: string[]
  bestTime: string
  tips: string[]
  
  // ===== 新增：结构化字段 =====
  /** 关联的场景预设 ID */
  presetId?: ScenePresetId
  /** 光线角度 0-360 度（0=正前方，90=右侧，180=正后方，270=左侧） */
  lightDirectionAngle?: number
  /** 拍摄距离米数 */
  shootingDistanceM?: number
  /** 最佳时间起 HH:mm */
  bestTimeFrom?: string
  /** 最佳时间止 HH:mm */
  bestTimeTo?: string
}

/** 场景预设：完整的参数建议包 */
export interface ScenePreset {
  id: ScenePresetId
  name: string
  /** Phosphor 图标 class */
  icon: string
  /** 场景描述 */
  description: string
  /** 一键应用的相机参数 */
  cameraSuggestion: Partial<CameraParams>
  /** 一键应用的后期参数 */
  postSuggestion: Partial<PostProcess>
  /** 场景指南数据 */
  sceneGuide: Omit<SceneGuide, 'presetId'>
  /** 关联的模板分类 */
  relatedCategory: Target
}
```

### 3.4 `PostProcess` 完整接口

```typescript
export interface PostProcess {
  cropRatio: string
  color: PostProcessColor  // 含 6 个新字段
  smoothStrength: number
  sharpen: number
  vignette: number
  grain: number
  lut: LutPreset
  systemFilter?: SystemFilter
}
```

## 4. 内置场景预设

新增数据文件 `lumira-app/src/data/scenePresets.ts`，包含 10 个内置场景：

| ID | 名称 | 图标 | 相机建议 | 后期建议 | 关联分类 |
|---|---|---|---|---|---|
| cafe | 咖啡馆 | ph-coffee | WB=cloudy, K=4800, style=warm, aperture=f/2.8 | warm_film LUT, temp+20, contrast+10 | portrait |
| street | 街拍 | ph-buildings | WB=daylight, style=high_contrast, aperture=f/4 | cinematic LUT, contrast+15, clarity+10 | street |
| beach | 海边 | ph-waves | WB=daylight, K=5500, style=standard, aperture=f/8 | cool_film LUT, brightness+5, vibrance+10 | landscape |
| macro | 微距 | ph-flower | WB=daylight, focus=manual, aperture=f/8 | pastel LUT, clarity+15, sharpen+20 | macro |
| night | 夜景 | ph-moon | nightMode=true, ISO=800, shutter=1/30, aperture=f/1.8 | cyberpunk LUT, contrast+20, vignette+20 | night |
| food | 美食 | ph-fork-knife | WB=tungsten, K=3200, style=warm, aperture=f/2.8 | warm_film LUT, saturation+15, sharpen+10 | food |
| home | 居家 | ph-house | WB=tungsten, K=3200, style=warm, aperture=f/2.0 | warm_film LUT, temp+15 | still-life |
| sunset | 黄昏 | ph-sunset | WB=shade, K=7500, style=warm, aperture=f/5.6 | twilight LUT, temp+30, saturation+10 | landscape |
| forest | 森林 | ph-tree | WB=daylight, style=standard, aperture=f/5.6 | fuji LUT, vibrance+10 | landscape |
| indoor | 室内 | ph-building | WB=fluorescent, K=4000, style=standard, aperture=f/2.8 | pastel LUT, brightness+5 | still-life |

每个预设包含完整的 `sceneGuide` 字段（lightDirection/shootingDistance/background/props/bestTime/tips）。

## 5. filterRecipe.ts 扩展

### 5.1 新增 6 个后期参数的 CSS filter 映射

```typescript
// 在 buildCssFilter 函数中按以下顺序追加：

// 高光（负值压暗亮部，正值提亮亮部）
const highlights = post.color?.highlights ?? 0
if (highlights !== 0) {
  // 使用 brightness 微调亮部：正值提亮，负值压暗
  filters.push(`brightness(${(1 + highlights / 300).toFixed(3)})`)
}

// 阴影（负值压暗暗部，正值提亮暗部）
const shadows = post.color?.shadows ?? 0
if (shadows !== 0) {
  // 用 brightness + contrast 反向组合模拟阴影调整
  filters.push(`brightness(${(1 + shadows / 250).toFixed(3)})`)
  filters.push(`contrast(${(1 - shadows / 400).toFixed(3)})`)
}

// 黑点（0-100，加深黑场）
const blackPoint = post.color?.blackPoint ?? 0
if (blackPoint !== 0) {
  filters.push(`contrast(${(1 + blackPoint / 200).toFixed(3)})`)
  filters.push(`brightness(${(1 - blackPoint / 500).toFixed(3)})`)
}

// 清晰度（中间调对比度）
const clarity = post.color?.clarity ?? 0
if (clarity !== 0) {
  filters.push(`contrast(${(1 + clarity / 200).toFixed(3)})`)
}

// 自然饱和度（智能饱和度，CSS filter 无法精确模拟，用 saturate 近似）
const vibrance = post.color?.vibrance ?? 0
if (vibrance !== 0) {
  filters.push(`saturate(${(1 + vibrance / 150).toFixed(3)})`)
}

// 鲜明度（亮度+饱和度组合）
const brilliance = post.color?.brilliance ?? 0
if (brilliance !== 0) {
  filters.push(`brightness(${(1 + brilliance / 300).toFixed(3)})`)
  filters.push(`saturate(${(1 + brilliance / 200).toFixed(3)})`)
}
```

### 5.2 应用顺序（最终 filter 链）

```
1. EV → brightness
2. WB → sepia + hue-rotate
3. 后期 brightness
4. 后期 contrast
5. 后期 saturation
6. 后期 highlights  ← 新
7. 后期 shadows    ← 新
8. 后期 blackPoint ← 新
9. 后期 clarity    ← 新
10. 后期 vibrance  ← 新
11. 后期 brilliance← 新
12. 后期 temperature
13. 后期 tint
14. systemFilter
15. LUT
```

### 5.3 Canvas 烘焙对齐

`captureBake.ts` 中 Canvas filter 字符串通过 `buildCanvasFilter` 调用 `buildCssFilter`，新参数自动同步。但 vignette/grain/sharpen/smoothStrength 仍需 Canvas 像素级处理，本次不扩展像素处理范围。

## 6. ParamPanel 重构

### 6.1 新增 `mode` prop

```typescript
const props = defineProps<{
  template: PhotoTemplate
  visible: boolean
  applied: boolean
  rawMode: boolean
  mode?: 'full' | 'post-only'  // 新增，默认 'full'
}>()

const isFullMode = computed(() => (props.mode ?? 'full') === 'full')
```

- `mode='full'`：显示 Tab 切换栏 + 全部 5 个 Tab
- `mode='post-only'`：隐藏 Tab 切换栏，仅显示后期 Tab（activeTab 强制为 4）

模板调整：
```vue
<view v-if="isFullMode" class="panel-tabs">...</view>
<view class="panel-content">
  <view v-if="isFullMode && activeTab === 0" class="tab-pane">相机 Tab</view>
  <view v-if="isFullMode && activeTab === 1" class="tab-pane">构图 Tab</view>
  <view v-if="isFullMode && activeTab === 2" class="tab-pane">场景 Tab</view>
  <view v-if="isFullMode && activeTab === 3" class="tab-pane">姿势 Tab</view>
  <view v-if="!isFullMode || activeTab === 4" class="tab-pane">后期 Tab</view>
</view>
```

### 6.2 相机 Tab 高级参数区新增控件

在现有"高级参数"折叠区内追加：

```vue
<AdvancedSection title="高级参数" ...>
  <!-- 现有：快门速度 pill / 镜头 pill / 拍照风格 pill / HDR -->
  
  <!-- 新增：光圈（aperture 为 null 表示非人像模式，仍显示控件以让用户切换） -->
  <view class="param-row">
    <text class="param-label">光圈</text>
    <view class="pill-list-inline">
      <view v-for="opt in apertureOptions" :key="opt.value"
            class="pill" :class="{ active: template.camera.aperture === opt.value }"
            @click="updateCamera('aperture', opt.value)">
        <text>f/{{ opt.value }}</text>
      </view>
    </view>
  </view>
  
  <!-- 新增：夜景模式 -->
  <view class="param-row">
    <text class="param-label">夜景模式</text>
    <view class="switch-row">
      <switch class="mode-toggle" :checked="template.camera.nightMode || false"
              @change="updateCamera('nightMode', $event.detail.value)" />
    </view>
  </view>
  <view class="slider-block" v-if="template.camera.nightMode">
    <view class="slider-header">
      <text class="param-label">曝光时间</text>
      <text class="slider-value">{{ template.camera.nightExposureTime || 3 }}s</text>
    </view>
    <slider class="param-slider" :value="template.camera.nightExposureTime || 3"
            :min="1" :max="30" :step="1" ... />
  </view>
  
  <!-- 新增：实况照片 -->
  <view class="param-row">
    <text class="param-label">实况照片</text>
    <view class="switch-row">
      <switch class="mode-toggle" :checked="template.camera.livePhoto || false" ... />
    </view>
  </view>
  
  <!-- 新增：网格 -->
  <view class="param-row">
    <text class="param-label">网格辅助线</text>
    <view class="switch-row">
      <switch class="mode-toggle" :checked="template.camera.gridEnabled || false" ... />
    </view>
  </view>
  
  <!-- 新增：AE/AF 锁定 -->
  <view class="param-row">
    <text class="param-label">AE/AF 锁定</text>
    <view class="switch-row">
      <switch class="mode-toggle" :checked="template.camera.aeAfLock || false" ... />
    </view>
  </view>
  
  <!-- 新增：镜头校正 -->
  <view class="param-row">
    <text class="param-label">镜头校正</text>
    <view class="switch-row">
      <switch class="mode-toggle" :checked="template.camera.lensCorrection || false" ... />
    </view>
  </view>
</AdvancedSection>
```

新增选项数组：
```typescript
const apertureOptions = [
  { value: 1.4, label: '1.4' },
  { value: 1.8, label: '1.8' },
  { value: 2.0, label: '2.0' },
  { value: 2.8, label: '2.8' },
  { value: 4, label: '4' },
  { value: 5.6, label: '5.6' },
  { value: 8, label: '8' },
  { value: 11, label: '11' },
  { value: 16, label: '16' }
]
```

### 6.3 后期 Tab 高级参数区新增 6 个滑块

在现有"高级参数"折叠区内追加：

```vue
<AdvancedSection title="高级参数" ...>
  <!-- 现有：裁剪比/色温/色调/磨皮 -->
  
  <!-- 新增：高光 -->
  <view class="slider-block">
    <view class="slider-header">
      <text class="param-label">高光</text>
      <text class="slider-value">{{ template.postProcess.color.highlights }}</text>
    </view>
    <slider class="param-slider" :value="template.postProcess.color.highlights"
            :min="-100" :max="100" :step="1"
            @change="(e) => updateColor('highlights', e.detail.value)" />
  </view>
  
  <!-- 阴影 / 黑点 / 清晰度 / 自然饱和度 / 鲜明度 同结构 -->
</AdvancedSection>
```

### 6.4 场景 Tab 完全重构

```vue
<!-- 场景 Tab -->
<view v-if="isFullMode && activeTab === 2" class="tab-pane">
  <!-- 场景预设选择 -->
  <view class="scene-preset-section">
    <text class="section-title">场景预设</text>
    <scroll-view scroll-x class="scene-preset-scroll">
      <view class="scene-preset-list">
        <view
          v-for="preset in scenePresets"
          :key="preset.id"
          class="scene-preset-card"
          :class="{ active: template.sceneGuide.presetId === preset.id }"
          @click="onSelectScenePreset(preset.id)"
        >
          <view class="scene-preset-icon-wrap">
            <text class="ph scene-preset-icon" :class="preset.icon" />
          </view>
          <text class="scene-preset-name">{{ preset.name }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
  
  <!-- 一键应用场景参数 -->
  <view class="scene-apply-btn" @click="onApplyScenePreset">
    <text class="ph ph-sparkle" />
    <text>一键应用场景参数</text>
  </view>
  
  <!-- 当前场景参数预览 -->
  <view v-if="currentScenePreset" class="scene-suggestion-block">
    <text class="section-title">场景参数建议</text>
    <view class="param-row">
      <text class="param-label">白平衡</text>
      <text class="param-value">{{ wbLabel(currentScenePreset.cameraSuggestion.whiteBalance, currentScenePreset.cameraSuggestion.whiteBalanceK ?? 5500) }}</text>
    </view>
    <view class="param-row" v-if="currentScenePreset.cameraSuggestion.photographicStyle">
      <text class="param-label">拍照风格</text>
      <text class="param-value">{{ photographicStyleLabel(currentScenePreset.cameraSuggestion.photographicStyle) }}</text>
    </view>
    <view class="param-row" v-if="currentScenePreset.cameraSuggestion.aperture">
      <text class="param-label">建议光圈</text>
      <text class="param-value">f/{{ currentScenePreset.cameraSuggestion.aperture }}</text>
    </view>
    <view class="param-row" v-if="currentScenePreset.postSuggestion.lut">
      <text class="param-label">建议 LUT</text>
      <text class="param-value">{{ getLutLabel(currentScenePreset.postSuggestion.lut) }}</text>
    </view>
    <!-- 注：getLutLabel 从 filterRecipe.ts 导出的 LUT_FILTERS 中按 id 查找 label；若 filterRecipe.ts 未导出该函数，本次实施时新增并导出 -->
  </view>
  
  <!-- 场景信息（只读） -->
  <view class="param-row">
    <text class="param-label">光线方向</text>
    <text class="param-value">{{ template.sceneGuide.lightDirection }}</text>
  </view>
  <view class="param-row">
    <text class="param-label">拍摄距离</text>
    <text class="param-value">{{ template.sceneGuide.shootingDistance }}</text>
  </view>
  <view class="param-row">
    <text class="param-label">背景建议</text>
    <text class="param-value">{{ template.sceneGuide.background }}</text>
  </view>
  <view class="param-row">
    <text class="param-label">最佳时间</text>
    <text class="param-value">{{ template.sceneGuide.bestTime }}</text>
  </view>
  
  <!-- 道具建议 -->
  <view class="tag-list-block" v-if="template.sceneGuide.props.length">
    <text class="desc-title">道具建议</text>
    <view class="tag-list">
      <view class="prop-tag" v-for="(item, idx) in template.sceneGuide.props" :key="idx">
        {{ item }}
      </view>
    </view>
  </view>
  
  <!-- 拍摄贴士 -->
  <view class="desc-block" v-if="template.sceneGuide.tips.length">
    <text class="desc-title">拍摄贴士</text>
    <view class="tips-list">
      <view class="tips-item" v-for="(tip, idx) in template.sceneGuide.tips" :key="idx">
        <text class="ph ph-circle tips-dot" />
        <text class="tips-text">{{ tip }}</text>
      </view>
    </view>
  </view>
  
  <!-- 高级：自定义场景参数 -->
  <AdvancedSection title="自定义场景参数" :open="advancedOpen.sceneCustom" ...>
    <view class="param-row">
      <text class="param-label">光线方向</text>
      <view class="pill-list-inline">
        <view v-for="opt in lightDirectionOptions" :key="opt.value"
              class="pill" :class="{ active: template.sceneGuide.lightDirectionAngle === opt.value }"
              @click="updateSceneGuide('lightDirectionAngle', opt.value)">
          <text>{{ opt.label }}</text>
        </view>
      </view>
    </view>
    <view class="slider-block">
      <view class="slider-header">
        <text class="param-label">拍摄距离</text>
        <text class="slider-value">{{ template.sceneGuide.shootingDistanceM || 2 }}m</text>
      </view>
      <slider class="param-slider" :value="template.sceneGuide.shootingDistanceM || 2"
              :min="0.1" :max="10" :step="0.1" ... />
    </view>
  </AdvancedSection>
</view>
```

新增方法：
```typescript
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { ScenePreset, ScenePresetId } from '@/types/template'

const scenePresets = SCENE_PRESETS

const currentScenePreset = computed(() => {
  const id = props.template.sceneGuide.presetId
  return id ? scenePresets.find(p => p.id === id) : null
})

const onSelectScenePreset = (id: ScenePresetId) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  // 仅更新 presetId 与场景信息（不自动应用相机/后期参数，由用户点"一键应用"触发）
  tpl.sceneGuide.presetId = id
  const preset = scenePresets.find(p => p.id === id)
  if (preset) {
    tpl.sceneGuide.lightDirection = preset.sceneGuide.lightDirection
    tpl.sceneGuide.shootingDistance = preset.sceneGuide.shootingDistance
    tpl.sceneGuide.background = preset.sceneGuide.background
    tpl.sceneGuide.props = [...preset.sceneGuide.props]
    tpl.sceneGuide.bestTime = preset.sceneGuide.bestTime
    tpl.sceneGuide.tips = [...preset.sceneGuide.tips]
  }
  emit('update:template', tpl)
}

const onApplyScenePreset = () => {
  if (props.rawMode) return
  const preset = currentScenePreset.value
  if (!preset) {
    uni.showToast({ title: '请先选择场景预设', icon: 'none' })
    return
  }
  const tpl = cloneTemplate()
  // 应用相机建议参数（浅合并）
  Object.assign(tpl.camera, preset.cameraSuggestion)
  // 应用后期建议参数：color 单独浅合并避免整体替换丢失现有 color 字段
  if (preset.postSuggestion.color) {
    Object.assign(tpl.postProcess.color, preset.postSuggestion.color)
  }
  const { color: _omitColor, ...restPost } = preset.postSuggestion
  Object.assign(tpl.postProcess, restPost)
  emit('update:template', tpl)
  uni.showToast({ title: '已应用场景参数', icon: 'success' })
}

const updateSceneGuide = <K extends keyof PhotoTemplate['sceneGuide']>(key: K, value: PhotoTemplate['sceneGuide'][K]) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.sceneGuide[key] = value
  emit('update:template', tpl)
}
```

新增选项数组：
```typescript
const lightDirectionOptions = [
  { value: 0, label: '顺光' },
  { value: 45, label: '前侧光' },
  { value: 90, label: '侧光' },
  { value: 135, label: '侧逆光' },
  { value: 180, label: '逆光' },
  { value: 270, label: '反射光' }
]
```

## 7. emptyTemplate.ts 更新

`createEmptyTemplate()` 必须返回包含所有新增字段的完整对象，避免 `undefined` 引发计算错误：

```typescript
export function createEmptyTemplate(): PhotoTemplate {
  return {
    meta: { ... },
    composition: { ... },
    pose: { ... },
    camera: {
      // 现有
      exposureCompensation: 0,
      iso: 0,
      shutterSpeed: 'auto',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      hdr: false,
      // 新增
      aperture: null,
      nightMode: false,
      nightExposureTime: 3,
      livePhoto: false,
      gridEnabled: false,
      aeAfLock: false,
      lensCorrection: false
    },
    sceneGuide: {
      lightDirection: '自然光',
      shootingDistance: '2m',
      background: '简洁背景',
      props: [],
      bestTime: '白天',
      tips: [],
      presetId: undefined,
      lightDirectionAngle: 0,
      shootingDistanceM: 2,
      bestTimeFrom: '09:00',
      bestTimeTo: '17:00'
    },
    postProcess: {
      cropRatio: '3:4',
      color: {
        brightness: 0, contrast: 0, saturation: 0,
        temperature: 0, tint: 0,
        // 新增
        highlights: 0, shadows: 0, blackPoint: 0,
        clarity: 0, vibrance: 0, brilliance: 0
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

## 8. 现有模板数据迁移

13 个模板文件（`data/templates/*.ts`）需要更新，补全新增字段。

**策略**：每个模板的 `camera` 和 `postProcess.color` 字段补全默认值 0/false/null，`sceneGuide` 添加 `presetId` 与场景关联。

示例（`cafe-portrait.ts`）：
```typescript
camera: {
  // 现有保留
  exposureCompensation: 0.3,
  iso: 400,
  shutterSpeed: '1/80',
  whiteBalance: 'cloudy',
  whiteBalanceK: 4800,
  flashMode: 'off',
  focusMode: 'auto',
  // 新增（默认值）
  aperture: 2.8,           // 咖啡馆人像建议 f/2.8
  nightMode: false,
  nightExposureTime: 3,
  livePhoto: false,
  gridEnabled: false,
  aeAfLock: false,
  lensCorrection: false
},
sceneGuide: {
  // 现有保留
  lightDirection: '侧光 45°-90°（窗户自然光为主光源）',
  shootingDistance: '1.5-2.5m',
  background: '咖啡馆室内环境...',
  props: ['咖啡杯', '书本', '绿植盆栽'],
  bestTime: '下午 14:00-17:00',
  tips: [...],
  // 新增
  presetId: 'cafe',
  lightDirectionAngle: 90,
  shootingDistanceM: 2,
  bestTimeFrom: '14:00',
  bestTimeTo: '17:00'
},
postProcess: {
  cropRatio: '3:4',
  color: {
    brightness: 5, contrast: 10, saturation: 10,
    temperature: 20, tint: -5,
    // 新增（默认 0）
    highlights: 0, shadows: 0, blackPoint: 0,
    clarity: 0, vibrance: 0, brilliance: 0
  },
  // ...
}
```

## 9. preview-template.vue 对齐

### 9.1 移除内联调整面板

删除 `<view class="adjust-panel">` 整块（约 130 行模板 + 350 行 SCSS），删除本地 wbOptions/flashOptions/focusOptions/lutOptions 等数据数组。

### 9.2 引入 ParamPanel

```vue
<ParamPanel
  :template="template"
  :visible="true"
  :applied="false"
  :raw-mode="false"
  mode="full"
  @close="onPanelClose"
  @apply="onSyncBack"
  @update:template="onTemplateUpdate"
  @update:opacity="onOpacityUpdate"
  @select-system-filter="onSelectSystemFilter"
  @select-lut="onSelectLut"
/>
```

### 9.3 保留独有功能

- 取景器、剪影拖动（silhouette drag layer）保留
- 同步到编辑器按钮（onSyncBack）保留
- `onTemplateUpdate` 调用 `saveAdjustment` 持久化

### 9.4 布局调整与 close 事件处理

ParamPanel 默认 visible=false 滑出底部，需在 preview-template 页强制可见：
- 顶部取景器占 60% 高度
- ParamPanel 占 40% 高度，固定 visible=true
- **close 事件处理**：preview-template 拦截 `@close` 事件，调用 `uni.navigateBack()` 返回上一页，而非将 visible 设为 false（避免面板消失后页面下方留白）
- ParamPanel 内置的关闭按钮（panel-handle）保留原样，点击即触发 navigateBack

## 10. preview.vue 后期处理页重构

### 10.1 页面结构

```
[深色导航栏]
[照片展示区] - 应用 buildCssFilter(camera, post) 实时预览
[EXIF 卡片区] - 显示拍摄时的相机参数
[ParamPanel mode="post-only"] - 完整后期编辑能力
[心情/场景标签区] - 保留现有
[对比图按钮] - 切换原图/编辑后对比
[保存按钮]
```

### 10.2 EXIF 卡片

```vue
<view class="exif-card" v-if="exifData">
  <view class="exif-header">
    <text class="ph ph-clipboard-text exif-icon" />
    <text class="exif-title">EXIF 信息</text>
  </view>
  <view class="exif-grid">
    <view class="exif-item">
      <text class="exif-label">EV</text>
      <text class="exif-value">{{ exifData.exposureCompensation }}</text>
    </view>
    <view class="exif-item">
      <text class="exif-label">ISO</text>
      <text class="exif-value">{{ exifData.iso || 'auto' }}</text>
    </view>
    <view class="exif-item">
      <text class="exif-label">快门</text>
      <text class="exif-value">{{ exifData.shutterSpeed }}</text>
    </view>
    <view class="exif-item">
      <text class="exif-label">白平衡</text>
      <text class="exif-value">{{ exifData.whiteBalanceK }}K</text>
    </view>
    <view class="exif-item" v-if="exifData.aperture">
      <text class="exif-label">光圈</text>
      <text class="exif-value">f/{{ exifData.aperture }}</text>
    </view>
    <view class="exif-item" v-if="exifData.photographicStyle">
      <text class="exif-label">风格</text>
      <text class="exif-value">{{ photographicStyleLabel(exifData.photographicStyle) }}</text>
    </view>
    <view class="exif-item" v-if="exifData.lensType">
      <text class="exif-label">镜头</text>
      <text class="exif-value">{{ exifData.lensType }}</text>
    </view>
    <view class="exif-item" v-if="exifData.hdr">
      <text class="exif-label">HDR</text>
      <text class="exif-value">✓</text>
    </view>
  </view>
</view>
```

### 10.3 EXIF 数据来源

通过 `uni._lastCaptureData` 同时传递照片 dataURL 与拍摄时的 template 快照：

```typescript
// capture/index.vue onShutter 内
;(uni as any)._lastCaptureData = result.dataUrl
;(uni as any)._lastCaptureTemplate = rawMode.value ? null : JSON.parse(JSON.stringify(
  editableTemplate.value ?? emptyTemplate
))

// preview.vue onLoad
const photoUrl = ref('')
const exifData = ref<CameraParams | null>(null)
const editableTemplate = ref<PhotoTemplate | null>(null)

onLoad(() => {
  const data = (uni as any)._lastCaptureData
  const tpl = (uni as any)._lastCaptureTemplate
  if (data) {
    photoUrl.value = data
    delete (uni as any)._lastCaptureData
  }
  if (tpl) {
    editableTemplate.value = tpl
    exifData.value = tpl.camera
    delete (uni as any)._lastCaptureTemplate
  }
})
```

### 10.4 对比图

```vue
<view class="compare-section">
  <view class="compare-toggle" @click="showCompare = !showCompare">
    <text class="ph ph-git-compare" />
    <text>{{ showCompare ? '退出对比' : '对比原图' }}</text>
  </view>
  
  <view v-if="showCompare" class="compare-viewer">
    <view class="compare-pane">
      <text class="compare-label">原图</text>
      <image class="compare-img" :src="photoUrl" mode="aspectFill" />
    </view>
    <view class="compare-pane">
      <text class="compare-label">编辑后</text>
      <image class="compare-img" :src="photoUrl" mode="aspectFill" :style="editedFilterStyle" />
    </view>
  </view>
</view>
```

### 10.5 实时滤镜预览

```typescript
const editedFilterStyle = computed(() => {
  if (!editableTemplate.value) return {}
  const filter = buildCssFilter(editableTemplate.value.camera, editableTemplate.value.postProcess)
  return filter ? { filter, webkitFilter: filter } : {}
})
```

照片展示区应用 `editedFilterStyle`，实时反映 ParamPanel 的编辑结果。

## 11. scene-guide.vue 重构

### 11.1 数据迁移

将 myScenes / recommendScenes / sceneTips 从组件内移到 `data/scenePresets.ts`，复用 `SCENE_PRESETS`。

```typescript
// data/scenePresets.ts
export const SCENE_PRESETS: ScenePreset[] = [
  {
    id: 'cafe',
    name: '咖啡馆',
    icon: 'ph-coffee',
    description: '柔和自然光，温暖氛围',
    cameraSuggestion: {
      whiteBalance: 'cloudy',
      whiteBalanceK: 4800,
      photographicStyle: 'warm',
      aperture: 2.8
    },
    postSuggestion: {
      lut: 'warm_film',
      color: { temperature: 20, contrast: 10 }
    },
    sceneGuide: {
      lightDirection: '侧光 45°-90°（窗户自然光为主光源）',
      shootingDistance: '1.5-2.5m',
      background: '咖啡馆室内环境，虚化的吧台、书架或暖色墙面',
      props: ['咖啡杯', '书本', '绿植盆栽'],
      bestTime: '下午 14:00-17:00',
      tips: [
        '让模特面朝窗户，利用柔光均匀照亮面部',
        '使用大光圈虚化背景突出人物',
        '避免顶光直射造成眼窝阴影'
      ]
    },
    relatedCategory: 'portrait'
  },
  // ...其余 9 个
]

export const SCENE_TO_CATEGORY: Record<ScenePresetId, Target> = {
  cafe: 'portrait',
  street: 'street',
  beach: 'landscape',
  macro: 'macro',
  night: 'night',
  food: 'food',
  home: 'still-life',
  sunset: 'landscape',
  forest: 'landscape',
  indoor: 'still-life'
}
```

### 11.2 scene-guide.vue 简化

```vue
<script setup lang="ts">
import { SCENE_PRESETS, SCENE_TO_CATEGORY } from '@/data/scenePresets'

const myScenes = ref(SCENE_PRESETS.slice(0, 8))  // 前 8 个作为"我的场景"
const recommendScenes = ref(SCENE_PRESETS.slice(8))  // 后 2 个作为推荐

const onSceneTap = (preset: ScenePreset) => {
  // 跳转到拍摄页并预选场景
  uni.navigateTo({
    url: `/pages/capture/index?scenePreset=${preset.id}`
  })
}

const goTemplates = (preset: ScenePreset) => {
  const cat = SCENE_TO_CATEGORY[preset.id]
  uni.navigateTo({
    url: `/pages/templates/index?scene=${preset.id}&category=${cat}`
  })
}
</script>
```

### 11.3 capture/index.vue 接收 scenePreset 参数

```typescript
onLoad((options) => {
  if (options?.templateId) {
    currentTemplateId.value = options.templateId
    pushRecent(options.templateId)
  }
  // 新增：接收场景预设
  if (options?.scenePreset) {
    const preset = SCENE_PRESETS.find(p => p.id === options.scenePreset)
    if (preset) {
      // 基于 preset 创建可编辑模板
      editableTemplate.value = createEmptyTemplate()
      editableTemplate.value.sceneGuide.presetId = preset.id
      Object.assign(editableTemplate.value.sceneGuide, preset.sceneGuide)
      // 自动应用相机/后期参数
      Object.assign(editableTemplate.value.camera, preset.cameraSuggestion)
      Object.assign(editableTemplate.value.postProcess, preset.postSuggestion)
    }
  }
  loadRecent()
  // ...
})
```

## 12. captureBake.ts 兼容性

`captureBake.ts` 中通过 `buildCanvasFilter` 调用 `buildCssFilter`，新参数自动生效。无需修改。

但需检查 `captureBake.ts` 是否依赖 CameraParams/PostProcess 的具体字段，避免新字段引发类型错误。

## 13. parameterMatch.ts 兼容性

`isParametersMatchingTemplate` 用于判断 editableTemplate 是否与 originalTemplate 一致（计算 `applied` 状态）。新增字段需要加入比较列表：

```typescript
const CAMERA_KEYS: (keyof CameraParams)[] = [
  'exposureCompensation', 'iso', 'shutterSpeed',
  'whiteBalance', 'whiteBalanceK', 'flashMode', 'focusMode',
  'lensType', 'photographicStyle', 'hdr',
  // 新增
  'aperture', 'nightMode', 'nightExposureTime',
  'livePhoto', 'gridEnabled', 'aeAfLock', 'lensCorrection'
]

const POST_COLOR_KEYS: (keyof PostProcessColor)[] = [
  'brightness', 'contrast', 'saturation', 'temperature', 'tint',
  // 新增
  'highlights', 'shadows', 'blackPoint', 'clarity', 'vibrance', 'brilliance'
]
```

## 14. useTemplate.ts 兼容性

`useTemplate` 提供 `loadTemplate`/`saveAdjustment`/`loadDraft` 等方法。新增字段不影响接口，但需要确认：
- `saveAdjustment(template)` 是否深拷贝（避免引用泄漏）
- `loadDraft(draftId)` 是否返回完整 PhotoTemplate

## 15. 风险与缓解

### 15.1 风险：现有模板数据缺新字段导致 undefined

**缓解**：所有新增字段都是可选（`?:`），且在 ParamPanel 中通过 `?? 0` / `|| false` 默认值访问。filterRecipe 中 `post.color?.highlights ?? 0` 同样安全。

### 15.2 风险：ParamPanel mode='post-only' 时 Tab 切换栏隐藏破坏布局

**缓解**：通过 `v-if="isFullMode"` 控制 Tab 切换栏的显示，activeTab 在 post-only 模式强制为 4（后期）。布局上 panel-content 占满整个高度。

### 15.3 风险：preview-template.vue 移除内联面板后样式破坏

**缓解**：preview-template.vue 改为 ParamPanel 始终 visible=true，原有 `adjust-panel` 的 SCSS 全部删除（不再需要）。保留 sync-btn 底部栏。

### 15.4 风险：preview.vue 添加 ParamPanel 后高度溢出

**缓解**：preview.vue 整体改为可滚动布局（page 容器），ParamPanel 不再 fixed，作为流式布局的一部分。EXIF 卡片与对比图作为可折叠区。

### 15.5 风险：场景预设应用覆盖用户已调参数

**缓解**：onApplyScenePreset 使用 `Object.assign` 浅合并，仅覆盖 preset 中定义的字段。对于 color 子对象，单独合并 `postSuggestion.color` 到 `tpl.postProcess.color` 而非整体替换。完整实现见 6.4 节 `onApplyScenePreset`。

## 16. 测试策略

### 16.1 类型检查
- `npm run type-check`（vue-tsc）零错误

### 16.2 手动验证
1. 拍摄页打开 ParamPanel → 相机 Tab 高级区 → 验证光圈/夜景/Live Photo/网格/AE-AF 锁/镜头校正 6 个新控件可交互
2. 后期 Tab 高级区 → 验证高光/阴影/黑点/清晰度/自然饱和度/鲜明度 6 个滑块可调且实时影响预览
3. 场景 Tab → 选择 10 个场景预设之一 → 点"一键应用" → 验证相机/后期参数同步更新
4. preview-template.vue → 验证 ParamPanel 显示与拍摄页一致（5 个 Tab 完整）
5. preview.vue → 验证 EXIF 卡片显示、对比图切换、ParamPanel post-only 模式
6. scene-guide.vue → 验证 10 个场景显示、点击跳转拍摄页并预选场景

### 16.3 浏览器调试
- Chrome DevTools MCP 检查 pill 布局、点击事件、CSS 变量
- 截图对比改动前后

## 17. 实施顺序建议

1. **类型系统扩展**（types/template.ts）→ 编译通过
2. **场景预设数据**（data/scenePresets.ts）→ 单元可用
3. **filterRecipe.ts 扩展** → 后期参数生效
4. **emptyTemplate.ts 更新** → 默认值完备
5. **现有 13 个模板迁移** → 数据完整
6. **ParamPanel 重构**：mode prop + 相机 Tab 新控件 + 后期 Tab 新控件 + 场景 Tab 重构
7. **preview-template.vue 对齐**：替换内联面板为 ParamPanel
8. **preview.vue 重构**：EXIF 卡片 + 对比图 + ParamPanel post-only
9. **scene-guide.vue 重构**：数据迁移 + 跳转预选场景
10. **capture/index.vue 接收 scenePreset 参数**
11. **parameterMatch.ts 字段同步**
12. **类型检查 + 浏览器调试 + 提交**

## 18. 验收标准

- [ ] vue-tsc 零错误
- [ ] 拍摄页 ParamPanel 6 个新相机控件全部可交互
- [ ] 拍摄页 ParamPanel 6 个新后期滑块全部可调且实时影响预览
- [ ] 拍摄页 ParamPanel 场景 Tab 10 个预设可选可应用
- [ ] preview-template.vue 与拍摄页 ParamPanel 完全一致（5 Tab 完整）
- [ ] preview.vue 显示 EXIF 卡片 + 对比图 + 完整后期编辑
- [ ] scene-guide.vue 显示 10 个场景，点击跳转拍摄页并预选场景
- [ ] 所有改动通过 Chrome DevTools 截图验证 UI 正常
