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
        <text class="count-text">128 张照片</text>
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
            v-for="(p, i) in pills"
            :key="i"
            class="pill"
            :class="{ active: activePill === i }"
            @click="activePill = i"
          >
            <text v-if="p.icon" class="ph pill-icon" :class="p.icon"></text>
            <text class="pill-text">{{ p.label }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <!-- 3-Column Photo Grid -->
    <view class="grid-wrap">
      <view class="photo-grid">
        <view
          v-for="(photo, i) in photos"
          :key="i"
          class="photo-cell fade-up"
          :class="delayClass(i)"
          @click="goDetail"
        >
          <image class="photo-img" :src="photo.img" mode="aspectFill" />
          <view v-if="photo.mark" class="photo-mark">
            <text class="ph photo-mark-icon" :class="photo.mark"></text>
          </view>
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
import { ref } from 'vue'

const viewTab = ref<'photo' | 'diary'>('photo')
const activePill = ref(0)

const pills = ref([
  { label: '全部', icon: '' },
  { label: '穿搭', icon: 'ph-t-shirt' },
  { label: '收藏', icon: 'ph-heart' },
  { label: '咖啡馆', icon: 'ph-coffee' },
  { label: '街拍', icon: 'ph-buildings' },
  { label: '花店', icon: 'ph-flower' }
])

const photos = ref([
  { img: 'https://picsum.photos/seed/2074130/400/600', mark: 'ph-heart' },
  { img: 'https://picsum.photos/seed/457882/400/400', mark: '' },
  { img: 'https://picsum.photos/seed/1153245/400/400', mark: 'ph-t-shirt' },
  { img: 'https://picsum.photos/seed/1042140/400/400', mark: '' },
  { img: 'https://picsum.photos/seed/373326/400/400', mark: 'ph-heart' },
  { img: 'https://picsum.photos/seed/774095/400/400', mark: '' },
  { img: 'https://picsum.photos/seed/312415/400/400', mark: 'ph-coffee' },
  { img: 'https://picsum.photos/seed/1926773/400/400', mark: 'ph-heart' },
  { img: 'https://picsum.photos/seed/414628/400/400', mark: '' }
])

const delayClass = (i: number) => {
  const d = (i % 3) + 1
  return d === 1 ? 'fade-up-d1' : d === 2 ? 'fade-up-d2' : 'fade-up-d3'
}

const back = () => uni.navigateBack()
const goDetail = () => uni.navigateTo({ url: '/pages/gallery/detail' })
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
  display: flex;
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

/* 3 列网格 */
.grid-wrap {
  padding: 0 48rpx;
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

.photo-mark {
  position: absolute;
  bottom: 8rpx;
  right: 8rpx;
}

.photo-mark-icon {
  font-size: 24rpx;
  color: #fff;
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
