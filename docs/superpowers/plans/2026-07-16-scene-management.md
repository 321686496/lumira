# 如画场景管理功能 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现场景管理页（自定义场景 CRUD + 预设收藏），修复首页/灵感页/场景指南页的场景跳转断链与 Tab 切换无效问题，统一场景数据流。

**Architecture:** 新增 `useSceneManager.ts` composable 作为场景持久层（module-level singleton state + localStorage），新增 `ScenePresetView.vue` 通用卡片组件，新增 `scene-manage.vue` 管理页（双 Tab + 内联表单），修改 home/inspiration/scene-guide 三页接入场景管理器。

**Tech Stack:** uni-app (Vue 3 + TypeScript), SCSS, vue-tsc 类型检查, Phosphor Icons, localStorage (uni.setStorageSync)

## Global Constraints

- 所有页面必须使用 uni-app 组件（`<view>` 而非 `<div>`，`<text>` 而非 `<span>`，`<image>` 而非 `<img>`）
- CSS 单位必须使用 rpx 而非 px
- 所有样式（全局和 scoped）只能使用 class 选择器，不可使用标签选择器
- 类型检查命令：`npm run type-check`（在 `lumira-app` 目录下运行），必须零错误
- `<scroll-view scroll-x>` 内部容器必须 `display: inline-flex`，scroll-view 本身需 `white-space: nowrap`
- pill 类元素必须 `display: inline-flex; align-items: center;`
- 自定义场景 id 以 `custom_` 前缀区分（如 `custom_1`），避免与预设 id 冲突
- localStorage key 统一使用 `lumira_scene_manager`（单 key 存储整个 state）
- 标题栏文本不应居中对齐
- 非_tabbar 页面不带 tab bar（scene-manage、scene-guide 均为 `no-tabbar`）
- 所有图片资源必须来自 picsum.photos（本计划场景预设无图片字段，不涉及）
- composable 命名遵循 `useXxx` 模式，与 `useTemplate`、`useTemplateIO` 一致
- 修改已有文件时保持现有代码风格（不顺手重构其他部分）
- SCSS 变量在 template 内联 style 中不生效，需使用具体颜色值或 class
- CSS 自定义属性 `var(--xxx)` 在 scoped 样式中可用（通过 App.vue 全局注入）

---

### Task 1: 类型系统扩展（types/template.ts）

**Files:**
- Modify: `lumira-app/src/types/template.ts`

**Interfaces:**
- Consumes: `ScenePreset`（现有）、`ScenePresetId`（现有）
- Produces: `CustomSceneId` 类型、`CustomScenePreset` 接口。Task 2 的 useSceneManager 依赖这些类型。

- [ ] **Step 1: 在 ScenePreset 接口之后新增 CustomSceneId 和 CustomScenePreset**

在 `lumira-app/src/types/template.ts` 文件中，找到 `ScenePreset` 接口定义（约 256-271 行），在其后（`PhotoTemplate` 接口之前）新增：

```typescript
/** 自定义场景 ID */
export type CustomSceneId = `custom_${string}`

/** 自定义场景预设：用户创建的场景，复用 ScenePreset 结构 */
export interface CustomScenePreset extends Omit<ScenePreset, 'id'> {
  id: CustomSceneId
  creator: 'user'
  createdAt: number
  updatedAt: number
}

/** 任意场景（预设或自定义） */
export type AnyScene = ScenePreset | CustomScenePreset
```

- [ ] **Step 2: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。新增类型不影响现有代码。

- [ ] **Step 3: 提交**

```bash
cd lumira-app
git add src/types/template.ts
git commit -m "feat(types): 新增 CustomSceneId/CustomScenePreset/AnyScene 类型"
```

---

### Task 2: useSceneManager composable（composables/useSceneManager.ts）

**Files:**
- Create: `lumira-app/src/composables/useSceneManager.ts`

**Interfaces:**
- Consumes: `ScenePreset`、`ScenePresetId`、`CustomScenePreset`、`CustomSceneId`、`AnyScene`（from Task 1），`SCENE_PRESETS`（from `@/data/scenePresets`）
- Produces: `useSceneManager()` composable，返回 `customScenes`、`favoritePresetIds`、`allScenes`、`favoriteScenes`、`addCustomScene`、`updateCustomScene`、`deleteCustomScene`、`toggleFavorite`、`isFavorite`、`getSceneById`、`isCustomScene`。Task 3-7 均依赖此 composable。

- [ ] **Step 1: 创建 composable 文件**

创建 `lumira-app/src/composables/useSceneManager.ts`，完整内容如下：

