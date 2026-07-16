# 场景模块社交化重构 + 模板分层分类设计

> **日期**：2026-07-16
> **状态**：已确认，待编写实施计划
> **前置工作**：场景管理 v1（2026-07-16-scene-management-design.md）已实现基础 CRUD

---

## 1. 背景与动机

### 1.1 当前问题

经实测发现，当前场景模块（`ScenePreset`）与模板模块（`PhotoTemplate`）存在严重功能重叠：

```
ScenePreset.cameraSuggestion（4 项）⊂ PhotoTemplate.camera（17 项）
ScenePreset.postSuggestion（3 项）  ⊂ PhotoTemplate.postProcess（18 项）
ScenePreset.sceneGuide              = PhotoTemplate.sceneGuide
```

场景模块本质上是"去掉了构图叠图和姿势剪影的阉版模板"，独立价值不足。

### 1.2 重新定位

将场景模块从"参数调整工具"重新定位为 **"场景灵感与氛围引擎"**：

- **弱化参数调整**：仅保留氛围滤镜（LUT + systemFilter），不再调整相机参数
- **强化灵感属性**：增加情绪化文字、示例图、出片地点、拍摄小贴士
- **社交驱动留存**：照片统计、成就系统、场景排行榜
- **与模板互补组合**：场景提供滤镜+氛围，模板提供构图+姿势+参数

### 1.3 新增能力

1. **场景分类**：两层结构（大类 → 风格 → 场景预设）
2. **模板分类**：三层结构（摄影类型 → 拍摄风格 → 拍摄方式）
3. **自定义标签**：场景与模板均可打多个标签，支持标签筛选
4. **拍摄组合（Kit）**：场景+模板一键保存为组合，下次快速调用
5. **照片统计**：每张照片归属场景，驱动成就与排行

---

## 2. 数据模型

### 2.1 场景分类体系（两层结构）

```typescript
/** 场景大类 */
type SceneCategory =
  | 'light'       // 光线氛围
  | 'outdoor'     // 室外环境
  | 'indoor'      // 室内空间
  | 'mood'        // 情绪氛围

/** 场景风格（小类） */
interface SceneStyle {
  id: string          // 如 'window-light', 'sunset-backlight'
  name: string        // 如 '窗光', '日落逆光'
  category: SceneCategory
}

/** 场景大类聚合（用于 UI 分组展示） */
interface SceneCategoryGroup {
  category: SceneCategory
  name: string
  icon: string
  styles: SceneStyle[]
}
```

**分类体系内容**：

```
☀️ 光线氛围 (light)
  ├── window-light    窗光
  ├── sunset-backlight 日落逆光
  ├── neon             霓虹
  └── candle           烛光

🌊 室外环境 (outdoor)
  ├── seaside   海边
  ├── forest    森林
  └── urban     城市

🏠 室内空间 (indoor)
  ├── home       居家
  ├── cafe       咖啡馆店铺
  └── studio     影棚

🎭 情绪氛围 (mood)
  ├── healing    治愈
  ├── lonely     孤独
  └── festive    节日
```

### 2.2 ScenePreset（重构）

