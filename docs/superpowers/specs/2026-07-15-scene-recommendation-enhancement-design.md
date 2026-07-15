# 如画 Lumira 场景推荐功能完善 — 设计文档

**日期**：2026-07-15
**作者**：协同设计
**前置工作**：
- `2026-07-14-capture-full-enhancement-design.md`（拍摄/预览/场景功能完整对齐与增强设计，本设计为其子集实施）
- `2026-07-14-capture-page-enhancement-design.md`（拍照页核心功能完善，已完成）
**实施范围**：场景推荐页（scene-guide.vue）+ ParamPanel 场景 Tab，不含 ParamPanel 相机/后期 Tab 控件扩展、preview-template/preview 重构、模板数据迁移。

## 1. 背景与目标

### 1.1 现状问题

当前 `lumira-app/src/pages/capture/scene-guide.vue` 场景推荐页存在以下问题：

1. **数据硬编码分散**：8 个「我的场景」+ 3 个「推荐场景」直接写在组件 `<script setup>` 中，与 home/index.vue、inspiration/index.vue 三处重复
2. **场景小贴士覆盖不全**：`sceneTips` 字典仅含 4 个场景（cafe/street/food/home），其余 7 个场景点击后 `currentTip` 为 null，小贴士卡片不显示
3. **场景→模板分类映射不全**：`sceneToCategory` 仅 4 条映射，其余场景点击「查看模板」无法带 category 参数
4. **导航链路断裂**：点击场景列表项仅更新 `currentTip`，不跳转拍摄页；卡片「开始拍摄」按钮固定跳 `/pages/capture/index` 不带任何参数，无法预选场景
5. **无结构化场景预设**：场景对象仅含 `name/desc/icon/scene` 字段，无相机/后期参数建议，无法支持「一键应用场景参数」
6. **ParamPanel 场景 Tab 只读**：当前场景 Tab（ParamPanel.vue 336-368 行）仅展示 `sceneGuide` 的 4 个字段 + 道具 + 贴士，无法切换场景预设，无法应用场景参数

### 1.2 目标

- 新建 `data/scenePresets.ts` 作为场景数据单一源（10 个内置场景预设）
- 扩展 `types/template.ts`：新增 `ScenePresetId`/`ScenePreset` 类型 + `SceneGuide` 结构化字段 + `CameraParams`/`PostProcessColor` 可选新字段
- 扩展 `utils/filterRecipe.ts`：6 个新色彩参数的 CSS filter 映射，使预设后期参数应用后视觉实时生效
- 更新 `utils/emptyTemplate.ts`：补全新字段默认值
- 重写 `pages/capture/scene-guide.vue`：数据驱动 + 保留小贴士卡片交互 + 跳转带 scenePreset 参数
- 更新 `pages/capture/index.vue`：`onLoad` 接收 `scenePreset` 参数并应用预设
- 重构 `components/ParamPanel.vue` 场景 Tab：预设选择 + 一键应用 + 参数预览 + 自定义场景参数

### 1.3 非目标

- 不迁移现有 13 个模板数据（新字段均为可选 `?:`，访问处 `?? 0` 兜底）
- 不扩展 ParamPanel 相机 Tab（6.2）/后期 Tab（6.3）控件
- 不重构 `preview-template.vue`（第 9 章）/ `preview.vue`（第 10 章）
- 不统一 home/index.vue、inspiration/index.vue 的场景数据（本次仅 scene-guide.vue + ParamPanel）
- 不实现场景 CRUD（新建/编辑/删除场景）
- 不实现场景云端同步

## 2. 架构方案

### 2.1 数据流

```
data/scenePresets.ts (10 个 ScenePreset，单一数据源)
        │
        ├──→ scene-guide.vue  (列表展示 + 小贴士卡片)
        │         └── 卡片「开始拍摄」→ /pages/capture/index?scenePreset=id
        │                └──→ capture/index.vue onLoad 接收 scenePreset
        │                       └──→ 基于 preset 构建 editableTemplate
        │                             (Object.assign camera/postProcess/sceneGuide)
        │
        └──→ ParamPanel.vue 场景 Tab (预设选择 + 一键应用 + 参数预览)
                  ├── onSelectScenePreset → 更新 sceneGuide.presetId + 场景信息
                  ├── onApplyScenePreset  → Object.assign camera/postProcess
                  └── updateSceneGuide   → 自定义结构化字段
                           └──→ emit('update:template') → 父页面
                                    └──→ buildCssFilter(camera, post) 实时预览
```

### 2.2 单一数据源原则