```typescript
/**
 * 场景管理组合式函数
 *
 * 提供自定义场景 CRUD、预设收藏、localStorage 持久化。
 * 使用 module-level ref 实现跨组件共享的单例状态。
 */

import { computed, ref } from 'vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type {
  ScenePreset,
  ScenePresetId,
  CustomScenePreset,
  CustomSceneId,
  AnyScene
} from '@/types/template'

const STORAGE_KEY = 'lumira_scene_manager'

interface PersistedState {
  customScenes: CustomScenePreset[]
  favoritePresetIds: ScenePresetId[]
  customOrder: string[]
}

const DEFAULT_STATE: PersistedState = {
  customScenes: [],
  favoritePresetIds: [],
  customOrder: []
}

/** 从 localStorage 读取状态 */
function loadState(): PersistedState {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (!raw) return { ...DEFAULT_STATE }
    return {
      customScenes: Array.isArray(raw.customScenes) ? raw.customScenes : [],
      favoritePresetIds: Array.isArray(raw.favoritePresetIds) ? raw.favoritePresetIds : [],
      customOrder: Array.isArray(raw.customOrder) ? raw.customOrder : []
    }
  } catch {
    return { ...DEFAULT_STATE }
  }
}

/** 写入 localStorage */
function saveState(state: PersistedState): void {
  try {
    uni.setStorageSync(STORAGE_KEY, state)
  } catch {
    // 忽略写入异常
  }
}

/** 生成唯一自定义场景 ID */
function generateCustomId(): CustomSceneId {
  return `custom_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`
}

/** 判断是否为自定义场景 */
function isCustomScene(scene: AnyScene): scene is CustomScenePreset {
  return scene.id.startsWith('custom_')
}

/** module-level 单例状态（跨组件共享） */
const state = ref<PersistedState>(loadState())

/** 持久化写入 */
function persist() {
  saveState(state.value)
}

export function useSceneManager() {
  const customScenes = computed(() => state.value.customScenes)
  const favoritePresetIds = computed(() => state.value.favoritePresetIds)

  const allScenes = computed<AnyScene[]>(() => {
    return [...state.value.customScenes, ...SCENE_PRESETS]
  })

  const favoriteScenes = computed<ScenePreset[]>(() => {
    return state.value.favoritePresetIds
      .map(id => SCENE_PRESETS.find(p => p.id === id))
      .filter((p): p is ScenePreset => p !== undefined)
  })

  const addCustomScene = (
    scene: Omit<CustomScenePreset, 'id' | 'creator' | 'createdAt' | 'updatedAt'>
  ): CustomScenePreset => {
    const now = Date.now()
    const newScene: CustomScenePreset = {
      ...scene,
      id: generateCustomId(),
      creator: 'user',
      createdAt: now,
      updatedAt: now
    }
    state.value = {
      ...state.value,
      customScenes: [...state.value.customScenes, newScene],
      customOrder: [...state.value.customOrder, newScene.id]
    }
    persist()
    return newScene
  }

  const updateCustomScene = (id: string, patch: Partial<CustomScenePreset>): void => {
    state.value = {
      ...state.value,
      customScenes: state.value.customScenes.map(s =>
        s.id === id ? { ...s, ...patch, updatedAt: Date.now() } : s
      )
    }
    persist()
  }

  const deleteCustomScene = (id: string): void => {
    state.value = {
      ...state.value,
      customScenes: state.value.customScenes.filter(s => s.id !== id),
      customOrder: state.value.customOrder.filter(oid => oid !== id)
    }
    persist()
  }

  const toggleFavorite = (presetId: ScenePresetId): void => {
    const current = state.value.favoritePresetIds
    if (current.includes(presetId)) {
      state.value = {
        ...state.value,
        favoritePresetIds: current.filter(id => id !== presetId)
      }
    } else {
      state.value = {
        ...state.value,
        favoritePresetIds: [...current, presetId]
      }
    }
    persist()
  }

  const isFavorite = (presetId: ScenePresetId): boolean => {
    return state.value.favoritePresetIds.includes(presetId)
  }

  const getSceneById = (id: string): AnyScene | undefined => {
    const custom = state.value.customScenes.find(s => s.id === id)
    if (custom) return custom
    return SCENE_PRESETS.find(p => p.id === id)
  }

  return {
    customScenes,
    favoritePresetIds,
    allScenes,
    favoriteScenes,
    addCustomScene,
    updateCustomScene,
    deleteCustomScene,
    toggleFavorite,
    isFavorite,
    getSceneById,
    isCustomScene
  }
}
```

- [ ] **Step 2: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 3: 提交**

```bash
cd lumira-app
git add src/composables/useSceneManager.ts
git commit -m "feat(composable): useSceneManager 场景管理 composable - 自定义场景 CRUD + 预设收藏 + localStorage 持久化"
```

---

### Task 3: ScenePresetView 组件（components/ScenePresetView.vue）

**Files:**
- Create: `lumira-app/src/components/ScenePresetView.vue`

**Interfaces:**
- Consumes: `AnyScene`（from Task 1）、`useSceneManager.isCustomScene`（from Task 2）
- Produces: `<ScenePresetView :scene="..." :size="full|mini" @click="..." />` 通用场景卡片组件。Task 4 的 scene-manage.vue 依赖此组件。

- [ ] **Step 1: 创建组件文件**

创建 `lumira-app/src/components/ScenePresetView.vue`，完整内容如下：

```vue
<template>
  <view class="scene-preset-view" :class="'size-' + size" @click="onClick">
    <view class="spv-icon-wrap" :class="{ 'spv-icon-custom': isCustom }">
      <text class="ph spv-icon" :class="scene.icon"></text>
    </view>
    <view class="spv-text">
      <view class="spv-title-row">
        <text class="spv-name">{{ scene.name }}</text>
        <view v-if="isCustom" class="spv-custom-tag">
          <text class="spv-custom-tag-text">自定义</text>
        </view>
      </view>
      <text v-if="size === 'full' && scene.description" class="spv-desc">{{ scene.description }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSceneManager } from '@/composables/useSceneManager'
import type { AnyScene } from '@/types/template'

const props = withDefaults(defineProps<{
  scene: AnyScene
  size?: 'full' | 'mini'
}>(), {
  size: 'full'
})

const emit = defineEmits<{
  click: [id: string]
}>()

const { isCustomScene } = useSceneManager()

const isCustom = computed(() => isCustomScene(props.scene))

const onClick = () => {
  emit('click', props.scene.id)
}
</script>

<style lang="scss" scoped>
.scene-preset-view {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx;
  border-radius: 24rpx;
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-divider);
}

.scene-preset-view:active {
  opacity: 0.7;
}

.size-mini {
  padding: 20rpx 24rpx;
  gap: 16rpx;
}

.spv-icon-wrap {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background-color: var(--color-surface-alt);
}

.size-mini .spv-icon-wrap {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
}

.spv-icon-custom {
  background-color: var(--color-brand-subtle);
}

.spv-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.spv-icon-custom .spv-icon {
  color: var(--color-brand);
}

.spv-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.spv-title-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.spv-name {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.size-mini .spv-name {
  font-size: 28rpx;
}

.spv-custom-tag {
  padding: 4rpx 16rpx;
  border-radius: 9999rpx;
  background-color: var(--color-brand-subtle);
}

.spv-custom-tag-text {
  font-size: 20rpx;
  font-weight: 600;
  color: var(--color-brand);
}

.spv-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  line-height: 1.4;
}
</style>
```

- [ ] **Step 2: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 3: 提交**

```bash
cd lumira-app
git add src/components/ScenePresetView.vue
git commit -m "feat(component): ScenePresetView 通用场景卡片组件 - 支持 full/mini 两种尺寸 + 自定义标签"
```

---

### Task 4: pages.json 注册 + scene-manage.vue 管理页

**Files:**
- Modify: `lumira-app/src/pages.json`
- Create: `lumira-app/src/pages/capture/scene-manage.vue`