```typescript
/** 场景预设 ID（内置） */
type ScenePresetId =
  | 'cafe-window' | 'library-quiet' | 'home-cozy'
  | 'sunset-silhouette' | 'golden-rim-portrait'
  | 'night-street' | 'bar-neon' | 'convenience-store'
  | 'seaside-beach' | 'seaside-rocks' | 'forest-bamboo' | 'forest-maple'
  | 'urban-rooftop' | 'urban-subway'
  | 'bedroom-morning' | 'kitchen-cooking'
  | 'candle-warm' | 'rainy-window'
  // ... 可扩展

/** 氛围滤镜配置 */
interface SceneFilter {
  lut: LutPreset
  systemFilter?: SystemFilter
  /** 选用该滤镜的理由（情绪化说明） */
  reason: string
}

/** 场景预设（重新定位：氛围引擎） */
interface ScenePreset {
  id: ScenePresetId
  name: string
  icon: string

  /** 两层分类 */
  category: SceneCategory
  style: string            // SceneStyle.id

  /* ── 氛围滤镜（唯一保留的"参数"） ── */
  filter: SceneFilter

  /* ── 灵感内容板块（新增） ── */
  /** 情绪化主标题，如「慵懒午后，把光调成蜜糖色」 */
  vibe: string
  /** 场景描述：氛围 + 光线 + 环境 */
  description: string
  /** 示例图 1-3 张（picsum.photos 占位） */
  exampleImages: string[]
  /** 拍摄小贴士 */
  tips: string[]
  /** 出片地点建议 */
  whereToShoot: string
  /** 最佳拍摄时间 */
  bestTime: string

  /* ── 兼容保留 ── */
  /** 保留场景指南文字（仅 tips/lightDirection/background/props） */
  sceneGuide: Omit<SceneGuide, 'presetId'>
  relatedCategory: Target

  /* ── 标签 ── */
  /** 推荐标签 ids（预设自带） */
  recommendedTagIds: string[]
}
```

**字段变更对比**：

| 字段 | 旧版 | 新版 |
|------|------|------|
| cameraSuggestion | 4 项相机参数 | ✗ 删除 |
| postSuggestion | 3 项后期参数 | ✗ 删除 |
| filter | — | ✓ 新增（lut + systemFilter + reason） |
| vibe | — | ✓ 新增 |
| description | 简短描述 | ✓ 增强 |
| exampleImages | — | ✓ 新增 |
| whereToShoot | — | ✓ 新增 |
| bestTime | 在 sceneGuide 内 | ✓ 独立字段 |
| tips | 在 sceneGuide 内 | ✓ 独立字段 |
| recommendedTagIds | — | ✓ 新增 |

### 2.3 CustomScenePreset（自定义场景，同步重构）

```typescript
/** 自定义场景 ID */
export type CustomSceneId = `custom_${string}`

/** 自定义场景预设：复用新 ScenePreset 结构 */
export interface CustomScenePreset extends Omit<ScenePreset, 'id'> {
  id: CustomSceneId
  creator: 'user'
  createdAt: number
  updatedAt: number
  /** 用户自定义标签 ids */
  tagIds: string[]
}

/** 任意场景（预设或自定义） */
export type AnyScene = ScenePreset | CustomScenePreset
```

### 2.4 PhotoTemplate 分类增强（三层结构）

```typescript
/** 模板三层分类 */
interface TemplateClassification {
  /** 摄影类型：人像/风景/美食/街拍/夜景/微距/静物 */
  type: Target
  /** 拍摄风格：如 'japanese'（日系）/ 'emotional'（情绪）/ 'film'（胶片） */
  style: string
  /** 拍摄方式：如 'selfie'（自拍）/ 'overhead'（俯拍）/ 'wide'（远景）/ 'macro'（特写） */
  method: string
}

/** PhotoTemplate meta 扩展 */
interface TemplateMeta {
  id: string
  name: string
  author: string
  version: string
  description: string
  /** 三层分类 */
  classification: TemplateClassification
  tags: string[]                    // 系统标签
  /** 用户自定义标签 ids */
  tagIds: string[]
  cover?: string
  price?: number
  referenceSource?: string
}
```

**模板分类体系**：

```
portrait (人像)
  ├── japanese (日系)
  │     ├── selfie    自拍
  │     ├── normal    他拍
  │     └── overhead  俯拍
  ├── emotional (情绪)
  │     ├── selfie
  │     └── wide      远景
  ├── film (胶片)
  │     └── normal
  └── western (欧美)
        └── normal

landscape (风景)
  ├── fresh (清新)
  │     ├── wide
  │     └── aerial    航拍
  └── epic (大气)
        ├── long-exposure  长曝
        └── slow-shutter   慢门

food (美食)
  ├── overhead (俯拍美食)
  │     └── flat-lay
  └── closeup (特写美食)
        └── macro

street (街拍)
  ├── casual (随性)
  │     └── candid    抓拍
  └── geometric (几何)
        └── architecture

night (夜景)
  ├── neon (霓虹)
  │     └── portrait
  └── starry (星空)
        └── wide

macro (微距)
  ├── nature (自然)
  │     └── flower
  └── object (物品)
        └── texture

still-life (静物)
  ├── minimal (极简)
  │     └── single
  └── flat (扁平)
        └── flat-lay
```

