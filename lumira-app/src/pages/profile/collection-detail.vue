<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">我最爱的九张</text>
      <view class="lumira-nav-right" @click="editCollection">
        <text class="nav-edit">编辑</text>
      </view>
    </view>

    <!-- 3-Column Grid -->
    <view class="grid-wrap">
      <view class="photo-grid">
        <view
          v-for="(p, i) in photos"
          :key="i"
          class="photo-cell fade-up"
          :class="delayClass(i)"
        >
          <image class="photo-img" :src="p" mode="aspectFill" />
        </view>
      </view>
    </view>

    <!-- Stats -->
    <view class="stats-section fade-in">
      <view class="stats-row">
        <view class="stats-item">
          <text class="lumira-stat-num">9</text>
          <text class="lumira-stat-label">张照片</text>
        </view>
        <view class="stats-divider"></view>
        <view class="stats-item">
          <text class="lumira-stat-num">7.9</text>
          <text class="lumira-stat-label">平均评分</text>
        </view>
        <view class="stats-divider"></view>
        <view class="stats-item">
          <text class="lumira-stat-num">7/1</text>
          <text class="lumira-stat-label">创建日</text>
        </view>
      </view>
    </view>

    <!-- Export Button -->
    <view class="export-section">
      <view class="lumira-btn-primary" @click="exportGrid">
        <text class="export-btn-text">导出九宫格拼图</text>
        <text class="ph ph-paper-plane-tilt export-btn-icon"></text>
      </view>
    </view>

    <!-- Hint -->
    <view class="hint fade-in">
      <text class="hint-text">导出的拼图可直接分享到社交媒体</text>
    </view>
  </view>
</template>

<script setup lang="ts">
const photos = [
  'https://picsum.photos/seed/733872/400/600',
  'https://picsum.photos/seed/1926769/400/600',
  'https://picsum.photos/seed/2074130/400/600',
  'https://picsum.photos/seed/1038002/400/600',
  'https://picsum.photos/seed/172217/400/400',
  'https://picsum.photos/seed/326473/400/600',
  'https://picsum.photos/seed/1239291/400/600',
  'https://picsum.photos/seed/326473/400/600',
  'https://picsum.photos/seed/1080696/400/600'
]

const delayClass = (i: number) => {
  const map = [
    '',
    'fade-up-d1',
    'fade-up-d2',
    'fade-up-d1',
    'fade-up-d2',
    'fade-up-d3',
    'fade-up-d2',
    'fade-up-d3',
    'fade-up-d4'
  ]
  return map[i] || ''
}

const back = () => uni.navigateBack()
const editCollection = () => {
  uni.showToast({ title: '编辑精选集', icon: 'none' })
}
const exportGrid = () => {
  uni.showToast({ title: '已导出拼图', icon: 'success' })
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.nav-edit {
  font-size: 28rpx;
  font-weight: 500;
  color: $color-text-primary;
  padding: 12rpx 24rpx;
}

/* 3 列网格 */
.grid-wrap {
  padding: 40rpx 48rpx 0;
}

.photo-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16rpx;
}

.photo-cell {
  width: 100%;
  height: 0;
  padding-bottom: 100%;
  border-radius: 16rpx;
  overflow: hidden;
  position: relative;
}

.photo-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

/* 统计 */
.stats-section {
  padding: 40rpx 48rpx 0;
}

.stats-row {
  display: flex;
  justify-content: center;
  gap: 64rpx;
  padding: 32rpx 0;
}

.stats-item {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stats-divider {
  width: 2rpx;
  background-color: $color-border;
}

/* 导出按钮 */
.export-section {
  padding: 48rpx 48rpx 0;
}

.export-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: #FAF7F2;
}

.export-btn-icon {
  font-size: 32rpx;
  color: #FAF7F2;
}

/* 提示 */
.hint {
  padding: 32rpx 48rpx 0;
  text-align: center;
}

.hint-text {
  font-size: 22rpx;
  color: $color-text-tertiary;
}
</style>
