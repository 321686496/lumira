# 如画 Lumira 场景管理功能设计

> 本设计基于已完成的"场景推荐功能完善"计划（2026-07-15），在其基础上新增场景管理页、打通首页→场景指南跳转、对接场景数据流。

**Goal:** 提供独立的场景管理页支持自定义场景 CRUD 与预设收藏，修复首页/灵感页场景卡片的跳转断链，统一场景数据流。

**Architecture:** 新增 `scene-manage.vue` 管理页 + `useSceneManager.ts` composable 持久层；修改 `home/index.vue`、`inspiration/index.vue`、`scene-guide.vue` 接入场景管理器；自定义场景复用 `ScenePreset` 接口，localStorage 持久化。

## 全局约束

- 所有页面必须使用 uni-app 组件（`<view>`/`<text>`/`<image>` 而非 `<div>`/`<span>`/`<img>`）
- CSS 单位必须使用 rpx 而非 px
- 所有样式（全局和 scoped）只能使用 class 选择器，不可使用标签选择器
- 类型检查命令：`npm run type-check`（在 `lumira-app` 目录下运行），必须零错误
- `<scroll-view scroll-x>` 内部容器必须 `display: inline-flex`，scroll-view 本身需 `white-space: nowrap`
- pill 类元素必须 `display: inline-flex; align-items: center;`
- 自定义场景 id 以 `custom_` 前缀区分（如 `custom_1`），避免与预设 id 冲突
- localStorage key 统一使用 `lumira_scene_manager`（单 key 存储整个 SceneManagerState，包含 customScenes / favoritePresetIds / customOrder）

## 1. 数据模型

自定义场景复用 `ScenePreset` 接口（来自 `@/types/template`），仅 id 和元数据不同：

```typescript
// 自定义场景：id 带 custom_ 前缀，creator 为 'user'
type CustomScenePreset = ScenePreset & {
  id: `custom_${string}`  // 如 'custom_1', 'custom_2'
  creator: 'user'
  createdAt: number        // 创建时间戳
  updatedAt: number        // 更新时间戳
}
```

持久化结构：

```typescript
interface SceneManagerState {
  customScenes: CustomScenePreset[]   // 用户创建的场景
  favoritePresetIds: ScenePresetId[]  // 收藏的预设 id
  customOrder: string[]               // 自定义场景排序（id 列表）
}
```

## 2. composables/useSceneManager.ts（新建）

### 接口

```typescript
function useSceneManager(): {
  // 状态（computed）
  customScenes: ComputedRef<CustomScenePreset[]>
  favoritePresetIds: ComputedRef<ScenePresetId[]>
  allScenes: ComputedRef<ScenePreset[]>           // SCENE_PRESETS + customScenes
  favoriteScenes: ComputedRef<ScenePreset[]>      // 收藏的预设，按收藏顺序

  // 自定义场景 CRUD
  addCustomScene: (scene: Omit<CustomScenePreset, 'id' | 'createdAt' | 'updatedAt'>) => CustomScenePreset
  updateCustomScene: (id: string, patch: Partial<CustomScenePreset>) => void
  deleteCustomScene: (id: string) => void

  // 收藏预设
  toggleFavorite: (presetId: ScenePresetId) => void
  isFavorite: (presetId: ScenePresetId) => boolean

  // 工具
  getSceneById: (id: string) => ScenePreset | CustomScenePreset | undefined
  isCustomScene: (scene: ScenePreset | CustomScenePreset) => scene is CustomScenePreset
}
```

### 持久化策略

- `uni.setStorageSync('lumira_scene_manager', state)` 写
- `uni.getStorageSync('lumira_scene_manager')` 读（`onLoad`/`onShow` 时刷新）
- 防读取异常：try-catch + 默认值 `{ customScenes: [], favoritePresetIds: [], customOrder: [] }`

## 3. ScenePresetView 组件（新建）

为避免 home/inspiration/scene-guide 三处场景卡片模板重复，抽取共用组件：

```vue
<!-- components/ScenePresetView.vue -->
<props>
  scene: ScenePreset | CustomScenePreset
  size: 'full' | 'mini'   // full=大图+描述, mini=紧凑
</props>
<emits>
  click: (id: string)
</emits>
```

- 展示：图标、名称、描述（custom 标签 "自定义"）
- 发布 `click` 事件携 scene id

## 4. pages/capture/scene-manage.vue（新建）

### 整体结构

```
顶部导航（返回 + 标题"场景管理" + 占位）
  └── Tab 栏（"我的收藏" | "自定义场景"）
      └── Tab 内容区
```

### Tab 1：我的收藏（Preset Favorites）

