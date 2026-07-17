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
        <view
          class="tab-pill"
          :class="{ active: tab === 'kit' }"
          @click="tab = 'kit'"
        >
          <text class="tab-pill-text">我的组合</text>
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
        <ScenePresetView
          v-for="preset in favoriteScenes"
          :key="preset.id"
          :scene="preset"
          @click="goGuide($event)"
        >
          <template #actions>
            <view class="fav-star-btn" @click.stop="onToggleFav(preset.id)">
              <text class="ph ph-star-fill fav-star-icon"></text>
            </view>
          </template>
        </ScenePresetView>
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

        <!-- 氛围主标题 vibe -->
        <view class="form-field">
          <text class="form-label">情绪主标题</text>
          <input class="form-input" v-model="formData.vibe" placeholder="如：慵懒午后，把光调成蜜糖色" maxlength="40" />
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

        <!-- 出片地点 -->
        <view class="form-field">
          <text class="form-label">出片地点</text>
          <input class="form-input" v-model="formData.whereToShoot" placeholder="如：咖啡馆 / 图书馆" />
        </view>

        <!-- 最佳拍摄时间 -->
        <view class="form-field">
          <text class="form-label">最佳拍摄时间</text>
          <input class="form-input" v-model="formData.bestTime" placeholder="如：下午 14:00-17:00" />
        </view>

        <!-- 氛围滤镜 LUT -->
        <view class="form-field">
          <text class="form-label">LUT 滤镜</text>
          <view class="pill-list-inline">
            <view
              v-for="lut in lutOptions"
              :key="lut.value"
              class="pill"
              :class="{ active: formData.filter.lut === lut.value }"
              @click="formData.filter.lut = lut.value"
            >
              <text class="pill-text">{{ lut.label }}</text>
            </view>
          </view>
        </view>

        <!-- 系统滤镜（可选） -->
        <view class="form-field">
          <text class="form-label">系统滤镜（可选）</text>
          <view class="pill-list-inline">
            <view
              v-for="sf in systemFilterOptions"
              :key="sf.value"
              class="pill"
              :class="{ active: formData.filter.systemFilter === sf.value }"
              @click="formData.filter.systemFilter = formData.filter.systemFilter === sf.value ? undefined : sf.value"
            >
              <text class="pill-text">{{ sf.label }}</text>
            </view>
          </view>
        </view>

        <!-- 滤镜理由 -->
        <view class="form-field">
          <text class="form-label">滤镜理由</text>
          <input class="form-input" v-model="formData.filter.reason" placeholder="如：让画面像被夕阳包住一样温柔" />
        </view>

        <!-- 示例图（picsum seed） -->
        <view class="form-field">
          <text class="form-label">示例图（输入关键词，最多 3 张）</text>
          <view class="seed-list">
            <view
              v-for="(_, idx) in formData.exampleImageSeeds"
              :key="idx"
              class="seed-row"
            >
              <input
                class="form-input seed-input"
                v-model="formData.exampleImageSeeds[idx]"
                :placeholder="`图 ${idx + 1} 关键词（如：cat`"
              />
            </view>
          </view>
        </view>

        <!-- 拍摄贴士 -->
        <view class="form-field">
          <text class="form-label">拍摄贴士（每行一条）</text>
          <textarea
            class="form-textarea"
            v-model="formData.tipsText"
            placeholder="如：&#10;让模特侧对窗户&#10;白平衡偏暖一档"
            :auto-height="true"
          />
        </view>

        <!-- 标签 -->
        <view class="form-field">
          <text class="form-label">标签</text>
          <TagSelector
            :selected-tag-ids="formData.tagIds"
            type="scene"
            @update:selectedTagIds="onTagIdsUpdate"
          />
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
          <ScenePresetView
            v-for="scene in customScenes"
            :key="scene.id"
            :scene="scene"
            @click="goGuide($event)"
          >
            <template #actions>
              <view class="custom-more-btn" @click.stop="onMore(scene)">
                <text class="ph ph-dots-three custom-more-icon"></text>
              </view>
            </template>
          </ScenePresetView>
          <view class="add-btn" @click="onNew">
            <text class="ph ph-plus add-btn-icon"></text>
            <text class="add-btn-text">新建场景</text>
          </view>
        </view>
      </view>
    </view>

    <!-- Tab 3: 我的组合 -->
    <view v-if="tab === 'kit'" class="section-pad fade-up fade-up-d1">
      <view v-if="kits.length === 0" class="empty-state">
        <text class="ph ph-stack empty-icon"></text>
        <text class="empty-title">还没有组合</text>
        <text class="empty-desc">点击下方按钮新建一个吧</text>
      </view>
      <view v-else class="kit-list">
        <view
          v-for="kit in kits"
          :key="kit.id"
          class="kit-item"
          @click="onKitClick(kit.id)"
        >
          <KitCard
            :kit="kit"
            :scene="getSceneById(kit.sceneId)"
            :template="loadTemplate(kit.templateId) || undefined"
          />
        </view>
      </view>
      <view class="kit-create-btn" @click="goCreateKit">
        <text class="ph ph-plus kit-create-icon"></text>
        <text class="kit-create-text">新建组合</text>
      </view>
    </view>

    <view class="bottom-spacer"></view>
  </view>
