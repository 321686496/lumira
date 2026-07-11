<template>
  <view class="lumira-container no-tabbar">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">挑战详情</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="detail-body fade-up">
      <!-- 挑战主卡 -->
      <view class="hero-card">
        <view class="hero-badge-wrap">
          <text class="lumira-tag lumira-tag-gold">
            <text class="ph ph-target"></text>
            <text>今日主挑战</text>
          </text>
          <text class="hero-status done">已完成</text>
        </view>
        <text class="hero-title">用三分法构图拍一张人像</text>
        <text class="hero-desc">利用三分法构图，将人物置于画面三分之一处，营造自然平衡的视觉感受。适合户外、街拍等场景。</text>

        <view class="hero-reward">
          <text class="ph ph-medal hero-reward-icon"></text>
          <text class="hero-reward-text">奖励 +30 XP</text>
        </view>

        <view class="hero-progress-wrap">
          <view class="hero-progress-bar">
            <view class="hero-progress-fill" style="width: 100%"></view>
          </view>
          <text class="hero-progress-text">1/1 已完成</text>
        </view>
      </view>

      <!-- 完成的作品 -->
      <view class="section">
        <view class="lumira-section-title">
          <text class="section-title-text">完成的作品</text>
        </view>
        <view class="work-card">
          <view class="work-img-wrap">
            <image class="work-img" src="https://picsum.photos/seed/challenge-work-1/600/800" mode="aspectFill" />
          </view>
          <view class="work-info">
            <view class="work-meta">
              <text class="ph ph-calendar-blank work-meta-icon"></text>
              <text class="work-meta-text">2026年7月10日</text>
            </view>
            <text class="work-title">午后窗边人像</text>
            <view class="work-tags">
              <text class="lumira-tag lumira-tag-gold">三分法</text>
              <text class="lumira-tag lumira-tag-green">人像</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 挑战要求 -->
      <view class="section">
        <view class="lumira-section-title">
          <text class="section-title-text">挑战要求</text>
        </view>
        <view class="lumira-card">
          <view class="req-item">
            <view class="req-num"><text class="req-num-text">1</text></view>
            <view class="req-body">
              <text class="req-title">使用三分法构图</text>
              <text class="req-desc">将画面横竖各分三份，把主体放在交叉点或线上</text>
            </view>
            <text class="ph ph-check req-done-icon"></text>
          </view>
          <view class="req-item">
            <view class="req-num"><text class="req-num-text">2</text></view>
            <view class="req-body">
              <text class="req-title">拍摄人像照片</text>
              <text class="req-desc">可以是自拍或他拍，人物为主体</text>
            </view>
            <text class="ph ph-check req-done-icon"></text>
          </view>
          <view class="req-item">
            <view class="req-num"><text class="req-num-text">3</text></view>
            <view class="req-body">
              <text class="req-title">自然光线</text>
              <text class="req-desc">使用自然光拍摄，不使用闪光灯</text>
            </view>
            <text class="ph ph-check req-done-icon"></text>
          </view>
        </view>
      </view>

      <!-- 拍摄建议 -->
      <view class="section">
        <view class="lumira-section-title">
          <text class="section-title-text">拍摄建议</text>
        </view>
        <view class="lumira-card">
          <view class="tip-row">
            <view class="tip-icon-wrap tip-icon-gold">
              <text class="ph ph-sun tip-row-icon"></text>
            </view>
            <view class="tip-row-body">
              <text class="tip-row-title">光线选择</text>
              <text class="tip-row-desc">侧光或逆光拍摄，轮廓更立体</text>
            </view>
          </view>
          <view class="tip-row">
            <view class="tip-icon-wrap tip-icon-green">
              <text class="ph ph-frame-corners tip-row-icon"></text>
            </view>
            <view class="tip-row-body">
              <text class="tip-row-title">构图技巧</text>
              <text class="tip-row-desc">开启相机网格线辅助构图</text>
            </view>
          </view>
          <view class="tip-row">
            <view class="tip-icon-wrap tip-icon-red">
              <text class="ph ph-camera tip-row-icon"></text>
            </view>
            <view class="tip-row-body">
              <text class="tip-row-title">推荐模板</text>
              <text class="tip-row-desc">使用「自然光人像」模板效果更佳</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 底部操作 -->
      <view class="bottom-actions">
        <view class="lumira-btn-outline action-btn" @click="back">
          <text>返回挑战</text>
        </view>
        <view class="lumira-btn-brand action-btn" @click="goCapture">
          <text class="ph ph-camera"></text>
          <text>再拍一张</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
