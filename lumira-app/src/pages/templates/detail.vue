<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">模板详情</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- Overlay Preview Image -->
    <view class="preview-wrap fade-up">
      <view class="preview-img-wrap">
        <image class="preview-img" src="https://picsum.photos/seed/1563356/800/600" mode="aspectFill" />
        <view class="grid-overlay">
          <view class="grid-line-h grid-line-h-1"></view>
          <view class="grid-line-h grid-line-h-2"></view>
          <view class="grid-line-v grid-line-v-1"></view>
          <view class="grid-line-v grid-line-v-2"></view>
        </view>
      </view>
    </view>

    <!-- Template Name & Tags -->
    <view class="title-wrap fade-up fade-up-d1">
      <text class="tpl-title">日落逆光剪影</text>
      <view class="tag-row">
        <text class="lumira-tag lumira-tag-gold">构图</text>
        <text class="lumira-tag lumira-tag-gold">姿势</text>
        <text class="lumira-tag lumira-tag-gold">参数</text>
        <text class="lumira-tag lumira-tag-gold">后期</text>
      </view>
    </view>

    <!-- Scene Guide -->
    <view class="block-pad fade-up fade-up-d2">
      <view class="lumira-card lumira-card-svg-bg">
        <text class="card-title">场景指南</text>
        <view class="guide-list">
          <view class="guide-item">
            <text class="ph ph-lightbulb guide-icon"></text>
            <view class="guide-text">
              <text class="guide-label">光线</text>
              <text class="guide-value">逆光，太阳位于模特身后 45°</text>
            </view>
          </view>
          <view class="guide-item">
            <text class="ph ph-ruler guide-icon"></text>
            <view class="guide-text">
              <text class="guide-label">距离</text>
              <text class="guide-value">3-5 米，中长焦压缩背景</text>
            </view>
          </view>
          <view class="guide-item">
            <text class="ph ph-magic-wand guide-icon"></text>
            <view class="guide-text">
              <text class="guide-label">道具</text>
              <text class="guide-value">宽檐帽、纱巾、透明伞</text>
            </view>
          </view>
          <view class="guide-item">
            <text class="ph ph-notepad guide-icon"></text>
            <view class="guide-text">
              <text class="guide-label">Tips</text>
              <text class="guide-value">让模特侧身站立，轮廓边缘会更清晰</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- Camera Parameters -->
    <view class="block-pad-top fade-up fade-up-d3">
      <view class="lumira-card lumira-card-svg-bg">
        <text class="card-title">相机参数建议</text>
        <view class="param-mono">
          <text class="param-line">EV -0.7    ISO 100    1/200s</text>
          <text class="param-line">WB: 日光    镜头: 主摄 2×</text>
        </view>
      </view>
    </view>

    <!-- Example Works -->
    <view class="block-pad-top fade-up fade-up-d4">
      <view class="lumira-section-title">
        <text class="section-title-text">示例作品</text>
      </view>
      <view class="gallery-grid">
        <view class="gallery-img-wrap">
          <image class="gallery-img" src="https://picsum.photos/seed/206434/400/400" mode="aspectFill" />
        </view>
        <view class="gallery-img-wrap">
          <image class="gallery-img" src="https://picsum.photos/seed/1689731/400/400" mode="aspectFill" />
        </view>
      </view>
    </view>

    <!-- Unlock Status -->
    <view class="block-pad-top fade-up fade-up-d5">
      <view class="unlock-status">
        <text class="ph ph-check-circle unlock-icon"></text>
        <text class="unlock-text">已解锁</text>
      </view>
    </view>

    <!-- Spacer for fixed CTA -->
    <view class="cta-spacer"></view>

    <!-- Fixed Bottom CTA -->
    <view class="fixed-cta">
      <view class="lumira-btn-primary" @click="goCapture">套用此模板拍摄</view>
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
  color: var(--color-text-primary);
}

.preview-wrap {
  padding: 0 48rpx 40rpx;
}

.preview-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 75%;
  border-radius: 28rpx;
  overflow: hidden;
}

.preview-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.grid-overlay {
  position: absolute;
  top: 24rpx;
  left: 24rpx;
  right: 24rpx;
  bottom: 24rpx;
  pointer-events: none;
}

.grid-line-h {
  position: absolute;
  left: 0;
  right: 0;
  height: 2rpx;
  background: rgba(201, 169, 110, 0.5);
}

.grid-line-h-1 {
  top: 33.3%;
}

.grid-line-h-2 {
  top: 66.6%;
}

.grid-line-v {
  position: absolute;
  top: 0;
  bottom: 0;
  width: 2rpx;
  background: rgba(201, 169, 110, 0.5);
}

.grid-line-v-1 {
  left: 33.3%;
}

.grid-line-v-2 {
  left: 66.6%;
}

.title-wrap {
  padding: 0 48rpx;
}

.tpl-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 20rpx;
}

.tag-row {
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}

.block-pad {
  padding: 48rpx 48rpx 0;
}

.block-pad-top {
  padding: 32rpx 48rpx 0;
}

.card-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 28rpx;
}

.guide-list {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.guide-item {
  display: flex;
  gap: 16rpx;
  align-items: flex-start;
}

.guide-icon {
  flex-shrink: 0;
  font-size: 32rpx;
  color: var(--color-brand);
  margin-top: 4rpx;
}

.guide-text {
  flex: 1;
}

.guide-label {
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.guide-value {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  margin-left: 8rpx;
}

.param-mono {
  line-height: 2;
}

.param-line {
  display: block;
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
  color: var(--color-text-secondary);
  letter-spacing: 0.02em;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.gallery-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.gallery-img-wrap {
  width: 100%;
  padding-bottom: 100%;
  position: relative;
  overflow: hidden;
  border-radius: 28rpx;
}

.gallery-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.unlock-status {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.unlock-icon {
  font-size: 32rpx;
  color: var(--color-success);
}

.unlock-text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.cta-spacer {
  height: 200rpx;
}

.fixed-cta {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 32rpx 48rpx 48rpx;
  background: linear-gradient(to top, var(--color-canvas) 60%, transparent);
  z-index: 100;
}
</style>