</template>

<script setup lang="ts">
import { ref, reactive, watch, nextTick } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import ScenePresetView from '@/components/ScenePresetView.vue'
import KitCard from '@/components/KitCard.vue'
import TagSelector from '@/components/TagSelector.vue'
import { useSceneManager } from '@/composables/useSceneManager'
import { useShootKit } from '@/composables/useShootKit'
import { useTemplate } from '@/composables/useTemplate'
import { getLutOptions, getSystemFilterOptions } from '@/utils/filterRecipe'
import type {
  ScenePresetId,
  Target,
  LutPreset,
  SystemFilter,
  SceneCategory,
  CustomScenePreset
} from '@/types/template'

const {
  customScenes,
  favoriteScenes,
  toggleFavorite,
  addCustomScene,
  updateCustomScene,
  deleteCustomScene,
  reloadFromStorage,
  getSceneById
} = useSceneManager()

const { kits, deleteKit } = useShootKit()
const { loadTemplate } = useTemplate()

const tab = ref<'fav' | 'custom' | 'kit'>('fav')
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

const lutOptions = getLutOptions().map(o => ({ value: o.id, label: o.name }))
const systemFilterOptions = getSystemFilterOptions().map(o => ({ value: o.id, label: o.name }))

interface FormData {
  name: string
  icon: string
  description: string
  vibe: string
  relatedCategory: Target
  category: SceneCategory
  style: string
  sceneGuide: {
    lightDirection: string
    shootingDistance: string
    background: string
    props: string[]
    bestTime: string
    tips: string[]
  }
  filter: {
    lut: LutPreset
    systemFilter?: SystemFilter
    reason: string
  }
  exampleImageSeeds: string[]
  whereToShoot: string
  bestTime: string
  tipsText: string
  recommendedTagIds: string[]
  tagIds: string[]
}

function createDefaultForm(): FormData {
  return {
    name: '',
    icon: 'ph-camera',
    description: '',
    vibe: '',
    relatedCategory: 'portrait',
    category: 'indoor',
    style: 'cafe',
    sceneGuide: {
      lightDirection: '自然光',
      shootingDistance: '1-2米',
      background: '简洁背景',
      props: [],
      bestTime: '全天',
      tips: []
    },
    filter: {
      lut: 'none',
      systemFilter: undefined,
      reason: ''
    },
    exampleImageSeeds: ['', '', ''],
    whereToShoot: '',
    bestTime: '',
    tipsText: '',
    recommendedTagIds: [],
    tagIds: []
  }
}

const formData = reactive<FormData>(createDefaultForm())
const formDirty = ref(false)

onLoad((options) => {
  if (options?.tab === 'custom') {
    tab.value = 'custom'
  } else if (options?.tab === 'kit') {
    tab.value = 'kit'
  }
  // sceneId 参数：从 scene-detail 跳转来创建组合的入口；
  // 当前页仅展示已有组合列表，这里仅做读取，不强制弹出新建表单（YAGNI）。
})

onShow(() => {
  reloadFromStorage()
})

// 监听表单字段变化，标记为脏状态
watch(
  () => ({
    name: formData.name,
    icon: formData.icon,
    description: formData.description,
    vibe: formData.vibe,
    relatedCategory: formData.relatedCategory,
    category: formData.category,
    style: formData.style,
    lightDirection: formData.sceneGuide.lightDirection,
    shootingDistance: formData.sceneGuide.shootingDistance,
    background: formData.sceneGuide.background,
    whereToShoot: formData.whereToShoot,
    bestTime: formData.bestTime,
    filterLut: formData.filter.lut,
    filterSystemFilter: formData.filter.systemFilter,
    filterReason: formData.filter.reason,
    exampleImageSeeds: [...formData.exampleImageSeeds],
    tipsText: formData.tipsText
  }),
  () => {
    if (formVisible.value) {
      formDirty.value = true
    }
  }
)

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