**Interfaces:**
- Consumes: `useSceneManager`（from Task 2）、`ScenePresetView`（from Task 3）、`SCENE_PRESETS`（现有）、`ScenePresetId`/`CustomScenePreset`（from Task 1）、`getLutLabel`（现有 `@/utils/filterRecipe`）
- Produces: 场景管理页（双 Tab + 收藏 + 自定义场景 CRUD 表单）。Task 5-7 的跳转目标。

- [ ] **Step 1: 在 pages.json 注册新路由**

在 `lumira-app/src/pages.json` 的 `pages` 数组中，找到 `pages/capture/scene-guide` 条目（约 36-38 行），在其后新增：

```json
		{
			"path": "pages/capture/scene-manage",
			"style": { "navigationStyle": "custom", "backgroundColor": "#FAF7F2" }
		},
```

注意：JSON 不支持注释，确保逗号正确。在 `scene-guide` 条目的 `}` 后加 `,`，然后添加新条目。

- [ ] **Step 2: 创建 scene-manage.vue 页面**

创建 `lumira-app/src/pages/capture/scene-manage.vue`，完整内容如下：

```vue
<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">场景管理</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- Tab 栏 -->
    <view class="tabs-wrap fade-up">
      <view class="tabs-row">
        <view
          class="tab-pill"
          :class="{ active: tab === 'fav' }"
          @click="tab = 'fav'"
        >
          <text class="tab-pill-text">我的收藏</text>
        </view>
        <view
          class="tab-pill"
          :class="{ active: tab === 'custom' }"
          @click="tab = 'custom'"
        >
          <text class="tab-pill-text">自定义场景</text>
        </view>
      </view>
    </view>

    <!-- Tab 1: 我的收藏 -->
    <view v-if="tab === 'fav'" class="section-pad fade-up fade-up-d1">
      <view v-if="favoriteScenes.length === 0" class="empty-state">
        <text class="ph ph-star empty-icon"></text>
        <text class="empty-title">还没有收藏的场景</text>
        <text class="empty-desc">收藏的场景会出现在首页和场景指南中</text>
        <view class="empty-btn" @click="goGuide">
          <text class="empty-btn-text">去场景指南发现更多</text>
        </view>
      </view>
      <view v-else class="fav-list">
        <view
          v-for="preset in favoriteScenes"
          :key="preset.id"
          class="fav-item"
          @click="goGuide(preset.id)"
        >
          <view class="fav-item-icon">
            <text class="ph fav-icon" :class="preset.icon"></text>
          </view>
          <view class="fav-item-text">
            <text class="fav-item-name">{{ preset.name }}</text>
            <text class="fav-item-desc">{{ preset.description }}</text>
          </view>
          <view class="fav-star-btn" @click.stop="onToggleFav(preset.id)">
            <text class="ph ph-star-fill fav-star-icon"></text>
          </view>
          <text class="ph ph-caret-right fav-item-arrow"></text>
        </view>
      </view>
    </view>

    <!-- Tab 2: 自定义场景 -->
    <view v-if="tab === 'custom'" class="section-pad fade-up fade-up-d1">
      <!-- 新建/编辑表单 -->
      <view v-if="formVisible" class="form-card">
        <text class="form-title">{{ editingId ? '编辑场景' : '新建场景' }}</text>

        <!-- 名称 -->
        <view class="form-field">
          <text class="form-label">场景名称</text>
          <input class="form-input" v-model="formData.name" placeholder="如：夕阳人像" maxlength="20" />
        </view>

        <!-- 图标选择 -->
        <view class="form-field">
          <text class="form-label">图标</text>
          <scroll-view scroll-x class="icon-scroll">
            <view class="icon-list">
              <view
                v-for="ic in iconOptions"
                :key="ic"
                class="icon-option"
                :class="{ active: formData.icon === ic }"
                @click="formData.icon = ic"
              >
                <text class="ph icon-option-icon" :class="ic"></text>
              </view>
            </view>
          </scroll-view>
        </view>

        <!-- 分类 -->
        <view class="form-field">
          <text class="form-label">关联分类</text>
          <view class="pill-list-inline">
            <view
              v-for="cat in categoryOptions"
              :key="cat.value"
              class="pill"
              :class="{ active: formData.relatedCategory === cat.value }"
              @click="formData.relatedCategory = cat.value"
            >
              <text class="pill-text">{{ cat.label }}</text>
            </view>
          </view>
        </view>

        <!-- 场景指南 -->
        <view class="form-field">
          <text class="form-label">光线方向</text>
          <input class="form-input" v-model="formData.sceneGuide.lightDirection" placeholder="如：侧光 45°" />
        </view>
        <view class="form-field">
          <text class="form-label">拍摄距离</text>
          <input class="form-input" v-model="formData.sceneGuide.shootingDistance" placeholder="如：1.5-2.5m" />
        </view>
        <view class="form-field">
          <text class="form-label">背景建议</text>
          <input class="form-input" v-model="formData.sceneGuide.background" placeholder="如：简洁背景" />
        </view>

        <!-- 相机建议 -->
        <view class="form-field">
          <text class="form-label">白平衡</text>
          <view class="pill-list-inline">
            <view
              v-for="wb in wbOptions"
              :key="wb.value"
              class="pill"
              :class="{ active: formData.cameraSuggestion.whiteBalance === wb.value }"
              @click="formData.cameraSuggestion.whiteBalance = wb.value"
            >
              <text class="pill-text">{{ wb.label }}</text>
            </view>
          </view>
        </view>
        <view class="form-field">
          <text class="form-label">拍照风格</text>
          <view class="pill-list-inline">
            <view
              v-for="ps in psOptions"
              :key="ps.value"
              class="pill"
              :class="{ active: formData.cameraSuggestion.photographicStyle === ps.value }"
              @click="formData.cameraSuggestion.photographicStyle = ps.value"
            >
              <text class="pill-text">{{ ps.label }}</text>
            </view>
          </view>
        </view>

        <!-- LUT -->
        <view class="form-field">
          <text class="form-label">LUT 滤镜</text>
          <view class="pill-list-inline">
            <view
              v-for="lut in lutOptions"
              :key="lut.value"
              class="pill"
              :class="{ active: formData.postSuggestion.lut === lut.value }"
              @click="formData.postSuggestion.lut = lut.value"
            >
              <text class="pill-text">{{ lut.label }}</text>
            </view>
          </view>
        </view>

        <!-- 表单按钮 -->
        <view class="form-actions">
          <view class="form-btn-ghost" @click="onCancelForm">
            <text>取消</text>
          </view>
          <view class="form-btn-brand" @click="onSaveForm">
            <text>保存</text>
          </view>
        </view>
      </view>

      <!-- 自定义场景列表（非编辑状态） -->
      <view v-if="!formVisible">
        <view v-if="customScenes.length === 0" class="empty-state">
          <text class="ph ph-camera empty-icon"></text>
          <text class="empty-title">还没有自定义场景</text>
          <text class="empty-desc">创建你的专属拍摄场景，快速应用参数</text>
          <view class="empty-btn" @click="onNew">
            <text class="empty-btn-text">+ 新建场景</text>
          </view>
        </view>
        <view v-else class="custom-list">
          <view
            v-for="scene in customScenes"
            :key="scene.id"
            class="custom-item"
            @click="goGuide(scene.id)"
          >
            <view class="custom-item-icon">
              <text class="ph custom-icon" :class="scene.icon"></text>
            </view>
            <view class="custom-item-text">
              <text class="custom-item-name">{{ scene.name }}</text>
              <text class="custom-item-desc">{{ scene.description || '点击查看详情' }}</text>
            </view>
            <view class="custom-more-btn" @click.stop="onMore(scene)">
              <text class="ph ph-dots-three custom-more-icon"></text>
            </view>
            <text class="ph ph-caret-right custom-item-arrow"></text>
          </view>
          <view class="add-btn" @click="onNew">
            <text class="ph ph-plus add-btn-icon"></text>
            <text class="add-btn-text">新建场景</text>
          </view>
        </view>
      </view>
    </view>

    <view class="bottom-spacer"></view>
  </view>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import { getLutOptions } from '@/utils/filterRecipe'
import type { ScenePresetId, Target, WhiteBalance, PhotographicStyle, LutPreset, CustomScenePreset } from '@/types/template'

const {
  customScenes,
  favoriteScenes,
  toggleFavorite,
  addCustomScene,
  updateCustomScene,
  deleteCustomScene
} = useSceneManager()

const tab = ref<'fav' | 'custom'>('fav')
const formVisible = ref(false)
const editingId = ref<string | null>(null)

const iconOptions = [
  'ph-camera', 'ph-coffee', 'ph-sun', 'ph-flower', 'ph-buildings',
  'ph-car', 'ph-paw-print', 'ph-fork-knife', 'ph-mountain',
  'ph-snowflake', 'ph-lightning', 'ph-leaf', 'ph-moon', 'ph-house',
  'ph-tree', 'ph-waves', 'ph-sunset', 'ph-building'
]

const categoryOptions: { value: Target; label: string }[] = [
  { value: 'portrait', label: '人像' },
  { value: 'landscape', label: '风光' },
  { value: 'food', label: '美食' },
  { value: 'street', label: '街拍' },
  { value: 'night', label: '夜景' },
  { value: 'macro', label: '微距' },
  { value: 'still-life', label: '静物' }
]

const wbOptions: { value: WhiteBalance; label: string }[] = [
  { value: 'daylight', label: '日光' },
  { value: 'cloudy', label: '阴天' },
  { value: 'shade', label: '阴影' },
  { value: 'tungsten', label: '白炽灯' },
  { value: 'fluorescent', label: '荧光灯' }
]

const psOptions: { value: PhotographicStyle; label: string }[] = [
  { value: 'standard', label: '标准' },
  { value: 'high_contrast', label: '高对比' },
  { value: 'warm', label: '暖色' },
  { value: 'cool', label: '冷色' },
  { value: 'mono', label: '黑白' }
]

const lutOptions = getLutOptions().map(o => ({ value: o.id, label: o.name }))

interface FormData {
  name: string
  icon: string
  description: string
  relatedCategory: Target
  sceneGuide: {
    lightDirection: string
    shootingDistance: string
    background: string
    props: string[]
    bestTime: string
    tips: string[]
  }
  cameraSuggestion: {
    whiteBalance: WhiteBalance
    photographicStyle: PhotographicStyle
  }
  postSuggestion: {
    lut: LutPreset
  }
}

function createDefaultForm(): FormData {
  return {
    name: '',
    icon: 'ph-camera',
    description: '',
    relatedCategory: 'portrait',
    sceneGuide: {
      lightDirection: '自然光',
      shootingDistance: '1-2米',
      background: '简洁背景',
      props: [],
      bestTime: '全天',
      tips: []
    },
    cameraSuggestion: {
      whiteBalance: 'daylight',
      photographicStyle: 'standard'
    },
    postSuggestion: {
      lut: 'none'
    }
  }
}

const formData = reactive<FormData>(createDefaultForm())

onLoad((options) => {
  if (options?.tab === 'custom') {
    tab.value = 'custom'
  }
})

const back = () => uni.navigateBack()

const goGuide = (sceneId?: string) => {
  const url = sceneId
    ? `/pages/capture/scene-guide?scenePreset=${sceneId}`
    : '/pages/capture/scene-guide'
  uni.navigateTo({ url })
}

const onToggleFav = (id: ScenePresetId) => {
  toggleFavorite(id)
}

const onNew = () => {
  editingId.value = null
  Object.assign(formData, createDefaultForm())
  formVisible.value = true
}

const onEdit = (scene: CustomScenePreset) => {
  editingId.value = scene.id
  Object.assign(formData, {
    name: scene.name,
    icon: scene.icon,
    description: scene.description,
    relatedCategory: scene.relatedCategory,
    sceneGuide: {
      lightDirection: scene.sceneGuide.lightDirection,
      shootingDistance: scene.sceneGuide.shootingDistance,
      background: scene.sceneGuide.background,
      props: [...scene.sceneGuide.props],
      bestTime: scene.sceneGuide.bestTime,
      tips: [...scene.sceneGuide.tips]
    },
    cameraSuggestion: {
      whiteBalance: scene.cameraSuggestion.whiteBalance || 'daylight',
      photographicStyle: scene.cameraSuggestion.photographicStyle || 'standard'
    },
    postSuggestion: {
      lut: scene.postSuggestion.lut || 'none'
    }
  })
  formVisible.value = true
}

const onCancelForm = () => {
  formVisible.value = false
  editingId.value = null
}

const onSaveForm = () => {
  if (!formData.name.trim()) {
    uni.showToast({ title: '请输入场景名称', icon: 'none' })
    return
  }

  const sceneData = {
    name: formData.name.trim(),
    icon: formData.icon,
    description: formData.description.trim(),
    sceneGuide: {
      lightDirection: formData.sceneGuide.lightDirection,
      shootingDistance: formData.sceneGuide.shootingDistance,
      background: formData.sceneGuide.background,
      props: [...formData.sceneGuide.props],
      bestTime: formData.sceneGuide.bestTime,
      tips: [...formData.sceneGuide.tips]
    },
    cameraSuggestion: {
      whiteBalance: formData.cameraSuggestion.whiteBalance,
      photographicStyle: formData.cameraSuggestion.photographicStyle
    },
    postSuggestion: {
      lut: formData.postSuggestion.lut
    },
    relatedCategory: formData.relatedCategory
  }

  if (editingId.value) {
    updateCustomScene(editingId.value, sceneData)
    uni.showToast({ title: '已保存', icon: 'success' })
  } else {
    addCustomScene(sceneData)
    uni.showToast({ title: '已创建', icon: 'success' })
  }
  formVisible.value = false
  editingId.value = null
}

const onMore = (scene: CustomScenePreset) => {
  uni.showActionSheet({
    itemList: ['编辑', '删除'],
    success: (res) => {
      if (res.tapIndex === 0) {
        onEdit(scene)
      } else if (res.tapIndex === 1) {
        uni.showModal({
          title: '删除场景',
          content: `确定删除「${scene.name}」吗？`,
          confirmColor: '#C9453D',
          success: (modalRes) => {
            if (modalRes.confirm) {
              deleteCustomScene(scene.id)
              uni.showToast({ title: '已删除', icon: 'success' })
            }
          }
        })
      }
    }
  })
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

/* ===== Tab 栏 ===== */
.tabs-wrap {
  padding: 32rpx 48rpx 0;
}

.tabs-row {
  display: flex;
  gap: 16rpx;
}

.tab-pill {
  padding: 16rpx 40rpx;
  border-radius: 9999rpx;
  border: 3rpx solid var(--color-divider);
  background-color: var(--color-surface);
}

.tab-pill.active {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  border-color: transparent;
}

.tab-pill-text {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.tab-pill.active .tab-pill-text {
  color: #ffffff;
}

/* ===== 通用 ===== */
.section-pad {
  padding: 32rpx 48rpx 0;
}

.bottom-spacer {
  height: 48rpx;
}

/* ===== 空状态 ===== */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 40rpx;
  text-align: center;
}

.empty-icon {
  font-size: 80rpx;
  color: var(--color-text-tertiary);
  margin-bottom: 24rpx;
}

.empty-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 12rpx;
}

.empty-desc {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
  line-height: 1.5;
  margin-bottom: 40rpx;
}

.empty-btn {
  padding: 20rpx 48rpx;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
}

.empty-btn-text {
  font-size: 28rpx;
  font-weight: 500;
  color: #ffffff;
}

/* ===== 收藏列表 ===== */
.fav-list {
  display: flex;
  flex-direction: column;
}

.fav-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 0;
  border-bottom: 2rpx solid var(--color-divider);
}

.fav-list .fav-item:last-child {
  border-bottom: none;
}

.fav-item:active {
  opacity: 0.7;
}

.fav-item-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background-color: var(--color-brand-subtle);
}

.fav-icon {
  font-size: 40rpx;
  color: var(--color-brand);
}

.fav-item-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.fav-item-name {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.fav-item-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.fav-star-btn {
  flex-shrink: 0;
  padding: 8rpx;
}

.fav-star-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

.fav-item-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

/* ===== 自定义场景列表 ===== */
.custom-list {
  display: flex;
  flex-direction: column;
}

.custom-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 0;
  border-bottom: 2rpx solid var(--color-divider);
}

.custom-list .custom-item:last-child {
  border-bottom: none;
}

.custom-item:active {
  opacity: 0.7;
}

.custom-item-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background-color: var(--color-surface-alt);
}

.custom-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.custom-item-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.custom-item-name {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.custom-item-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.custom-more-btn {
  flex-shrink: 0;
  padding: 8rpx;
}

.custom-more-icon {
  font-size: 36rpx;
  color: var(--color-text-tertiary);
}

.custom-item-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

.add-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  padding: 32rpx;
  margin-top: 24rpx;
  border-radius: 24rpx;
  border: 3rpx dashed var(--color-divider);
  background-color: var(--color-surface);
}

.add-btn:active {
  opacity: 0.7;
}

.add-btn-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

.add-btn-text {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-brand);
}

/* ===== 表单 ===== */
.form-card {
  background-color: var(--color-surface);
  border-radius: 28rpx;
  padding: 40rpx;
  box-shadow: var(--shadow-convex);
}

.form-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 32rpx;
}

.form-field {
  margin-bottom: 32rpx;
}

.form-label {
  display: block;
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
  margin-bottom: 16rpx;
}

.form-input {
  width: 100%;
  padding: 20rpx 24rpx;
  border-radius: 16rpx;
  border: 2rpx solid var(--color-divider);
  background-color: var(--color-surface-alt);
  font-size: 28rpx;
  color: var(--color-text-primary);
  box-sizing: border-box;
}

/* icon scroll-x */
.icon-scroll {
  white-space: nowrap;
}

.icon-list {
  display: inline-flex;
  gap: 16rpx;
  padding: 4rpx;
}

.icon-option {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 80rpx;
  height: 80rpx;
  border-radius: 16rpx;
  background-color: var(--color-surface-alt);
  border: 2rpx solid transparent;
  flex-shrink: 0;
}

.icon-option.active {
  border-color: var(--color-brand);
  background-color: var(--color-brand-subtle);
}

.icon-option-icon {
  font-size: 36rpx;
  color: var(--color-text-primary);
}

.icon-option.active .icon-option-icon {
  color: var(--color-brand);
}

/* pill 选择器 */
.pill-list-inline {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}

.pill {
  display: inline-flex;
  align-items: center;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
  border: 2rpx solid transparent;
}

.pill.active {
  background-color: var(--color-brand-subtle);
  border-color: var(--color-brand);
}

.pill-text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.pill.active .pill-text {
  color: var(--color-brand);
  font-weight: 500;
}

/* 表单按钮 */
.form-actions {
  display: flex;
  gap: 20rpx;
  margin-top: 40rpx;
}

.form-btn-ghost,
.form-btn-brand {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24rpx 0;
  border-radius: 9999rpx;
  font-size: 28rpx;
  font-weight: 500;
}

.form-btn-ghost {
  background-color: var(--color-surface-alt);
  color: var(--color-text-primary);
}

.form-btn-brand {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #ffffff;
}

.form-btn-ghost:active,
.form-btn-brand:active {
  opacity: 0.8;
}
</style>
```

