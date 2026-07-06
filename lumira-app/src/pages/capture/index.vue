<script setup lang="ts">
import { computed } from 'vue'
import { onShow, onHide } from '@dcloudio/uni-app'
import { useCaptureStore } from '@/stores/capture'

const captureStore = useCaptureStore()

const currentTemplateName = computed(() => {
  return captureStore.activeTemplateId ? `模板 #${captureStore.activeTemplateId}` : '自由拍摄'
})

const evDisplay = computed(() => captureStore.cameraParameters?.evBias ?? 0)
const isoDisplay = computed(() => captureStore.cameraParameters?.iso ?? 100)
const wbDisplay = computed(() => {
  const wb = captureStore.cameraParameters?.whiteBalance ?? 'auto'
  if (wb === 'auto') return 'AUTO'
  if (wb === 'daylight') return '日光'
  if (wb === 'cloudy') return '阴天'
  return String(wb)
})

const isLevel = computed(() => captureStore.alignmentStatus?.isLevel ?? true)

onShow(() => {
  captureStore.setActive(true)
})

onHide(() => {
  captureStore.setActive(false)
})

const onBack = () => {
  uni.navigateBack()
}

const openParameters = () => {
  uni.navigateTo({ url: '/pages/capture/parameters' })
}

const goTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const goGallery = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const onShutter = () => {
  uni.navigateTo({ url: '/pages/capture/preview?photoId=tmp' })
}
</script>

<template>
  <view class="capture-page">
    <!-- 顶部控制栏 -->
    <view class="top-bar">
      <view class="top-btn back-btn" @click="onBack">
        <text class="top-btn-icon">‹</text>
      </view>
      <view class="top-center" @click="goTemplates">
        <text class="template-label">当前模板</text>
        <text class="template-value">{{ currentTemplateName }}</text>
      </view>
      <view class="top-btn" @click="openParameters">
        <text class="top-btn-icon">⚙</text>
      </view>
    </view>

    <!-- 取景区 -->
    <view class="viewfinder">
      <view class="viewfinder-frame">
        <!-- 构图引导线 -->
        <view class="grid-lines">
          <view class="grid-line grid-line-h" style="top: 33.33%"></view>
          <view class="grid-line grid-line-h" style="top: 66.66%"></view>
          <view class="grid-line grid-line-v" style="left: 33.33%"></view>
          <view class="grid-line grid-line-v" style="left: 66.66%"></view>
        </view>
        <!-- 主体框 -->
        <view class="subject-frame"></view>
        <!-- 水平指示 -->
        <view class="level-indicator" :class="{ level: isLevel }">
          <view class="level-bar"></view>
        </view>
        <!-- 中心提示 -->
        <view class="viewfinder-hint">
          <text class="hint-icon">◐</text>
          <text class="hint-text">取景框</text>
          <text class="hint-sub">将主体对准框内</text>
        </view>
      </view>
    </view>

    <!-- 底部控制区 -->
    <view class="bottom-controls">
      <!-- 参数条 -->
      <view class="param-pill" @click="openParameters">
        <text class="param-item">EV {{ evDisplay > 0 ? '+' : '' }}{{ evDisplay }}</text>
        <text class="param-sep">·</text>
        <text class="param-item">ISO {{ isoDisplay }}</text>
        <text class="param-sep">·</text>
        <text class="param-item">WB {{ wbDisplay }}</text>
      </view>

      <!-- 快门行 -->
      <view class="shutter-row">
        <view class="shutter-side" @click="goGallery">
          <view class="side-icon-wrap">
            <text class="side-icon">▦</text>
          </view>
          <text class="side-label">相册</text>
        </view>

        <view class="shutter-btn" @click="onShutter">
          <view class="shutter-outer">
            <view class="shutter-inner"></view>
          </view>
        </view>

        <view class="shutter-side" @click="goTemplates">
          <view class="side-icon-wrap">
            <text class="side-icon">▦</text>
          </view>
          <text class="side-label">模板</text>
        </view>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.capture-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: #1A1A1A;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* 顶部控制栏 */
.top-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-4) var(--space-3);
  display: flex;
  align-items: center;
  justify-content: space-between;
  z-index: 10;
}

.top-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);

  &:active {
    background: rgba(255, 255, 255, 0.2);
  }
}

.top-btn-icon {
  font-size: 22px;
  color: #FFFFFF;
  line-height: 1;
}

.top-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: var(--space-1) var(--space-4);
  border-radius: var(--radius-pill);
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
}

.template-label {
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.6);
  line-height: 1.2;
}

.template-value {
  font-size: var(--font-size-caption);
  color: #FFFFFF;
  font-weight: 500;
  line-height: 1.2;
}

/* 取景区 */
.viewfinder {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 100px var(--space-4) 180px;
}

.viewfinder-frame {
  position: relative;
  width: 100%;
  max-width: 320px;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: linear-gradient(135deg, #2A2A2A 0%, #1A1A1A 100%);
  overflow: hidden;
  border: 1px solid rgba(201, 169, 110, 0.2);
}

/* 构图网格线 */
.grid-lines {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.grid-line {
  position: absolute;
  background: rgba(255, 255, 255, 0.1);
}

.grid-line-h {
  left: 0;
  right: 0;
  height: 1px;
}

.grid-line-v {
  top: 0;
  bottom: 0;
  width: 1px;
}

/* 主体框 */
.subject-frame {
  position: absolute;
  top: 20%;
  left: 25%;
  right: 25%;
  bottom: 20%;
  border: 1px dashed rgba(201, 169, 110, 0.4);
  border-radius: 8px;
}

/* 水平指示器 */
.level-indicator {
  position: absolute;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  width: 60px;
  height: 3px;
  border-radius: 2px;
  background: rgba(255, 255, 255, 0.2);
  transition: background 0.3s ease;

  &.level {
    background: var(--color-brand-primary);
  }
}

.level-bar {
  position: absolute;
  top: -1px;
  left: 50%;
  transform: translateX(-50%);
  width: 2px;
  height: 5px;
  border-radius: 1px;
  background: #FFFFFF;
}

/* 中心提示 */
.viewfinder-hint {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
}

.hint-icon {
  font-size: 36px;
  color: rgba(201, 169, 110, 0.3);
  line-height: 1;
}

.hint-text {
  font-size: var(--font-size-body);
  color: rgba(255, 255, 255, 0.4);
}

.hint-sub {
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.25);
}

/* 底部控制区 */
.bottom-controls {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 0 var(--space-4) calc(var(--space-6) + env(safe-area-inset-bottom));
  z-index: 10;
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

/* 参数条 */
.param-pill {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
  align-self: center;
}

.param-item {
  font-size: var(--font-size-caption);
  color: #FFFFFF;
  font-weight: 500;
}

.param-sep {
  font-size: var(--font-size-caption);
  color: rgba(255, 255, 255, 0.3);
}

/* 快门行 */
.shutter-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--space-4);
}

.shutter-side {
  width: 64px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);

  &:active {
    opacity: 0.6;
  }
}

.side-icon-wrap {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.1);
}

.side-icon {
  font-size: 18px;
  color: rgba(255, 255, 255, 0.7);
}

.side-label {
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.5);
}

/* 快门按钮 */
.shutter-btn {
  &:active {
    .shutter-outer {
      transform: scale(0.92);
    }
  }
}

.shutter-outer {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 4px solid #FFFFFF;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.15s ease;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.1);
}

.shutter-inner {
  width: 58px;
  height: 58px;
  border-radius: 50%;
  background: linear-gradient(135deg, #D4B57A 0%, #C9A96E 50%, #A88550 100%);
}
</style>
