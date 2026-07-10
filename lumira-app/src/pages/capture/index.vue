<template>
  <view class="capture-container">
    <!-- 顶部玻璃栏 -->
    <view class="glass-bar top-bar">
      <view class="status-spacer" :style="{ height: statusBarHeight + 'px' }"></view>
      <view class="top-bar-main">
        <view class="icon-btn" @click="goSceneGuide">
          <text class="ph ph-list top-icon"></text>
        </view>
        <text class="top-template-name">旅行人像</text>
        <view class="icon-btn" @click="toggleFlash">
          <text class="ph top-icon" :class="flashOn ? 'ph-lightning top-icon-gold' : 'ph-lightning-slash'"></text>
        </view>
      </view>
      <view class="top-bar-secondary">
        <view class="icon-btn">
          <text class="ph ph-sun top-icon-sm top-icon-muted"></text>
        </view>
        <view class="icon-btn">
          <text class="ph ph-star top-icon-sm top-icon-muted"></text>
        </view>
        <view class="icon-btn">
          <text class="ph ph-gear top-icon-sm top-icon-muted"></text>
        </view>
      </view>
    </view>

    <!-- 全屏取景器 -->
    <view class="capture-viewer">
      <image class="viewer-bg" src="https://picsum.photos/seed/733872/400/600" mode="aspectFill" />
      <view class="viewer-overlay"></view>

      <!-- 三分法网格 -->
      <view class="capture-grid">
        <view class="grid-line-h grid-line-h1"></view>
        <view class="grid-line-h grid-line-h2"></view>
        <view class="grid-line-v grid-line-v1"></view>
        <view class="grid-line-v grid-line-v2"></view>
      </view>

      <!-- 姿势剪影指示 -->
      <view class="pose-pill">
        <text class="ph ph-camera pose-pill-icon"></text>
        <text class="pose-pill-text">姿势剪影已开启</text>
      </view>
    </view>

    <!-- 底部玻璃控制区 -->
    <view class="glass-bar bottom-bar">
      <!-- 参数栏 -->
      <view class="param-bar">
        <view class="param-pill">
          <view class="param-label">
            <text class="ph ph-camera param-label-icon"></text>
            <text class="param-label-text">水平</text>
          </view>
          <text class="param-sep">|</text>
          <text class="param-value">EV+0.3</text>
          <text class="param-sep">|</text>
          <text class="param-value">WB 5200K</text>
        </view>
      </view>

      <!-- 快门行 -->
      <view class="shutter-row">
        <view class="last-thumb" @click="goPreview">
          <image class="last-thumb-img" src="https://picsum.photos/seed/733872/400/600" mode="aspectFill" />
        </view>
        <view class="shutter-btn" @click="onShutter">
          <view class="shutter-inner"></view>
        </view>
        <view class="flip-btn" @click="onFlip">
          <text class="ph ph-arrows-left-right flip-icon"></text>
        </view>
      </view>

      <!-- 快速模板选择 -->
      <scroll-view class="template-scroll" scroll-x>
        <view class="template-list">
          <view
            class="template-thumb"
            :class="{ active: t.active }"
            v-for="t in templates"
            :key="t.name"
            @click="selectTemplate(t)"
          >
            <image class="template-thumb-img" :src="t.img" mode="aspectFill" />
            <view class="template-thumb-label">
              <text class="template-thumb-label-text">{{ t.name }}</text>
            </view>
          </view>
        </view>
      </scroll-view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const statusBarHeight = uni.getSystemInfoSync().statusBarHeight || 20
const flashOn = ref(true)

const templates = ref([
  { name: '咖啡馆', img: 'https://picsum.photos/seed/2074130/400/400', active: true },
  { name: '日落', img: 'https://picsum.photos/seed/355465/400/400', active: false },
  { name: '街拍', img: 'https://picsum.photos/seed/1926769/400/400', active: false },
  { name: '花园', img: 'https://picsum.photos/seed/1038002/400/400', active: false },
  { name: '居家', img: 'https://picsum.photos/seed/1571460/400/400', active: false }
])

const toggleFlash = () => {
  flashOn.value = !flashOn.value
}

const selectTemplate = (t: { name: string; active: boolean }) => {
  templates.value.forEach((item) => (item.active = item.name === t.name))
}

const onShutter = () => {
  uni.navigateTo({ url: '/pages/capture/preview' })
}

const goPreview = () => {
  uni.navigateTo({ url: '/pages/capture/preview' })
}

const goSceneGuide = () => {
  uni.navigateTo({ url: '/pages/capture/scene-guide' })
}

const onFlip = () => {
  uni.showToast({ title: '翻转镜头', icon: 'none' })
}
</script>

<style lang="scss" scoped>
.capture-container {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100vh;
  background-color: #181614;
  position: relative;
  overflow: hidden;
}

/* ===== 玻璃栏通用 ===== */
.glass-bar {
  background-color: rgba(24, 22, 20, 0.75);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 2rpx solid rgba(255, 255, 255, 0.06);
}

/* ===== 顶部玻璃栏 ===== */
.top-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
}

.status-spacer {
  width: 100%;
}

.top-bar-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 104rpx;
  padding: 0 40rpx;
}

.top-template-name {
  color: #ffffff;
  font-size: 28rpx;
  font-weight: 500;
  letter-spacing: 0.04em;
}