/** 从 picsum URL 中提取 seed */
function seedFromUrl(url: string): string {
  const m = url.match(/\/seed\/([^/]+)\//)
  return m ? m[1] : ''
}

const onNew = () => {
  editingId.value = null
  Object.assign(formData, createDefaultForm())
  formVisible.value = true
  // 在 watch 触发后重置脏状态，避免初始赋值被误判为用户编辑
  nextTick(() => {
    formDirty.value = false
  })
}

const onEdit = (scene: CustomScenePreset) => {
  editingId.value = scene.id
  Object.assign(formData, {
    name: scene.name,
    icon: scene.icon,
    description: scene.description,
    vibe: scene.vibe,
    relatedCategory: scene.relatedCategory,
    category: scene.category,
    style: scene.style,
    sceneGuide: {
      lightDirection: scene.sceneGuide.lightDirection,
      shootingDistance: scene.sceneGuide.shootingDistance,
      background: scene.sceneGuide.background,
      props: [...scene.sceneGuide.props],
      bestTime: scene.sceneGuide.bestTime,
      tips: [...scene.sceneGuide.tips]
    },
    filter: {
      lut: scene.filter.lut,
      systemFilter: scene.filter.systemFilter,
      reason: scene.filter.reason
    },
    exampleImageSeeds: [
      scene.exampleImages[0] ? seedFromUrl(scene.exampleImages[0]) : '',
      scene.exampleImages[1] ? seedFromUrl(scene.exampleImages[1]) : '',
      scene.exampleImages[2] ? seedFromUrl(scene.exampleImages[2]) : ''
    ],
    whereToShoot: scene.whereToShoot,
    bestTime: scene.bestTime,
    tipsText: scene.tips.join('\n'),
    recommendedTagIds: [...scene.recommendedTagIds],
    tagIds: [...scene.tagIds]
  })
  formVisible.value = true
  nextTick(() => {
    formDirty.value = false
  })
}

const onCancelForm = () => {
  if (formDirty.value) {
    uni.showModal({
      title: '确认离开',
      content: '当前表单有未保存的变更，确定要离开吗？',
      success: (res) => {
        if (res.confirm) {
          formVisible.value = false
          editingId.value = null
          formDirty.value = false
        }
      }
    })
  } else {
    formVisible.value = false
    editingId.value = null
  }
}

// TagSelector 双向更新：直接赋值触发 reactive 更新
const onTagIdsUpdate = (ids: string[]) => {
  formData.tagIds = ids
}

const onSaveForm = () => {
  if (!formData.name.trim()) {
    uni.showToast({ title: '请输入场景名称', icon: 'none' })
    return
  }

  const exampleImages = formData.exampleImageSeeds
    .map(s => s.trim())
    .filter(s => s.length > 0)
    .map(s => `https://picsum.photos/seed/${s}/600/800`)

  const tips = formData.tipsText
    .split('\n')
    .map(t => t.trim())
    .filter(t => t.length > 0)

  const sceneData = {
    name: formData.name.trim(),
    icon: formData.icon,
    description: formData.description.trim(),
    vibe: formData.vibe.trim(),
    relatedCategory: formData.relatedCategory,
    category: formData.category,
    style: formData.style,
    sceneGuide: {
      lightDirection: formData.sceneGuide.lightDirection,
      shootingDistance: formData.sceneGuide.shootingDistance,
      background: formData.sceneGuide.background,
      props: [...formData.sceneGuide.props],
      bestTime: formData.sceneGuide.bestTime,
      tips: [...formData.sceneGuide.tips]
    },
    filter: {
      lut: formData.filter.lut,
      systemFilter: formData.filter.systemFilter,
      reason: formData.filter.reason.trim()
    },
    exampleImages,
    whereToShoot: formData.whereToShoot.trim(),
    bestTime: formData.bestTime.trim(),
    tips,
    recommendedTagIds: [...formData.recommendedTagIds],
    tagIds: [...formData.tagIds]
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
  formDirty.value = false
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

const onKitClick = (id: string) => {
  uni.showActionSheet({
    itemList: ['删除组合'],
    success: (res) => {
      if (res.tapIndex === 0) {
        uni.showModal({
          title: '删除组合',
          content: '确定删除这个组合吗？',
          confirmColor: '#C9453D',
          success: (modalRes) => {
            if (modalRes.confirm) {
              deleteKit(id)
              uni.showToast({ title: '已删除', icon: 'success' })
            }
          }
        })
      }
    }
  })
}

function goCreateKit() {
  uni.navigateTo({ url: '/pages/shootkit/editor' })
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

.fav-star-btn {
  flex-shrink: 0;
  padding: 8rpx;
}

.fav-star-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

/* ===== 自定义场景列表 ===== */
.custom-list {
  display: flex;
  flex-direction: column;
}

.custom-more-btn {
  flex-shrink: 0;
  padding: 8rpx;
}

.custom-more-icon {
  font-size: 36rpx;
  color: var(--color-text-tertiary);
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

.form-textarea {
  width: 100%;
  min-height: 160rpx;
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

/* 示例图 seed 输入 */
.seed-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.seed-row {
  display: flex;
}

.seed-input {
  flex: 1;
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

/* ===== 组合列表 ===== */
.kit-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.kit-item {
  border-radius: 20rpx;
  overflow: hidden;
}

.kit-item:active {
  opacity: 0.85;
}

/* ===== 新建组合按钮 ===== */
.kit-create-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  margin-top: 32rpx;
  padding: 24rpx;
  border-radius: 16rpx;
  border: 2rpx dashed var(--color-brand);
  background: var(--color-brand-subtle);
}

.kit-create-icon {
  font-size: 32rpx;
  color: var(--color-brand);
}

.kit-create-text {
  font-size: 28rpx;
  color: var(--color-brand);
  font-weight: 500;
}
</style>
