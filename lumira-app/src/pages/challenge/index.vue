<template>
  <view class="lumira-container">
    <!-- 顶部导航 -->
    <view class="lumira-nav nav-solid">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">每日挑战</text>
      <view class="lumira-nav-right" @click="goHistory">
        <text class="ph ph-clipboard-text nav-icon"></text>
      </view>
    </view>

    <!-- 内容区 -->
    <view class="page-body">
      <!-- 主挑战卡 -->
      <view class="lumira-card main-card fade-up" :class="{ 'main-card-done': mainCompleted }">
        <view class="main-head">
          <view class="challenge-check" :class="{ 'challenge-check-done': mainCompleted }">
            <text v-if="mainCompleted" class="ph ph-check"></text>
            <text v-else class="ph ph-target"></text>
          </view>
          <view class="main-head-body">
            <view class="main-title-row">
              <text class="ph main-title-icon" :class="mainCompleted ? 'ph-check' : 'ph-circle-half'"></text>
              <text class="main-title">{{ mainCompleted ? '今日挑战已完成' : '今日挑战' }}</text>
            </view>
            <text class="main-desc">{{ mainChallenge.desc }}</text>
            <view class="main-tags">
              <text class="lumira-tag lumira-tag-gold">+{{ mainChallenge.xp }} XP</text>
              <text v-if="mainCompleted" class="lumira-tag lumira-tag-green">
                <text class="ph ph-check"></text>
                <text>已完成</text>
              </text>
              <text v-else class="lumira-tag lumira-tag-red">进行中</text>
            </view>
          </view>
        </view>
        <view class="main-divider"></view>
        <view class="main-img-wrap">
          <image class="main-img" :src="`https://picsum.photos/seed/challenge-${today}/400/600`" mode="aspectFill" />
        </view>
        <view v-if="!mainCompleted" class="main-btn-wrap">
          <view class="lumira-btn-brand sub-btn" @click="goComplete">
            <text class="ph ph-camera"></text>
            <text>去完成</text>
          </view>
        </view>
      </view>

      <!-- 附加挑战区块 -->
      <view class="section-block fade-up fade-up-d1">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">附加挑战</text>
          <text class="section-title-sub">{{ completedCount }}/{{ totalChallenges }} 弹性模式</text>
        </view>
      </view>

      <!-- 附加挑战列表 -->
      <view
        v-for="s in subStatuses"
        :key="s.challenge.id"
        class="lumira-card sub-card fade-up fade-up-d2"
        :class="{ 'sub-card-done': s.done }"
      >
        <view class="sub-row sub-row-top">
          <view class="lumira-list-icon" :class="{ 'list-icon-green': s.done }">
            <text class="ph" :class="s.done ? 'ph-check' : 'ph-palette'"></text>
          </view>
          <view class="list-text">
            <text class="list-title">{{ s.challenge.title }}</text>
            <text class="list-desc">{{ s.done ? '已完成' : s.challenge.condition }}</text>
          </view>
        </view>
        <view class="sub-tags">
          <text class="lumira-tag lumira-tag-gold">+{{ s.challenge.xp }} XP</text>
          <text v-if="s.challenge.hasFragment" class="lumira-tag lumira-tag-red">碎片机会</text>
        </view>
        <view v-if="!s.done" class="lumira-btn-brand sub-btn" @click="goComplete">
          <text>去完成</text>
        </view>
      </view>

      <!-- 明日挑战预览 -->
      <view class="section-block fade-up fade-up-d4">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">明日挑战预览</text>
        </view>
        <view class="lumira-card preview-card">
          <view class="blur-layer">
            <text class="blur-title">{{ tomorrowPreview.title }}</text>
            <text class="blur-desc">{{ tomorrowPreview.desc }}</text>
          </view>
          <view class="preview-mask">
            <text class="lumira-badge lumira-badge-brand">明日揭晓</text>
          </view>
        </view>
      </view>

      <!-- 连续打卡信息 -->
      <view class="section-block fade-up fade-up-d5">
        <view class="lumira-card streak-card">
          <text class="ph ph-flame streak-flame"></text>
          <text class="streak-title">连续打卡 {{ streak }} 天</text>
          <text class="streak-sub">{{ streak > 0 ? '继续保持，解锁连续打卡奖励！' : '今天就开始你的拍摄之旅吧' }}</text>
          <view class="streak-dots">
            <view v-for="n in Math.max(streak, 1)" :key="n" class="streak-dot streak-dot-done">
              <text class="ph ph-check streak-check"></text>
            </view>
            <view class="streak-dot streak-dot-next">
              <text class="streak-dot-num">{{ streak + 1 }}</text>
            </view>
          </view>
          <text class="streak-tip">再坚持 {{ streak >= 7 ? 30 - streak : 7 - streak }} 天获得额外 {{ streak >= 7 ? 100 : 50 }} XP</text>
        </view>
      </view>

      <view class="bottom-space"></view>
    </view>

    <FloatingTabBar active="challenge" />
  </view>
</template>

<script setup lang="ts">
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useChallenge } from '@/composables/useChallenge'
import { useSceneManager } from '@/composables/useSceneManager'