`SCENE_PRESETS` 同时供 scene-guide.vue 与 ParamPanel 场景 Tab 使用，消除重复硬编码。`SCENE_TO_CATEGORY` 提供 scenePresetId → Target 的映射，供 scene-guide.vue 跳转模板列表时携带 category 参数。

### 2.3 类型扩展策略

所有新增字段均为可选（`?:`），保证：
- 现有 13 个模板数据无需迁移
- `emptyTemplate.ts` 提供完整默认值
- `filterRecipe.ts` / `ParamPanel.vue` 访问新字段时统一用 `?? 0` / `|| false` 兜底
- `parameterMatch.ts` 对 undefined 字段安全（undefined === undefined），无需修改

## 3. 类型系统扩展（types/template.ts）

### 3.1 新增 ScenePresetId

```typescript
export type ScenePresetId =
  | 'cafe' | 'street' | 'beach' | 'macro'
  | 'night' | 'food' | 'home' | 'sunset'
  | 'forest' | 'indoor'
```

### 3.2 CameraParams 新增 6 个可选字段

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

### 3.3 PostProcessColor 新增 6 个可选字段

```typescript
export interface PostProcessColor {
  // 现有
  brightness: number
  contrast: number
  saturation: number
  temperature: number
  tint: number

  // ===== 新增 6 项（苹果相册编辑参数对齐）=====
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

### 3.4 SceneGuide 新增结构化字段

```typescript
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
```

### 3.5 新增 ScenePreset 接口

```typescript
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
  /** 一键应用的后期参数（含 color 子对象） */
  postSuggestion: Partial<PostProcess> & { color?: Partial<PostProcessColor> }
  /** 场景指南数据 */
  sceneGuide: Omit<SceneGuide, 'presetId'>
  /** 关联的模板分类 */
  relatedCategory: Target
}
```

## 4. 数据层（data/scenePresets.ts）

新建 `lumira-app/src/data/scenePresets.ts`，包含 10 个内置场景预设。

### 4.1 预设清单

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

每个预设包含完整的 `sceneGuide` 字段（lightDirection/shootingDistance/background/props/bestTime/tips），10 个场景全覆盖。

### 4.2 数据结构示例

```typescript
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
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 2,
      bestTimeFrom: '14:00',
      bestTimeTo: '17:00'
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

## 5. filterRecipe.ts 扩展

### 5.1 新增 6 个后期参数的 CSS filter 映射

在 `buildCssFilter` 函数中，按以下顺序在现有 temperature/tint 之后追加（对齐设计文档 5.2 节应用顺序）：