- [ ] **Step 3: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。若 `getLutOptions` 导出不存在则检查 `@/utils/filterRecipe` 的实际导出名。

- [ ] **Step 4: 提交**

```bash
cd lumira-app
git add src/pages.json src/pages/capture/scene-manage.vue
git commit -m "feat(scene-manage): 场景管理页 - 双 Tab（收藏/自定义）+ CRUD 表单 + icon 选择器 + pages.json 注册"
```

---

### Task 5: 首页集成（pages/home/index.vue）

**Files:**
- Modify: `lumira-app/src/pages/home/index.vue`

**Interfaces:**
- Consumes: `useSceneManager`（from Task 2）、`SCENE_PRESETS`（现有）
- Produces: 首页场景推荐区数据源更新、"管理"链接修复、"收藏"链接新增。

- [ ] **Step 1: 在 script setup 中新增导入和场景管理器**

在 `lumira-app/src/pages/home/index.vue` 的 `<script setup lang="ts">` 块中，修改 import 区域和 scenes 定义。

找到现有 import 区域（约 210-211 行）：
```typescript
import { ref } from 'vue'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
```

替换为：
```typescript
import { ref, computed } from 'vue'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'

const { customScenes } = useSceneManager()
```

- [ ] **Step 2: 替换硬编码 scenes 为 computed 数据源**

