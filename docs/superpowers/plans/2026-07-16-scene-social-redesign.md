# 场景社交化重构 + 模板分层分类 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将场景模块从"参数调整工具"重构为"场景灵感与氛围引擎"，新增照片统计/成就/排行/标签/组合功能，并为模板增加三层分类体系。

**Architecture:** 类型层先行（重构 ScenePreset、扩展 TemplateMeta），数据层迁移（10 旧预设 + 12 新预设、12 模板加 classification），composable 层扩展（useSceneManager 加统计/成就/排行，新增 useTagManager/useShootKit），UI 层重构（scene-detail 新建、scene-guide/scene-manage/preview/capture/templates 重构）。

**Tech Stack:** uni-app (Vue 3 + TypeScript), SCSS (rpx), localStorage (uni.getStorageSync/setStorageSync), Phosphor Icons, vue-tsc 类型检查

## Global Constraints

- 所有页面使用 uni-app 组件（`<view>` 而非 `<div>`，`<text>` 而非 `<span>`，`<image>` 而非 `<img>`）
- CSS 单位使用 rpx 而非 px
- 所有图片资源来自 picsum.photos（格式：`https://picsum.photos/seed/<seed>/<w>/<h>`）
- 标题栏文字不居中对齐
- Tab 页固定底部 `position: fixed; z-index: 900`
- 全局工具类放 App.vue `<style>`（非 scoped，纯 CSS）
- scoped 样式可使用 `<style lang="scss" scoped>`，SCSS 变量通过 uni.scss 自动注入
- SCSS 变量在 template 内联 style 中不生效，需用具体颜色值或 class
- `<image>` 组件不支持 `:alt` 属性
- 所有样式只使用 class 选择器，不用标签选择器
- scroll-x 内部容器需 `display: inline-flex`，scroll-view 需 `white-space: nowrap`
- pill 元素需 `display: inline-flex; align-items: center;`
- CSS 自定义属性 `var(--xxx)` 在 uni-app scoped 样式中不生效，需使用 SCSS 变量或具体颜色值
- Google Fonts 通过 `<link>` 标签在 HTML 中引入，不用 CSS @import
- 验证命令：`cd lumira-app && npm run type-check`（必须零错误）
- 模型选择：类型/数据/composable 任务用标准模型；UI 重构任务用标准模型；最终验证用最 capable 模型

---

## 文件结构

### 新增文件

| 文件 | 职责 |
|------|------|
| `lumira-app/src/composables/useTagManager.ts` | 标签 CRUD + 多标签筛选（场景/模板） |
| `lumira-app/src/composables/useShootKit.ts` | 拍摄组合（场景+模板）CRUD + 使用记录 |
| `lumira-app/src/pages/capture/scene-detail.vue` | 场景详情页（示例图/氛围/滤镜/贴士/成就） |
| `lumira-app/src/components/SceneFilterBadge.vue` | 滤镜徽章（显示 LUT 名 + reason） |
| `lumira-app/src/components/SceneAchievementCard.vue` | 成就卡片（照片数/等级/进度/排行） |
| `lumira-app/src/components/TagSelector.vue` | 标签选择器（多选 + 创建） |
| `lumira-app/src/components/KitCard.vue` | 组合卡片（场景+模板信息 + 使用次数） |
| `lumira-app/src/components/CategoryNav.vue` | 分类导航（可复用，支持多层） |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `lumira-app/src/types/template.ts` | ScenePreset 重构 + 新类型（SceneCategory/SceneFilter/TemplateClassification/UserTag/ShootKit/LocalPhoto/SceneAchievement） |
| `lumira-app/src/data/scenePresets.ts` | 10 旧预设迁移 + 12 新预设 + 分类常量 |
| `lumira-app/src/data/templates/*.ts` | 12 模板加 classification 字段 |
| `lumira-app/src/data/templates/index.ts` | 保持导出不变 |
| `lumira-app/src/composables/useSceneManager.ts` | 加分类/照片统计/成就/排行 + 旧数据迁移 |
| `lumira-app/src/composables/useTemplate.ts` | 加三层分类 computed + 标签筛选 |
| `lumira-app/src/components/ScenePresetView.vue` | 适配新 ScenePreset 结构（显示 vibe/照片数/成就） |
| `lumira-app/src/pages/capture/scene-guide.vue` | 重构：两层分类 + 标签筛选 + 卡片显示统计 |
| `lumira-app/src/pages/capture/scene-manage.vue` | 加"我的组合" Tab + 表单字段更新 |
| `lumira-app/src/pages/capture/preview.vue` | 场景选择器改真实数据 + 保存 LocalPhoto |
| `lumira-app/src/pages/capture/index.vue` | 组合快速入口 + 自动场景标记 |
| `lumira-app/src/pages/templates/index.vue` | 三层分类 + 标签筛选 |
| `lumira-app/src/pages.json` | 新增 scene-detail 路由 |
| `lumira-app/src/pages/home/index.vue` | 场景卡片显示照片数 |
| `lumira-app/src/pages/inspiration/index.vue` | 场景卡片显示照片数 |

---

## Task 1: 类型定义重构

**Files:**
- Modify: `lumira-app/src/types/template.ts`

**Interfaces:**
- Consumes: 现有 ScenePreset、PhotoTemplate、SceneGuide、CameraParams、PostProcess、LutPreset、SystemFilter、Target、CustomSceneId、CustomScenePreset、AnyScene
- Produces: 新 SceneCategory、SceneStyle、SceneCategoryGroup、SceneFilter、重构后 ScenePreset、新 ScenePresetId、重构后 CustomScenePreset、TemplateClassification、扩展 TemplateMeta、UserTag、ShootKit、LocalPhoto、SceneAchievement、SCENE_LEVELS 常量

**说明:** 此任务是所有后续任务的基础。ScenePreset 结构变更较大（删除 cameraSuggestion/postSuggestion，新增 filter/vibe/exampleImages 等），会导致依赖旧字段的代码出现类型错误，这些错误将在后续任务中逐个修复。

- [ ] **Step 1: 在 types/template.ts 顶部新增场景分类相关类型**

在 `export type Target = ...` 之后新增：

```typescript
/* ── 场景分类（两层结构） ── */
export type SceneCategory = 'light' | 'outdoor' | 'indoor' | 'mood'

export interface SceneStyle {
  id: string
  name: string
  category: SceneCategory
}

export interface SceneCategoryGroup {
  category: SceneCategory
  name: string
  icon: string
  styles: SceneStyle[]
}
```

- [ ] **Step 2: 更新 ScenePresetId**

将现有的 `export type ScenePresetId = ...`（10 个值）替换为新的 18 个值：

```typescript
export type ScenePresetId =
  | 'cafe-window' | 'library-quiet' | 'home-cozy'
  | 'sunset-silhouette' | 'golden-rim-portrait'
  | 'night-street' | 'bar-neon' | 'convenience-store'
  | 'seaside-beach' | 'seaside-rocks'
  | 'forest-bamboo' | 'forest-maple'
  | 'urban-rooftop' | 'urban-subway'
  | 'bedroom-morning' | 'kitchen-cooking'
  | 'candle-warm' | 'rainy-window'
```

- [ ] **Step 3: 新增 SceneFilter 类型**

在 ScenePresetId 之后新增：

```typescript
/** 场景氛围滤镜配置 */
export interface SceneFilter {
  lut: LutPreset
  systemFilter?: SystemFilter
  /** 选用该滤镜的理由（情绪化说明） */
  reason: string
}
```

- [ ] **Step 4: 重构 ScenePreset 接口**

将现有 `export interface ScenePreset { ... }` 替换为：

```typescript
/** 场景预设（氛围引擎定位） */
export interface ScenePreset {
  id: ScenePresetId
  name: string
  icon: string

  /** 两层分类 */
  category: SceneCategory
  style: string

  /** 氛围滤镜（唯一保留的"参数"） */
  filter: SceneFilter

  /** 情绪化主标题 */
  vibe: string
  /** 场景描述：氛围 + 光线 + 环境 */
  description: string
  /** 示例图 1-3 张（picsum.photos） */
  exampleImages: string[]
  /** 拍摄小贴士 */
  tips: string[]
  /** 出片地点建议 */
  whereToShoot: string
  /** 最佳拍摄时间 */
  bestTime: string

  /** 兼容保留：场景指南文字 */
  sceneGuide: Omit<SceneGuide, 'presetId'>
  relatedCategory: Target

  /** 推荐标签 ids（预设自带） */
  recommendedTagIds: string[]
}
```

- [ ] **Step 5: 更新 CustomScenePreset**

将现有 `export interface CustomScenePreset extends Omit<ScenePreset, 'id'> { ... }` 更新为：

```typescript
export interface CustomScenePreset extends Omit<ScenePreset, 'id'> {
  id: CustomSceneId
  creator: 'user'
  createdAt: number
  updatedAt: number
  /** 用户自定义标签 ids */
  tagIds: string[]
}
```

（AnyScene 类型不变：`export type AnyScene = ScenePreset | CustomScenePreset`）

- [ ] **Step 6: 新增 TemplateClassification 并扩展 TemplateMeta**

在 `TemplateMeta` 接口之前新增：

```typescript
/** 模板三层分类 */
export interface TemplateClassification {
  type: Target
  style: string
  method: string
}
```

将现有 `export interface TemplateMeta { ... }` 替换为：

```typescript
export interface TemplateMeta {
  id: string
  name: string
  author: string
  version: string
  category: Target                    // 保留旧字段（向后兼容）
  classification: TemplateClassification  // 新增三层分类
  tags: string[]
  /** 用户自定义标签 ids */
  tagIds: string[]
  price: number
  cover: string
  description: string
  referenceSource: string
}
```

- [ ] **Step 7: 新增 UserTag、ShootKit、LocalPhoto、SceneAchievement 类型**

在文件末尾（AnyScene 之后）新增：