### 2.5 UserTag（自定义标签）

```typescript
/** 用户自定义标签 */
interface UserTag {
  id: string           // `tag_${Date.now()}_${random}`
  name: string
  /** 标签适用范围 */
  type: 'scene' | 'template' | 'both'
  /** 标签颜色（可选，用于 UI 区分） */
  color?: string
  createdAt: number
}

/** 标签存储 */
localStorage key: 'lumira_user_tags'
```

### 2.6 ShootKit（拍摄组合）

```typescript
/** 拍摄组合：场景 + 模板 */
interface ShootKit {
  id: string           // `kit_${Date.now()}_${random}`
  name: string         // 用户命名，如「咖啡馆日系自拍」
  sceneId: ScenePresetId | CustomSceneId
  templateId: string   // PhotoTemplate.meta.id
  /** 可选：用户微调后的参数快照 */
  overrides?: {
    camera?: Partial<CameraParams>
    postProcess?: Partial<PostProcess>
  }
  createdAt: number
  updatedAt: number
  /** 使用次数 */
  useCount: number
  /** 最后使用时间 */
  lastUsedAt?: number
}

/** 组合存储 */
localStorage key: 'lumira_shoot_kits'
```

### 2.7 LocalPhoto（本地照片）

```typescript
/** 本地照片记录（用于场景统计） */
interface LocalPhoto {
  id: string           // `photo_${Date.now()}_${random}`
  /** 照片 dataUrl（压缩后存储） */
  dataUrl: string
  /** 归属场景 ID */
  sceneId: ScenePresetId | CustomSceneId | null
  /** 使用的模板 ID（可选） */
  templateId?: string
  /** 使用的组合 ID（可选） */
  kitId?: string
  /** 情绪标记（可选，用户自定义） */
  mood?: string
  /** 使用的 LUT */
  lut?: LutPreset
  createdAt: number
}

/** 照片存储 */
localStorage key: 'lumira_photos'
```

### 2.8 成就系统

```typescript
/** 场景成就等级 */
interface SceneAchievement {
  sceneId: string
  /** 当前等级（1-5） */
  level: number
  /** 当前等级名称 */
  levelName: string
  /** 累计照片数 */
  photoCount: number
  /** 距离下一等级所需照片数 */
  nextLevelCount: number
}

/** 等级配置 */
const SCENE_LEVELS = [
  { level: 1, name: '初探',  threshold: 1  },
  { level: 2, name: '熟悉',  threshold: 5  },
  { level: 3, name: '达人',  threshold: 15 },
  { level: 4, name: '专家',  threshold: 30 },
  { level: 5, name: '大师',  threshold: 50 },
]
```

---

## 3. Composable 接口设计

### 3.1 useSceneManager（扩展）

