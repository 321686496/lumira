<script setup lang="ts">
import { ref } from 'vue'
import { useCaptureStore } from '@/stores/capture'

const captureStore = useCaptureStore()

const evBias = ref(captureStore.cameraParameters.evBias)
const iso = ref(captureStore.cameraParameters.iso)
const whiteBalance = ref(captureStore.cameraParameters.whiteBalance)

const applyParams = () => {
  captureStore.updateCameraParameters({
    evBias: evBias.value,
    iso: iso.value,
    whiteBalance: whiteBalance.value,
  })
  uni.navigateBack()
}

const closePanel = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="parameters-page">
    <view class="panel-header">
      <text class="panel-title">相机参数</text>
      <view class="close-btn" @click="closePanel">
        <text class="close-icon">✕</text>
      </view>
    </view>

    <view class="params-list">
      <view class="param-row">
        <text class="param-label">曝光补偿</text>
        <view class="param-control">
          <text class="param-minus" @click="evBias = Math.max(-3, evBias - 0.3)">−</text>
          <text class="param-value">EV {{ evBias > 0 ? '+' : '' }}{{ evBias.toFixed(1) }}</text>
          <text class="param-plus" @click="evBias = Math.min(3, evBias + 0.3)">+</text>
        </view>
      </view>

      <view class="param-row">
        <text class="param-label">ISO</text>
        <view class="param-control">
          <text class="param-minus" @click="iso = Math.max(100, iso - 100)">−</text>
          <text class="param-value">{{ iso }}</text>
          <text class="param-plus" @click="iso = Math.min(3200, iso + 100)">+</text>
        </view>
      </view>

      <view class="param-row">
        <text class="param-label">白平衡</text>
        <view class="param-control">
          <text class="wb-option" :class="{ active: whiteBalance === 'auto' }" @click="whiteBalance = 'auto'">AUTO</text>
          <text class="wb-option" :class="{ active: whiteBalance === 'daylight' }" @click="whiteBalance = 'daylight'">日光</text>
          <text class="wb-option" :class="{ active: whiteBalance === 'cloudy' }" @click="whiteBalance = 'cloudy'">阴天</text>
        </view>
      </view>
    </view>

    <view class="apply-area">
      <view class="apply-btn" @click="applyParams">
        <text class="apply-text">应用</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.parameters-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  padding-top: env(safe-area-inset-top);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--color-border);
}

.panel-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.close-btn {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  &:active { opacity: 0.6; }
}

.close-icon {
  font-size: 18px;
  color: var(--color-text-secondary);
}

.params-list {
  padding: var(--space-5);
}

.param-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) 0;
  border-bottom: 1px solid var(--color-border);
}

.param-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.param-control {
  display: flex;
  align-items: center;
  gap: var(--space-4);
}

.param-minus,
.param-plus {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--color-bg-surface);
  font-size: 18px;
  color: var(--color-text-primary);
  &:active { opacity: 0.6; }
}

.param-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  min-width: 60px;
  text-align: center;
}

.wb-option {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  padding: var(--space-2) var(--space-3);
  border-radius: var(--radius-pill);
  background: var(--color-bg-surface);
  color: var(--color-text-secondary);
  &.active {
    background: var(--color-tag-gold-bg);
    color: var(--color-tag-gold-text);
  }
}

.apply-area {
  padding: var(--space-5);
}

.apply-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4);
  background: var(--color-text-primary);
  border-radius: var(--radius-button);
  &:active { transform: scale(0.98); }
}

.apply-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}
</style>