```typescript
/* ── 用户自定义标签 ── */
export interface UserTag {
  id: string
  name: string
  type: 'scene' | 'template' | 'both'
  color?: string
  createdAt: number
}

/* ── 拍摄组合 ── */
export interface ShootKit {
  id: string
  name: string
  sceneId: ScenePresetId | CustomSceneId
  templateId: string
  overrides?: {
    camera?: Partial<CameraParams>
    postProcess?: Partial<PostProcess>
  }
  createdAt: number
  updatedAt: number
  useCount: number
  lastUsedAt?: number
}

/* ── 本地照片记录 ── */
export interface LocalPhoto {
  id: string
  dataUrl: string
  sceneId: ScenePresetId | CustomSceneId | null
  templateId?: string
  kitId?: string
  mood?: string
  lut?: LutPreset
  createdAt: number
}

/* ── 场景成就 ── */
export interface SceneAchievement {
  sceneId: string
  level: number
  levelName: string
  photoCount: number
  nextLevelCount: number
}

export const SCENE_LEVELS = [
  { level: 1, name: '初探', threshold: 1 },
  { level: 2, name: '熟悉', threshold: 5 },
  { level: 3, name: '达人', threshold: 15 },
  { level: 4, name: '专家', threshold: 30 },
  { level: 5, name: '大师', threshold: 50 },
] as const
```

- [ ] **Step 8: 验证类型定义**

Run: `cd lumira-app && npm run type-check`

Expected: 会出现大量错误（因为旧字段 cameraSuggestion/postSuggestion 被删除，新字段 classification/tagIds 未在数据中添加），这些是预期的，将在后续任务中修复。**仅确认 types/template.ts 本身无语法错误**（即错误来自其他文件引用旧字段，而非 types/template.ts 内部语法问题）。

- [ ] **Step 9: Commit**

```bash
cd lumira-app && git add src/types/template.ts
git commit -m "refactor(types): 场景模块类型重构 + 模板分类 + 标签/组合/照片/成就类型"
```

---

## Task 2: 场景预设数据迁移 + 新增

**Files:**
- Modify: `lumira-app/src/data/scenePresets.ts`

**Interfaces:**
- Consumes: 新 ScenePreset、ScenePresetId、SceneCategory、SceneFilter、SceneCategoryGroup、SceneStyle（来自 Task 1）
- Produces: `SCENE_PRESETS: ScenePreset[]`（18 个预设）、`SCENE_TO_CATEGORY: Record<ScenePresetId, Target>`、`SCENE_CATEGORIES: SceneCategoryGroup[]`、`SCENE_STYLES: SceneStyle[]`

**说明:** 完全重写 scenePresets.ts。旧 ID（cafe/street/beach/macro/night/food/home/sunset/forest/indoor）被新 ID 替换。macro/food 废弃（归入模板分类）。

- [ ] **Step 1: 重写 scenePresets.ts 的分类常量和导出结构**

文件顶部结构：

```typescript
import type { ScenePreset, ScenePresetId, SceneCategory, SceneStyle, SceneCategoryGroup, Target } from '@/types/template'

/** 场景风格列表 */
export const SCENE_STYLES: SceneStyle[] = [
  { id: 'window-light', name: '窗光', category: 'light' },
  { id: 'sunset-backlight', name: '日落逆光', category: 'light' },
  { id: 'neon', name: '霓虹', category: 'light' },
  { id: 'candle', name: '烛光', category: 'light' },
  { id: 'seaside', name: '海边', category: 'outdoor' },
  { id: 'forest', name: '森林', category: 'outdoor' },
  { id: 'urban', name: '城市', category: 'outdoor' },
  { id: 'home', name: '居家', category: 'indoor' },
  { id: 'cafe', name: '咖啡馆店铺', category: 'indoor' },
  { id: 'studio', name: '影棚', category: 'indoor' },
  { id: 'healing', name: '治愈', category: 'mood' },
  { id: 'lonely', name: '孤独', category: 'mood' },
]

/** 场景大类聚合 */
export const SCENE_CATEGORIES: SceneCategoryGroup[] = [
  { category: 'light', name: '光线氛围', icon: 'ph-sun', styles: SCENE_STYLES.filter(s => s.category === 'light') },
  { category: 'outdoor', name: '室外环境', icon: 'ph-mountains', styles: SCENE_STYLES.filter(s => s.category === 'outdoor') },
  { category: 'indoor', name: '室内空间', icon: 'ph-house', styles: SCENE_STYLES.filter(s => s.category === 'indoor') },
  { category: 'mood', name: '情绪氛围', icon: 'ph-heart', styles: SCENE_STYLES.filter(s => s.category === 'mood') },
]
```

- [ ] **Step 2: 编写 18 个场景预设**

每个预设使用以下模板结构（以 cafe-window 为例）：

```typescript
const cafeWindow: ScenePreset = {
  id: 'cafe-window',
  name: '咖啡馆',
  icon: 'ph-coffee',
  category: 'indoor',
  style: 'cafe',
  filter: {
    lut: 'warm_film',
    systemFilter: 'vivid_warm',
    reason: '色温偏暖 +20，对比度 +10，像被午后的光晒软了',
  },
  vibe: '慵懒午后，把光调成蜜糖色',
  description: '适合下午 2-5 点，当阳光斜照进落地窗，整个世界都慢了下来。咖啡馆的木质桌椅、暖色墙面和飘散的咖啡香，构成最治愈的拍摄空间。',
  exampleImages: [
    'https://picsum.photos/seed/scene-cafe-window-1/600/800',
    'https://picsum.photos/seed/scene-cafe-window-2/600/800',
    'https://picsum.photos/seed/scene-cafe-window-3/600/800',
  ],
  tips: [
    '让模特面朝窗户，利用柔光均匀照亮面部',
    '大光圈虚化背景，突出人物',
    '咖啡杯做前景更有氛围感',
  ],
  whereToShoot: '咖啡馆 / 图书馆 / 居家窗边',
  bestTime: '下午 14:00-17:00',
  sceneGuide: {
    lightDirection: '侧光 45°-90°（窗户自然光为主光源）',
    shootingDistance: '1.5-2.5m',
    background: '咖啡馆室内环境，虚化的吧台、书架或暖色墙面',
    props: ['咖啡杯', '书本', '绿植盆栽'],
    bestTime: '下午 14:00-17:00',
    tips: ['让模特面朝窗户', '大光圈虚化背景', '咖啡杯做前景'],
    lightDirectionAngle: 90,
    shootingDistanceM: 2,
    bestTimeFrom: '14:00',
    bestTimeTo: '17:00',
  },
  relatedCategory: 'portrait',
  recommendedTagIds: [],
}
```

完整 18 个预设列表（每个都要按上述结构编写，以下仅列 ID + 分类 + 风格 + 滤镜，内容字段需编写完整）：

1. `cafe-window` — indoor/cafe — warm_film + vivid_warm
2. `library-quiet` — indoor/cafe — fuji
3. `home-cozy` — indoor/home — warm_film
4. `sunset-silhouette` — light/sunset-backlight — cinematic
5. `golden-rim-portrait` — light/sunset-backlight — rouge
6. `night-street` — light/neon — cyberpunk
7. `bar-neon` — light/neon — cyberpunk
8. `convenience-store` — light/neon — twilight
9. `seaside-beach` — outdoor/seaside — pastel
10. `seaside-rocks` — outdoor/seaside — cinematic
11. `forest-bamboo` — outdoor/forest — fuji
12. `forest-maple` — outdoor/forest — vintage
13. `urban-rooftop` — outdoor/urban — cinematic
14. `urban-subway` — outdoor/urban — bw
15. `bedroom-morning` — indoor/home — mist
16. `kitchen-cooking` — indoor/home — warm_film
17. `candle-warm` — light/candle — sepia_classic
18. `rainy-window` — mood/healing — mist

- [ ] **Step 3: 导出 SCENE_PRESETS 数组和 SCENE_TO_CATEGORY 映射**

```typescript
export const SCENE_PRESETS: ScenePreset[] = [
  cafeWindow, libraryQuiet, homeCozy,
  sunsetSilhouette, goldenRimPortrait,
  nightStreet, barNeon, convenienceStore,
  seasideBeach, seasideRocks,
  forestBamboo, forestMaple,
  urbanRooftop, urbanSubway,
  bedroomMorning, kitchenCooking,
  candleWarm, rainyWindow,
]

export const SCENE_TO_CATEGORY: Record<ScenePresetId, Target> = {
  'cafe-window': 'portrait',
  'library-quiet': 'portrait',
  'home-cozy': 'still-life',
  'sunset-silhouette': 'portrait',
  'golden-rim-portrait': 'portrait',
  'night-street': 'night',
  'bar-neon': 'night',
  'convenience-store': 'street',
  'seaside-beach': 'landscape',
  'seaside-rocks': 'landscape',
  'forest-bamboo': 'landscape',
  'forest-maple': 'landscape',
  'urban-rooftop': 'landscape',
  'urban-subway': 'street',
  'bedroom-morning': 'still-life',
  'kitchen-cooking': 'food',
  'candle-warm': 'still-life',
  'rainy-window': 'still-life',
}
```

- [ ] **Step 4: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: scenePresets.ts 本身无错误。其他文件引用旧 ScenePresetId（如 'cafe'）会报错，这些在后续任务修复。

- [ ] **Step 5: Commit**

```bash
cd lumira-app && git add src/data/scenePresets.ts
git commit -m "feat(data): 场景预设迁移至氛围引擎结构 + 新增 12 个预设"
```

---

## Task 3: 模板分类增强

**Files:**
- Modify: `lumira-app/src/data/templates/sunset-silhouette.ts`
- Modify: `lumira-app/src/data/templates/cafe-portrait.ts`
- Modify: `lumira-app/src/data/templates/street-bw.ts`
- Modify: `lumira-app/src/data/templates/food-flat-lay.ts`
- Modify: `lumira-app/src/data/templates/night-cityscape.ts`
- Modify: `lumira-app/src/data/templates/golden-landscape.ts`
- Modify: `lumira-app/src/data/templates/indoor-still-life.ts`
- Modify: `lumira-app/src/data/templates/soft-portrait.ts`
- Modify: `lumira-app/src/data/templates/neon-portrait.ts`
- Modify: `lumira-app/src/data/templates/macro-flower.ts`
- Modify: `lumira-app/src/data/templates/film-vintage.ts`
- Modify: `lumira-app/src/data/templates/urban-architecture.ts`