```typescript
interface UseSceneManager {
  /* ── 原有（保留） ── */
  customScenes: Readonly<Ref<CustomScenePreset[]>>
  favoritePresetIds: Readonly<Ref<string[]>>
  allScenes: ComputedRef<AnyScene[]>
  favoriteScenes: ComputedRef<AnyScene[]>
  addCustomScene(data: Omit<CustomScenePreset, 'id' | 'creator' | 'createdAt' | 'updatedAt'>): CustomSceneId
  updateCustomScene(id: CustomSceneId, data: Partial<CustomScenePreset>): void
  deleteCustomScene(id: CustomSceneId): void
  toggleFavorite(id: string): void
  isFavorite(id: string): boolean
  getSceneById(id: string): AnyScene | undefined
  isCustomScene(scene: AnyScene): scene is CustomScenePreset

  /* ── 新增：分类 ── */
  /** 按大类分组获取场景 */
  scenesByCategory: ComputedRef<Record<SceneCategory, AnyScene[]>>
  /** 按风格分组获取场景 */
  scenesByStyle: ComputedRef<Record<string, AnyScene[]>>
  /** 获取分类树 */
  sceneCategoryTree: ComputedRef<SceneCategoryGroup[]>

  /* ── 新增：照片统计 ── */
  photos: Readonly<Ref<LocalPhoto[]>>
  /** 添加照片 */
  addPhoto(data: Omit<LocalPhoto, 'id' | 'createdAt'>): string
  /** 删除照片 */
  deletePhoto(id: string): void
  /** 获取指定场景的照片数 */
  getPhotoCountByScene(sceneId: string): number
  /** 获取指定场景的照片列表 */
  getPhotosByScene(sceneId: string): LocalPhoto[]

  /* ── 新增：成就系统 ── */
  /** 获取指定场景的成就信息 */
  getSceneAchievement(sceneId: string): SceneAchievement
  /** 所有场景的成就列表 */
  sceneAchievements: ComputedRef<SceneAchievement[]>

  /* ── 新增：排行榜 ── */
  /** 本周热门场景 TOP N */
  weeklyRanking: ComputedRef<{ scene: AnyScene; photoCount: number; rank: number }[]>
  /** 全场景排行 */
  allTimeRanking: ComputedRef<{ scene: AnyScene; photoCount: number; rank: number }[]>
}
```

### 3.2 useTagManager（新增）

```typescript
interface UseTagManager {
  tags: Readonly<Ref<UserTag[]>>
  /** 按类型筛选标签 */
  getTagsByType(type: UserTag['type']): UserTag[]
  /** 创建标签 */
  createTag(name: string, type: UserTag['type']): string
  /** 更新标签 */
  updateTag(id: string, data: Partial<UserTag>): void
  /** 删除标签 */
  deleteTag(id: string): void
  /** 获取标签下的场景 */
  getScenesByTag(tagId: string): AnyScene[]
  /** 获取标签下的模板 */
  getTemplatesByTag(tagId: string): PhotoTemplate[]
  /** 多标签筛选场景（OR 逻辑） */
  filterScenesByTags(tagIds: string[]): AnyScene[]
  /** 多标签筛选模板（OR 逻辑） */
  filterTemplatesByTags(tagIds: string[]): PhotoTemplate[]
}
```

### 3.3 useShootKit（新增）

```typescript
interface UseShootKit {
  kits: Readonly<Ref<ShootKit[]>>
  /** 创建组合 */
  createKit(data: Omit<ShootKit, 'id' | 'createdAt' | 'updatedAt' | 'useCount'>): string
  /** 更新组合 */
  updateKit(id: string, data: Partial<ShootKit>): void
  /** 删除组合 */
  deleteKit(id: string): void
  /** 获取组合详情（含场景与模板对象） */
  getKitDetail(id: string): { kit: ShootKit; scene: AnyScene; template: PhotoTemplate } | null
  /** 记录使用 */
  recordUsage(id: string): void
  /** 按使用频率排序的组合 */
  recentKits: ComputedRef<ShootKit[]>
}
```

### 3.4 useTemplateManager（扩展）

```typescript
interface UseTemplateManager {
  /* ── 原有 ── */
  templates: Readonly<Ref<PhotoTemplate[]>>
  customTemplates: Readonly<Ref<PhotoTemplate[]>>

  /* ── 新增：三层分类 ── */
  /** 按摄影类型分组 */
  templatesByType: ComputedRef<Record<Target, PhotoTemplate[]>>
  /** 按 (type, style) 分组 */
  templatesByStyle: ComputedRef<Record<string, PhotoTemplate[]>>
  /** 获取分类树 */
  templateCategoryTree: ComputedRef<TemplateCategoryGroup[]>
  /** 按分类筛选 */
  filterByClassification(type?: Target, style?: string, method?: string): PhotoTemplate[]
}
```

---

## 4. UI 设计

### 4.1 场景指南页（scene-guide.vue，重构）

**页面结构**：

