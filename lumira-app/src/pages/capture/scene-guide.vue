<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">场景</text>
      <view class="lumira-nav-right" @click="onAdd">
        <text class="ph ph-plus nav-icon"></text>
      </view>
    </view>

    <!-- 场景分类标签 -->
    <view class="tabs-wrap fade-up">
      <view class="tabs-row">
        <view
          class="tab-pill"
          :class="{ active: tab === t.value }"
          v-for="t in tabList"
          :key="t.value"
          @click="tab = t.value"
        >
          <text class="tab-pill-text">{{ t.label }}</text>
        </view>
      </view>
    </view>

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

    <!-- 场景小贴士（选中场景后显示） -->
    <view v-if="selectedPreset" class="section-pad fade-up">
      <view class="tip-detail-card">
        <view class="tip-detail-head">
          <text class="ph ph-lightbulb tip-detail-icon"></text>
          <text class="tip-detail-title">{{ selectedPreset.name }} · 拍摄小贴士</text>
          <view
            v-if="selectedPreset && !isCustomScene(selectedPreset)"
            class="fav-btn-tip"
            @click="selectedPreset && onToggleFav(selectedPreset.id)"
          >
            <text class="ph fav-tip-icon" :class="isFavorite(selectedPreset.id as ScenePresetId) ? 'ph-star-fill' : 'ph-star'"></text>
          </view>
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

    <view class="bottom-spacer"></view>
  </view>
</template>

<script setup lang="ts">
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
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

/* ===== 分类标签 ===== */
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

/* ===== 区块通用 ===== */
.section-pad {
  padding: 48rpx 48rpx 0;
}

.section-pad-bottom {
  padding: 0 48rpx 0;
  margin-top: 48rpx;
}

.section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 32rpx;
}

.section-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.section-count {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

/* ===== 场景列表 ===== */
.scene-list {
  display: flex;
  flex-direction: column;
}

.scene-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 0;
  border-bottom: 2rpx solid var(--color-divider);
}

.scene-list .scene-item:last-child {
  border-bottom: none;
}

.scene-item:active {
  opacity: 0.7;
}

.scene-item-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background-color: var(--color-surface-alt);
}

.icon-bg-green {
  background-color: var(--color-success-subtle);
}

.scene-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.icon-bg-green .scene-icon {
  color: var(--color-success);
}

.scene-item-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.scene-item-title {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.scene-item-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.scene-item-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

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

.bottom-spacer {
  height: 48rpx;
}

/* ===== 场景小贴士卡片 ===== */
.tip-detail-card {
  background-color: var(--color-surface);
  border-radius: 28rpx;
  padding: 40rpx;
  box-shadow: var(--shadow-convex);
}

.tip-detail-head {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 32rpx;
}

.tip-detail-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

.tip-detail-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.tip-detail-body {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  margin-bottom: 40rpx;
}

.tip-detail-row {
  display: flex;
  align-items: flex-start;
  gap: 12rpx;
}

.tip-detail-row-icon {
  font-size: 28rpx;
  color: var(--color-brand);
  flex-shrink: 0;
  margin-top: 2rpx;
}

.tip-detail-row-label {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
  width: 64rpx;
}

.tip-detail-row-text {
  font-size: 26rpx;
  color: var(--color-text-primary);
  line-height: 1.5;
  flex: 1;
}

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

.tip-detail-actions {
  display: flex;
  gap: 20rpx;
}

.tip-detail-btn-ghost,
.tip-detail-btn-brand {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  padding: 24rpx 0;
  border-radius: 9999rpx;
  font-size: 28rpx;
  font-weight: 500;
}

.tip-detail-btn-ghost {
  background-color: var(--color-surface-alt);
  color: var(--color-text-primary);
}

.tip-detail-btn-brand {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
}

.tip-detail-btn-ghost .ph,
.tip-detail-btn-brand .ph {
  font-size: 30rpx;
}
</style>
