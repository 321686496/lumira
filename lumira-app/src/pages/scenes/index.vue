<template>
  <view class="scenes-container lumira-container">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">场景库</text>
      <view class="lumira-nav-right" @click="onSearch">
        <text class="ph ph-magnifying-glass nav-search-icon"></text>
      </view>
    </view>

    <view class="category-bar">
      <scroll-view scroll-x class="category-scroll" :show-scrollbar="false">
        <view class="category-list">
          <view
            v-for="c in categories"
            :key="c.id"
            class="category-pill"
            :class="{ active: activeCategory === c.id }"
            @click="activeCategory = c.id"
          >
            <text>{{ c.name }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <view class="scenes-grid">
      <view
        v-for="scene in filteredScenes"
        :key="scene.id"
        class="scene-card-wrap"
        @click="goDetail(scene.id)"
      >
        <ScenePresetView
          :scene="scene"
          :image-src="scene.exampleImages[0]"
          variant="card"
          :badge-text="getPhotoCountByScene(scene.id) > 0 ? `${getPhotoCountByScene(scene.id)} 张` : ''"
        />
      </view>
    </view>

    <view class="fab-btn" @click="goCreate">
      <text class="ph ph-plus fab-icon"></text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useSceneManager } from '@/composables/useSceneManager'
import ScenePresetView from '@/components/ScenePresetView.vue'
import type { SceneCategory } from '@/types/template'

const { allScenes, getPhotoCountByScene } = useSceneManager()

// 分类筛选：全部 + 四种场景分类
const categories = [
  { id: 'all' as const, name: '全部' },
  { id: 'light' as const, name: '光线' },
  { id: 'outdoor' as const, name: '室外' },
  { id: 'indoor' as const, name: '室内' },
  { id: 'mood' as const, name: '情绪' }
]

const activeCategory = ref<SceneCategory | 'all'>('all')
const filteredScenes = computed(() => {
  if (activeCategory.value === 'all') return allScenes.value
  return allScenes.value.filter(s => s.category === activeCategory.value)
})

const back = () => uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/home/index' }) })
const onSearch = () => uni.showToast({ title: '搜索功能开发中', icon: 'none' })
const goDetail = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-detail?sceneId=${id}` })
const goCreate = () => uni.navigateTo({ url: '/pages/capture/scene-manage?tab=custom' })
</script>

<style lang="scss" scoped>
.scenes-container {
  min-height: 100vh;
  background-color: #FAF7F2;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
}

.nav-back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}
.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
  flex: 1;
  padding-left: 16rpx;
  text-align: left;
}
.nav-search-icon {
  font-size: 36rpx;
  color: $color-text-primary;
}

.category-bar {
  padding: 16rpx 24rpx;
  background: #FAF7F2;
}
.category-scroll {
  width: 100%;
  white-space: nowrap;
}
.category-list {
  display: inline-flex;
  gap: 16rpx;
}
.category-pill {
  flex-shrink: 0;
  padding: 12rpx 28rpx;
  border-radius: 9999rpx;
  font-size: 26rpx;
  background: $color-bg-card;
  color: $color-text-secondary;
  display: inline-flex;
  align-items: center;
}
.category-pill.active {
  background: $color-brand-primary;
  color: #ffffff;
}

.scenes-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  padding: 16rpx 24rpx;
}
.scene-card-wrap {
  width: 100%;
}

.fab-btn {
  position: fixed;
  right: 40rpx;
  bottom: calc(env(safe-area-inset-bottom) + 60rpx);
  width: 96rpx;
  height: 96rpx;
  border-radius: 48rpx;
  background: $color-brand-primary;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8rpx 24rpx rgba(0, 0, 0, 0.15);
}
.fab-icon {
  font-size: 48rpx;
  color: #ffffff;
}
</style>