```
┌─────────────────────────────────────┐
│  ← 场景灵感                          │
├─────────────────────────────────────┤
│  [全部] [光线氛围] [室外] [室内] [情绪] │ ← 大类 Tab
├─────────────────────────────────────┤
│  窗光  逆光  霓虹  烛光              │ ← 风格横滑
├─────────────────────────────────────┤
│  标签：[暖色调] [适合自拍] [+]        │ ← 标签筛选
├─────────────────────────────────────┤
│  ┌─ 场景卡片 ───────────────────┐   │
│  │ [示例图]  ☕ 咖啡馆            │   │
│  │           「慵懒午后」         │   │
│  │           📷 47  🏆 Lv.3     │   │
│  └─────────────────────────────┘   │
│  ┌─ 场景卡片 ───────────────────┐   │
│  │ ...                          │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 4.2 场景详情页（新增 scene-detail.vue）

```
┌─────────────────────────────────────┐
│  ← 咖啡馆                    ❤️ 收藏  │
├─────────────────────────────────────┤
│  ┌─ 示例图轮播 ─────────────────┐   │
│  │       [img1] [img2] [img3]   │   │
│  │       ● ○ ○                  │   │
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│  ☕ 咖啡馆                            │
│  「慵懒午后，把光调成蜜糖色」           │
│                                     │
│  🏷️ [窗光] [暖色调] [室内]            │
├─────────────────────────────────────┤
│  ┌─ 氛围 ───────────────────────┐   │
│  │ 适合下午 2-5 点，当阳光斜照    │   │
│  │ 进落地窗，整个世界都慢了下来。 │   │
│  │ 📍 咖啡馆 / 图书馆 / 居家窗边  │   │
│  │ 🕐 最佳时间：下午 2-5 点       │   │
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│  ┌─ 推荐滤镜 ───────────────────┐   │
│  │ 🎞️ warm_film                 │   │
│  │ 色温偏暖 +20，对比度 +10，    │   │
│  │ 像被午后的光晒软了。           │   │
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│  ┌─ 拍摄小贴士 ──────────────────┐   │
│  │ • 让模特面朝窗户               │   │
│  │ • 大光圈虚化背景               │   │
│  │ • 咖啡杯做前景更有氛围          │   │
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│  ┌─ 我的成就 ───────────────────┐   │
│  │ 📷 47 张   🏆 咖啡馆达人 Lv.3 │   │
│  │ 进度条 ████████░░ 47/50       │   │
│  │ 🔥 本周热门 #2                │   │
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│  [ 用此场景拍照 ]  [ 加入组合 ]      │
└─────────────────────────────────────┘
```

### 4.3 拍摄页（capture/index.vue，增强）

**底部新增"我的组合"横滑区**：

```
┌─────────────────────────────────────┐
│  取景器（构图叠图 + 姿势剪影）        │
├─────────────────────────────────────┤
│  我的组合 →                          │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │☕📓│ │🌅👤│ │🌙🌃│ │+   │       │
│  │馆日│ │落人│ │夜街│ │新建│       │
│  └────┘ └────┘ └────┘ └────┘       │
├─────────────────────────────────────┤
│  当前场景：咖啡馆 warm_film          │
│  当前模板：日系咖啡馆人像             │
├─────────────────────────────────────┤
│  [快门]                             │
└─────────────────────────────────────┘
```

点击组合卡片 → 一键加载场景滤镜 + 模板构图姿势 + 参数面板

### 4.4 预览页（capture/preview.vue，增强）

**场景选择器改用真实数据**：

```
┌─────────────────────────────────────┐
│  预览                                │
│  [照片预览]                          │
├─────────────────────────────────────┤
│  归属场景：                          │
│  ☕ 咖啡馆 (47张)  🌅 日落 (12张)    │
│  🌃 夜街 (8张)     ➕ 不标记          │
├─────────────────────────────────────┤
│  情绪标记（可选）：                   │
│  [开心] [放松] [孤独] [自定义]        │
├─────────────────────────────────────┤
│  [保存]  [保存为新组合]              │
└─────────────────────────────────────┘
```

### 4.5 模板库页（templates/index.vue，重构）

**三层分类导航**：

```
┌─────────────────────────────────────┐
│  ← 模板库                            │
├─────────────────────────────────────┤
│  [人像] [风景] [美食] [街拍] [夜景]   │ ← 摄影类型
├─────────────────────────────────────┤
│  人像 > 风格：                       │
│  [日系] [情绪] [胶片] [欧美]          │ ← 拍摄风格
├─────────────────────────────────────┤
│  日系 > 拍摄方式：                    │
│  [自拍] [他拍] [俯拍] [远景]          │ ← 拍摄方式
├─────────────────────────────────────┤
│  标签：[文艺] [暖色] [+]             │ ← 标签筛选
├─────────────────────────────────────┤
│  ┌─ 模板卡片 ───────────────────┐   │
│  │ [封面] 日系咖啡馆人像          │   │
│  │        🏷️ 文艺 暖色           │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 4.6 场景管理页（scene-manage.vue，增强）