找到现有 `scenes` ref 定义（约 223-228 行）：
```typescript
const scenes = ref([
  { name: '咖啡馆', desc: '柔和光线 · 氛围感', img: '/static/scenes/scene_cafe.jpg', tag: '你最常去', brand: false, scene: 'cafe' },
  { name: '街拍', desc: '城市光影 · 故事感', img: '/static/scenes/scene_street.jpg', tag: '31张照片', brand: false, scene: 'street' },
  { name: '探店', desc: '美食记录 · 色温', img: '/static/scenes/scene_shop.jpg', tag: '新场景推荐', brand: true, scene: 'food' },
  { name: '居家', desc: '温馨光线 · 静谧', img: '/static/scenes/scene_home.jpg', tag: '适合今天天气', brand: false, scene: 'home' }
])
```

替换为：
```typescript
const scenes = computed(() => {
  const customs = customScenes.value.slice(0, 4).map(c => ({
    name: c.name,
    desc: c.description,
    img: `https://picsum.photos/seed/scene-home-${c.id}/400/600`,
    tag: '我的场景',
    brand: false,
    scene: c.id
  }))
  const presets = SCENE_PRESETS.slice(0, 4).map((p, i) => ({
    name: p.name,
    desc: p.description,
    img: `https://picsum.photos/seed/scene-home-${p.id}/400/600`,
    tag: i === 0 ? '你最常去' : i === 2 ? '新场景推荐' : `${p.name}拍摄`,
    brand: i === 2,
    scene: p.id
  }))
  return [...customs, ...presets].slice(0, 4)
})
```

- [ ] **Step 3: 新增跳转函数**

找到现有跳转函数区域（约 238-240 行）：
```typescript
const goTab = (url: string) => uni.reLaunch({ url })
const goPage = (url: string) => uni.navigateTo({ url })
const goCapture = () => uni.navigateTo({ url: '/pages/capture/index' })
```

在其后新增：
```typescript
const goSceneManage = () => uni.navigateTo({ url: '/pages/capture/scene-manage' })
const goSceneFav = () => uni.navigateTo({ url: '/pages/capture/scene-manage?tab=fav' })
```

- [ ] **Step 4: 修改模板中"管理"链接绑定 + 新增"收藏"链接**

找到模板中场景推荐标题行（约 120-126 行）：
```html
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="section-title-text">场景推荐</text>
          <text class="lumira-tag lumira-tag-green">为你而选</text>
        </view>
        <text class="lumira-section-link">管理</text>
      </view>