const back = () => uni.navigateBack()
const goCapture = () => uni.navigateTo({ url: '/pages/capture/index' })
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.detail-body {
  padding: 0 40rpx 40rpx;
}

.section {
  margin-top: 48rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

/* 主卡 */
.hero-card {
  border-radius: $radius-card;
  padding: 48rpx 40rpx;
  background: linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%);
  position: relative;
  overflow: hidden;
}

.hero-badge-wrap {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24rpx;
}

.hero-status {
  font-size: 24rpx;
  font-weight: 600;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
}

.hero-status.done {
  background-color: $color-tag-green-bg;
  color: $color-tag-green-text;
}

.hero-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: $color-text-primary;
  line-height: 1.3;
  margin-bottom: 16rpx;
  letter-spacing: -0.01em;
}

.hero-desc {
  display: block;
  font-size: 26rpx;
  color: $color-text-secondary;
  line-height: 1.7;
  margin-bottom: 32rpx;
}

.hero-reward {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 32rpx;
}

.hero-reward-icon {
  font-size: 32rpx;
  color: $color-brand-primary;
}

.hero-reward-text {
  font-size: 28rpx;
  font-weight: 600;
  color: $color-brand-secondary;
  font-family: 'Noto Serif SC', serif;
}

.hero-progress-wrap {
  display: flex;
  align-items: center;
  gap: 20rpx;
}

.hero-progress-bar {
  flex: 1;
  height: 16rpx;
  border-radius: 8rpx;
  background-color: rgba(201, 169, 110, 0.2);
  overflow: hidden;
}

.hero-progress-fill {
  height: 100%;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  border-radius: 8rpx;
}

.hero-progress-text {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

/* 完成的作品 */
.work-card {
  border-radius: $radius-card;
  overflow: hidden;
  background-color: var(--color-canvas);
  border: 2rpx solid $color-border;
  box-shadow: $shadow-card;
}

.work-img-wrap {
  width: 100%;
  padding-bottom: 133.33%;
  position: relative;
  overflow: hidden;
}

.work-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.work-info {
  padding: 32rpx;
}

.work-meta {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 16rpx;
}

.work-meta-icon {
  font-size: 26rpx;
  color: $color-text-tertiary;
}

.work-meta-text {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

.work-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
  margin-bottom: 20rpx;
}

.work-tags {
  display: flex;
  gap: 12rpx;
}

/* 挑战要求 */
.req-item {
  display: flex;
  align-items: flex-start;
  gap: 24rpx;
  padding: 24rpx 0;
  border-bottom: 2rpx solid $color-border;
}

.req-item:last-child {
  border-bottom: none;
  padding-bottom: 0;
}

.req-item:first-child {
  padding-top: 0;
}

.req-num {
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background-color: $color-brand-light;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.req-num-text {
  font-size: 24rpx;
  font-weight: 600;
  color: $color-brand-secondary;
  font-family: 'Noto Serif SC', serif;
}

.req-body {
  flex: 1;
}

.req-title {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  color: $color-text-primary;
  margin-bottom: 8rpx;
}

.req-desc {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
  line-height: 1.6;
}

.req-done-icon {
  font-size: 32rpx;
  color: $color-brand-primary;
  flex-shrink: 0;
}

/* 拍摄建议 */
.tip-row {
  display: flex;
  align-items: flex-start;
  gap: 24rpx;
  padding: 20rpx 0;
}

.tip-row:first-child {
  padding-top: 0;
}

.tip-row:last-child {
  padding-bottom: 0;
}

.tip-icon-wrap {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.tip-icon-gold {
  background-color: rgba(201, 169, 110, 0.12);
}

.tip-icon-green {
  background-color: rgba(90, 122, 72, 0.1);
}

.tip-icon-red {
  background-color: rgba(196, 74, 74, 0.1);
}

.tip-row-icon {
  font-size: 32rpx;
}

.tip-icon-gold .tip-row-icon {
  color: $color-brand-primary;
}

.tip-icon-green .tip-row-icon {
  color: #5A7A48;
}

.tip-icon-red .tip-row-icon {
  color: #C44A4A;
}

.tip-row-body {
  flex: 1;
}

.tip-row-title {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  color: $color-text-primary;
  margin-bottom: 6rpx;
}

.tip-row-desc {
  display: block;
  font-size: 24rpx;
  color: $color-text-secondary;
  line-height: 1.5;
}

/* 底部操作 */
.bottom-actions {
  display: flex;
  gap: 24rpx;
  margin-top: 56rpx;
}

.action-btn {
  flex: 1;
}
</style>