```
提示文案："收藏的场景会出现在首页和你收录的模板中"
  └── 收藏预设网格（2列）
      ├── ScenePresetView（size=full）：展示预设信息 + 收藏按钮 ★
      └── 每个卡片支持：点击跳转 scene-guide，收藏按钮 toggleFavorite
```

- 空状态：未收藏任何预设时显示引导"去场景指南发现更多"按钮

### Tab 2：自定义场景 CRUD

```
自定义列表（纵向卡片）
  ├── ScenePresetView（size=full）：展示自定义场景 + 更多按钮（⋮）
  │     └── 更多菜单：编辑 | 删除
  └── 底部"新建场景"按钮

新建/编辑表单（内联展开区域，不跳页）
  字段：name、icon（Phosphor 选择器 grid）、category
        lightDirection、shootingDistance、background
        cameraSuggestion.whiteBalance、cameraSuggestion.photographicStyle
        postSuggestion.lut
  底部按钮：取消 | 保存
```

### 交互

- 删除确认：uni.showModal 确认后 deleteCustomScene
- 表单校验：name 为空时 toast 提示并阻止保存
- icon 选择器：使用 scroll-x 展示常用 Phosphor 图标（coffee, camera, sun, flower, building, car, paw-print, fork-knife, mountain, snowflake, lightning, leaf），点击选中高亮
- 离开编辑时若有未保存变更，showModal 二次确认

### 新建场景默认值

```typescript
const defaultCustomScene = {
  name: '',
  icon: 'ph-camera',
  category: 'portrait' as Target,
  description: '',
  sceneGuide: {
    lightDirection: '自然光',
    shootingDistance: '1-2米',
    background: '简洁背景',
    props: [],
    bestTime: '全天',
    tips: []
  },
  cameraSuggestion: { whiteBalance: 'daylight' as WhiteBalance, photographicStyle: 'standard' as PhotographicStyle },
  postSuggestion: { lut: 'none' as LutPreset },
  relatedCategory: 'portrait' as Target
}
```

## 5. 首页集成（pages/home/index.vue）

### 场景推荐区变更

**数据：**
```typescript
// 预览场景 = 预设前 4 + 自定义前 4（不足补预设），最多 8 个
const displayScenes = computed(() => {
  const presets = SCENE_PRESETS.slice(0, 4)
  const customs = customScenes.value.slice(0, 4)
  const merged = [...customs, ...presets].slice(0, 8)
  return merged
})
```

**跳转修复：**
```typescript
const goScene = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-guide?scenePreset=${id}` })
```

**管理链接修复：**
当前 home/index.vue 的"管理"文字（约 125 行 `<text class="lumira-section-link">管理</text>`）无 `@click` 绑定，点击无响应。修复为：
```html
<text class="lumira-section-link" @click="goSceneManage">管理</text>
```
```typescript
const goSceneManage = () => uni.navigateTo({ url: '/pages/capture/scene-manage' })
```

**收藏入口（新增）：**
在"管理"链接旁增加"收藏"文字链，跳转 scene-manage 的收藏 Tab：
```html
<text class="lumira-section-link" @click="goSceneFav">收藏</text>
```
```typescript
const goSceneFav = () => uni.navigateTo({ url: '/pages/capture/scene-manage?tab=fav' })
```

### 导入变更

```typescript
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'
import ScenePresetView from '@/components/ScenePresetView.vue'
```

## 6. 灵感页集成（pages/inspiration/index.vue）

**场景卡片变更：**
```typescript
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'

const scenes = computed(() => {
  const customs = customScenes.value.slice(0, 4)
  const presets = SCENE_PRESETS.filter(s => !customs.find(c => c.id === s.id)).slice(0, 4)
  return [...customs, ...presets]
})

const goScene = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-guide?scenePreset=${id}` })
```

- 卡片点击绑定 goScene(s.id)
- "发现更多场景"链接绑定 goSceneManage

## 7. 场景指南页集成（pages/capture/scene-guide.vue）

### Tab 切换修复（当前 Tab 切换无效果）

当前三个 Tab（常用/收藏/推荐）切换时内容不变。修复为根据 Tab 切换显示内容：

```typescript
const tabList = [
  { label: '常用场景', value: 'common' },
  { label: '收藏场景', value: 'fav' },
  { label: '推荐场景', value: 'recommend' }
]

// 常用场景 = SCENE_PRESETS 前 8 个 + 自定义场景
const myScenes = computed(() => [...customScenes.value, ...SCENE_PRESETS.slice(0, 8)])
// 收藏场景 = favoriteScenes（按收藏顺序）
const favScenes = favoriteScenes
// 推荐场景 = SCENE_PRESETS 后 2 个
const recommendScenes = SCENE_PRESETS.slice(8)

// 当前 Tab 对应的列表
const currentList = computed(() => {
  if (tab.value === 'fav') return favScenes.value
  if (tab.value === 'recommend') return recommendScenes
  return myScenes.value
})
```