const {
  mainChallenge,
  tomorrowPreview,
  mainCompleted,
  subStatuses,
  totalChallenges,
  completedCount,
  streak,
  today,
  autoCheckChallenge,
} = useChallenge()

const { photos } = useSceneManager()

// 每次显示页面时自动检查挑战完成情况
onShow(() => {
  const usedTemplateIds = [...new Set(photos.value.map(p => p.templateId).filter(Boolean) as string[])]
  const usedSceneIds = [...new Set(photos.value.map(p => p.sceneId).filter(Boolean) as string[])]
  autoCheckChallenge(photos.value.length, usedTemplateIds, usedSceneIds)
})

const goComplete = () => uni.navigateTo({ url: '/pages/capture/index' })
const goHistory = () => uni.navigateTo({ url: '/pages/challenge/detail' })
</script>

<style lang="scss" scoped>
/* 固定标题栏背景，防止内容透出 */
.nav-solid {
  background-color: var(--color-canvas);
}

.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-secondary);
}

.page-body {
  padding: 48rpx 40rpx 0;
}

/* 主挑战卡 */
.main-card {
  padding: 48rpx;
  border-color: var(--color-brand);
}

.main-card-done {
  border-color: var(--color-success);
}

.main-head {
  display: flex;
  align-items: flex-start;
  gap: 28rpx;
}

.challenge-check {
  width: 96rpx;
  height: 96rpx;
  border-radius: 50%;
  background-color: var(--color-brand-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.challenge-check-done {
  background-color: var(--color-success-subtle);
}

.challenge-check .ph {
  font-size: 44rpx;
  color: var(--color-brand-text);
}

.challenge-check-done .ph {
  color: var(--color-success);
}

.main-head-body {
  flex: 1;
}

.main-title-row {
  display: flex;
  align-items: center;
  gap: 8rpx;
  margin-bottom: 12rpx;
}

.main-title-icon {
  font-size: 28rpx;
  color: var(--color-brand);
}

.main-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.main-desc {
  display: block;
  font-size: 28rpx;
  color: var(--color-text-secondary);
  line-height: 1.6;
  margin-bottom: 24rpx;
}

.main-tags {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.main-divider {
  margin-top: 32rpx;
  padding-top: 32rpx;
  border-top: 2rpx solid var(--color-divider);
}

.main-img-wrap {
  width: 100%;
  padding-bottom: 56.25%;
  position: relative;
  overflow: hidden;
  border-radius: 16rpx;
}

.main-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.main-btn-wrap {
  margin-top: 32rpx;
}

/* 区块标题 */
.section-block {
  margin-top: 64rpx;
}

.section-title-row {
  margin-bottom: 24rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.section-title-sub {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.04em;
}

/* 支线挑战 */
.sub-card {
  margin-bottom: 24rpx;
  padding: 32rpx;
}

.sub-card-done {
  opacity: 0.7;
}

.sub-row {
  display: flex;
  align-items: center;
  gap: 24rpx;
}

.sub-row-top {
  align-items: flex-start;
  margin-bottom: 28rpx;
}

.lumira-list-icon {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  background-color: var(--color-brand-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.lumira-list-icon .ph {
  font-size: 32rpx;
  color: var(--color-brand-text);
}

.list-icon-green {
  background-color: var(--color-success-subtle);
}

.list-icon-green .ph {
  color: var(--color-success);
}

.list-text {
  flex: 1;
}

.list-title {
  display: block;
  font-size: 28rpx;
  color: var(--color-text-primary);
  font-weight: 500;
}

.list-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 6rpx;
}

.sub-tags {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 28rpx;
}

.sub-btn {
  font-size: 26rpx;
  padding: 20rpx 48rpx;
  width: auto;
  align-self: flex-start;
}

/* 明日挑战预览 */
.preview-card {
  padding: 40rpx;
  position: relative;
  overflow: hidden;
}

.blur-layer {
  filter: blur(10rpx);
  user-select: none;
  pointer-events: none;
  line-height: 2;
}

.blur-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  margin-bottom: 16rpx;
  color: var(--color-text-primary);
}

.blur-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.preview-mask {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(250, 247, 242, 0.4);
  backdrop-filter: blur(4rpx);
  -webkit-backdrop-filter: blur(4rpx);
}

/* 连续打卡 */
.streak-card {
  text-align: center;
  padding: 48rpx;
}

.streak-flame {
  font-size: 72rpx;
  color: var(--color-brand);
  margin-bottom: 16rpx;
}

.streak-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 8rpx;
}

.streak-sub {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}

.streak-dots {
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
  gap: 12rpx;
  margin-top: 32rpx;
}

.streak-dot {
  width: 56rpx;
  height: 56rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.streak-dot-done {
  background-color: var(--color-brand);
}

.streak-check {
  font-size: 24rpx;
  color: #fff;
}

.streak-dot-next {
  background-color: var(--color-divider);
}

.streak-dot-num {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.streak-tip {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  margin-top: 24rpx;
}

.bottom-space {
  height: 48rpx;
}
</style>
