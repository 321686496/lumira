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