```

替换为：
```html
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="section-title-text">场景推荐</text>
          <text class="lumira-tag lumira-tag-green">为你而选</text>
        </view>
        <view class="section-link-row">
          <text class="lumira-section-link" @click="goSceneFav">收藏</text>
          <text class="lumira-section-link" @click="goSceneManage">管理</text>
        </view>
      </view>
```

- [ ] **Step 5: 新增 section-link-row 样式**

在 `<style lang="scss" scoped>` 中，找到 `.section-title-left` 类定义（约 252 行），在其后新增：

```scss
.section-link-row {
  display: flex;
  gap: 24rpx;
}
```

- [ ] **Step 6: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 7: 提交**

```bash
cd lumira-app
git add src/pages/home/index.vue
git commit -m "feat(home): 场景推荐区数据源改用 SCENE_PRESETS + 管理链接跳转修复 + 收藏入口新增"
```

---

### Task 6: 灵感页集成（pages/inspiration/index.vue）

**Files:**
- Modify: `lumira-app/src/pages/inspiration/index.vue`

**Interfaces:**
- Consumes: `useSceneManager`（from Task 2）、`SCENE_PRESETS`（现有）
- Produces: 灵感页场景卡片数据源更新 + 点击跳转 + "发现更多"链接跳转。

- [ ] **Step 1: 在 script setup 中新增导入和场景管理器**

在 `lumira-app/src/pages/inspiration/index.vue` 的 `<script setup lang="ts">` 块中，找到现有 import（约 132 行）：
```typescript
import { ref } from 'vue'
```

替换为：
```typescript
import { ref, computed } from 'vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'