**新增"组合"Tab**：

```
┌─────────────────────────────────────┐
│  ← 场景管理                          │
├─────────────────────────────────────┤
│  [我的收藏] [自定义场景] [我的组合]   │ ← 三 Tab
├─────────────────────────────────────┤
│  我的组合：                          │
│  ┌─ 组合卡片 ───────────────────┐   │
│  │ ☕📓 咖啡馆日系自拍             │   │
│  │      场景:咖啡馆 模板:日系人像  │   │
│  │      使用 12 次               │   │
│  └──────────────────────────────┘   │
│  ┌─ 组合卡片 ───────────────────┐   │
│  │ ...                          │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 5. 数据迁移策略

### 5.1 ScenePreset 迁移

10 个现有预设迁移到新结构：

| 旧 ID | 新分类 | 新风格 | 删除字段 | 新增字段 |
|-------|--------|--------|---------|---------|
| cafe | indoor / cafe | window-light | cameraSuggestion, postSuggestion | filter, vibe, exampleImages, whereToShoot |
| street | outdoor / urban | casual | 同上 | 同上 |
| seaside | outdoor / seaside | beach | 同上 | 同上 |
| macro | (废弃，归入模板微距) | — | — | — |
| night | light / neon | night-street | 同上 | 同上 |
| food | (废弃，归入模板美食) | — | — | — |
| home | indoor / home | bedroom-morning | 同上 | 同上 |
| sunset | light / sunset-backlight | golden-rim | 同上 | 同上 |
| forest | outdoor / forest | forest-bamboo | 同上 | 同上 |
| indoor | indoor / studio | studio | 同上 | 同上 |

**新增场景预设**（补充分类体系）：

- `library-quiet` 图书馆（indoor/cafe, window-light）
- `home-cozy` 居家温馨（indoor/home, bedroom-morning）
- `golden-rim-portrait` 金边逆光人像（light/sunset-backlight）
- `bar-neon` 酒吧霓虹（light/neon）
- `convenience-store` 便利店（light/neon）
- `seaside-rocks` 海边礁石（outdoor/seaside）
- `forest-maple` 枫叶林（outdoor/forest）
- `urban-rooftop` 城市天台（outdoor/urban）
- `urban-subway` 地铁站（outdoor/urban）
- `kitchen-cooking` 厨房烹饪（indoor/home）
- `candle-warm` 烛光（light/candle）
- `rainy-window` 雨天窗边（mood/healing）

### 5.2 PhotoTemplate 迁移

12 个现有模板补充 `classification` 字段：

| 旧 category | 新 classification |
|-------------|-------------------|
| portrait | `{ type: 'portrait', style: 'japanese', method: 'normal' }` |
| landscape | `{ type: 'landscape', style: 'fresh', method: 'wide' }` |
| food | `{ type: 'food', style: 'overhead', method: 'flat-lay' }` |
| ... | ... |

### 5.3 localStorage 兼容

- `lumira_scene_manager`：保留 favorites 和 customScenes
- `lumira_user_tags`：新增
- `lumira_shoot_kits`：新增
- `lumira_photos`：新增
- 自定义场景数据结构变更：旧 customScenes 读取时做一次迁移（删除 cameraSuggestion/postSuggestion，补默认 vibe/description）

---

## 6. 文件清单

### 6.1 新增文件

| 文件 | 内容 |
|------|------|
| `composables/useTagManager.ts` | 标签管理 composable |
| `composables/useShootKit.ts` | 拍摄组合 composable |
| `pages/capture/scene-detail.vue` | 场景详情页 |
| `components/SceneFilterBadge.vue` | 滤镜徽章组件 |
| `components/SceneAchievementCard.vue` | 成就卡片组件 |
| `components/TagSelector.vue` | 标签选择器组件 |
| `components/KitCard.vue` | 组合卡片组件 |
| `components/CategoryNav.vue` | 分类导航组件（可复用） |

### 6.2 修改文件

| 文件 | 修改内容 |
|------|---------|
| `types/template.ts` | ScenePreset 重构 + TemplateClassification + ShootKit + UserTag + LocalPhoto |
| `data/scenePresets.ts` | 10 个预设迁移 + 新增 12 个预设 |
| `data/templates/*.ts` | 12 个模板加 classification |
| `composables/useSceneManager.ts` | 加分类/照片统计/成就/排行 |
| `composables/useTemplateManager.ts` | 加三层分类/标签筛选 |
| `pages/capture/preview.vue` | 场景选择器改真实数据 + 保存 LocalPhoto |
| `pages/capture/index.vue` | 自动场景标记 + 组合快速入口 |
| `pages/capture/scene-guide.vue` | 重构：两层分类 + 标签筛选 + 卡片显示统计 |
| `pages/capture/scene-manage.vue` | 加"我的组合" Tab |
| `pages/templates/index.vue` | 重构：三层分类 + 标签筛选 |
| `pages.json` | 新增 scene-detail 路由 |
| `pages/home/index.vue` | 场景卡片显示照片数 |
| `pages/inspiration/index.vue` | 场景卡片显示照片数 |

---

## 7. 全局约束（沿用项目规则）

- 所有页面使用 uni-app 组件（`<view>` 而非 `<div>`，`<text>` 而非 `<span>`，`<image>` 而非 `<img>`）
- CSS 单位使用 rpx 而非 px
- 所有图片资源来自 picsum.photos
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

---

## 8. 验收清单

### 8.1 功能验收

- [ ] 场景预设数据完成迁移，10 旧预设 + 12 新预设全部可用
- [ ] 场景分类两层结构正确显示（4 大类 × 多风格）
- [ ] 场景详情页显示：示例图轮播 + 氛围文字 + 推荐滤镜 + 拍摄小贴士 + 成就
- [ ] 拍照后照片正确归属选定场景
- [ ] 场景卡片显示照片数 + 成就等级
- [ ] 场景排行榜按周更新
- [ ] 模板三层分类正确显示
- [ ] 自定义标签可创建/编辑/删除
- [ ] 标签筛选场景/模板（OR 逻辑）正确
- [ ] 拍摄组合可创建/编辑/删除
- [ ] 拍摄页组合横滑区一键加载场景+模板
- [ ] 预览页场景选择器显示真实数据
- [ ] localStorage 持久化（tags/kits/photos）

### 8.2 技术验收

- [ ] `npm run type-check` 零错误
- [ ] 无破坏性变更：旧 localStorage 数据可读取并自动迁移
- [ ] 所有新增组件遵循 uni-app 组件规范
- [ ] 所有样式使用 rpx 单位
- [ ] 所有图片使用 picsum.photos

### 8.3 非重叠验收

- [ ] ScenePreset 不再包含 cameraSuggestion / postSuggestion
- [ ] ScenePreset.filter 仅含 lut + systemFilter，不含其他相机参数
- [ ] 场景与模板可独立使用，也可组合使用
- [ ] 组合使用时场景滤镜与模板构图姿势同时生效

---

## 9. 后续扩展方向（非本次实施）

- 场景社区：用户上传自定义场景到云端，分享给其他用户
- 照片瀑布流：场景详情页显示该场景下所有用户照片
- 成就徽章：解锁成就时推送通知，徽章可展示在个人主页
- 组合市场：组合包分享、下载
- AI 推荐：根据用户拍照历史推荐相似场景
