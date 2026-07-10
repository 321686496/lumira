<template>
  <view class="lumira-container">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">每日挑战</text>
      <view class="lumira-nav-right">
        <text class="ph ph-clipboard-text nav-icon"></text>
      </view>
    </view>

    <!-- 内容区 -->
    <view class="page-body">
      <!-- 主挑战卡（已完成） -->
      <view class="lumira-card main-card fade-up">
        <view class="main-head">
          <view class="challenge-check">
            <text class="ph ph-check"></text>
          </view>
          <view class="main-head-body">
            <view class="main-title-row">
              <text class="ph ph-check main-title-icon"></text>
              <text class="main-title">今日挑战已完成</text>
            </view>
            <text class="main-desc">用模板拍一张人像照</text>
            <view class="main-tags">
              <text class="lumira-tag lumira-tag-gold">+30 XP</text>
              <text class="lumira-tag lumira-tag-green">
                <text class="ph ph-check"></text>
                <text>已完成</text>
              </text>
            </view>
          </view>
        </view>
        <view class="main-divider"></view>
        <view class="main-img-wrap">
          <image class="main-img" src="https://picsum.photos/seed/733872/400/600" mode="aspectFill" />
        </view>
      </view>

      <!-- 附加挑战区块 -->
      <view class="section-block fade-up fade-up-d1">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">附加挑战</text>
          <text class="section-title-sub">1+2 弹性模式</text>
        </view>
      </view>

      <!-- 支线挑战 A（已完成） -->
      <view class="lumira-card sub-card sub-card-done fade-up fade-up-d2">
        <view class="sub-row">
          <view class="lumira-list-icon list-icon-green">
            <text class="ph ph-check"></text>
          </view>
          <view class="list-text">
            <text class="list-title">3个不同模板分别拍一张</text>
            <text class="list-desc">已完成 · 3/3</text>
          </view>
          <text class="lumira-tag lumira-tag-gold list-tag">+15 XP</text>
        </view>
      </view>

      <!-- 支线挑战 B（可完成） -->
      <view class="lumira-card sub-card fade-up fade-up-d3">
        <view class="sub-row sub-row-top">
          <view class="lumira-list-icon">
            <text class="ph ph-palette"></text>
          </view>
          <view class="list-text">
            <text class="list-title">拍一张照片完成调色并导出</text>
            <text class="list-desc">未完成 · 0/1</text>
          </view>
        </view>
        <view class="sub-tags">
          <text class="lumira-tag lumira-tag-gold">+20 XP</text>
          <text class="lumira-tag lumira-tag-red">碎片机会</text>
        </view>
        <view class="lumira-btn-brand sub-btn" @click="goComplete">
          <text>去完成</text>
        </view>
      </view>

      <!-- 明日挑战预览 -->
      <view class="section-block fade-up fade-up-d4">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">明日挑战预览</text>
          <text class="lumira-section-link">
            <text>全部</text>
            <text class="ph ph-arrow-right link-arrow"></text>
          </text>
        </view>
        <view class="lumira-card preview-card">
          <view class="blur-layer">
            <text class="blur-title">在日落时分拍一张剪影照</text>
            <text class="blur-desc">附加挑战：使用「黄金时刻」模板</text>
            <text class="blur-sub">附加挑战：完成一次胶片调色导出</text>
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
          <text class="streak-title">连续打卡 7 天</text>
          <text class="streak-sub">继续保持，解锁连续打卡奖励！</text>
          <view class="streak-dots">
            <view class="streak-dot streak-dot-done" v-for="n in 7" :key="n">
              <text class="ph ph-check streak-check"></text>
            </view>
            <view class="streak-dot streak-dot-next">
              <text class="streak-dot-num">8</text>
            </view>
          </view>
          <text class="streak-tip">再坚持 1 天获得额外 50 XP</text>
        </view>
      </view>

      <view class="bottom-space"></view>
    </view>

    <FloatingTabBar active="challenge" />
  </view>
</template>

<script setup lang="ts">
import FloatingTabBar from '@/components/FloatingTabBar.vue'

const goBack = () => uni.navigateBack()
const goComplete = () => uni.navigateTo({ url: '/pages/challenge/detail' })
</script>

<style lang="scss" scoped>
.nav-back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
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

.challenge-check .ph {
  font-size: 44rpx;
  color: var(--color-brand-text);
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

.link-arrow {
  font-size: 24rpx;
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

.list-tag {
  margin-left: auto;
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

.blur-sub {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 16rpx;
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