const { customScenes } = useSceneManager()
```

- [ ] **Step 2: 替换硬编码 scenes 为 computed 数据源**

找到现有 `scenes` ref 定义（约 149-154 行）：
```typescript
const scenes = ref([
  { img: 'https://picsum.photos/seed/2074130/400/533', icon: 'ph-coffee', name: '咖啡馆', tag: '你最常去', tagCls: 'lumira-tag-gold' },
  { img: 'https://picsum.photos/seed/1926769/400/533', icon: 'ph-buildings', name: '街拍', tag: '31张照片', tagCls: 'lumira-tag-gold' },
  { img: 'https://picsum.photos/seed/1640777/400/533', icon: 'ph-shopping-bag', name: '探店', tag: '新场景推荐', tagCls: 'lumira-tag-red' },
  { img: 'https://picsum.photos/seed/1571460/400/533', icon: 'ph-house-line', name: '居家', tag: '适合今天天气', tagCls: 'lumira-tag-green' }
])
```

替换为：
```typescript
const scenes = computed(() => {
  const customs = customScenes.value.slice(0, 4).map(c => ({
    id: c.id,
    img: `https://picsum.photos/seed/scene-inspiration-${c.id}/400/533`,
    icon: c.icon,
    name: c.name,
    tag: '我的场景',
    tagCls: 'lumira-tag-gold'
  }))
  const presets = SCENE_PRESETS.slice(0, 4).map((p, i) => ({
    id: p.id,
    img: `https://picsum.photos/seed/scene-inspiration-${p.id}/400/533`,
    icon: p.icon,
    name: p.name,
    tag: i === 0 ? '你最常去' : i === 2 ? '新场景推荐' : `${p.name}拍摄`,
    tagCls: i === 0 ? 'lumira-tag-gold' : i === 2 ? 'lumira-tag-red' : 'lumira-tag-green'
  }))
  return [...customs, ...presets].slice(0, 4)
})

const goScene = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-guide?scenePreset=${id}` })
const goSceneManage = () => uni.navigateTo({ url: '/pages/capture/scene-manage' })
```

- [ ] **Step 3: 修改模板中场景卡片添加点击跳转**

找到模板中推荐场景的 scene-card（约 73 行）：
```html
          <view class="scene-card lumira-card-hover" v-for="s in scenes" :key="s.name">
```

替换为：
```html
          <view class="scene-card lumira-card-hover" v-for="s in scenes" :key="s.id" @click="goScene(s.id)">
```

- [ ] **Step 4: 修改"发现更多场景"链接添加跳转**

找到模板中"发现更多场景"链接（约 86-90 行）：
```html
        <view class="more-link-wrap">
          <text class="more-link">
            <text>发现更多场景</text>
            <text class="ph ph-arrow-right"></text>
          </text>
        </view>
```

替换为：
```html
        <view class="more-link-wrap" @click="goSceneManage">
          <text class="more-link">
            <text>发现更多场景</text>
            <text class="ph ph-arrow-right"></text>
          </text>
        </view>
```

- [ ] **Step 5: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 6: 提交**

```bash
cd lumira-app
git add src/pages/inspiration/index.vue
git commit -m "feat(inspiration): 场景卡片数据源改用 SCENE_PRESETS + 点击跳转 + 发现更多链接跳转"
```

---

### Task 7: 场景指南页集成（pages/capture/scene-guide.vue）

**Files:**
- Modify: `lumira-app/src/pages/capture/scene-guide.vue`

**Interfaces:**
- Consumes: `useSceneManager`（from Task 2）、`SCENE_PRESETS`、`SCENE_TO_CATEGORY`（现有）、`AnyScene`（from Task 1）
- Produces: Tab 切换修复 + 收藏按钮 + onAdd/onMoreRecommend 跳转修复 + onLoad 参数兼容。

- [ ] **Step 1: 替换 script setup 块**

将 `lumira-app/src/pages/capture/scene-guide.vue` 的 `<script setup lang="ts">` 块整体替换为：

```typescript
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { SCENE_PRESETS, SCENE_TO_CATEGORY } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'
import type { AnyScene, ScenePresetId } from '@/types/template'

const {
  customScenes,
  favoriteScenes,
  toggleFavorite,
  isFavorite,
  isCustomScene,
  getSceneById
} = useSceneManager()

const tab = ref('common')

const tabList = [
  { label: '常用场景', value: 'common' },
  { label: '收藏场景', value: 'fav' },
  { label: '推荐场景', value: 'recommend' }
]

const myScenes = computed<AnyScene[]>(() => [...customScenes.value, ...SCENE_PRESETS.slice(0, 8)])
const recommendScenes = SCENE_PRESETS.slice(8)

const currentList = computed<AnyScene[]>(() => {
  if (tab.value === 'fav') return favoriteScenes.value
  if (tab.value === 'recommend') return recommendScenes
  return myScenes.value
})

const currentTitle = computed(() => {
  if (tab.value === 'fav') return '我的收藏'
  if (tab.value === 'recommend') return '推荐场景'
  return '我的场景'
})

const selectedPreset = ref<AnyScene | null>(null)

onLoad((options) => {
  const sceneId = options?.scene || options?.scenePreset
  if (sceneId) {
    const scene = getSceneById(sceneId)
    if (scene) {
      selectedPreset.value = scene
      tab.value = isCustomScene(scene) ? 'common' : 'recommend'
    }
  }
})

const back = () => uni.navigateBack()

const onAdd = () => {
  uni.navigateTo({ url: '/pages/capture/scene-manage?tab=custom' })
}

const onMoreRecommend = () => {
  uni.navigateTo({ url: '/pages/capture/scene-manage?tab=fav' })
}

const onSceneTap = (preset: AnyScene) => {
  selectedPreset.value = preset
}

const onToggleFav = (id: string) => {
  toggleFavorite(id as ScenePresetId)
}

const goTemplates = () => {
  if (!selectedPreset.value) return
  const cat = isCustomScene(selectedPreset.value)
    ? selectedPreset.value.relatedCategory
    : SCENE_TO_CATEGORY[selectedPreset.value.id as ScenePresetId]
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

- [ ] **Step 2: 替换模板 - 场景列表区（合并我的场景和推荐场景为单一列表）**

找到模板中「我的场景」区块开始到「推荐场景」区块结束（约 29-83 行），即从：
```html
    <!-- 我的场景 -->
    <view class="section-pad fade-up fade-up-d1">
```
到：
```html
    </view>
  </view>
