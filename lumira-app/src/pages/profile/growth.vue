<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="lumira-nav-title">成长中心</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 等级进度卡 -->
      <view class="lumira-card level-card fade-up">
        <text class="level-label">LEVEL</text>
        <text class="level-num">{{ growthData.level }}</text>
        <text class="level-name">{{ growthData.levelName }}</text>
        <view class="lumira-progress level-progress">
          <view class="lumira-progress-fill" :style="{ width: growthData.progressPercent + '%' }"></view>
        </view>
        <view class="level-meta">
          <text class="level-meta-text">{{ growthData.currentXp }} XP</text>
          <text class="level-meta-mid">还差 {{ growthData.remainingXp }} XP 升级</text>
          <text class="level-meta-text">{{ growthData.nextLevelXp }} XP</text>
        </view>
      </view>

      <!-- 成就墙 -->
      <view class="lumira-card achievement-card fade-up fade-up-d1">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">成就</text>
          <text class="section-title-count">{{ unlockedAchievementCount }} / {{ achievements.length }}</text>
        </view>
        <view class="achievement-grid">
          <view class="achievement-item" v-for="(a, i) in achievements" :key="i" :class="{ locked: a.locked }">
            <text class="ph achievement-icon" :class="a.icon"></text>
            <text class="achievement-name">{{ a.name }}</text>
          </view>
        </view>
      </view>

      <!-- 成长轨迹 -->
      <view class="lumira-card trajectory-card fade-up fade-up-d2">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">成长轨迹</text>
        </view>
        <view v-if="trajectory.length > 0" class="trajectory-list">
          <view class="trajectory-item" v-for="(t, i) in trajectory" :key="i" :class="{ last: i === trajectory.length - 1 }">
            <view class="trajectory-line-col">
              <view class="trajectory-dot"></view>
              <view class="trajectory-line" v-if="i !== trajectory.length - 1"></view>
            </view>
            <view class="trajectory-body">
              <text class="trajectory-title">{{ t.title }}</text>
              <text class="trajectory-date">{{ t.date }}</text>
            </view>
          </view>
        </view>
        <view v-else class="empty-trajectory">
          <text class="ph ph-path empty-trajectory-icon"></text>
          <text class="empty-trajectory-text">开始拍摄，记录你的成长轨迹</text>
        </view>
      </view>

      <!-- 拍摄日历 -->
      <view class="lumira-card calendar-card fade-up fade-up-d3">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">拍摄日历</text>
          <text class="section-title-count">本月 {{ monthPhotoCount }} 张</text>
        </view>
        <scroll-view scroll-x class="heatmap-scroll">
          <view class="heatmap-grid">
            <view
              class="heatmap-cell"
              :class="heatClass(c)"
              v-for="(c, i) in heatmap"
              :key="i"
            ></view>
          </view>
        </scroll-view>
        <view class="heatmap-legend">
          <text class="legend-text">少</text>
          <view class="heatmap-cell legend-cell"></view>
          <view class="heatmap-cell heatmap-c1 legend-cell"></view>
          <view class="heatmap-cell heatmap-c2 legend-cell"></view>
          <view class="heatmap-cell heatmap-c3 legend-cell"></view>
          <view class="heatmap-cell heatmap-c4 legend-cell"></view>
          <text class="legend-text">多</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { useGrowth } from '@/composables/useGrowth'

const goBack = () => uni.navigateBack()

const {
  growthData,
  achievements,
  unlockedAchievementCount,
  trajectory,
  heatmap,
  monthPhotoCount,
} = useGrowth()

const heatClass = (level: number) => {
  if (level === 0) return ''
  return `heatmap-c${level}`
}
</script>

<style lang="scss" scoped>
.nav-back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.page-body {
  padding: 48rpx;
}

/* 等级进度卡 */
.level-card {
  margin-bottom: 32rpx;
  text-align: center;
}

.level-label {
  display: block;
  font-family: 'Courier New', monospace;
  font-size: 26rpx;
  letter-spacing: 0.06em;
  color: $color-brand-primary;
}

