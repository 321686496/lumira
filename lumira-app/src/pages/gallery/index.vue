<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">相册</text>
      <view class="lumira-nav-right" @click="goCollections">
        <text class="nav-link">精选集</text>
      </view>
    </view>

    <!-- Count & View Toggle -->
    <view class="top-bar fade-up">
      <view class="top-bar-row">
        <text class="count-text">{{ photos.length }} 张照片</text>
        <view class="view-toggle">
          <view
            class="view-toggle-item"
            :class="{ active: viewTab === 'photo' }"
            @click="viewTab = 'photo'"
          >
            <text class="view-toggle-text">照片</text>
          </view>
          <view
            class="view-toggle-item"
            :class="{ active: viewTab === 'diary' }"
            @click="goDiary"
          >
            <text class="view-toggle-text">拍摄日记</text>
          </view>
        </view>
      </view>

      <!-- Filter Pills -->
      <scroll-view scroll-x class="pill-row" :show-scrollbar="false">
        <view class="pill-inner">
          <view
            v-for="p in pills"
            :key="p.key"
            class="pill"
            :class="{ active: activeFilter === p.key }"
            @click="activeFilter = p.key"
          >
            <text v-if="p.icon" class="ph pill-icon" :class="p.icon"></text>
            <text class="pill-text">{{ p.label }}</text>
            <text class="pill-count">{{ p.count }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <!-- 3-Column Photo Grid -->
    <view class="grid-wrap">
      <view v-if="filteredPhotos.length === 0" class="empty-state">
        <text class="ph ph-image empty-icon"></text>
        <text class="empty-text">还没有照片，去拍一张吧</text>
      </view>
      <view v-else class="photo-grid">
        <view
          v-for="(photo, i) in filteredPhotos"
          :key="photo.id"
          class="photo-cell fade-up"
          :class="delayClass(i)"
          @click="goDetail(photo.id)"
        >
          <image class="photo-img" :src="photo.dataUrl" mode="aspectFill" />
        </view>
      </view>
    </view>

    <!-- Long-press Multi-select Hint -->
    <view class="hint">
      <text class="hint-text">长按照片进入多选模式 · 支持批量删除与导出</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import type { AnyScene } from '@/types/template'

const { photos, getPhotosGroupedByScene, getSceneById, reloadFromStorage } = useSceneManager()

const viewTab = ref<'photo' | 'diary'>('photo')

interface Pill {
  label: string
  icon: string
  count: number
  key: string
}

const pills = computed<Pill[]>(() => {
  const groups = getPhotosGroupedByScene()
  const result: Pill[] = [
    { label: '全部', icon: '', count: photos.value.length, key: 'all' }
  ]
  Object.entries(groups).forEach(([key, list]) => {
    if (key === 'uncategorized') {
      result.push({ label: '未分类', icon: 'ph-folder-dashed', count: list.length, key: 'uncategorized' })
    } else {
      const scene = getSceneById(key)
      if (scene) {
        result.push({ label: scene.name, icon: scene.icon, count: list.length, key: `scene_${key}` })
      }
    }
  })
  return result
})

const activeFilter = ref('all')

const filteredPhotos = computed(() => {
  if (activeFilter.value === 'all') return photos.value
  if (activeFilter.value === 'uncategorized') {
    return photos.value.filter(p => !p.sceneId)
  }
  if (activeFilter.value.startsWith('scene_')) {
    const sceneId = activeFilter.value.replace('scene_', '')
    return photos.value.filter(p => p.sceneId === sceneId)
  }
  return photos.value
})

const delayClass = (i: number) => {
  const d = (i % 3) + 1
  return d === 1 ? 'fade-up-d1' : d === 2 ? 'fade-up-d2' : 'fade-up-d3'
}

onShow(() => {
  reloadFromStorage()
})

const back = () => uni.navigateBack()
const goDetail = (id: string) => uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
const goDiary = () => uni.navigateTo({ url: '/pages/gallery/diary' })
const goCollections = () => uni.navigateTo({ url: '/pages/profile/collections' })
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.nav-link {
  font-size: 26rpx;
  color: $color-brand-primary;
  font-weight: 500;
}

/* 顶部信息条 */
.top-bar {
  padding: 32rpx 48rpx 0;
}

.top-bar-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 32rpx;
}

.count-text {
  font-size: 26rpx;
  color: $color-text-tertiary;
}

.view-toggle {
  display: flex;
  background-color: $color-bg-surface;
  border-radius: 9999rpx;
  padding: 6rpx;
}

.view-toggle-item {
  padding: 12rpx 36rpx;
  border-radius: 9999rpx;
  background: transparent;
}

.view-toggle-item.active {
  background-color: $color-bg-card;
  box-shadow: 0 2rpx 6rpx rgba(0, 0, 0, 0.06);
}

.view-toggle-text {
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-tertiary;
}

.view-toggle-item.active .view-toggle-text {
  color: $color-text-primary;
}

/* 筛选 Pills */
.pill-row {
  margin-bottom: 32rpx;
  white-space: nowrap;
}

.pill-inner {
  display: inline-flex;
  gap: 16rpx;
}

.pill {
  flex-shrink: 0;
  padding: 14rpx 32rpx;
  border-radius: 9999rpx;
  border: 3rpx solid $color-border;
  background-color: $color-bg-card;
  display: inline-flex;
  align-items: center;
  gap: 12rpx;
}

.pill.active {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  border-color: transparent;
}

.pill-icon {
  font-size: 28rpx;
  color: $color-text-secondary;
}

.pill.active .pill-icon {
  color: #fff;
}

.pill-text {
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-secondary;
}

.pill.active .pill-text {
  color: #fff;
}

.pill-count {
  font-size: 20rpx;
  background: rgba(0, 0, 0, 0.1);
  padding: 2rpx 12rpx;
  border-radius: 9999rpx;
  color: $color-text-tertiary;
}

.pill.active .pill-count {
  background: rgba(255, 255, 255, 0.3);
  color: #fff;
}

/* 3 列网格 */
.grid-wrap {
  padding: 0 48rpx;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 120rpx 0;
  gap: 16rpx;
}

.empty-icon {
  font-size: 96rpx;
  color: $color-text-tertiary;
}

.empty-text {
  font-size: 28rpx;
  color: $color-text-tertiary;
}

.photo-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16rpx;
}

.photo-cell {
  position: relative;
  width: 100%;
  height: 0;
  padding-bottom: 100%;
  border-radius: 16rpx;
  overflow: hidden;
}

.photo-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

/* 提示 */
.hint {
  text-align: center;
  padding: 48rpx 48rpx 32rpx;
}

.hint-text {
  font-size: 22rpx;
  color: $color-text-tertiary;
  letter-spacing: 0.04em;
}
</style>
