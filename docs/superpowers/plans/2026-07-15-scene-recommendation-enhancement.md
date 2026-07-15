# 如画场景推荐功能完善 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善如画 Lumira 场景推荐功能：新建 10 个场景预设数据源、扩展类型系统、重构 scene-guide.vue 与 ParamPanel 场景 Tab，实现场景预设选择与一键应用。

**Architecture:** 单一数据源 `data/scenePresets.ts` 同时供场景推荐页与 ParamPanel 场景 Tab 使用；类型扩展均为可选字段（`?:`），现有 13 个模板无需迁移；filterRecipe 扩展 6 个新色彩参数 CSS filter 映射使预设后期参数应用后视觉实时生效。

**Tech Stack:** uni-app (Vue 3 + TypeScript), SCSS, vue-tsc 类型检查, Phosphor Icons

## Global Constraints

- 所有页面必须使用 uni-app 组件（`<view>` 而非 `<div>`，`<text>` 而非 `<span>`，`<image>` 而非 `<img>`）
- CSS 单位必须使用 rpx 而非 px
- `<image>` 组件不支持 `:alt` 属性
- 所有样式（全局和 scoped）都只能使用 class 选择器，不可使用标签选择器（如 `view {}`, `.parent text {}`）
- SCSS 变量在 template 内联 style 中不生效，需使用具体颜色值或在 style 块中定义类
- uni-app `<scroll-view scroll-x>` 的内部容器必须显式设置 `display: inline-flex`，scroll-view 本身需 `white-space: nowrap`
- pill 类内联元素必须显式设置 `display: inline-flex; align-items: center;`
- 所有图片资源必须来自 picsum.photos（本次场景预设无图片字段，不涉及）
- 标题栏文本不应居中对齐
- 类型检查命令：`npm run type-check`（在 `lumira-app` 目录下运行），必须零错误
- ParamPanel 拍照页面始终使用深色配色，不跟随全局主题（CSS 变量在 `.param-panel-body` 内注入深色值）
- AdvancedSection 组件接口：prop `title: string` + `open: boolean`，event `update:open: (value: boolean)`
- 现有 `advancedOpen` ref 的 key 为 `camera/composition/pose/post`，无 `scene` key（本计划需新增）
- 现有 ParamPanel 无 `photographicStyleLabel` 函数，但有 `photographicStyleOptions` 数组（本计划需新增 label 函数）
- 现有 `cloneTemplate` 为 function 声明（非 const 箭头函数），位于 script 末尾

---

### Task 1: 类型系统扩展（types/template.ts）

**Files:**
- Modify: `lumira-app/src/types/template.ts`

**Interfaces:**
- Produces: `ScenePresetId` 类型、`ScenePreset` 接口、扩展后的 `CameraParams`（+6 可选字段）、`PostProcessColor`（+6 可选字段）、`SceneGuide`（+5 结构化字段）。后续任务的 scenePresets.ts、emptyTemplate.ts、ParamPanel.vue 均依赖这些类型。

- [ ] **Step 1: 新增 ScenePresetId 类型**

在 `types/template.ts` 文件顶部（`Target` 类型定义之后）新增：

```typescript
/** 场景预设 ID */
export type ScenePresetId =
  | 'cafe' | 'street' | 'beach' | 'macro'
  | 'night' | 'food' | 'home' | 'sunset'
  | 'forest' | 'indoor'
```

- [ ] **Step 2: CameraParams 新增 6 个可选字段**

在 `CameraParams` 接口末尾（`hdr?: boolean` 之后、`@deprecated` 注释之前）新增：

```typescript
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
```

- [ ] **Step 3: PostProcessColor 新增 6 个可选字段**

将 `PostProcess` 接口中的 `color` 字段类型从内联对象改为命名接口。先在 `PostProcess` 接口之前新增 `PostProcessColor` 接口：

