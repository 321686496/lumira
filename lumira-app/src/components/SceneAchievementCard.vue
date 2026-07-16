<template>
  <view class="achievement-card">
    <view class="ach-row">
      <view class="ach-stat">
        <text class="ach-icon">📷</text>
        <text class="ach-value">{{ achievement.photoCount }} 张</text>
      </view>
      <view class="ach-stat" v-if="achievement.level > 0">
        <text class="ach-icon">🏆</text>
        <text class="ach-value">{{ sceneName }} {{ achievement.levelName }} Lv.{{ achievement.level }}</text>
      </view>
    </view>
    <view class="ach-progress" v-if="achievement.level < 5">
      <view class="ach-progress-bar">
        <view class="ach-progress-fill" :style="{ width: progressPercent + '%' }"></view>
      </view>
      <text class="ach-progress-text">{{ achievement.photoCount }}/{{ achievement.nextLevelCount }}</text>
    </view>
    <view class="ach-rank" v-if="rank">
      <text class="ach-rank-icon">🔥</text>
      <text class="ach-rank-text">{{ rankLabel || '本周' }}热门 #{{ rank }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { SceneAchievement } from '@/types/template'

const props = defineProps<{
  achievement: SceneAchievement
  sceneName: string
  rank?: number
  rankLabel?: string
}>()

const progressPercent = computed(() => {
  const { photoCount, nextLevelCount } = props.achievement
  if (nextLevelCount <= 0) return 100
  return Math.min(100, Math.max(0, (photoCount / nextLevelCount) * 100))
})
</script>

<style lang="scss" scoped>
.achievement-card {
  padding: 24rpx;
  background: rgba(0, 0, 0, 0.04);
  border-radius: 20rpx;
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.ach-row {
  display: flex;
  gap: 32rpx;
  flex-wrap: wrap;
}

.ach-stat {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.ach-icon {
  font-size: 32rpx;
  line-height: 1;
}

.ach-value {
  font-size: 26rpx;
  color: #2A2520;
  font-weight: 500;
}

.ach-progress {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.ach-progress-bar {
  flex: 1;
  height: 12rpx;
  background: rgba(0, 0, 0, 0.08);
  border-radius: 6rpx;
  overflow: hidden;
}

.ach-progress-fill {
  height: 100%;
  background: #C9A876;
  border-radius: 6rpx;
  transition: width 0.3s ease;
}

.ach-progress-text {
  font-size: 22rpx;
  color: #6B635A;
  flex-shrink: 0;
}

.ach-rank {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.ach-rank-icon {
  font-size: 28rpx;
  line-height: 1;
}

.ach-rank-text {
  font-size: 24rpx;
  color: #C9A876;
  font-weight: 600;
}
</style>