模板中「我的场景」区块改为根据 `currentList` 渲染单一列表（Tab='common' 时标题"我的场景"，Tab='fav' 时标题"我的收藏"，Tab='recommend' 时标题"推荐场景"），不再同时显示两个区块。

### 收藏按钮

收藏按钮放在**每个场景列表项的右侧**（箭头之前），以及**小贴士卡片标题栏**：

**列表项收藏按钮：**
```html
<view class="scene-item" v-for="preset in currentList" :key="preset.id" @click="onSceneTap(preset)">
  <view class="scene-item-icon">...</view>
  <view class="scene-item-text">...</view>
  <!-- 收藏按钮（仅预设场景显示，自定义场景不显示） -->
  <view v-if="!isCustomScene(preset)" class="fav-btn" @click.stop="onToggleFav(preset.id)">
    <text class="ph" :class="isFavorite(preset.id) ? 'ph-star-fill' : 'ph-star'"></text>
  </view>
  <text class="ph ph-caret-right scene-item-arrow"></text>
</view>
```

**小贴士卡片收藏按钮：**
```html
<view class="tip-detail-head">
  <text class="ph ph-lightbulb tip-detail-icon"></text>
  <text class="tip-detail-title">{{ selectedPreset.name }} · 拍摄小贴士</text>
  <!-- 收藏按钮（仅预设场景显示） -->
  <view v-if="selectedPreset && !isCustomScene(selectedPreset)" class="fav-btn-tip" @click="onToggleFav(selectedPreset.id)">
    <text class="ph" :class="isFavorite(selectedPreset.id) ? 'ph-star-fill' : 'ph-star'"></text>
  </view>
</view>
```

**渲染逻辑：**
- 预设场景：根据 `isFavorite(preset.id)` 显示实心 `ph-star-fill` 或空心 `ph-star`
- 自定义场景：不显示收藏按钮（`v-if="!isCustomScene(preset)"` 控制）
- `@click.stop` 阻止冒泡到列表项的 `onSceneTap`

### 脚本逻辑

```typescript
import { useSceneManager } from '@/composables/useSceneManager'

const { customScenes, favoriteScenes, favoritePresetIds, toggleFavorite, isFavorite, isCustomScene, getSceneById } = useSceneManager()

const onToggleFav = (id: string) => {
  toggleFavorite(id as ScenePresetId)
}
```

### onAdd 修复

当前 `onAdd` 仅 toast。改为跳转场景管理页的自定义场景 Tab：

```typescript
const onAdd = () => {
  uni.navigateTo({ url: '/pages/capture/scene-manage?tab=custom' })
}
```

### onMoreRecommend 修复

当前 `onMoreRecommend` 仅 toast。改为跳转场景管理页的收藏 Tab：

```typescript
const onMoreRecommend = () => {
  uni.navigateTo({ url: '/pages/capture/scene-manage?tab=fav' })
}
```

### onLoad 参数兼容

当前 scene-guide.vue onLoad 仅读 `options?.scene`，但 home/inspiration 页面跳转使用 `?scenePreset=` 参数。修改 onLoad 同时兼容两种参数名，并支持 custom_ 前缀的自定义场景查找：

```typescript
onLoad((options) => {
  const sceneId = options?.scene || options?.scenePreset
  if (sceneId) {
    // 同时查找预设和自定义场景
    const scene = getSceneById(sceneId)
    if (scene) {
      selectedPreset.value = scene
      // 自定义场景定位到常用 Tab，预设场景定位到推荐 Tab
      tab.value = isCustomScene(scene) ? 'common' : 'recommend'
    }
  }
})
```

## 8. 文件影响清单

| 文件路径 | 操作 | 改动内容 |
|----------|------|----------|
| `lumira-app/src/components/ScenePresetView.vue` | **新建** | 通用场景卡片组件（size=full/mini） |
| `lumira-app/src/composables/useSceneManager.ts` | **新建** | 场景管理 composable（CRUD + 收藏 + 持久化 + isCustomScene） |
| `lumira-app/src/pages/capture/scene-manage.vue` | **新建** | 场景管理页（双 Tab + CRUD 表单） |
| `lumira-app/src/pages.json` | 修改 | 注册 `pages/capture/scene-manage` 路由 |
| `lumira-app/src/pages/home/index.vue` | 修改 | 场景区数据源更新；"管理"链接 @click 修复；新增"收藏"链接 |
| `lumira-app/src/pages/inspiration/index.vue` | 修改 | 场景卡片数据源更新；添加点击跳转；"发现更多"链接跳转 |
| `lumira-app/src/pages/capture/scene-guide.vue` | 修改 | Tab 切换修复（内容随 Tab 变化）；收藏按钮（列表项 + 小贴士卡片）；onAdd/onMoreRecommend 跳转修复 |