```typescript
/** 后期色彩参数 */
export interface PostProcessColor {
  brightness: number
  contrast: number
  saturation: number
  /** 暖/冷 -100 ~ 100 */
  temperature: number
  /** 绿/品 -100 ~ 100 */
  tint: number
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

然后修改 `PostProcess` 接口，将内联 color 对象替换为引用：

```typescript
export interface PostProcess {
  /** 裁剪比，如 '3:4' */
  cropRatio: string
  color: PostProcessColor
  /** 磨皮 0-100 */
  smoothStrength: number
  /** 锐化 0-100 */
  sharpen: number
  /** 暗角 0-100 */
  vignette: number
  /** 颗粒 0-100 */
  grain: number
  /** LUT 预设 */
  lut: LutPreset
  /** 系统内置滤镜（苹果风格） */
  systemFilter?: SystemFilter
}
```

- [ ] **Step 4: SceneGuide 新增结构化字段**

在 `SceneGuide` 接口末尾（`tips: string[]` 之后）新增：

```typescript
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
```

- [ ] **Step 5: 新增 ScenePreset 接口**

在 `PhotoTemplate` 接口之前新增：

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

- [ ] **Step 6: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。现有代码不使用新字段，类型扩展为可选，不影响现有编译。

- [ ] **Step 7: 提交**

```bash
cd lumira-app
git add src/types/template.ts
git commit -m "feat(types): 扩展 CameraParams/PostProcessColor/SceneGuide + 新增 ScenePresetId/ScenePreset 类型"
```

---

### Task 2: 场景预设数据（data/scenePresets.ts）

**Files:**
- Create: `lumira-app/src/data/scenePresets.ts`

**Interfaces:**
- Consumes: `ScenePreset`、`ScenePresetId`、`Target`（from Task 1 的 `@/types/template`）
- Produces: `SCENE_PRESETS: ScenePreset[]`（10 个预设）、`SCENE_TO_CATEGORY: Record<ScenePresetId, Target>`。Task 3-7 均依赖此数据。

- [ ] **Step 1: 创建数据文件**

创建 `lumira-app/src/data/scenePresets.ts`，包含 10 个场景预设。完整内容如下：

```typescript
import type { ScenePreset, ScenePresetId, Target } from '@/types/template'

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
  {
    id: 'street',
    name: '街拍',
    icon: 'ph-buildings',
    description: '城市光影，故事感构图',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      photographicStyle: 'high_contrast',
      aperture: 4
    },
    postSuggestion: {
      lut: 'cinematic',
      color: { contrast: 15, clarity: 10 }
    },
    sceneGuide: {
      lightDirection: '侧光/侧逆光（利用建筑遮挡形成光斑）',
      shootingDistance: '3-5m 环境人像',
      background: '街角、橱窗、斑马线、涂鸦墙等城市元素',
      props: ['咖啡杯', '墨镜', '手提包'],
      bestTime: '黄金时刻 16:00-18:00 或清晨 07:00-09:00',
      tips: [
        '寻找街角光影对比，利用橱窗反光增加层次',
        '采用抓拍方式捕捉自然步态',
        '注意背景行人避免干扰主体'
      ],
      lightDirectionAngle: 135,
      shootingDistanceM: 4,
      bestTimeFrom: '16:00',
      bestTimeTo: '18:00'
    },
    relatedCategory: 'street'
  },
  {
    id: 'beach',
    name: '海边',
    icon: 'ph-waves',
    description: '广阔天际线，清新明亮',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      photographicStyle: 'standard',
      aperture: 8
    },
    postSuggestion: {
      lut: 'cool_film',
      color: { brightness: 5, vibrance: 10 }
    },
    sceneGuide: {
      lightDirection: '顺光或侧光（避免正午顶光）',
      shootingDistance: '2-5m 半身至全身',
      background: '海平面、沙滩、礁石、天空',
      props: ['草帽', '丝巾', '沙滩裙'],
      bestTime: '黄金时刻 06:00-08:00 或 17:00-19:00',
      tips: [
        '利用海风让头发飘动增加动感',
        '低角度拍摄拉长身形，融入海平面',
        '注意镜头防沙防水'
      ],
      lightDirectionAngle: 45,
      shootingDistanceM: 3,
      bestTimeFrom: '17:00',
      bestTimeTo: '19:00'
    },
    relatedCategory: 'landscape'
  },
  {
    id: 'macro',
    name: '微距',
    icon: 'ph-flower',
    description: '细节之美，浅景深虚化',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      focusMode: 'manual',
      aperture: 8
    },
    postSuggestion: {
      lut: 'pastel',
      color: { clarity: 15 },
      sharpen: 20
    },
    sceneGuide: {
      lightDirection: '柔光（避免直射造成硬阴影）',
      shootingDistance: '10-30cm 微距范围',
      background: '纯色虚化背景或同色系环境',
      props: ['花朵', '水滴', '昆虫'],
      bestTime: '上午 09:00-11:00 柔光时段',
      tips: [
        '使用手动对焦精准控制焦点',
        '保持稳定，建议使用三脚架',
        '收小光圈保证足够景深'
      ],
      lightDirectionAngle: 45,
      shootingDistanceM: 0.2,
      bestTimeFrom: '09:00',
      bestTimeTo: '11:00'
    },
    relatedCategory: 'macro'
  },
  {
    id: 'night',
    name: '夜景',
    icon: 'ph-moon',
    description: '霓虹光影，赛博氛围',
    cameraSuggestion: {
      nightMode: true,
      iso: 800,
      shutterSpeed: '1/30',
      aperture: 1.8,
      whiteBalance: 'daylight',
      whiteBalanceK: 5500
    },
    postSuggestion: {
      lut: 'cyberpunk',
      color: { contrast: 20 },
      vignette: 20
    },
    sceneGuide: {
      lightDirection: '利用环境光源（霓虹灯、路灯、橱窗灯）',
      shootingDistance: '2-4m 人像',
      background: '霓虹招牌、车流光轨、城市天际线',
      props: ['透明雨伞', '反光镜面', '发光道具'],
      bestTime: '夜晚 19:00-23:00',
      tips: [
        '开启夜景模式提升暗部细节',
        '寻找霓虹灯作为轮廓光或发丝光',
        '注意快门速度避免手抖'
      ],
      lightDirectionAngle: 180,
      shootingDistanceM: 3,
      bestTimeFrom: '19:00',
      bestTimeTo: '23:00'
    },
    relatedCategory: 'night'
  },
  {
    id: 'food',
    name: '美食',
    icon: 'ph-fork-knife',
    description: '诱人色泽，俯拍构图',
    cameraSuggestion: {
      whiteBalance: 'tungsten',
      whiteBalanceK: 3200,
      photographicStyle: 'warm',
      aperture: 2.8
    },
    postSuggestion: {
      lut: 'warm_film',
      color: { saturation: 15 },
      sharpen: 10
    },
    sceneGuide: {
      lightDirection: '侧光或逆光（突出食物质感）',
      shootingDistance: '30-50cm 俯拍或 45 度',
      background: '木质桌面、大理石、纯色餐布',
      props: ['餐具', '餐巾', '装饰花草'],
      bestTime: '白天自然光 11:00-14:00',
      tips: [
        '注意白平衡让美食色彩还原自然',
        '俯拍展示全貌，45 度展示层次',
        '加入手部动作增加生活感'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 0.4,
      bestTimeFrom: '11:00',
      bestTimeTo: '14:00'
    },
    relatedCategory: 'food'
  },
  {
    id: 'home',
    name: '居家',
    icon: 'ph-house',
    description: '温馨日常，生活质感',
    cameraSuggestion: {
      whiteBalance: 'tungsten',
      whiteBalanceK: 3200,
      photographicStyle: 'warm',
      aperture: 2.0
    },
    postSuggestion: {
      lut: 'warm_film',
      color: { temperature: 15 }
    },
    sceneGuide: {
      lightDirection: '窗边柔光或室内暖灯',
      shootingDistance: '1-3m 生活场景',
      background: '沙发、床铺、书架、绿植角落',
      props: ['抱枕', '毛毯', '马克杯', '书本'],
      bestTime: '上午 09:00-11:00 或下午 15:00-17:00',
      tips: [
        '保持画面简洁，突出居家温馨氛围',
        '利用窗光营造柔和明暗过渡',
        '大光圈虚化背景杂物'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 2,
      bestTimeFrom: '09:00',
      bestTimeTo: '11:00'
    },
    relatedCategory: 'still-life'
  },
  {
    id: 'sunset',
    name: '黄昏',
    icon: 'ph-sunset',
    description: '逆光剪影，暖调氛围',
    cameraSuggestion: {
      whiteBalance: 'shade',
      whiteBalanceK: 7500,
      photographicStyle: 'warm',
      aperture: 5.6
    },
    postSuggestion: {
      lut: 'twilight',
      color: { temperature: 30, saturation: 10 }
    },
    sceneGuide: {
      lightDirection: '逆光（太阳位于主体正后方）',
      shootingDistance: '3-8m 剪影或半身',
      background: '落日、晚霞、地平线、剪影前景',
      props: ['草帽', '气球', '雨伞'],
      bestTime: '黄昏 17:30-19:00（日落前后 30 分钟）',
      tips: [
        '对天空测光锁定，拍摄人物剪影',
        '利用前景增加画面纵深',
        '黄金时刻色温最暖，抓紧时间'
      ],
      lightDirectionAngle: 180,
      shootingDistanceM: 5,
      bestTimeFrom: '17:30',
      bestTimeTo: '19:00'
    },
    relatedCategory: 'landscape'
  },
  {
    id: 'forest',
    name: '森林',
    icon: 'ph-tree',
    description: '通透绿意，自然光影',
    cameraSuggestion: {
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      photographicStyle: 'standard',
      aperture: 5.6
    },
    postSuggestion: {
      lut: 'fuji',
      color: { vibrance: 10 }
    },
    sceneGuide: {
      lightDirection: '侧光或顶光穿透树叶（丁达尔效应）',
      shootingDistance: '2-5m 人像或环境',
      background: '树林、蕨类、苔藓、林间小径',
      props: ['野餐垫', '篮子', '花束'],
      bestTime: '上午 08:00-11:00 光线通透',
      tips: [
        '寻找光线穿透树叶的光斑',
        '使用绿色浓郁的 LUT 增强氛围',
        '低角度仰拍突出树冠'
      ],
      lightDirectionAngle: 90,
      shootingDistanceM: 3,
      bestTimeFrom: '08:00',
      bestTimeTo: '11:00'
    },
    relatedCategory: 'landscape'
  },
  {
    id: 'indoor',
    name: '室内',
    icon: 'ph-building',
    description: '柔和均匀，干净构图',
    cameraSuggestion: {
      whiteBalance: 'fluorescent',
      whiteBalanceK: 4000,
      photographicStyle: 'standard',
      aperture: 2.8
    },
    postSuggestion: {
      lut: 'pastel',
      color: { brightness: 5 }
    },
    sceneGuide: {
      lightDirection: '均匀柔光（避免强反差）',
      shootingDistance: '1.5-3m 人像或静物',
      background: '白墙、纯色背景纸、简约家具',
      props: ['书本', '花瓶', '装饰画'],
      bestTime: '全天（室内光线稳定）',
      tips: [
        '使用大光圈虚化背景突出主体',
        '注意色温准确性，避免偏色',
        '利用墙面反射光补光'
      ],
      lightDirectionAngle: 45,
      shootingDistanceM: 2,
      bestTimeFrom: '10:00',
      bestTimeTo: '16:00'
    },
    relatedCategory: 'still-life'
  }
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

- [ ] **Step 2: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。数据文件符合 ScenePreset 接口。

- [ ] **Step 3: 提交**

```bash
cd lumira-app
git add src/data/scenePresets.ts
git commit -m "feat(data): 新增 10 个场景预设数据源 SCENE_PRESETS + SCENE_TO_CATEGORY 映射"
```

---

### Task 3: filterRecipe.ts 扩展（6 个新色彩参数 CSS filter 映射）

**Files:**
- Modify: `lumira-app/src/utils/filterRecipe.ts`（`buildCssFilter` 函数内）

**Interfaces:**
- Consumes: `PostProcessColor` 的 6 个新可选字段（from Task 1）
- Produces: 扩展后的 `buildCssFilter` 函数，支持 highlights/shadows/blackPoint/clarity/vibrance/brilliance 的 CSS filter 渲染。Task 7 的 ParamPanel 场景 Tab 一键应用后视觉生效依赖此任务。

- [ ] **Step 1: 定位 buildCssFilter 函数中 temperature/tint 处理之后的位置**

Run: `cd lumira-app && grep -n "temperature\|tint\|systemFilter\|LUT\|filters.push" src/utils/filterRecipe.ts | head -30`

Expected: 找到 temperature/tint 的 `filters.push` 调用位置，在其后、systemFilter/LUT 处理之前插入新参数映射。

- [ ] **Step 2: 在 temperature/tint 之后追加 6 个新色彩参数映射**

在 `buildCssFilter` 函数中，找到处理 `post.color.temperature` 和 `post.color.tint` 的代码块之后，追加以下代码（注意：必须在 systemFilter 和 LUT 处理之前插入）：

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

- [ ] **Step 3: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。新字段为可选，`?? 0` 兜底安全。

- [ ] **Step 4: 提交**

```bash
cd lumira-app
git add src/utils/filterRecipe.ts
git commit -m "feat(filterRecipe): buildCssFilter 支持 highlights/shadows/blackPoint/clarity/vibrance/brilliance 6 个新色彩参数"
```

---

### Task 4: emptyTemplate.ts 更新（补全新字段默认值）

**Files:**
- Modify: `lumira-app/src/utils/emptyTemplate.ts`

**Interfaces:**
- Consumes: Task 1 扩展后的类型
- Produces: 更新后的 `createEmptyTemplate()`，返回包含所有新字段的完整对象。Task 6 的 capture/index.vue 接收 scenePreset 时依赖此函数构建基础模板。

- [ ] **Step 1: 在 camera 对象中追加 7 个新字段默认值**

在 `emptyTemplate.ts` 的 `camera` 对象中，在 `hdr: false` 之后追加：

```typescript
      // 新增字段默认值
      aperture: null,
      nightMode: false,
      nightExposureTime: 3,
      livePhoto: false,
      gridEnabled: false,
      aeAfLock: false,
      lensCorrection: false
```

- [ ] **Step 2: 在 sceneGuide 对象中追加 5 个新字段默认值**

在 `sceneGuide` 对象中，在 `tips: []` 之后追加：

```typescript
      presetId: undefined,
      lightDirectionAngle: 0,
      shootingDistanceM: 2,
      bestTimeFrom: '09:00',
      bestTimeTo: '17:00'
```

- [ ] **Step 3: 在 postProcess.color 对象中追加 6 个新字段默认值**

在 `postProcess.color` 对象中，在 `tint: 0` 之后追加：

```typescript
        highlights: 0,
        shadows: 0,
        blackPoint: 0,
        clarity: 0,
        vibrance: 0,
        brilliance: 0
```

- [ ] **Step 4: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 5: 提交**

```bash
cd lumira-app
git add src/utils/emptyTemplate.ts
git commit -m "feat(emptyTemplate): createEmptyTemplate 补全 camera/sceneGuide/postProcess.color 新字段默认值"
```

---

### Task 5: scene-guide.vue 重写（数据驱动 + 完整小贴士 + 跳转带参）

**Files:**
- Modify: `lumira-app/src/pages/capture/scene-guide.vue`

**Interfaces:**
- Consumes: `SCENE_PRESETS`、`SCENE_TO_CATEGORY`（from Task 2）、`ScenePreset`（from Task 1）
- Produces: 重写后的 scene-guide.vue，显示 10 个场景、点击展示完整小贴士卡片、跳转携带 scenePreset 参数。Task 6 的 capture/index.vue 接收的 scenePreset 参数由此页面传递。

- [ ] **Step 1: 替换 script setup 块（删除硬编码数据，改用 SCENE_PRESETS）**

将 `scene-guide.vue` 的 `<script setup lang="ts">` 块整体替换为：

```typescript
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { SCENE_PRESETS, SCENE_TO_CATEGORY } from '@/data/scenePresets'
import type { ScenePreset } from '@/types/template'

const tab = ref('common')

const tabList = [
  { label: '常用场景', value: 'common' },
  { label: '收藏场景', value: 'fav' },
  { label: '推荐场景', value: 'recommend' }
]

// 前 8 个作为「我的场景」，后 2 个作为「推荐场景」
const myScenes = ref<ScenePreset[]>(SCENE_PRESETS.slice(0, 8))
const recommendScenes = ref<ScenePreset[]>(SCENE_PRESETS.slice(8))

const selectedPreset = ref<ScenePreset | null>(null)

onLoad((options) => {
  if (options?.scene) {
    const preset = SCENE_PRESETS.find(p => p.id === options.scene)
    if (preset) {
      selectedPreset.value = preset
      tab.value = 'recommend'
    }
  }
})

const back = () => uni.navigateBack()

const onAdd = () => {
  uni.showToast({ title: '新建场景', icon: 'none' })
}

const onMoreRecommend = () => {
  uni.showToast({ title: '更多推荐', icon: 'none' })
}

const onSceneTap = (preset: ScenePreset) => {
  selectedPreset.value = preset
}

const goTemplates = () => {
  if (!selectedPreset.value) return
  const cat = SCENE_TO_CATEGORY[selectedPreset.value.id]
  uni.navigateTo({
    url: `/pages/templates/index?scene=${selectedPreset.value.id}&category=${cat}`
  })
}

const goCapture = () => {
  if (!selectedPreset.value) return
  uni.navigateTo({
    url: `/pages/capture/index?scenePreset=${selectedPreset.value.id}`
  })
}
```

- [ ] **Step 2: 调整「我的场景」列表项模板（移除缩略图，字段绑定改为 preset.xxx）**

将 template 中「我的场景」的 `<view class="scene-item" v-for="s in myScenes"...>` 块替换为：

```html
        <view
          class="scene-item"
          v-for="preset in myScenes"
          :key="preset.id"
          @click="onSceneTap(preset)"
        >
          <view class="scene-item-icon">
            <text class="ph scene-icon" :class="preset.icon"></text>
          </view>
          <view class="scene-item-text">
            <text class="scene-item-title">{{ preset.name }}</text>
            <text class="scene-item-desc">{{ preset.description }}</text>
          </view>
          <text class="ph ph-caret-right scene-item-arrow"></text>
        </view>
```

- [ ] **Step 3: 调整「推荐场景」列表项模板（字段绑定改为 preset.xxx）**

将 template 中「推荐场景」的 `<view class="scene-item" v-for="r in recommendScenes"...>` 块替换为：

```html
        <view
          class="scene-item"
          v-for="preset in recommendScenes"
          :key="preset.id"
          @click="onSceneTap(preset)"
        >
          <view class="scene-item-icon icon-bg-green">
            <text class="ph scene-icon" :class="preset.icon"></text>
          </view>
          <view class="scene-item-text">
            <text class="scene-item-title">{{ preset.name }}</text>
            <text class="scene-item-desc">{{ preset.description }}</text>
          </view>
          <view class="scene-badge badge-brand">
            <text class="scene-badge-text">推荐</text>
          </view>
          <text class="ph ph-caret-right scene-item-arrow"></text>
        </view>
```

- [ ] **Step 4: 替换小贴士卡片为完整场景指南（数据源改为 selectedPreset.sceneGuide）**

将 template 中 `<view v-if="currentTip" class="section-pad fade-up">` 整块替换为：

```html
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
          <view v-for="(tip, i) in selectedPreset.sceneGuide.tips" :key="'tip-'+i" class="tip-detail-row">
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

- [ ] **Step 5: 删除不再使用的 CSS 类（scene-item-thumb）并在 scoped 样式中新增 prop-tag-list/prop-tag-text 类**

在 `<style lang="scss" scoped>` 中：

1. 删除 `.scene-item-thumb` 类定义（约 394-399 行）
2. 在 `.tip-detail-row-text` 类之后新增：

```scss
.prop-tag-list {
  flex: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}

.prop-tag {
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
}

.prop-tag-text {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}
```

- [ ] **Step 6: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 7: 提交**

```bash
cd lumira-app
git add src/pages/capture/scene-guide.vue
git commit -m "feat(scene-guide): 重写为数据驱动 + 完整场景小贴士 + 跳转携带 scenePreset 参数"
```

---

### Task 6: capture/index.vue 接收 scenePreset 参数

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`（onLoad 函数内）

**Interfaces:**
- Consumes: `SCENE_PRESETS`（from Task 2）、`createEmptyTemplate`（from Task 4）
- Produces: capture/index.vue 支持接收 `?scenePreset=id` URL 参数，构建应用了场景预设的 editableTemplate。scene-guide.vue 的「开始拍摄」按钮跳转依赖此任务。

- [ ] **Step 1: 在 capture/index.vue 顶部新增导入**

在 `<script setup lang="ts">` 的现有 import 区域新增：

```typescript
import { SCENE_PRESETS } from '@/data/scenePresets'
import { createEmptyTemplate } from '@/utils/emptyTemplate'
```

注意：若 `createEmptyTemplate` 已被导入则跳过此行；若 `editableTemplate` 已存在且类型为 `PhotoTemplate`，则直接复用。

- [ ] **Step 2: 定位 onLoad 函数**

Run: `cd lumira-app && grep -n "onLoad\|currentTemplateId\|scenePreset\|editableTemplate" src/pages/capture/index.vue`

Expected: 找到 onLoad 函数（约 357 行）、currentTemplateId 赋值（约 359 行）、editableTemplate 引用（约 198 行附近）。

- [ ] **Step 3: 在 onLoad 中新增 scenePreset 分支**

在 onLoad 函数内，现有 `if (options?.templateId)` 分支之后、`loadRecent()` 之前，新增 `else if (options?.scenePreset)` 分支：

```typescript
  } else if (options?.scenePreset) {
    // 场景预设模式：基于 preset 创建可编辑模板
    const preset = SCENE_PRESETS.find(p => p.id === options.scenePreset)
    if (preset) {
      const tpl = createEmptyTemplate()
      tpl.sceneGuide.presetId = preset.id
      Object.assign(tpl.sceneGuide, preset.sceneGuide)
      Object.assign(tpl.camera, preset.cameraSuggestion)
      // postSuggestion 单独处理 color 子对象，避免整体替换
      if (preset.postSuggestion.color) {
        Object.assign(tpl.postProcess.color, preset.postSuggestion.color)
      }
      const { color: _omitColor, ...restPost } = preset.postSuggestion
      Object.assign(tpl.postProcess, restPost)
      editableTemplate.value = tpl
    }
  }
```

注意：需确认 `editableTemplate` 的变量名与现有代码一致（若不同则用实际变量名替换）。`_omitColor` 前缀下划线表示故意未使用。

- [ ] **Step 4: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 5: 提交**

```bash
cd lumira-app
git add src/pages/capture/index.vue
git commit -m "feat(capture): onLoad 接收 scenePreset 参数并应用场景预设到 editableTemplate"
```

---

### Task 7: ParamPanel 场景 Tab 重构（预设选择 + 一键应用 + 自定义参数）

**Files:**
- Modify: `lumira-app/src/components/ParamPanel.vue`

**Interfaces:**
- Consumes: `SCENE_PRESETS`（from Task 2）、`ScenePreset`/`ScenePresetId`（from Task 1）、`getLutLabel`（现有 filterRecipe 导出）、`AdvancedSection` 组件（现有）、`cloneTemplate` 函数（现有）、`advancedOpen` ref（现有，需新增 sceneCustom key）
- Produces: ParamPanel 场景 Tab 支持选择 10 个场景预设、一键应用场景参数、预览参数建议、自定义光线方向与拍摄距离。

- [ ] **Step 1: 新增 import 与 photographicStyleLabel 辅助函数**

在 ParamPanel.vue 的 `<script setup lang="ts">` 顶部 import 区，修改现有 import 行：

```typescript
import type { PhotoTemplate, WhiteBalance, FlashMode, FocusMode, LutPreset, SystemFilter, LensType, PhotographicStyle, OverlayType, GridType, ScenePresetId } from '@/types/template'
import { getSystemFilterOptions, getLutOptions, getLutLabel } from '@/utils/filterRecipe'
import AdvancedSection from '@/components/AdvancedSection.vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
```

在 `photographicStyleOptions` 数组定义之后，新增 label 辅助函数：

```typescript
const photographicStyleLabel = (style: PhotographicStyle | undefined): string => {
  if (!style) return '标准'
  const opt = photographicStyleOptions.find(o => o.value === style)
  return opt ? opt.label : '标准'
}
```

- [ ] **Step 2: 在 advancedOpen ref 中新增 sceneCustom key**

将 `advancedOpen` ref 定义修改为：

```typescript
const advancedOpen = ref<Record<string, boolean>>({
  camera: false,
  composition: false,
  pose: false,
  post: false,
  sceneCustom: false
})
```

- [ ] **Step 3: 新增场景预设相关脚本逻辑**

在 `updatePost` 函数之后（或 `onSelectSystemFilter` 之前），新增场景预设相关逻辑：

```typescript
const scenePresets = SCENE_PRESETS

const currentScenePreset = computed(() => {
  const id = props.template.sceneGuide.presetId
  return id ? scenePresets.find(p => p.id === id) : null
})

const onSelectScenePreset = (id: ScenePresetId) => {
  if (props.rawMode) return
  const tpl = cloneTemplate()
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
  Object.assign(tpl.camera, preset.cameraSuggestion)
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

- [ ] **Step 4: 替换场景 Tab 模板（336-371 行的只读场景 Tab）**

将 ParamPanel.vue 中 `<!-- 场景 Tab -->` 开始到 `<!-- 姿势 Tab -->` 之前的整块替换为：

```html
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
              <text class="param-value">{{ wbLabel(currentScenePreset.cameraSuggestion.whiteBalance || 'daylight', currentScenePreset.cameraSuggestion.whiteBalanceK ?? 5500) }}</text>
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
          <AdvancedSection
            title="自定义场景参数"
            :open="advancedOpen.sceneCustom"
            @update:open="advancedOpen.sceneCustom = $event"
          >
            <view class="param-row">
              <text class="param-label">光线方向</text>
              <view class="pill-list-inline">
                <view
                  v-for="opt in lightDirectionOptions"
                  :key="opt.value"
                  class="pill"
                  :class="{ active: template.sceneGuide.lightDirectionAngle === opt.value }"
                  @click="updateSceneGuide('lightDirectionAngle', opt.value)"
                >
                  <text>{{ opt.label }}</text>
                </view>
              </view>
            </view>
            <view class="slider-block">
              <view class="slider-header">
                <text class="param-label">拍摄距离</text>
                <text class="slider-value">{{ template.sceneGuide.shootingDistanceM || 2 }}m</text>
              </view>
              <slider
                class="param-slider"
                :value="template.sceneGuide.shootingDistanceM || 2"
                :min="0.1"
                :max="10"
                :step="0.1"
                activeColor="var(--color-brand)"
                backgroundColor="var(--color-divider)"
                block-color="var(--color-brand)"
                @change="(e: any) => updateSceneGuide('shootingDistanceM', e.detail.value)"
              />
            </view>
          </AdvancedSection>
        </view>
```

- [ ] **Step 5: 在 scoped 样式中新增场景预设相关 CSS 类**

在 ParamPanel.vue 的 `<style lang="scss" scoped>` 中（`.tips-text` 类之后或合适位置），新增：

```scss
.scene-preset-section {
  margin-bottom: 24rpx;
}

.scene-preset-scroll {
  white-space: nowrap;
  margin-top: 16rpx;
}

.scene-preset-list {
  display: inline-flex;
  gap: 16rpx;
  padding: 4rpx;
}

.scene-preset-card {
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  padding: 20rpx 24rpx;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
  border: 2rpx solid transparent;
  min-width: 120rpx;
}

.scene-preset-card.active {
  border-color: var(--color-brand);
  background-color: rgba(var(--color-brand-rgb), 0.12);
}

.scene-preset-icon-wrap {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background-color: var(--color-canvas-deep);
  display: flex;
  align-items: center;
  justify-content: center;
}

.scene-preset-icon {
  font-size: 36rpx;
  color: var(--color-text-primary);
}

.scene-preset-card.active .scene-preset-icon {
  color: var(--color-brand);
}

.scene-preset-name {
  font-size: 24rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.scene-preset-card.active .scene-preset-name {
  color: var(--color-brand);
}

.scene-apply-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  padding: 24rpx;
  margin: 24rpx 0;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #ffffff;
  font-size: 28rpx;
  font-weight: 500;
}

.scene-apply-btn:active {
  transform: scale(0.98);
  opacity: 0.9;
}

.scene-apply-btn .ph {
  font-size: 32rpx;
}

.scene-suggestion-block {
  padding: 24rpx;
  margin-bottom: 24rpx;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
}
```

注意：`--color-brand-rgb` 若不存在，则将 `.scene-preset-card.active` 的 background-color 改为 `rgba(255, 200, 120, 0.12)`（暖色调半透明，与品牌色协调）。先尝试用变量，若 type-check 或运行时报错再改硬编码。

- [ ] **Step 6: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。若 `--color-brand-rgb` 报错则改用硬编码颜色值。

- [ ] **Step 7: 提交**

```bash
cd lumira-app
git add src/components/ParamPanel.vue
git commit -m "feat(ParamPanel): 场景 Tab 重构 - 预设选择 + 一键应用 + 参数预览 + 自定义场景参数"
```

---

### Task 8: 最终类型检查与集成验证

**Files:**
- 无文件修改，仅验证

- [ ] **Step 1: 运行完整类型检查**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。验证所有 7 个任务的改动组合后类型安全。

- [ ] **Step 2: 检查 git 状态确认所有改动已提交**

Run: `cd lumira-app && git status`
Expected: working tree clean，所有改动已提交。

- [ ] **Step 3: 查看提交历史确认 7 个提交**

Run: `cd lumira-app && git log --oneline -8`
Expected: 看到 Task 1-7 的 7 个提交 + 之前的 design doc 提交。

- [ ] **Step 4: 手动验证清单（向用户报告）**

向用户报告以下手动验证项，建议在 H5 开发模式下验证：

1. **scene-guide.vue**：
   - 10 个场景显示（8 我的 + 2 推荐）
   - 点击场景项 → 小贴士卡片显示完整 6 字段（光线/距离/背景/时间/道具/贴士）
   - 卡片「开始拍摄」→ 跳转拍摄页，相机/后期参数已应用
   - 卡片「查看模板」→ 跳转模板列表带 scene + category 参数
2. **capture/index.vue**：接收 `?scenePreset=night` → 应用夜景预设（nightMode=true, ISO=800, cyberpunk LUT）
3. **ParamPanel 场景 Tab**：
   - 10 个预设横向滚动可选
   - 选中预设 → 参数预览区显示白平衡/风格/光圈/LUT
   - 点「一键应用」→ toast 提示 + 滤镜实时变化
   - 自定义场景参数折叠区 → 光线方向 pill + 拍摄距离 slider 可调
   - rawMode 下所有交互禁用