```
（推荐场景区块结束）

整体替换为：

```html
    <!-- 场景列表（根据 Tab 切换） -->
    <view class="section-pad fade-up fade-up-d1">
      <view class="section-title-row">
        <text class="section-title">{{ currentTitle }}</text>
        <text class="section-count">共 {{ currentList.length }} 个</text>
      </view>
      <view v-if="currentList.length === 0" class="empty-inline">
        <text class="empty-inline-text">{{ tab === 'fav' ? '还没有收藏的场景，点击 ☆ 收藏' : '暂无场景' }}</text>
      </view>
      <view v-else class="scene-list">
        <view
          class="scene-item"
          v-for="preset in currentList"
          :key="preset.id"
          @click="onSceneTap(preset)"
        >
          <view class="scene-item-icon" :class="{ 'icon-bg-green': tab === 'recommend' }">
            <text class="ph scene-icon" :class="preset.icon"></text>
          </view>
          <view class="scene-item-text">
            <text class="scene-item-title">{{ preset.name }}</text>
            <text class="scene-item-desc">{{ preset.description }}</text>
          </view>
          <view
            v-if="!isCustomScene(preset)"
            class="fav-btn"
            @click.stop="onToggleFav(preset.id)"
          >
            <text class="ph fav-icon" :class="isFavorite(preset.id as ScenePresetId) ? 'ph-star-fill' : 'ph-star'"></text>
          </view>
          <text class="ph ph-caret-right scene-item-arrow"></text>
        </view>
      </view>
    </view>
```

- [ ] **Step 3: 在小贴士卡片标题栏增加收藏按钮**

找到模板中小贴士卡片标题栏（约 86-91 行）：
```html
      <view class="tip-detail-card">
        <view class="tip-detail-head">
          <text class="ph ph-lightbulb tip-detail-icon"></text>
          <text class="tip-detail-title">{{ selectedPreset.name }} · 拍摄小贴士</text>
        </view>
```

替换为：
```html
      <view class="tip-detail-card">
        <view class="tip-detail-head">
          <text class="ph ph-lightbulb tip-detail-icon"></text>
          <text class="tip-detail-title">{{ selectedPreset.name }} · 拍摄小贴士</text>
          <view
            v-if="selectedPreset && !isCustomScene(selectedPreset)"
            class="fav-btn-tip"
            @click="onToggleFav(selectedPreset.id)"
          >
            <text class="ph fav-tip-icon" :class="isFavorite(selectedPreset.id as ScenePresetId) ? 'ph-star-fill' : 'ph-star'"></text>
          </view>
        </view>
```

- [ ] **Step 4: 删除"快速添加提示"区块（已由 onAdd 跳转替代）**

找到模板中"快速添加提示"区块（约 141-151 行）：
```html
    <!-- 快速添加提示 -->
    <view class="section-pad-bottom fade-up fade-up-d3">
      <view class="add-card">
        ...
      </view>
    </view>
```

整体删除此区块（从 `<!-- 快速添加提示 -->` 到其对应的 `</view>` 结束）。

- [ ] **Step 5: 新增收藏按钮相关样式**

在 `<style lang="scss" scoped>` 中，找到 `.scene-item-arrow` 类定义（约 378 行），在其后新增：

```scss
/* ===== 收藏按钮 ===== */
.fav-btn {
  flex-shrink: 0;
  padding: 8rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.fav-icon {
  font-size: 36rpx;
  color: var(--color-text-tertiary);
}

.fav-btn-tip {
  margin-left: auto;
  padding: 8rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.fav-tip-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

/* ===== 空状态（内联） ===== */
.empty-inline {
  padding: 48rpx 0;
  text-align: center;
}

.empty-inline-text {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}
```

- [ ] **Step 6: 删除不再使用的 CSS 类**

在 `<style lang="scss" scoped>` 中，删除以下不再使用的类定义：
- `.section-more`（约 285-289 行）
- `.section-more-text`（约 291-294 行）
- `.section-more-icon`（约 296-299 行）
- `.icon-bg-gold`（约 338-340 行）
- `.icon-bg-surface`（约 342-344 行）
- `.scene-badge`（约 385-389 行）
- `.badge-brand`（约 391-393 行）
- `.badge-red`（约 395-397 行）
- `.scene-badge-text`（约 399-403 行）
- `.badge-brand .scene-badge-text`（约 405-407 行）
- `.badge-red .scene-badge-text`（约 409-411 行）
- `.add-card` 及其子类（约 414-457 行）

注意：保留 `.icon-bg-green`（推荐场景 Tab 仍使用）。

- [ ] **Step 7: 运行类型检查验证**

Run: `cd lumira-app && npm run type-check`
Expected: PASS（零错误）。

- [ ] **Step 8: 提交**

```bash
cd lumira-app
git add src/pages/capture/scene-guide.vue
git commit -m "feat(scene-guide): Tab 切换修复 + 收藏按钮（列表项 + 小贴士卡片）+ onAdd/onMoreRecommend 跳转 + onLoad 参数兼容"
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
Expected: 看到 Task 1-7 的 7 个提交 + 之前的设计文档修正提交。

- [ ] **Step 4: 手动验证清单（向用户报告）**

向用户报告以下手动验证项，建议在 H5 开发模式下验证：

1. **首页：**
   - 场景推荐区显示 SCENE_PRESETS 前 4 个场景
   - 点击"管理" → 跳转场景管理页
   - 点击"收藏" → 跳转场景管理页收藏 Tab
   - 点击场景卡片 → 跳转 scene-guide 并正确定位
2. **场景管理页：**
   - 收藏 Tab：空状态显示引导按钮；收藏预设后在列表中显示
   - 自定义 Tab：空状态 → 新建表单 → 保存后出现在列表 → 编辑/删除
   - icon 选择器横向滚动正常
   - 删除确认弹窗
3. **灵感页：** 场景卡片点击跳转 scene-guide，"发现更多场景"跳转管理页
4. **场景指南页：**
   - Tab 切换：常用/收藏/推荐内容随 Tab 变化
   - 列表项收藏按钮：点击 ★ 收藏/取消
   - 小贴士卡片收藏按钮：点击 ★ 收藏/取消
   - onAdd（+号）→ 跳转管理页自定义 Tab
   - onLoad 接收 scene/scenePreset 参数正确定位
5. **数据持久化：** 刷新页面后自定义场景和收藏依然存在
6. **类型检查：** `npm run type-check` 零错误