```typescript
// 高光（负值压暗亮部，正值提亮亮部）
const highlights = post.color?.highlights ?? 0
if (highlights !== 0) {
  filters.push(`brightness(${(1 + highlights / 300).toFixed(3)})`)
}

// 阴影（负值压暗暗部，正值提亮暗部）
const shadows = post.color?.shadows ?? 0
if (shadows !== 0) {
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

### 5.2 现有函数复用

- `getLutLabel(lut: LutPreset)` 已存在（filterRecipe.ts 第 212 行），ParamPanel 场景 Tab 参数预览区直接复用
- `buildCanvasFilter` 通过调用 `buildCssFilter` 自动同步，无需修改

## 6. emptyTemplate.ts 更新

`createEmptyTemplate()` 必须返回包含所有新增字段的完整对象，避免 `undefined` 引发计算错误：

```typescript
export function createEmptyTemplate(): PhotoTemplate {
  return {
    // ...meta/composition/pose 保留
    camera: {
      // 现有
      exposureCompensation: 0,
      iso: 0,
      shutterSpeed: 'auto',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensType: '1x',
      photographicStyle: 'standard',
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
      lightDirection: '',
      shootingDistance: '',
      background: '',
      props: [],
      bestTime: '',
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

## 7. scene-guide.vue 重写

### 7.1 数据源迁移

```typescript
import { SCENE_PRESETS, SCENE_TO_CATEGORY } from '@/data/scenePresets'
import type { ScenePreset, ScenePresetId } from '@/types/template'

// 前 8 个作为「我的场景」，后 2 个作为「推荐场景」
const myScenes = ref<ScenePreset[]>(SCENE_PRESETS.slice(0, 8))
const recommendScenes = ref<ScenePreset[]>(SCENE_PRESETS.slice(8))

const selectedPreset = ref<ScenePreset | null>(null)
```

删除组件内硬编码的 `sceneTips`、`sceneToCategory`、`myScenes`、`recommendScenes` 数组。

### 7.2 交互模型（保留小贴士卡片 + 增加跳转）

保留现有「点击场景列表项 → 显示小贴士卡片」交互，但：

1. **小贴士卡片数据源**改为 `selectedPreset.sceneGuide`，展示完整 6 字段（光线/距离/背景/最佳时间/道具/贴士），10 个场景全覆盖
2. **卡片「开始拍摄」按钮**改为：
   ```typescript
   const goCapture = () => {
     if (!selectedPreset.value) return
     uni.navigateTo({
       url: `/pages/capture/index?scenePreset=${selectedPreset.value.id}`
     })
   }
   ```
3. **卡片「查看模板」按钮**改为：
   ```typescript
   const goTemplates = () => {
     if (!selectedPreset.value) return
     const cat = SCENE_TO_CATEGORY[selectedPreset.value.id]
     uni.navigateTo({
       url: `/pages/templates/index?scene=${selectedPreset.value.id}&category=${cat}`
     })
   }
   ```
4. **onLoad 接收 `?scene=` 参数**：自动定位到对应 preset 并展示小贴士卡片
   ```typescript
   onLoad((options) => {
     if (options?.scene) {
       const preset = SCENE_PRESETS.find(p => p.id === options.scene)
       if (preset) {
         selectedPreset.value = preset
         tab.value = 'recommend'
       }
     }
   })
   ```

### 7.3 小贴士卡片 UI 调整

现有小贴士卡片仅 3 行（光线/距离/技巧），扩展为完整场景指南：

```vue
<view v-if="selectedPreset" class="section-pad fade-up">
  <view class="tip-detail-card">
    <view class="tip-detail-head">
      <text class="ph ph-lightbulb tip-detail-icon"></text>
      <text class="tip-detail-title">{{ selectedPreset.name }} · 拍摄小贴士</text>
    </view>
    <view class="tip-detail-body">
      <view class="tip-detail-row">
        <text class="ph ph-sun tip-detail-row-icon"></text>
        <text class="tip-detail-row-label">光线</text>
        <text class="tip-detail-row-text">{{ selectedPreset.sceneGuide.lightDirection }}</text>
      </view>
      <view class="tip-detail-row">
        <text class="ph ph-ruler tip-detail-row-icon"></text>
        <text class="tip-detail-row-label">距离</text>
        <text class="tip-detail-row-text">{{ selectedPreset.sceneGuide.shootingDistance }}</text>
      </view>
      <view class="tip-detail-row">
        <text class="ph ph-image tip-detail-row-icon"></text>
        <text class="tip-detail-row-label">背景</text>
        <text class="tip-detail-row-text">{{ selectedPreset.sceneGuide.background }}</text>
      </view>
      <view class="tip-detail-row">
        <text class="ph ph-clock tip-detail-row-icon"></text>
        <text class="tip-detail-row-label">时间</text>
        <text class="tip-detail-row-text">{{ selectedPreset.sceneGuide.bestTime }}</text>
      </view>
      <view v-if="selectedPreset.sceneGuide.props.length" class="tip-detail-row">
        <text class="ph ph-package tip-detail-row-icon"></text>
        <text class="tip-detail-row-label">道具</text>
        <view class="prop-tag-list">
          <view class="prop-tag" v-for="(p, i) in selectedPreset.sceneGuide.props" :key="i">
            <text class="prop-tag-text">{{ p }}</text>
          </view>
        </view>
      </view>
      <view v-for="(tip, i) in selectedPreset.sceneGuide.tips" :key="i" class="tip-detail-row">
        <text class="ph ph-circle tip-detail-row-icon"></text>
        <text class="tip-detail-row-label">技巧</text>
        <text class="tip-detail-row-text">{{ tip }}</text>
      </view>
    </view>
    <view class="tip-detail-actions">
      <view class="tip-detail-btn-ghost" @click="goTemplates">
        <text class="ph ph-book-open"></text>
        <text>查看模板</text>
      </view>
      <view class="tip-detail-btn-brand" @click="goCapture">
        <text class="ph ph-camera"></text>
        <text>开始拍摄</text>
      </view>
    </view>
  </view>
</view>
```

### 7.4 列表项数据绑定调整

`myScenes` / `recommendScenes` 现在是 `ScenePreset[]`，列表项绑定字段调整：
- `s.name` → `preset.name`
- `s.desc` → `preset.description`
- `s.icon` → `preset.icon`
- `s.scene` → `preset.id`
- `s.img` 字段移除（ScenePreset 无图片字段，列表项的缩略图改为隐藏或用图标替代）

列表项点击改为：
```typescript
const onSceneTap = (preset: ScenePreset) => {
  selectedPreset.value = preset
}
```

## 8. capture/index.vue 接收 scenePreset 参数

### 8.1 onLoad 扩展

在现有 `onLoad` 中新增 `scenePreset` 参数处理，与现有 `templateId` 分支互斥：

```typescript
import { SCENE_PRESETS } from '@/data/scenePresets'
import { createEmptyTemplate } from '@/utils/emptyTemplate'

onLoad((options) => {
  if (options?.templateId) {
    currentTemplateId.value = options.templateId
    pushRecent(options.templateId)
  } else if (options?.scenePreset) {
    // 场景预设模式：基于 preset 创建可编辑模板
    const preset = SCENE_PRESETS.find(p => p.id === options.scenePreset)
    if (preset) {
      const tpl = createEmptyTemplate()
      tpl.sceneGuide.presetId = preset.id
      Object.assign(tpl.sceneGuide, preset.sceneGuide)
      Object.assign(tpl.camera, preset.cameraSuggestion)
      // postSuggestion 单独处理 color 子对象
      if (preset.postSuggestion.color) {
        Object.assign(tpl.postProcess.color, preset.postSuggestion.color)
      }
      const { color: _omitColor, ...restPost } = preset.postSuggestion
      Object.assign(tpl.postProcess, restPost)
      editableTemplate.value = tpl
    }
  }
  loadRecent()
  // ...
})
```

### 8.2 与现有 templateId 分支的关系

- `templateId` 优先（从模板进入拍摄页）
- 无 `templateId` 但有 `scenePreset` 时，走场景预设分支
- 两者均无时，走现有 `loadRecent()` 逻辑

## 9. ParamPanel 场景 Tab 重构

### 9.1 替换只读场景 Tab

删除 ParamPanel.vue 第 336-368 行的只读场景 Tab，替换为完整的场景预设交互区。

### 9.2 模板结构

```vue
<!-- 场景 Tab -->
<view v-if="activeTab === 2" class="tab-pane">
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
  <AdvancedSection title="自定义场景参数" :open="advancedOpen.sceneCustom" @toggle="toggleAdvanced('sceneCustom')">
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
              :min="0.1" :max="10" :step="0.1"
              @change="(e) => updateSceneGuide('shootingDistanceM', e.detail.value)" />
    </view>
  </AdvancedSection>
</view>
```

### 9.3 脚本逻辑

```typescript
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { ScenePreset, ScenePresetId } from '@/types/template'
import { getLutLabel } from '@/utils/filterRecipe'

const scenePresets = SCENE_PRESETS

const currentScenePreset = computed(() => {
  const id = props.template.sceneGuide.presetId
  return id ? scenePresets.find(p => p.id === id) : null
})

const onSelectScenePreset = (id: ScenePresetId) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  // 仅更新 presetId 与场景信息（不自动应用相机/后期参数，由用户点「一键应用」触发）
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

const updateSceneGuide = <K extends keyof PhotoTemplate['sceneGuide']>(
  key: K,
  value: PhotoTemplate['sceneGuide'][K]
) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
  tpl.sceneGuide[key] = value
  emit('update:template', tpl)
}

const lightDirectionOptions = [
  { value: 0, label: '顺光' },
  { value: 45, label: '前侧光' },
  { value: 90, label: '侧光' },
  { value: 135, label: '侧逆光' },
  { value: 180, label: '逆光' },
  { value: 270, label: '反射光' }
]
```

### 9.4 辅助函数复用

- `wbLabel` / `photographicStyleLabel`：复用 ParamPanel 现有函数（相机 Tab 已有）
- `getLutLabel`：从 `@/utils/filterRecipe` 导入（已存在）
- `cloneTemplate` / `toggleAdvanced` / `advancedOpen`：复用 ParamPanel 现有逻辑

### 9.5 rawMode 兼容

所有交互函数（onSelectScenePreset / onApplyScenePreset / updateSceneGuide）开头 `if (props.rawMode) return`，与现有契约一致。

## 10. 兼容性与风险

### 10.1 现有 13 个模板数据无需迁移

新字段均为可选（`?:`），`filterRecipe.ts` 通过 `?? 0` 兜底，`ParamPanel.vue` 通过 `|| false` / `?? 0` 兜底。现有模板访问新字段时为 `undefined`，不影响计算。

### 10.2 parameterMatch.ts 无需修改

`isParametersMatchingTemplate` 比较字段列表中未包含新字段。当应用场景预设后：
- editable 与 original 在比较列表内字段（如 whiteBalance/whiteBalanceK/photographicStyle）上存在差异 → `applied = true`（正确，因为预设确实修改了这些字段）
- 新字段（如 aperture）不参与比较，但预设同时修改了 whiteBalance 等列表内字段，所以 applied 状态仍然正确反映「用户已修改参数」

结论：行为正确，无需扩展比较列表。

### 10.3 风险：scene-guide.vue 列表项缩略图移除

**缓解**：ScenePreset 无 `img` 字段。列表项移除缩略图，仅保留图标 + 文字 + 箭头。视觉上更简洁，符合现有 `recommendScenes` 列表项风格（本就无缩略图）。

### 10.4 风险：ParamPanel 场景 Tab 高度增加

**缓解**：场景 Tab 内容增多（预设选择 + 应用按钮 + 参数预览 + 场景信息 + 道具 + 贴士 + 自定义折叠区），但 ParamPanel 本身为可滚动面板，内容超出时内部滚动。自定义场景参数放在 AdvancedSection 折叠区内，默认收起。

### 10.5 风险：applyScenePreset 覆盖用户已调参数

**缓解**：`onApplyScenePreset` 使用 `Object.assign` 浅合并，仅覆盖 preset 中定义的字段。color 子对象单独浅合并 `postSuggestion.color` 到 `tpl.postProcess.color`，而非整体替换。用户已调的其他参数（如 grain/smoothStrength）保留。

## 11. 测试策略

### 11.1 类型检查

- `npm run type-check`（vue-tsc）零错误

### 11.2 手动验证

1. **scene-guide.vue**：
   - 10 个场景显示（8 我的 + 2 推荐）
   - 点击场景项 → 小贴士卡片显示完整 6 字段（光线/距离/背景/时间/道具/贴士）
   - 卡片「开始拍摄」→ 跳转拍摄页，相机/后期参数已应用
   - 卡片「查看模板」→ 跳转模板列表带 scene + category 参数
   - onLoad 接收 `?scene=cafe` → 自动定位咖啡馆场景并展示小贴士
2. **capture/index.vue**：
   - 接收 `?scenePreset=night` → editableTemplate 应用夜景预设（nightMode=true, ISO=800, cyberpunk LUT）
   - 接收 `?scenePreset=food` → 应用美食预设（WB=tungsten, K=3200, warm_film LUT）
3. **ParamPanel 场景 Tab**：
   - 10 个预设横向滚动可选
   - 选中预设 → 参数预览区显示白平衡/风格/光圈/LUT
   - 点「一键应用」→ toast 提示 + 相机/后期参数同步 + 滤镜实时变化
   - 自定义场景参数折叠区 → 光线方向 pill + 拍摄距离 slider 可调
   - rawMode 下所有交互禁用

### 11.3 浏览器调试

- Chrome DevTools MCP 检查 pill 布局、点击事件、CSS 变量
- 截图对比改动前后

## 12. 实施顺序建议

1. **类型系统扩展**（types/template.ts）→ 编译通过
2. **场景预设数据**（data/scenePresets.ts）→ 单元可用
3. **filterRecipe.ts 扩展** → 后期参数生效
4. **emptyTemplate.ts 更新** → 默认值完备
5. **scene-guide.vue 重写** → 数据驱动 + 跳转
6. **capture/index.vue 接参** → scenePreset 参数应用
7. **ParamPanel 场景 Tab 重构** → 预设选择 + 一键应用
8. **类型检查 + 浏览器调试 + 提交**

## 13. 验收标准

- [ ] vue-tsc 零错误
- [ ] `data/scenePresets.ts` 包含 10 个完整 ScenePreset + SCENE_TO_CATEGORY 映射
- [ ] `types/template.ts` 新增 ScenePresetId/ScenePreset 类型 + SceneGuide/CameraParams/PostProcessColor 结构化字段
- [ ] `filterRecipe.ts` buildCssFilter 支持 6 个新色彩参数
- [ ] `emptyTemplate.ts` 补全所有新字段默认值
- [ ] scene-guide.vue 显示 10 个场景，点击显示完整小贴士，跳转带 scenePreset 参数
- [ ] capture/index.vue 接收 scenePreset 参数后应用相机/后期预设
- [ ] ParamPanel 场景 Tab 10 个预设可选，一键应用后参数同步且滤镜实时变化
- [ ] ParamPanel 自定义场景参数折叠区可调光线方向/拍摄距离
- [ ] rawMode 下 ParamPanel 场景 Tab 交互禁用
- [ ] 所有改动通过 Chrome DevTools 截图验证 UI 正常