.top-bar-secondary {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 64rpx;
  padding: 8rpx 40rpx 16rpx;
}

.icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 80rpx;
  min-height: 80rpx;
}

.top-icon {
  font-size: 44rpx;
  color: #ffffff;
}

.top-icon-gold {
  color: var(--color-brand);
}

.top-icon-sm {
  font-size: 36rpx;
}

.top-icon-muted {
  color: rgba(255, 255, 255, 0.7);
}

/* ===== 取景器 ===== */
.capture-viewer {
  flex: 1;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.viewer-bg {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.viewer-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(24, 22, 20, 0.45);
}

/* ===== 三分法网格 ===== */
.capture-grid {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 10;
}

.grid-line-h {
  position: absolute;
  width: 100%;
  height: 2rpx;
  left: 0;
  background-color: rgba(255, 255, 255, 0.2);
}

.grid-line-h1 {
  top: 33.33%;
}

.grid-line-h2 {
  top: 66.66%;
}

.grid-line-v {
  position: absolute;
  width: 2rpx;
  height: 100%;
  top: 0;
  background-color: rgba(255, 255, 255, 0.2);
}

.grid-line-v1 {
  left: 33.33%;
}

.grid-line-v2 {
  left: 66.66%;
}

/* ===== 姿势剪影指示 ===== */
.pose-pill {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 20;
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 12rpx 32rpx;
  border-radius: 9999rpx;
  background-color: rgba(24, 22, 20, 0.65);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border: 2rpx solid rgba(var(--color-brand-rgb), 0.3);
}

.pose-pill-icon {
  font-size: 28rpx;
  color: var(--color-brand);
}

.pose-pill-text {
  color: var(--color-brand);
  font-size: 24rpx;
  letter-spacing: 0.04em;
  white-space: nowrap;
}

/* ===== 底部玻璃控制区 ===== */
.bottom-bar {
  position: relative;
  z-index: 50;
  border-radius: 48rpx 48rpx 0 0;
  border-top: 2rpx solid rgba(255, 255, 255, 0.06);
  padding: 32rpx 48rpx;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
}

/* ===== 参数栏 ===== */
.param-bar {
  display: flex;
  justify-content: center;
  margin-bottom: 36rpx;
}

.param-pill {
  display: inline-flex;
  align-items: center;
  gap: 28rpx;
  padding: 16rpx 44rpx;
  border-radius: 9999rpx;
  background-color: rgba(24, 22, 20, 0.7);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 2rpx solid rgba(var(--color-brand-rgb), 0.25);
}

.param-label {
  display: flex;
  align-items: center;
  gap: 6rpx;
}

.param-label-icon {
  font-size: 24rpx;
  color: var(--color-brand);
}

.param-label-text {
  color: var(--color-brand);
  font-size: 22rpx;
  letter-spacing: 0.04em;
}

.param-sep {
  color: rgba(255, 255, 255, 0.3);
  font-size: 20rpx;
}

.param-value {
  color: #ffffff;
  font-size: 22rpx;
  font-family: 'Courier New', monospace;
}

/* ===== 快门行 ===== */
.shutter-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 56rpx;
}

.last-thumb {
  width: 100rpx;
  height: 100rpx;
  border-radius: 20rpx;
  overflow: hidden;
  border: 3rpx solid rgba(255, 255, 255, 0.15);
  flex-shrink: 0;
}

.last-thumb-img {
  width: 100%;
  height: 100%;
}

.shutter-btn {
  width: 152rpx;
  height: 152rpx;
  border-radius: 50%;
  border: 6rpx solid var(--color-brand);
  background-color: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.shutter-btn:active {
  transform: scale(0.9);
}

.shutter-inner {
  width: 116rpx;
  height: 116rpx;
  border-radius: 50%;
  background-color: #ffffff;
}

.shutter-btn:active .shutter-inner {
  background-color: var(--color-brand);
}

.flip-btn {
  width: 84rpx;
  height: 84rpx;
  border-radius: 50%;
  border: 3rpx solid rgba(255, 255, 255, 0.25);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.flip-btn:active {
  transform: scale(0.88);
}

.flip-icon {
  font-size: 40rpx;
  color: #ffffff;
}

/* ===== 快速模板选择 ===== */
.template-scroll {
  margin-top: 40rpx;
  width: 100%;
  white-space: nowrap;
}

.template-list {
  display: inline-flex;
  gap: 16rpx;
  padding-bottom: 8rpx;
}

.template-thumb {
  position: relative;
  width: 100rpx;
  height: 100rpx;
  border-radius: 20rpx;
  overflow: hidden;
  flex-shrink: 0;
  border: 3rpx solid rgba(255, 255, 255, 0.15);
}

.template-thumb.active {
  border: 4rpx solid var(--color-brand);
  box-shadow: 0 0 24rpx rgba(var(--color-brand-rgb), 0.4);
}

.template-thumb:active {
  transform: scale(0.94);
}

.template-thumb-img {
  width: 100%;
  height: 100%;
}

.template-thumb-label {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(transparent, rgba(0, 0, 0, 0.75));
  padding: 16rpx 0 6rpx;
  text-align: center;
}

.template-thumb-label-text {
  color: #ffffff;
  font-size: 16rpx;
  letter-spacing: 0.03em;
}
</style>