.level-num {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 96rpx;
  font-weight: 600;
  line-height: 1.1;
  margin: 8rpx 0;
  color: $color-text-primary;
}

.level-name {
  display: block;
  font-size: 30rpx;
  color: $color-text-secondary;
  margin-bottom: 32rpx;
}

.level-progress {
  height: 16rpx;
}

.level-meta {
  display: flex;
  justify-content: space-between;
  margin-top: 16rpx;
}

.level-meta-text {
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
  color: $color-text-secondary;
  letter-spacing: 0.02em;
}

.level-meta-mid {
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
  color: $color-text-secondary;
  letter-spacing: 0.02em;
}

/* 区块标题 */
.section-title-row {
  margin-bottom: 32rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.section-title-count {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

/* 成就墙 */
.achievement-card {
  margin-bottom: 32rpx;
}

.achievement-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24rpx;
}

.achievement-item {
  background-color: $color-bg-card;
  border: 2rpx solid $color-border;
  border-radius: 28rpx;
  padding: 32rpx 16rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.achievement-item.locked {
  opacity: 0.5;
  filter: grayscale(0.6);
}

.achievement-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 72rpx;
  margin-bottom: 12rpx;
  color: $color-text-primary;
  width: 100%;
  text-align: center;
}

.achievement-name {
  display: block;
  font-size: 22rpx;
  font-weight: 500;
  color: $color-text-primary;
  text-align: center;
  width: 100%;
}

.achievement-item.locked .achievement-name {
  color: $color-text-tertiary;
}

/* 成长轨迹 */
.trajectory-card {
  margin-bottom: 32rpx;
}

.trajectory-list {
  display: flex;
  flex-direction: column;
  padding-left: 8rpx;
}

.trajectory-item {
  display: flex;
  gap: 32rpx;
  position: relative;
}

.trajectory-line-col {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.trajectory-dot {
  width: 20rpx;
  height: 20rpx;
  border-radius: 50%;
  background-color: $color-brand-primary;
  border: 4rpx solid $color-bg-card;
  box-shadow: 0 0 0 4rpx $color-brand-primary;
}

.trajectory-line {
  width: 4rpx;
  height: 96rpx;
  background-color: $color-border;
}

.trajectory-body {
  padding-bottom: 32rpx;
}

.trajectory-item.last .trajectory-body {
  padding-bottom: 0;
}

/* 空轨迹状态 */
.empty-trajectory {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 48rpx 32rpx;
  gap: 12rpx;
}

.empty-trajectory-icon {
  font-size: 72rpx;
  color: $color-text-tertiary;
  opacity: 0.4;
}

.empty-trajectory-text {
  font-size: 26rpx;
  color: $color-text-tertiary;
}

.trajectory-title {
  display: block;
  font-size: 28rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.trajectory-date {
  display: block;
  font-family: 'Courier New', monospace;
  font-size: 22rpx;
  color: $color-text-secondary;
  margin-top: 4rpx;
  letter-spacing: 0.02em;
}

/* 拍摄日历 */
.calendar-card {
  margin-bottom: 32rpx;
}

.heatmap-scroll {
  white-space: nowrap;
}

.heatmap-grid {
  display: grid;
  grid-template-columns: repeat(10, 1fr);
  gap: 4rpx;
  min-width: 720rpx;
}

.heatmap-cell {
  aspect-ratio: 1;
  border-radius: 4rpx;
  background-color: $color-border;
}

.heatmap-c1 {
  background-color: rgba(201, 169, 110, 0.2);
}

.heatmap-c2 {
  background-color: rgba(201, 169, 110, 0.4);
}

.heatmap-c3 {
  background-color: rgba(201, 169, 110, 0.6);
}

.heatmap-c4 {
  background-color: $color-brand-primary;
}

.heatmap-legend {
  display: flex;
  align-items: center;
  gap: 12rpx;
  justify-content: flex-end;
  margin-top: 24rpx;
}

.legend-text {
  font-size: 22rpx;
  color: $color-text-tertiary;
}

.legend-cell {
  width: 20rpx;
  height: 20rpx;
  aspect-ratio: auto;
}
</style>