**Interfaces:**
- Consumes: TemplateClassification、扩展后 TemplateMeta（来自 Task 1）
- Produces: 12 个模板的 meta.classification 和 meta.tagIds 字段

**说明:** 为每个模板的 `meta` 对象新增 `classification` 和 `tagIds` 字段。`category` 字段保留（向后兼容），值与 `classification.type` 一致。

- [ ] **Step 1: 为每个模板添加 classification 和 tagIds**

映射表：

| 模板 ID | classification | tagIds |
|---------|---------------|--------|
| sunset_silhouette | `{ type: 'portrait', style: 'emotional', method: 'wide' }` | `[]` |
| cafe_portrait | `{ type: 'portrait', style: 'japanese', method: 'normal' }` | `[]` |
| street_bw | `{ type: 'street', style: 'casual', method: 'candid' }` | `[]` |
| food_flat_lay | `{ type: 'food', style: 'overhead', method: 'flat-lay' }` | `[]` |
| night_cityscape | `{ type: 'night', style: 'neon', method: 'wide' }` | `[]` |
| golden_landscape | `{ type: 'landscape', style: 'fresh', method: 'wide' }` | `[]` |
| indoor_still_life | `{ type: 'still-life', style: 'minimal', method: 'single' }` | `[]` |
| soft_portrait | `{ type: 'portrait', style: 'japanese', method: 'normal' }` | `[]` |
| neon_portrait | `{ type: 'portrait', style: 'film', method: 'normal' }` | `[]` |
| macro_flower | `{ type: 'macro', style: 'nature', method: 'macro' }` | `[]` |
| film_vintage | `{ type: 'portrait', style: 'film', method: 'normal' }` | `[]` |
| urban_architecture | `{ type: 'landscape', style: 'epic', method: 'wide' }` | `[]` |

每个文件的修改方式（以 cafe-portrait.ts 为例，在 meta 对象中 `category` 之后添加两个字段）：

```typescript
meta: {
  id: 'cafe_portrait',
  name: '咖啡馆人像',
  author: '如画 Lumira',
  version: '1.0.0',
  category: 'portrait',
  classification: { type: 'portrait', style: 'japanese', method: 'normal' },
  tags: ['咖啡馆', '人像', '柔光', '生活'],
  tagIds: [],
  price: 0,
  cover: 'https://picsum.photos/seed/template-cafe-portrait/400/600',
  description: '咖啡馆室内自然光人像，氛围温暖柔和，适合生活感肖像',
  referenceSource: '样片 EXIF: Unsplash #67890'
},
```

（注意：cover 字段从 `/static/templates/xxx.jpg` 改为 `https://picsum.photos/seed/template-xxx/400/600`，遵循全局约束）

- [ ] **Step 2: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: 模板文件无错误。剩余错误来自 useSceneManager.ts（引用旧 ScenePreset 字段）、scenePresets 的引用方、preview.vue 等。

- [ ] **Step 3: Commit**

```bash
cd lumira-app && git add src/data/templates/
git commit -m "feat(templates): 12 个内置模板添加三层分类 classification + tagIds"
```

---

## Task 4: useSceneManager 扩展

**Files:**
- Modify: `lumira-app/src/composables/useSceneManager.ts`

**Interfaces:**
- Consumes: 新 ScenePreset、SceneCategory、SceneCategoryGroup、LocalPhoto、SceneAchievement、SCENE_LEVELS、SCENE_CATEGORIES（来自 Task 1, 2）
- Produces: 扩展后的 useSceneManager（新增 scenesByCategory、scenesByStyle、sceneCategoryTree、photos、addPhoto、deletePhoto、getPhotoCountByScene、getPhotosByScene、getSceneAchievement、sceneAchievements、weeklyRanking、allTimeRanking）

**说明:** 保留原有 API（customScenes/favorites/CRUD），新增分类、照片统计、成就、排行功能。localStorage 需迁移旧 customScenes 数据结构。

- [ ] **Step 1: 扩展 PersistedState 结构**

在 useSceneManager.ts 中更新持久化状态：

```typescript
interface PersistedState {
  version: number  // 升级到 2
  customScenes: CustomScenePreset[]
  favoritePresetIds: string[]
  photos: LocalPhoto[]
}
```

- [ ] **Step 2: 实现旧数据迁移逻辑**

在 `loadFromStorage` 函数中添加版本迁移：

```typescript
function migrateState(raw: any): PersistedState {
  // v1 → v2: 删除 customScenes 中的 cameraSuggestion/postSuggestion，补默认字段
  if (raw.version === 1) {
    const migratedCustomScenes = (raw.customScenes || []).map((s: any) => ({
      ...s,
      // 删除旧字段
      cameraSuggestion: undefined,
      postSuggestion: undefined,
      // 补新字段默认值
      filter: s.filter || { lut: 'none' as LutPreset, reason: '自定义场景滤镜' },
      vibe: s.vibe || s.description || '自定义场景',
      description: s.description || '',
      exampleImages: s.exampleImages || [],
      tips: s.tips || s.sceneGuide?.tips || [],
      whereToShoot: s.whereToShoot || '',
      bestTime: s.bestTime || s.sceneGuide?.bestTime || '',
      category: s.category || 'indoor' as SceneCategory,
      style: s.style || 'cafe',
      recommendedTagIds: s.recommendedTagIds || [],
      tagIds: s.tagIds || [],
    }))
    return {
      version: 2,
      customScenes: migratedCustomScenes,
      favoritePresetIds: raw.favoritePresetIds || [],
      photos: [],
    }
  }
  return raw as PersistedState
}
```

- [ ] **Step 3: 实现分类 computed**

```typescript
import { SCENE_CATEGORIES } from '@/data/scenePresets'

const scenesByCategory = computed<Record<SceneCategory, AnyScene[]>>(() => {
  const result: Record<SceneCategory, AnyScene[]> = {
    light: [], outdoor: [], indoor: [], mood: [],
  }
  for (const scene of allScenes.value) {
    result[scene.category].push(scene)
  }
  return result
})

const scenesByStyle = computed<Record<string, AnyScene[]>>(() => {
  const result: Record<string, AnyScene[]> = {}
  for (const scene of allScenes.value) {
    if (!result[scene.style]) result[scene.style] = []
    result[scene.style].push(scene)
  }
  return result
})

const sceneCategoryTree = computed<SceneCategoryGroup[]>(() => {
  return SCENE_CATEGORIES.map(group => ({
    ...group,
    styles: group.styles.map(style => ({
      ...style,
    })),
  }))
})
```

- [ ] **Step 4: 实现照片管理 API**

```typescript
const photos = ref<LocalPhoto[]>(state.photos)

function savePhotos() {
  state.photos = photos.value
  saveToStorage()
}

function addPhoto(data: Omit<LocalPhoto, 'id' | 'createdAt'>): string {
  const id = `photo_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  const photo: LocalPhoto = { ...data, id, createdAt: Date.now() }
  photos.value = [photo, ...photos.value]
  savePhotos()
  return id
}

function deletePhoto(id: string): void {
  photos.value = photos.value.filter(p => p.id !== id)
  savePhotos()
}

function getPhotoCountByScene(sceneId: string): number {
  return photos.value.filter(p => p.sceneId === sceneId).length
}

function getPhotosByScene(sceneId: string): LocalPhoto[] {
  return photos.value.filter(p => p.sceneId === sceneId)
}
```

- [ ] **Step 5: 实现成就系统**

```typescript
import { SCENE_LEVELS } from '@/types/template'

function getSceneAchievement(sceneId: string): SceneAchievement {
  const count = getPhotoCountByScene(sceneId)
  let currentLevel = 0
  for (const lv of SCENE_LEVELS) {
    if (count >= lv.threshold) currentLevel = lv.level
  }
  if (currentLevel === 0) {
    return { sceneId, level: 0, levelName: '未开始', photoCount: count, nextLevelCount: 1 }
  }
  const currentLevelDef = SCENE_LEVELS.find(l => l.level === currentLevel)!
  const nextLevelDef = SCENE_LEVELS.find(l => l.level === currentLevel + 1)
  return {
    sceneId,
    level: currentLevel,
    levelName: currentLevelDef.name,
    photoCount: count,
    nextLevelCount: nextLevelDef ? nextLevelDef.threshold : currentLevelDef.threshold,
  }
}

const sceneAchievements = computed<SceneAchievement[]>(() => {
  return allScenes.value.map(s => getSceneAchievement(s.id))
})
```

- [ ] **Step 6: 实现排行榜**

```typescript
const allTimeRanking = computed<{ scene: AnyScene; photoCount: number; rank: number }[]>(() => {
  const list = allScenes.value
    .map(scene => ({ scene, photoCount: getPhotoCountByScene(scene.id) }))
    .filter(item => item.photoCount > 0)
    .sort((a, b) => b.photoCount - a.photoCount)
    .map((item, idx) => ({ ...item, rank: idx + 1 }))
  return list
})

const weeklyRanking = computed<{ scene: AnyScene; photoCount: number; rank: number }[]>(() => {
  const oneWeekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000
  const list = allScenes.value
    .map(scene => ({
      scene,
      photoCount: photos.value.filter(p => p.sceneId === scene.id && p.createdAt >= oneWeekAgo).length,
    }))
    .filter(item => item.photoCount > 0)
    .sort((a, b) => b.photoCount - a.photoCount)
    .map((item, idx) => ({ ...item, rank: idx + 1 }))
  return list
})
```

- [ ] **Step 7: 更新 return 对象**

确保 useSceneManager 返回所有新增 API。

- [ ] **Step 8: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: useSceneManager.ts 无错误。剩余错误来自引用旧 ScenePreset 字段的页面。

- [ ] **Step 9: Commit**

```bash
cd lumira-app && git add src/composables/useSceneManager.ts
git commit -m "feat(composable): useSceneManager 扩展分类/照片统计/成就/排行 + v1→v2 数据迁移"
```

---

## Task 5: useTagManager + useShootKit 新建

**Files:**
- Create: `lumira-app/src/composables/useTagManager.ts`
- Create: `lumira-app/src/composables/useShootKit.ts`

**Interfaces:**
- Consumes: UserTag、ShootKit、AnyScene、PhotoTemplate、SCENE_PRESETS、useSceneManager、useTemplate（来自 Task 1, 2, 4）
- Produces: useTagManager（tags/getTagsByType/createTag/updateTag/deleteTag/getScenesByTag/getTemplatesByTag/filterScenesByTags/filterTemplatesByTags）、useShootKit（kits/createKit/updateKit/deleteKit/getKitDetail/recordUsage/recentKits）

- [ ] **Step 1: 创建 useTagManager.ts**

```typescript
import { ref, computed } from 'vue'
import type { UserTag, AnyScene, PhotoTemplate } from '@/types/template'
import { useSceneManager } from './useSceneManager'

