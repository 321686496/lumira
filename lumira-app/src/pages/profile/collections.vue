<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">我的精选集</text>
      <view class="lumira-nav-right" @click="createCollection">
        <text class="nav-create">+ 新建</text>
      </view>
    </view>

    <!-- Collections Grid -->
    <view class="grid-wrap">
      <view class="collection-grid">
        <view
          v-for="(c, i) in collections"
          :key="i"
          class="lumira-card lumira-card-hover collection-card fade-up"
          :class="delayClass(i)"
          @click="goDetail"
        >
          <view class="card-cover-wrap">
            <image class="card-cover" :src="c.img" mode="aspectFill" />
            <view class="card-count">
              <text class="card-count-text">{{ c.count }}张</text>
            </view>
          </view>
          <view class="card-info">
            <text class="card-name">{{ c.name }}</text>
            <text class="card-updated">更新于 {{ c.updated }}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- Tip Section -->
    <view class="tip-section fade-in">
      <view class="tip-card">
        <text class="ph ph-lightbulb tip-icon"></text>
        <view class="tip-body">
          <text class="tip-title">精选集功能</text>
          <text class="tip-text">将喜欢的照片整理成集，一键导出九宫格拼图</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const collections = ref([
  { img: 'https://picsum.photos/seed/326473/400/400', name: '我最爱的九张', count: 9, updated: '7月10日' },
  { img: 'https://picsum.photos/seed/457882/400/400', name: '旅行精选', count: 24, updated: '6月28日' },
  { img: 'https://picsum.photos/seed/1926769/400/400', name: '穿搭合集', count: 12, updated: '7月10日' },
  { img: 'https://picsum.photos/seed/312415/400/400', name: '咖啡馆时光', count: 8, updated: '6月15日' }
])

const delayClass = (i: number) => {
  const map = ['', 'fade-up-d1', 'fade-up-d2', 'fade-up-d3']
  return map[i] || ''
}

const back = () => uni.navigateBack()
const goDetail = () => uni.navigateTo({ url: '/pages/profile/collection-detail' })
const createCollection = () => {
  uni.showToast({ title: '新建精选集', icon: 'none' })
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.nav-create {
  font-size: 28rpx;
  font-weight: 500;
  color: $color-text-primary;
  padding: 12rpx 24rpx;
}

/* 网格 */
.grid-wrap {
  padding: 40rpx 48rpx 0;
}

.collection-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 32rpx;
}

.collection-card {
  padding: 0;
  overflow: hidden;
}

.card-cover-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 100%;
  overflow: hidden;
  border-radius: 24rpx 24rpx 0 0;
}

.card-cover {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.card-count {
  position: absolute;
  top: 16rpx;
  right: 16rpx;
  background-color: rgba(26, 26, 26, 0.7);
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
}

.card-count-text {
  font-size: 20rpx;
  font-weight: 600;
  color: #fff;
}

.card-info {
  padding: 24rpx 28rpx 28rpx;
}

.card-name {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 28rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.card-updated {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-top: 4rpx;
}

/* 提示 */
.tip-section {
  padding: 64rpx 48rpx 0;
}

.tip-card {
  background-color: $color-bg-surface;
  border-radius: 24rpx;
  padding: 32rpx 40rpx;
  display: flex;
  align-items: center;
  gap: 24rpx;
}

.tip-icon {
  font-size: 48rpx;
  color: $color-text-primary;
}

.tip-body {
  flex: 1;
}

.tip-title {
  display: block;
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.tip-text {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-top: 4rpx;
}
</style>