## 9. 类型设计

### CustomScenePreset

```typescript
export type CustomSceneId = `custom_${string}`

export interface CustomScenePreset extends Omit<ScenePreset, 'id'> {
  id: CustomSceneId
  creator: 'user'
  createdAt: number
  updatedAt: number
}
```

### SceneManager 持久化接口

```typescript
interface PersistedSceneManager {
  version: 1
  customScenes: CustomScenePreset[]
  favoritePresetIds: ScenePresetId[]
  customOrder: CustomSceneId[]
}
```

### 工具类型

```typescript
// 联合类型：任何场景来源
type AnyScene = ScenePreset | CustomScenePreset

// 用于判断是否为自定义场景
function isCustomScene(scene: AnyScene): scene is CustomScenePreset {
  return scene.id.startsWith('custom_')
}
```

## 10. 验证清单

实施完成后手动验证项（H5 开发模式）：

1. **首页：**
   - 场景推荐区显示 SCENE_PRESETS 前 4 个场景
   - 如有自定义场景，出现在最前
   - 点击场景卡片 → 跳转 scene-guide 并正确高亮
   - 点击"管理" → 场景管理页
2. **场景管理页：**
   - 收藏预设 Tab：10 个预设，可收藏/取消收藏
   - 自定义场景 Tab：空状态 → 新建表单 → 保存后出现在列表 → 编辑/删除
   - 新建表单 icon 选择器正常
   - 删除确认弹窗
3. **灵感页：** 场景卡片点击跳转 scene指南，"发现更多"跳转管理页
4. **场景指南页：** Tab 切换正常（常用/收藏/推荐内容随 Tab 变化）；列表项和小贴士卡片的收藏按钮可见，点击收藏/取消；onAdd 跳转管理页自定义 Tab；onMoreRecommend 跳转管理页收藏 Tab；onLoad 接收 `?scene=` 或 `?scenePreset=` 参数正确定位场景（含 custom_ 前缀的自定义场景）
5. **数据持久化：** 关闭小程序再打开，自定义场景和收藏依然存在
6. **类型检查：** `npm run type-check` 零错误

## 11. 边界条件与错误处理

- localStorage 读取异常：catch + 默认值重新写入
- 自定义场景 id 生成：`custom_${Date.now()}`。若在极端并发下产生冲突（同毫秒），追加 `_${Math.random().toString(36).slice(2, 6)}` 保证唯一。
- 空值保护：自定义场景表单 name 为空时 toast 提示
- 删除确认：uni.showModal 二次确认
- 未保存表单离开：有未保存变更时 showModal 确认
- 自定义场景跳转：scene-guide 接收 custom_ 前缀 id 时需兼容查找 allScenes

## 12. 风格与约定

- 遵循现有组件设计语言（`lumira-card`、`lumira-card-hover`、`lumira-tag`、`phosphor` 图标）
- 复用现有颜色变量：`--color-brand`、`--color-surface-alt`、`--color-divider` 等
- composable 命名遵循 `useXxx` 模式，与 `useTemplate`、`useTemplateIO` 一致
- 修改已有文件时保持现有代码风格（不顺手重构其他部分）

## V2 增强章节（2026-07-17）

### 场景标签系统
- 场景详情页支持标签 add/display
- 预设场景使用 recommendedTagIds（只读，预设自带）
- 自定义场景使用 tagIds（可增删，用户自定义）
- 通过 `useTagManager.updateSceneTags` 统一管理
- TagSelector 组件复用（type='scene'）

### 独立场景库页面
- 新增 `/pages/scenes/index.vue`（非 tab 页，含返回按钮）
- 从多入口跳转（首页"查看全部"、拍摄页、个人中心）
- 分类 tab + grid 2 列展示
- 复用 `ScenePresetView variant="list"`

### 滤镜合法性校验
- 场景引用的 systemFilter 必须是 `SYSTEM_FILTERS` 中存在的
- 通过 scene-manage 表单下拉限制 systemFilter 选项（用户只能选预设中的合法值）
- 未单独实现运行时 `isFilterRegistered` 校验函数（表单限制已足够防止非法值）

### 组合编辑器
- 新增 `/pages/shootkit/editor.vue`
- scene-detail "加入组合"按钮跳转到此页
- 支持选择模板 + 参数覆盖（EV/WB/ISO）
- ShootKit 数据结构含 sceneId + templateId + overrides