const STORAGE_KEY = 'lumira_user_tags'

interface PersistedState {
  version: number
  tags: UserTag[]
}

const state = ref<PersistedState>({
  version: 1,
  tags: [],
})

let initialized = false

function loadFromStorage() {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as PersistedState
      state.value = parsed
    }
  } catch (e) {
    console.error('useTagManager load failed:', e)
  }
}

function saveToStorage() {
  try {
    uni.setStorageSync(STORAGE_KEY, JSON.stringify(state.value))
  } catch (e) {
    console.error('useTagManager save failed:', e)
  }
}

function ensureInit() {
  if (!initialized) {
    loadFromStorage()
    initialized = true
  }
}

export function useTagManager() {
  ensureInit()

  const tags = computed(() => state.value.tags)

  function getTagsByType(type: UserTag['type']): UserTag[] {
    if (type === 'both') return state.value.tags
    return state.value.tags.filter(t => t.type === type || t.type === 'both')
  }

  function createTag(name: string, type: UserTag['type']): string {
    const id = `tag_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const tag: UserTag = { id, name, type, createdAt: Date.now() }
    state.value.tags = [...state.value.tags, tag]
    saveToStorage()
    return id
  }

  function updateTag(id: string, data: Partial<UserTag>): void {
    state.value.tags = state.value.tags.map(t => t.id === id ? { ...t, ...data } : t)
    saveToStorage()
  }

  function deleteTag(id: string): void {
    state.value.tags = state.value.tags.filter(t => t.id !== id)
    saveToStorage()
  }

  function getScenesByTag(tagId: string): AnyScene[] {
    const { allScenes } = useSceneManager()
    return allScenes.value.filter(s => {
      const tagIds = 'tagIds' in s ? s.tagIds : s.recommendedTagIds
      return tagIds.includes(tagId)
    })
  }

  function getTemplatesByTag(tagId: string): PhotoTemplate[] {
    // 延迟导入避免循环依赖
    const { getAllTemplates } = useTemplateLazy()
    return getAllTemplates().filter(t => t.meta.tagIds.includes(tagId))
  }

  function filterScenesByTags(tagIds: string[]): AnyScene[] {
    if (tagIds.length === 0) {
      const { allScenes } = useSceneManager()
      return allScenes.value
    }
    const { allScenes } = useSceneManager()
    return allScenes.value.filter(s => {
      const ids = 'tagIds' in s ? s.tagIds : s.recommendedTagIds
      return tagIds.some(id => ids.includes(id))
    })
  }

  function filterTemplatesByTags(tagIds: string[]): PhotoTemplate[] {
    if (tagIds.length === 0) {
      const { getAllTemplates } = useTemplateLazy()
      return getAllTemplates()
    }
    const { getAllTemplates } = useTemplateLazy()
    return getAllTemplates().filter(t => tagIds.some(id => t.meta.tagIds.includes(id)))
  }

  return {
    tags,
    getTagsByType,
    createTag,
    updateTag,
    deleteTag,
    getScenesByTag,
    getTemplatesByTag,
    filterScenesByTags,
    filterTemplatesByTags,
  }
}

// 延迟导入 useTemplate 避免循环依赖
function useTemplateLazy() {
  const { useTemplate } = require('./useTemplate')
  return useTemplate()
}
```

注意：`require` 在 uni-app 中可能不可用。改为在函数顶部直接 import，但要确保 useTemplate.ts 不反向依赖 useTagManager.ts。如果存在循环依赖，则在 getTemplatesByTag/filterTemplatesByTags 中接收模板数组作为参数，而非内部调用 useTemplate。

**修正方案**（避免循环依赖）：filterTemplatesByTags 接收 templates 数组参数：

```typescript
function filterTemplatesByTags(tagIds: string[], templates: PhotoTemplate[]): PhotoTemplate[] {
  if (tagIds.length === 0) return templates
  return templates.filter(t => tagIds.some(id => t.meta.tagIds.includes(id)))
}
```

- [ ] **Step 2: 创建 useShootKit.ts**

```typescript
import { ref, computed } from 'vue'
import type { ShootKit, AnyScene, PhotoTemplate } from '@/types/template'
import { useSceneManager } from './useSceneManager'

const STORAGE_KEY = 'lumira_shoot_kits'

interface PersistedState {
  version: number
  kits: ShootKit[]
}

const state = ref<PersistedState>({
  version: 1,
  kits: [],
})

let initialized = false

function loadFromStorage() {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (raw) {
      state.value = JSON.parse(raw) as PersistedState
    }
  } catch (e) {
    console.error('useShootKit load failed:', e)
  }
}

function saveToStorage() {
  try {
    uni.setStorageSync(STORAGE_KEY, JSON.stringify(state.value))
  } catch (e) {
    console.error('useShootKit save failed:', e)
  }
}

function ensureInit() {
  if (!initialized) {
    loadFromStorage()
    initialized = true
  }
}

export function useShootKit() {
  ensureInit()

  const kits = computed(() => state.value.kits)

  function createKit(data: Omit<ShootKit, 'id' | 'createdAt' | 'updatedAt' | 'useCount'>): string {
    const id = `kit_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const now = Date.now()
    const kit: ShootKit = { ...data, id, createdAt: now, updatedAt: now, useCount: 0 }
    state.value.kits = [kit, ...state.value.kits]
    saveToStorage()
    return id
  }

  function updateKit(id: string, data: Partial<ShootKit>): void {
    state.value.kits = state.value.kits.map(k =>
      k.id === id ? { ...k, ...data, updatedAt: Date.now() } : k
    )
    saveToStorage()
  }

  function deleteKit(id: string): void {
    state.value.kits = state.value.kits.filter(k => k.id !== id)
    saveToStorage()
  }

  function getKitDetail(id: string, templates: PhotoTemplate[]): { kit: ShootKit; scene: AnyScene; template: PhotoTemplate } | null {
    const kit = state.value.kits.find(k => k.id === id)
    if (!kit) return null
    const { getSceneById } = useSceneManager()
    const scene = getSceneById(kit.sceneId)
    const template = templates.find(t => t.meta.id === kit.templateId)
    if (!scene || !template) return null
    return { kit, scene, template }
  }

  function recordUsage(id: string): void {
    state.value.kits = state.value.kits.map(k =>
      k.id === id ? { ...k, useCount: k.useCount + 1, lastUsedAt: Date.now() } : k
    )
    saveToStorage()
  }

  const recentKits = computed(() => {
    return [...state.value.kits].sort((a, b) => {
      const aTime = a.lastUsedAt || a.createdAt
      const bTime = b.lastUsedAt || b.createdAt
      return bTime - aTime
    })
  })

  return {
    kits,
    createKit,
    updateKit,
    deleteKit,
    getKitDetail,
    recordUsage,
    recentKits,
  }
}
```

- [ ] **Step 3: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: 两个新文件无错误。

- [ ] **Step 4: Commit**

```bash
cd lumira-app && git add src/composables/useTagManager.ts src/composables/useShootKit.ts
git commit -m "feat(composable): 新增 useTagManager 标签管理 + useShootKit 拍摄组合"
```

---

## Task 6: 辅助组件新增 + ScenePresetView 更新

**Files:**
- Create: `lumira-app/src/components/SceneFilterBadge.vue`
- Create: `lumira-app/src/components/SceneAchievementCard.vue`
- Create: `lumira-app/src/components/TagSelector.vue`
- Create: `lumira-app/src/components/KitCard.vue`
- Create: `lumira-app/src/components/CategoryNav.vue`
- Modify: `lumira-app/src/components/ScenePresetView.vue`

**Interfaces:**
- Consumes: AnyScene、SceneFilter、SceneAchievement、UserTag、ShootKit、SceneCategoryGroup（来自 Task 1, 4）
- Produces: 5 个可复用 UI 组件 + 更新后的 ScenePresetView

- [ ] **Step 1: 创建 SceneFilterBadge.vue**

Props: `filter: SceneFilter`。显示 LUT 名称 + systemFilter（如有）+ reason。

```vue
<template>
  <view class="filter-badge">
    <text class="filter-icon">🎞</text>
    <view class="filter-info">
      <text class="filter-name">{{ lutName }}</text>
      <text class="filter-reason">{{ filter.reason }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { SceneFilter } from '@/types/template'
import { getLutLabel } from '@/utils/filterRecipe'

const props = defineProps<{ filter: SceneFilter }>()

const lutName = computed(() => getLutLabel(props.filter.lut))
</script>

<style lang="scss" scoped>
.filter-badge {
  display: flex;
  align-items: flex-start;
  gap: 16rpx;
  padding: 24rpx;
  background: rgba(0,0,0,0.04);
  border-radius: 20rpx;
}
.filter-icon { font-size: 40rpx; }
.filter-info { flex: 1; display: flex; flex-direction: column; gap: 8rpx; }
.filter-name { font-size: 28rpx; font-weight: 600; color: #2A2520; }
.filter-reason { font-size: 24rpx; color: #6B635A; line-height: 1.5; }
</style>
```

- [ ] **Step 2: 创建 SceneAchievementCard.vue**

Props: `achievement: SceneAchievement`、`sceneName: string`、`rank?: number`、`rankLabel?: string`。显示照片数、等级、进度条、排行。

```vue
<template>
  <view class="achievement-card">
    <view class="ach-row">
      <view class="ach-stat">
        <text class="ach-icon">📷</text>
        <text class="ach-value">{{ achievement.photoCount }} 张</text>
      </view>
      <view class="ach-stat" v-if="achievement.level > 0">
        <text class="ach-icon">🏆</text>
        <text class="ach-value">{{ sceneName }} {{ achievement.levelName }} Lv.{{ achievement.level }}</text>
      </view>
    </view>
    <view class="ach-progress" v-if="achievement.level < 5">
      <view class="ach-progress-bar">
        <view class="ach-progress-fill" :style="{ width: progressPercent + '%' }"></view>
      </view>
      <text class="ach-progress-text">{{ achievement.photoCount }}/{{ achievement.nextLevelCount }}</text>
    </view>
    <view class="ach-rank" v-if="rank">
      <text class="ach-rank-icon">🔥</text>
      <text class="ach-rank-text">{{ rankLabel || '本周' }}热门 #{{ rank }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { SceneAchievement } from '@/types/template'

const props = defineProps<{
  achievement: SceneAchievement
  sceneName: string
  rank?: number
  rankLabel?: string
}>()

const progressPercent = computed(() => {
  if (props.achievement.level === 0) {
    return Math.min(100, (props.achievement.photoCount / props.achievement.nextLevelCount) * 100)
  }
  return Math.min(100, (props.achievement.photoCount / props.achievement.nextLevelCount) * 100)
})
</script>

<style lang="scss" scoped>
.achievement-card { padding: 24rpx; background: rgba(0,0,0,0.04); border-radius: 20rpx; display: flex; flex-direction: column; gap: 16rpx; }
.ach-row { display: flex; gap: 32rpx; }
.ach-stat { display: flex; align-items: center; gap: 8rpx; }
.ach-icon { font-size: 32rpx; }
.ach-value { font-size: 26rpx; color: #2A2520; font-weight: 500; }
.ach-progress { display: flex; align-items: center; gap: 16rpx; }
.ach-progress-bar { flex: 1; height: 12rpx; background: rgba(0,0,0,0.08); border-radius: 6rpx; overflow: hidden; }
.ach-progress-fill { height: 100%; background: #C9A876; border-radius: 6rpx; transition: width 0.3s; }
.ach-progress-text { font-size: 22rpx; color: #6B635A; }
.ach-rank { display: flex; align-items: center; gap: 8rpx; }
.ach-rank-icon { font-size: 28rpx; }
.ach-rank-text { font-size: 24rpx; color: #C9A876; font-weight: 600; }
</style>
```

- [ ] **Step 3: 创建 TagSelector.vue**

Props: `selectedTagIds: string[]`、`type: 'scene' | 'template' | 'both'`。Emits: `update:selectedTagIds`、`create-tag`。显示标签 pill 列表（横滑）+ "+" 创建按钮。

```vue
<template>
  <scroll-view scroll-x class="tag-selector" :show-scrollbar="false">
    <view class="tag-list-inner">
      <view
        v-for="tag in availableTags"
        :key="tag.id"
        class="tag-pill"
        :class="{ 'tag-pill-active': selectedTagIds.includes(tag.id) }"
        @click="toggleTag(tag.id)"
      >
        <text class="tag-pill-text">{{ tag.name }}</text>
      </view>
      <view class="tag-pill tag-pill-add" @click="onCreateTag">
        <text class="tag-pill-text">+</text>
      </view>
    </view>
  </scroll-view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTagManager } from '@/composables/useTagManager'

const props = defineProps<{
  selectedTagIds: string[]
  type: 'scene' | 'template' | 'both'
}>()

const emit = defineEmits<{
  'update:selectedTagIds': [ids: string[]]
  'create-tag': []
}>()

const { getTagsByType } = useTagManager()
const availableTags = computed(() => getTagsByType(props.type))

function toggleTag(id: string) {
  if (props.selectedTagIds.includes(id)) {
    emit('update:selectedTagIds', props.selectedTagIds.filter(t => t !== id))
  } else {
    emit('update:selectedTagIds', [...props.selectedTagIds, id])
  }
}

function onCreateTag() {
  emit('create-tag')
}
</script>

<style lang="scss" scoped>
.tag-selector { white-space: nowrap; }
.tag-list-inner { display: inline-flex; align-items: center; gap: 16rpx; padding: 0 24rpx; }
.tag-pill { display: inline-flex; align-items: center; padding: 12rpx 24rpx; border-radius: 32rpx; background: rgba(0,0,0,0.05); }
.tag-pill-active { background: #C9A876; }
.tag-pill-text { font-size: 24rpx; color: #2A2520; }
.tag-pill-active .tag-pill-text { color: #FFFFFF; }
.tag-pill-add { background: transparent; border: 2rpx dashed #C9A876; }
</style>
```

- [ ] **Step 4: 创建 KitCard.vue**

Props: `kit: ShootKit`、`scene?: AnyScene`、`template?: PhotoTemplate`。显示组合名称、场景图标+模板图标、使用次数。

```vue
<template>
  <view class="kit-card">
    <view class="kit-icons">
      <text class="kit-icon">{{ scene?.icon || '📍' }}</text>
      <text class="kit-link">+</text>
      <text class="kit-icon">{{ template ? '📓' : '📸' }}</text>
    </view>
    <text class="kit-name">{{ kit.name }}</text>
    <text class="kit-meta">{{ scene?.name || '?' }} · {{ template?.meta.name || '?' }}</text>
    <text class="kit-count" v-if="kit.useCount > 0">使用 {{ kit.useCount }} 次</text>
  </view>
</template>

<script setup lang="ts">
import type { ShootKit, AnyScene, PhotoTemplate } from '@/types/template'

defineProps<{
  kit: ShootKit
  scene?: AnyScene
  template?: PhotoTemplate
}>()
</script>

<style lang="scss" scoped>
.kit-card { display: flex; flex-direction: column; align-items: center; gap: 8rpx; padding: 20rpx; background: rgba(0,0,0,0.04); border-radius: 20rpx; min-width: 180rpx; }
.kit-icons { display: flex; align-items: center; gap: 8rpx; }
.kit-icon { font-size: 36rpx; }
.kit-link { font-size: 24rpx; color: #6B635A; }
.kit-name { font-size: 24rpx; font-weight: 600; color: #2A2520; text-align: center; }
.kit-meta { font-size: 20rpx; color: #6B635A; text-align: center; }
.kit-count { font-size: 20rpx; color: #C9A876; }
</style>
```

- [ ] **Step 5: 创建 CategoryNav.vue**

通用分类导航组件，支持多层。Props: `layers: { label: string; options: { value: string; label: string }[]; selected: string | null }[]`。Emits: `select: [layerIndex: number, value: string | null]`。

```vue
<template>
  <view class="category-nav">
    <view v-for="(layer, idx) in layers" :key="idx" class="category-layer" v-if="shouldShowLayer(idx)">
      <scroll-view scroll-x class="category-scroll" :show-scrollbar="false">
        <view class="category-inner">
          <view
            class="category-pill"
            :class="{ 'category-pill-active': layer.selected === null }"
            @click="onSelect(idx, null)"
          >
            <text class="category-pill-text">全部</text>
          </view>
          <view
            v-for="opt in layer.options"
            :key="opt.value"
            class="category-pill"
            :class="{ 'category-pill-active': layer.selected === opt.value }"
            @click="onSelect(idx, opt.value)"
          >
            <text class="category-pill-text">{{ opt.label }}</text>
          </view>
        </view>
      </scroll-view>
    </view>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  layers: { label: string; options: { value: string; label: string }[]; selected: string | null }[]
}>()

const emit = defineEmits<{
  select: [layerIndex: number, value: string | null]
}>()

function shouldShowLayer(idx: number): boolean {
  if (idx === 0) return true
  // 前一层有选中时才显示下一层
  return props.layers[idx - 1].selected !== null
}

function onSelect(idx: number, value: string | null) {
  emit('select', idx, value)
}
</script>

<style lang="scss" scoped>
.category-nav { display: flex; flex-direction: column; gap: 16rpx; }
.category-scroll { white-space: nowrap; }
.category-inner { display: inline-flex; align-items: center; gap: 16rpx; padding: 0 24rpx; }
.category-pill { display: inline-flex; align-items: center; padding: 12rpx 24rpx; border-radius: 32rpx; background: rgba(0,0,0,0.05); }
.category-pill-active { background: #2A2520; }
.category-pill-text { font-size: 24rpx; color: #2A2520; }
.category-pill-active .category-pill-text { color: #FFFFFF; }
</style>
```

- [ ] **Step 6: 更新 ScenePresetView.vue 适配新结构**

修改要点：
- 旧字段 `description` 仍存在（保留）
- 新增显示 `vibe`（如存在）
- 新增显示照片数和成就等级（通过可选 props 传入）
- `imageSrc` 默认值改用 `scene.exampleImages[0]`（如存在）
- 移除对 `cameraSuggestion`/`postSuggestion` 的引用

Props 新增：
```typescript
photoCount?: number
achievementLevel?: number
```

在 card 变体的文字区新增 vibe 和统计行。

- [ ] **Step 7: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: 新组件无错误。ScenePresetView 更新后无错误。

- [ ] **Step 8: Commit**

```bash
cd lumira-app && git add src/components/
git commit -m "feat(components): 新增 SceneFilterBadge/SceneAchievementCard/TagSelector/KitCard/CategoryNav + 更新 ScenePresetView"
```

---

## Task 7: scene-detail.vue 新建 + 路由

**Files:**
- Create: `lumira-app/src/pages/capture/scene-detail.vue`
- Modify: `lumira-app/src/pages.json`

**Interfaces:**
- Consumes: useSceneManager（getSceneById、getSceneAchievement、isFavorite、toggleFavorite、weeklyRanking）、SceneFilterBadge、SceneAchievementCard
- Produces: 场景详情页，接收 `sceneId` 参数

- [ ] **Step 1: 在 pages.json 中新增路由**

在 `pages/capture/scene-manage` 之后添加：

```json
{
  "path": "pages/capture/scene-detail",
  "style": {
    "navigationBarTitleText": "场景详情",
    "navigationStyle": "custom",
    "backgroundColor": "#FAF7F2"
  }
}
```

- [ ] **Step 2: 创建 scene-detail.vue**

页面结构（按 spec 4.2 节）：
- 顶部自定义导航栏（返回 + 收藏按钮）
- 示例图轮播（swiper）
- 场景名 + vibe + 标签
- 氛围卡片（description + whereToShoot + bestTime）
- 推荐滤镜（SceneFilterBadge 组件）
- 拍摄小贴士列表
- 成就卡片（SceneAchievementCard 组件）
- 底部按钮："用此场景拍照" + "加入组合"

```vue
<template>
  <view class="scene-detail-page">
    <!-- 导航栏 -->
    <view class="detail-nav">
      <view class="nav-back" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">{{ scene?.name || '场景详情' }}</text>
      <view class="nav-fav" @click="onToggleFav">
        <text :class="['nav-fav-icon', isFav ? 'ph ph-heart' : 'ph ph-heart-straight']"></text>
      </view>
    </view>

    <scroll-view scroll-y class="detail-scroll" v-if="scene">
      <!-- 示例图轮播 -->
      <swiper class="detail-swiper" :indicator-dots="scene.exampleImages.length > 1" circular autoplay>
        <swiper-item v-for="(img, idx) in scene.exampleImages" :key="idx">
          <image class="detail-swiper-img" :src="img" mode="aspectFill" />
        </swiper-item>
      </swiper>

      <!-- 标题区 -->
      <view class="detail-header">
        <view class="detail-header-row">
          <text class="detail-icon">{{ scene.icon === 'ph-coffee' ? '☕' : '📍' }}</text>
          <text class="detail-name">{{ scene.name }}</text>
        </view>
        <text class="detail-vibe">{{ scene.vibe }}</text>
      </view>

      <!-- 氛围卡片 -->
      <view class="detail-section">
        <text class="section-title">氛围</text>
        <view class="section-card">
          <text class="section-text">{{ scene.description }}</text>
          <view class="section-meta">
            <text class="meta-item">📍 {{ scene.whereToShoot }}</text>
            <text class="meta-item">🕐 {{ scene.bestTime }}</text>
          </view>
        </view>
      </view>

      <!-- 推荐滤镜 -->
      <view class="detail-section">
        <text class="section-title">推荐滤镜</text>
        <SceneFilterBadge :filter="scene.filter" />
      </view>

      <!-- 拍摄小贴士 -->
      <view class="detail-section">
        <text class="section-title">拍摄小贴士</text>
        <view class="section-card">
          <view v-for="(tip, idx) in scene.tips" :key="idx" class="tip-row">
            <text class="tip-dot">•</text>
            <text class="tip-text">{{ tip }}</text>
          </view>
        </view>
      </view>

      <!-- 成就 -->
      <view class="detail-section">
        <text class="section-title">我的成就</text>
        <SceneAchievementCard
          :achievement="achievement"
          :scene-name="scene.name"
          :rank="sceneRank"
          rank-label="本周"
        />
      </view>

      <view class="detail-bottom-space"></view>
    </scroll-view>

    <!-- 底部按钮 -->
    <view class="detail-bottom" v-if="scene">
      <view class="btn-primary" @click="goCapture">
        <text class="btn-primary-text">用此场景拍照</text>
      </view>
      <view class="btn-secondary" @click="goCreateKit">
        <text class="btn-secondary-text">加入组合</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import SceneFilterBadge from '@/components/SceneFilterBadge.vue'
import SceneAchievementCard from '@/components/SceneAchievementCard.vue'

const sceneId = ref<string>('')

onLoad((options) => {
  if (options?.sceneId) {
    sceneId.value = options.sceneId
  }
})

const { getSceneById, getSceneAchievement, isFavorite, toggleFavorite, weeklyRanking } = useSceneManager()

const scene = computed(() => getSceneById(sceneId.value))
const isFav = computed(() => sceneId.value ? isFavorite(sceneId.value) : false)
const achievement = computed(() => getSceneAchievement(sceneId.value))
const sceneRank = computed(() => {
  const found = weeklyRanking.value.find(r => r.scene.id === sceneId.value)
  return found?.rank
})

function goBack() {
  uni.navigateBack()
}

function onToggleFav() {
  if (sceneId.value) toggleFavorite(sceneId.value)
}

function goCapture() {
  uni.navigateTo({ url: `/pages/capture/index?scenePreset=${sceneId.value}` })
}

function goCreateKit() {
  uni.navigateTo({ url: `/pages/capture/scene-manage?tab=kit&sceneId=${sceneId.value}` })
}
</script>

<style lang="scss" scoped>
.scene-detail-page { min-height: 100vh; background: #FAF7F2; display: flex; flex-direction: column; }
.detail-nav { display: flex; align-items: center; justify-content: space-between; padding: 0 24rpx; height: 88rpx; padding-top: env(safe-area-inset-top); }
.nav-back { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.nav-back-icon { font-size: 36rpx; color: #2A2520; }
.nav-title { font-size: 32rpx; font-weight: 600; color: #2A2520; }
.nav-fav { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.nav-fav-icon { font-size: 36rpx; color: #C9A876; }
.detail-scroll { flex: 1; }
.detail-swiper { width: 100%; height: 480rpx; }
.detail-swiper-img { width: 100%; height: 100%; }
.detail-header { padding: 32rpx 24rpx 16rpx; display: flex; flex-direction: column; gap: 12rpx; }
.detail-header-row { display: flex; align-items: center; gap: 16rpx; }
.detail-icon { font-size: 48rpx; }
.detail-name { font-size: 40rpx; font-weight: 700; color: #2A2520; }
.detail-vibe { font-size: 28rpx; color: #6B635A; font-style: italic; }
.detail-section { padding: 16rpx 24rpx; display: flex; flex-direction: column; gap: 16rpx; }
.section-title { font-size: 28rpx; font-weight: 600; color: #2A2520; }
.section-card { padding: 24rpx; background: rgba(0,0,0,0.04); border-radius: 20rpx; display: flex; flex-direction: column; gap: 16rpx; }
.section-text { font-size: 26rpx; color: #2A2520; line-height: 1.6; }
.section-meta { display: flex; flex-direction: column; gap: 8rpx; }
.meta-item { font-size: 24rpx; color: #6B635A; }
.tip-row { display: flex; gap: 12rpx; }
.tip-dot { font-size: 26rpx; color: #C9A876; }
.tip-text { font-size: 26rpx; color: #2A2520; flex: 1; line-height: 1.5; }
.detail-bottom-space { height: 160rpx; }
.detail-bottom { position: fixed; bottom: 0; left: 0; right: 0; display: flex; gap: 16rpx; padding: 24rpx; padding-bottom: calc(24rpx + env(safe-area-inset-bottom)); background: #FAF7F2; }
.btn-primary { flex: 1; height: 88rpx; background: #2A2520; border-radius: 44rpx; display: flex; align-items: center; justify-content: center; }
.btn-primary-text { font-size: 28rpx; color: #FFFFFF; font-weight: 600; }
.btn-secondary { flex: 1; height: 88rpx; background: rgba(201,168,118,0.15); border-radius: 44rpx; display: flex; align-items: center; justify-content: center; }
.btn-secondary-text { font-size: 28rpx; color: #C9A876; font-weight: 600; }
</style>
```

- [ ] **Step 3: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: scene-detail.vue 无错误。

- [ ] **Step 4: Commit**

```bash
cd lumira-app && git add src/pages/capture/scene-detail.vue src/pages.json
git commit -m "feat(page): 新增场景详情页 scene-detail + 路由注册"
```

---

## Task 8: scene-guide.vue 重构

**Files:**
- Modify: `lumira-app/src/pages/capture/scene-guide.vue`

**Interfaces:**
- Consumes: useSceneManager（scenesByCategory、sceneCategoryTree、getPhotoCountByScene、getSceneAchievement）、useTagManager（filterScenesByTags）、CategoryNav、TagSelector、ScenePresetView
- Produces: 重构后的场景指南页（两层分类 + 标签筛选 + 卡片显示统计）

**说明:** 完全重构页面。旧的三 Tab（common/fav/recommend）替换为：分类导航 + 标签筛选 + 场景卡片列表。场景卡片点击跳转到 scene-detail 页。

- [ ] **Step 1: 重写 scene-guide.vue 的 script 部分**

```typescript
import { ref, computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import { useTagManager } from '@/composables/useTagManager'
import { SCENE_CATEGORIES } from '@/data/scenePresets'
import CategoryNav from '@/components/CategoryNav.vue'
import TagSelector from '@/components/TagSelector.vue'
import type { SceneCategory, AnyScene } from '@/types/template'

const { allScenes, reloadFromStorage, getPhotoCountByScene, getSceneAchievement } = useSceneManager()
const { filterScenesByTags } = useTagManager()

onLoad(() => {})
onShow(() => { reloadFromStorage() })

// 分类导航：第一层大类，第二层风格
const selectedCategory = ref<SceneCategory | null>(null)
const selectedStyle = ref<string | null>(null)
const selectedTagIds = ref<string[]>([])

const categoryLayers = computed(() => {
  const layers = []
  // 第一层：大类
  layers.push({
    label: '大类',
    selected: selectedCategory.value,
    options: SCENE_CATEGORIES.map(c => ({ value: c.category, label: c.name })),
  })
  // 第二层：风格（仅当大类选中时显示）
  if (selectedCategory.value) {
    const group = SCENE_CATEGORIES.find(c => c.category === selectedCategory.value)
    if (group) {
      layers.push({
        label: '风格',
        selected: selectedStyle.value,
        options: group.styles.map(s => ({ value: s.id, label: s.name })),
      })
    }
  }
  return layers
})

function onLayerSelect(idx: number, value: string | null) {
  if (idx === 0) {
    selectedCategory.value = value as SceneCategory | null
    selectedStyle.value = null  // 重置子分类
  } else if (idx === 1) {
    selectedStyle.value = value
  }
}

// 筛选后的场景列表
const filteredScenes = computed(() => {
  let list = allScenes.value
  if (selectedCategory.value) {
    list = list.filter(s => s.category === selectedCategory.value)
  }
  if (selectedStyle.value) {
    list = list.filter(s => s.style === selectedStyle.value)
  }
  if (selectedTagIds.value.length > 0) {
    list = filterScenesByTags(selectedTagIds.value)
  }
  return list
})

function goSceneDetail(id: string) {
  uni.navigateTo({ url: `/pages/capture/scene-detail?sceneId=${id}` })
}

function goSceneManage() {
  uni.navigateTo({ url: '/pages/capture/scene-manage' })
}
```

- [ ] **Step 2: 重写 template 部分**

```vue
<template>
  <view class="scene-guide-page">
    <!-- 导航栏 -->
    <view class="guide-nav">
      <view class="nav-back" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">场景灵感</text>
      <view class="nav-manage" @click="goSceneManage">
        <text class="ph ph-gear-six nav-manage-icon"></text>
      </view>
    </view>

    <scroll-view scroll-y class="guide-scroll">
      <!-- 分类导航 -->
      <CategoryNav :layers="categoryLayers" @select="onLayerSelect" />

      <!-- 标签筛选 -->
      <view class="guide-tags">
        <TagSelector
          :selected-tag-ids="selectedTagIds"
          type="scene"
          @update:selected-tag-ids="selectedTagIds = $event"
        />
      </view>

      <!-- 场景卡片列表 -->
      <view class="guide-list">
        <view
          v-for="scene in filteredScenes"
          :key="scene.id"
          class="guide-card"
          @click="goSceneDetail(scene.id)"
        >
          <image
            v-if="scene.exampleImages[0]"
            class="guide-card-img"
            :src="scene.exampleImages[0]"
            mode="aspectFill"
          />
          <view class="guide-card-info">
            <text class="guide-card-name">{{ scene.name }}</text>
            <text class="guide-card-vibe">{{ scene.vibe }}</text>
            <view class="guide-card-stats">
              <text class="stat-item">📷 {{ getPhotoCountByScene(scene.id) }}</text>
              <text v-if="getSceneAchievement(scene.id).level > 0" class="stat-item">
                🏆 Lv.{{ getSceneAchievement(scene.id).level }}
              </text>
            </view>
          </view>
        </view>
      </view>

      <view v-if="filteredScenes.length === 0" class="guide-empty">
        <text class="guide-empty-text">暂无匹配场景</text>
      </view>
    </scroll-view>
  </view>
</template>
```

- [ ] **Step 3: 编写 style 部分**

使用 Morandi 色系，rpx 单位，class 选择器。参考现有 scene-guide.vue 的样式风格。

- [ ] **Step 4: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: scene-guide.vue 无错误。

- [ ] **Step 5: Commit**

```bash
cd lumira-app && git add src/pages/capture/scene-guide.vue
git commit -m "feat(page): scene-guide 重构为分类导航 + 标签筛选 + 统计卡片"
```

---

## Task 9: scene-manage.vue 重构

**Files:**
- Modify: `lumira-app/src/pages/capture/scene-manage.vue`

**Interfaces:**
- Consumes: useSceneManager（customScenes CRUD、favoritePresetIds）、useShootKit（kits CRUD）、useTagManager（tags CRUD）、KitCard
- Produces: 三 Tab 页面（收藏/自定义场景/我的组合）+ 自定义场景表单更新（新字段 vibe/filter/exampleImages 等）

**说明:** 保留现有收藏和自定义场景 Tab，新增"我的组合"Tab。自定义场景表单需适配新 ScenePreset 结构（删除 cameraSuggestion/postSuggestion 字段输入，新增 vibe/filter 等字段输入）。

- [ ] **Step 1: 更新 script — 新增组合 Tab 和 useShootKit 集成**

在现有 script 中添加：
- import useShootKit
- 新增 `activeTab` 支持 'kit' 值
- 新增组合列表 computed
- 新增组合 CRUD 函数（createKit/updateKit/deleteKit）
- onLoad 读取 `tab` 和 `sceneId` 参数（从 scene-detail 跳转来创建组合）

- [ ] **Step 2: 更新自定义场景表单字段**

删除表单中的 cameraSuggestion 和 postSuggestion 相关输入。新增：
- vibe（情绪化主标题）输入
- filter.lut 选择（用 getLutOptions）
- filter.reason 输入
- exampleImages（最多 3 个 picsum seed 输入）
- whereToShoot 输入
- bestTime 输入
- tips（多行文本，换行分隔）

- [ ] **Step 3: 新增组合 Tab 的 template**

```vue
<view v-if="activeTab === 'kit'" class="kit-tab">
  <view v-for="kit in kits" :key="kit.id" class="kit-item" @click="onKitClick(kit.id)">
    <KitCard :kit="kit" :scene="getSceneById(kit.sceneId)" :template="getTemplateById(kit.templateId)" />
  </view>
  <view v-if="kits.length === 0" class="kit-empty">
    <text class="kit-empty-text">还没有组合，去场景详情页创建一个吧</text>
  </view>
</view>
```

- [ ] **Step 4: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: scene-manage.vue 无错误。

- [ ] **Step 5: Commit**

```bash
cd lumira-app && git add src/pages/capture/scene-manage.vue
git commit -m "feat(page): scene-manage 新增组合 Tab + 表单适配新 ScenePreset 结构"
```

---

## Task 10: preview.vue 重构

**Files:**
- Modify: `lumira-app/src/pages/capture/preview.vue`

**Interfaces:**
- Consumes: useSceneManager（allScenes、addPhoto）、SCENE_PRESETS
- Produces: 场景选择器使用真实数据 + 保存时写入 LocalPhoto

**说明:** 删除硬编码的 6 个场景标签，改用 SCENE_PRESETS + customScenes。保存照片时调用 addPhoto 持久化。

- [ ] **Step 1: 替换硬编码场景为真实数据**

删除：
```typescript
const scenes = ref([
  { name: '咖啡馆', icon: 'ph-coffee', active: true },
  ...
])
```

替换为：
```typescript
import { useSceneManager } from '@/composables/useSceneManager'

const { allScenes, addPhoto } = useSceneManager()

const selectedSceneId = ref<string | null>(null)

const sceneOptions = computed(() => allScenes.value.map(s => ({
  id: s.id,
  name: s.name,
  icon: s.icon,
})))
```

- [ ] **Step 2: 更新 template 场景选择器**

```vue
<view class="preview-scenes">
  <text class="section-label">归属场景</text>
  <scroll-view scroll-x class="scene-scroll" :show-scrollbar="false">
    <view class="scene-list-inner">
      <view
        v-for="scene in sceneOptions"
        :key="scene.id"
        class="scene-pill"
        :class="{ 'scene-pill-active': selectedSceneId === scene.id }"
        @click="selectedSceneId = scene.id"
      >
        <text class="scene-pill-text">{{ scene.name }}</text>
      </view>
      <view
        class="scene-pill"
        :class="{ 'scene-pill-active': selectedSceneId === null }"
        @click="selectedSceneId = null"
      >
        <text class="scene-pill-text">不标记</text>
      </view>
    </view>
  </scroll-view>
</view>
```

- [ ] **Step 3: 保存时写入 LocalPhoto**

在保存照片的逻辑中添加：

```typescript
function onSave() {
  // ... 现有保存逻辑 ...

  // 新增：写入 LocalPhoto
  addPhoto({
    dataUrl: photoDataUrl.value,
    sceneId: selectedSceneId.value,
    mood: selectedMood.value || undefined,
    lut: currentLut.value,
  })

  // ... 跳转逻辑 ...
}
```

- [ ] **Step 4: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: preview.vue 无错误。

- [ ] **Step 5: Commit**

```bash
cd lumira-app && git add src/pages/capture/preview.vue
git commit -m "feat(page): preview 场景选择器改用真实数据 + 保存时写入 LocalPhoto"
```

---

## Task 11: capture/index.vue 增强

**Files:**
- Modify: `lumira-app/src/pages/capture/index.vue`

**Interfaces:**
- Consumes: useShootKit（kits、recordUsage）、useSceneManager（addPhoto）
- Produces: 底部新增"我的组合"横滑区 + 拍照后自动场景标记

**说明:** 在现有底部模板条之前新增组合横滑区。点击组合卡片一键加载场景滤镜+模板。拍照保存时自动传递 sceneId。

- [ ] **Step 1: 集成 useShootKit**

```typescript
import { useShootKit } from '@/composables/useShootKit'
import { useSceneManager } from '@/composables/useSceneManager'

const { kits, recordUsage } = useShootKit()
const { getSceneById } = useSceneManager()
const { loadTemplate } = useTemplate()
```

- [ ] **Step 2: 实现组合加载逻辑**

```typescript
function applyKit(kitId: string) {
  const kit = kits.value.find(k => k.id === kitId)
  if (!kit) return

  const scene = getSceneById(kit.sceneId)
  const template = loadTemplate(kit.templateId)
  if (!scene || !template) return

  // 加载模板
  editableTemplate.value = JSON.parse(JSON.stringify(template))
  currentTemplateId.value = template.meta.id

  // 叠加场景滤镜
  editableTemplate.value.postProcess.lut = scene.filter.lut
  if (scene.filter.systemFilter) {
    editableTemplate.value.postProcess.systemFilter = scene.filter.systemFilter
  }

  // 应用 overrides（如有）
  if (kit.overrides?.camera) {
    Object.assign(editableTemplate.value.camera, kit.overrides.camera)
  }
  if (kit.overrides?.postProcess) {
    Object.assign(editableTemplate.value.postProcess, kit.overrides.postProcess)
  }

  recordUsage(kitId)
}
```

- [ ] **Step 3: 在 template 中添加组合横滑区**

在底部模板条之前添加：

```vue
<view class="kit-bar" v-if="kits.length > 0">
  <text class="kit-bar-title">我的组合</text>
  <scroll-view scroll-x class="kit-scroll" :show-scrollbar="false">
    <view class="kit-scroll-inner">
      <view
        v-for="kit in kits"
        :key="kit.id"
        class="kit-bar-item"
        @click="applyKit(kit.id)"
      >
        <text class="kit-bar-name">{{ kit.name }}</text>
      </view>
    </view>
  </scroll-view>
</view>
```

- [ ] **Step 4: 更新场景预设加载逻辑**

现有 `onLoad` 中 `scenePreset` 参数处理需适配新 ScenePreset 结构（删除 cameraSuggestion/postSuggestion 引用，改为只应用 filter.lut + filter.systemFilter）：

```typescript
if (options?.scenePreset) {
  const preset = SCENE_PRESETS.find(p => p.id === options.scenePreset)
  if (preset) {
    const tpl = createEmptyTemplate()
    tpl.sceneGuide.presetId = preset.id
    Object.assign(tpl.sceneGuide, preset.sceneGuide)
    // 仅应用滤镜
    tpl.postProcess.lut = preset.filter.lut
    if (preset.filter.systemFilter) {
      tpl.postProcess.systemFilter = preset.filter.systemFilter
    }
    editableTemplate.value = tpl
  }
}
```

- [ ] **Step 5: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: capture/index.vue 无错误。

- [ ] **Step 6: Commit**

```bash
cd lumira-app && git add src/pages/capture/index.vue
git commit -m "feat(page): capture 新增组合快速入口 + 场景预设加载适配新结构"
```

---

## Task 12: templates/index.vue 重构

**Files:**
- Modify: `lumira-app/src/pages/templates/index.vue`

**Interfaces:**
- Consumes: useTemplate（getAllTemplates）、useTagManager（filterTemplatesByTags）、CategoryNav、TagSelector、TemplateClassification
- Produces: 三层分类导航 + 标签筛选 + 模板卡片列表

**说明:** 替换单层分类为三层分类（type → style → method）。删除局部 sceneToCategory，改用 SCENE_TO_CATEGORY。

- [ ] **Step 1: 更新 script — 三层分类 + 标签筛选**

```typescript
import { ref, computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import { useTagManager } from '@/composables/useTagManager'
import { SCENE_TO_CATEGORY } from '@/data/scenePresets'
import CategoryNav from '@/components/CategoryNav.vue'
import TagSelector from '@/components/TagSelector.vue'
import type { Target, TemplateClassification } from '@/types/template'

const { getAllTemplates, getCustomTemplates } = useTemplate()
const { filterTemplatesByTags } = useTagManager()

const selectedType = ref<Target | null>(null)
const selectedStyle = ref<string | null>(null)
const selectedMethod = ref<string | null>(null)
const selectedTagIds = ref<string[]>([])
const showCustom = ref(false)

// 三层分类选项
const STYLE_MAP: Record<Target, { value: string; label: string }[]> = {
  portrait: [
    { value: 'japanese', label: '日系' },
    { value: 'emotional', label: '情绪' },
    { value: 'film', label: '胶片' },
    { value: 'western', label: '欧美' },
  ],
  landscape: [
    { value: 'fresh', label: '清新' },
    { value: 'epic', label: '大气' },
  ],
  food: [
    { value: 'overhead', label: '俯拍' },
    { value: 'closeup', label: '特写' },
  ],
  street: [
    { value: 'casual', label: '随性' },
    { value: 'geometric', label: '几何' },
  ],
  night: [
    { value: 'neon', label: '霓虹' },
    { value: 'starry', label: '星空' },
  ],
  macro: [
    { value: 'nature', label: '自然' },
    { value: 'object', label: '物品' },
  ],
  'still-life': [
    { value: 'minimal', label: '极简' },
    { value: 'flat', label: '扁平' },
  ],
}

const METHOD_MAP: Record<string, { value: string; label: string }[]> = {
  japanese: [
    { value: 'selfie', label: '自拍' },
    { value: 'normal', label: '他拍' },
    { value: 'overhead', label: '俯拍' },
  ],
  emotional: [
    { value: 'selfie', label: '自拍' },
    { value: 'wide', label: '远景' },
  ],
  // ... 其他 style 的 method 选项 ...
}

const categoryLayers = computed(() => {
  const layers = [{
    label: '类型',
    selected: selectedType.value,
    options: [
      { value: 'portrait', label: '人像' },
      { value: 'landscape', label: '风景' },
      { value: 'food', label: '美食' },
      { value: 'street', label: '街拍' },
      { value: 'night', label: '夜景' },
      { value: 'macro', label: '微距' },
      { value: 'still-life', label: '静物' },
    ],
  }]
  if (selectedType.value && STYLE_MAP[selectedType.value]) {
    layers.push({
      label: '风格',
      selected: selectedStyle.value,
      options: STYLE_MAP[selectedType.value],
    })
  }
  if (selectedStyle.value && METHOD_MAP[selectedStyle.value]) {
    layers.push({
      label: '方式',
      selected: selectedMethod.value,
      options: METHOD_MAP[selectedStyle.value],
    })
  }
  return layers
})

function onLayerSelect(idx: number, value: string | null) {
  if (idx === 0) {
    selectedType.value = value as Target | null
    selectedStyle.value = null
    selectedMethod.value = null
  } else if (idx === 1) {
    selectedStyle.value = value
    selectedMethod.value = null
  } else if (idx === 2) {
    selectedMethod.value = value
  }
}

const filteredTemplates = computed(() => {
  let list = showCustom.value ? getCustomTemplates() : getAllTemplates()
  if (selectedType.value) {
    list = list.filter(t => t.meta.classification.type === selectedType.value)
  }
  if (selectedStyle.value) {
    list = list.filter(t => t.meta.classification.style === selectedStyle.value)
  }
  if (selectedMethod.value) {
    list = list.filter(t => t.meta.classification.method === selectedMethod.value)
  }
  if (selectedTagIds.value.length > 0) {
    list = filterTemplatesByTags(selectedTagIds.value, list)
  }
  return list
})
```

- [ ] **Step 2: 更新 template**

```vue
<view class="template-filter">
  <CategoryNav :layers="categoryLayers" @select="onLayerSelect" />
  <view class="template-tags">
    <TagSelector
      :selected-tag-ids="selectedTagIds"
      type="template"
      @update:selected-tag-ids="selectedTagIds = $event"
    />
  </view>
</view>
```

- [ ] **Step 3: 删除局部 sceneToCategory，改用 SCENE_TO_CATEGORY**

在 onLoad 中处理 scene 参数时：
```typescript
import { SCENE_TO_CATEGORY } from '@/data/scenePresets'

onLoad((options) => {
  if (options?.scene) {
    const cat = SCENE_TO_CATEGORY[options.scene as ScenePresetId]
    if (cat) selectedType.value = cat
  }
})
```

- [ ] **Step 4: 验证**

Run: `cd lumira-app && npm run type-check`

Expected: templates/index.vue 无错误。

- [ ] **Step 5: Commit**

```bash
cd lumira-app && git add src/pages/templates/index.vue
git commit -m "feat(page): templates 重构为三层分类 + 标签筛选 + 统一 SCENE_TO_CATEGORY"
```

---

## Task 13: home/inspiration 更新 + 最终验证

**Files:**
- Modify: `lumira-app/src/pages/home/index.vue`
- Modify: `lumira-app/src/pages/inspiration/index.vue`

**Interfaces:**
- Consumes: useSceneManager（getPhotoCountByScene）

**说明:** 场景卡片显示照片数。最终全局验证。

- [ ] **Step 1: 更新 home/index.vue 场景卡片**

在场景卡片中新增照片数显示：
```vue
<text class="scene-stat">📷 {{ getPhotoCountByScene(scene.id) }}</text>
```

确保场景卡片点击跳转到 scene-detail：
```typescript
function goSceneDetail(id: string) {
  uni.navigateTo({ url: `/pages/capture/scene-detail?sceneId=${id}` })
}
```

- [ ] **Step 2: 更新 inspiration/index.vue 场景卡片**

同上，新增照片数显示 + 跳转 scene-detail。

- [ ] **Step 3: 全局 type-check 验证**

Run: `cd lumira-app && npm run type-check`

Expected: 零错误。

- [ ] **Step 4: 验收清单检查**

手动检查 spec 8.3 节非重叠验收：
- [ ] ScenePreset 不再包含 cameraSuggestion / postSuggestion
- [ ] ScenePreset.filter 仅含 lut + systemFilter
- [ ] 场景与模板可独立使用
- [ ] 组合使用时场景滤镜与模板构图姿势同时生效

用 Grep 验证：
```
grep -r "cameraSuggestion" lumira-app/src/  → 应仅在 migrateState 迁移逻辑中出现
grep -r "postSuggestion" lumira-app/src/    → 应仅在 migrateState 迁移逻辑中出现
```

- [ ] **Step 5: Commit**

```bash
cd lumira-app && git add src/pages/home/index.vue src/pages/inspiration/index.vue
git commit -m "feat(pages): home/inspiration 场景卡片显示照片数 + 跳转 scene-detail"
```

---

## 依赖关系图

```
Task 1 (类型) ──┬─→ Task 2 (场景数据) ──┬─→ Task 4 (useSceneManager) ──┬─→ Task 7 (scene-detail)
                │                        ├─→ Task 5 (Tag+Kit)           ├─→ Task 8 (scene-guide)
                ├─→ Task 3 (模板数据)    │                              ├─→ Task 9 (scene-manage)
                │                        │                              ├─→ Task 10 (preview)
                └─→ Task 6 (组件) ───────┴─→ Task 7 (scene-detail)      ├─→ Task 11 (capture)
                                                                       ├─→ Task 12 (templates)
                                                                       └─→ Task 13 (home/inspiration + 验证)
```

- Task 1 是所有任务的基础
- Task 2, 3, 6 可并行（都只依赖 Task 1）
- Task 4, 5 依赖 Task 1, 2
- Task 7-12 依赖 Task 4, 5, 6
- Task 13 是最终验证
