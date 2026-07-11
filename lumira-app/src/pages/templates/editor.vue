<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">模板编辑器</text>
      <view class="lumira-nav-right">
        <text class="save-btn">保存</text>
      </view>
    </view>

    <!-- Upload Pose Reference -->
    <view class="block-pad fade-up">
      <view class="upload-card">
        <text class="ph ph-paper-plane-tilt upload-icon"></text>
        <text class="upload-title">上传姿势参考图</text>
        <text class="upload-desc">支持 JPG / PNG 格式</text>
      </view>
    </view>

    <!-- Composition Overlay Drawing -->
    <view class="block-pad-top fade-up fade-up-d1">
      <view class="lumira-section-title">
        <text class="section-title-text">构图叠图</text>
        <text class="lumira-section-link">编辑 ›</text>
      </view>
      <view class="canvas-wrap">
        <view class="canvas-grid">
          <view class="grid-line-h grid-line-h-1"></view>
          <view class="grid-line-h grid-line-h-2"></view>
          <view class="grid-line-v grid-line-v-1"></view>
          <view class="grid-line-v grid-line-v-2"></view>
        </view>
        <text class="canvas-placeholder">叠图画布区域</text>
      </view>
    </view>

    <!-- Camera Parameters Form -->
    <view class="block-pad-top fade-up fade-up-d2">
      <view class="lumira-card">
        <text class="card-title">相机参数</text>

        <!-- EV Slider -->
        <view class="slider-row">
          <text class="slider-label">EV</text>
          <slider class="slider" min="-3" max="3" step="0.1" :value="ev" activeColor="#C9A96E" block-size="20" @changing="onEvChanging" />
          <text class="slider-value">{{ evText }}</text>
        </view>

        <!-- ISO Selector -->
        <view class="slider-row">
          <text class="slider-label">ISO</text>
          <view class="pill-group">
            <view class="pill" :class="{ active: iso === '100' }" @click="iso = '100'">100</view>
            <view class="pill" :class="{ active: iso === '200' }" @click="iso = '200'">200</view>
            <view class="pill" :class="{ active: iso === '400' }" @click="iso = '400'">400</view>
            <view class="pill" :class="{ active: iso === '800' }" @click="iso = '800'">800</view>
          </view>
        </view>

        <!-- Shutter Speed -->
        <view class="slider-row">
          <text class="slider-label">快门</text>
          <view class="pill-group">
            <view class="pill" :class="{ active: shutter === '1/125' }" @click="shutter = '1/125'">1/125</view>
            <view class="pill" :class="{ active: shutter === '1/200' }" @click="shutter = '1/200'">1/200</view>
            <view class="pill" :class="{ active: shutter === '1/500' }" @click="shutter = '1/500'">1/500</view>
          </view>
        </view>

        <!-- White Balance -->
        <view class="slider-row">
          <text class="slider-label">白平衡</text>
          <view class="pill-group">
            <view class="pill" :class="{ active: wb === '日光' }" @click="wb = '日光'">日光</view>
            <view class="pill" :class="{ active: wb === '阴天' }" @click="wb = '阴天'">阴天</view>
            <view class="pill" :class="{ active: wb === '钨丝灯' }" @click="wb = '钨丝灯'">钨丝灯</view>
          </view>
        </view>
      </view>
    </view>

    <!-- Post-Process Section -->
    <view class="block-pad-top fade-up fade-up-d3">
      <view class="lumira-card">
        <text class="card-title">后期调色</text>

        <!-- Brightness -->
        <view class="slider-row">
          <text class="slider-label">亮度</text>
          <slider class="slider" min="-100" max="100" step="1" :value="brightness" activeColor="#C9A96E" block-size="20" @changing="onBrightnessChanging" />
          <text class="slider-value">{{ formatVal(brightness) }}</text>
        </view>

        <!-- Contrast -->
        <view class="slider-row">
          <text class="slider-label">对比度</text>
          <slider class="slider" min="-100" max="100" step="1" :value="contrast" activeColor="#C9A96E" block-size="20" @changing="onContrastChanging" />
          <text class="slider-value">{{ formatVal(contrast) }}</text>
        </view>

        <!-- Saturation -->
        <view class="slider-row">
          <text class="slider-label">饱和度</text>
          <slider class="slider" min="-100" max="100" step="1" :value="saturation" activeColor="#C9A96E" block-size="20" @changing="onSaturationChanging" />
          <text class="slider-value">{{ formatVal(saturation) }}</text>
        </view>
      </view>
    </view>

    <!-- Spacer for preview button -->
    <view class="cta-spacer"></view>

    <!-- Fixed Bottom Preview Button -->
    <view class="fixed-cta">
      <view class="lumira-btn-brand">预览效果</view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const ev = ref(-0.7)
const iso = ref('400')
const shutter = ref('1/200')
const wb = ref('日光')
const brightness = ref(0)
const contrast = ref(0)
const saturation = ref(0)

const evText = computed(() => {
  const v = ev.value
  if (v === 0) return '0'
  return (v > 0 ? '+' : '') + Number(v.toFixed(1))
})

const formatVal = (v: number) => v > 0 ? '+' + v : String(v)

const onEvChanging = (e: any) => { ev.value = Math.round(e.detail.value * 10) / 10 }
const onBrightnessChanging = (e: any) => { brightness.value = e.detail.value }
const onContrastChanging = (e: any) => { contrast.value = e.detail.value }
const onSaturationChanging = (e: any) => { saturation.value = e.detail.value }

const back = () => uni.navigateBack()
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.save-btn {
  font-size: 28rpx;
  font-weight: 500;
  color: $color-brand-primary;
}

.block-pad {
  padding: 32rpx 48rpx 0;
}

.block-pad-top {
  padding: 32rpx 48rpx 0;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

/* Upload card */
.upload-card {
  border-radius: $radius-card;
  border: 4rpx dashed $color-border;
  text-align: center;
  padding: 64rpx 40rpx;
  background: var(--color-canvas);
  box-shadow: $shadow-card;
}

.upload-icon {
  font-size: 64rpx;
  color: $color-brand-primary;
  margin-bottom: 16rpx;
}

.upload-title {
  display: block;
  font-size: 28rpx;
  font-weight: 500;
  color: $color-text-primary;
  margin-bottom: 8rpx;
}

.upload-desc {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
}

/* Canvas */
.canvas-wrap {
  border-radius: $radius-card;
  overflow: hidden;
  background-color: $color-bg-surface;
  height: 0;
  padding-bottom: 133.33%;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.canvas-grid {
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
  background: rgba(201, 169, 110, 0.4);
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
  background: rgba(201, 169, 110, 0.4);
}

.grid-line-v-1 {
  left: 33.3%;
}

.grid-line-v-2 {
  left: 66.6%;
}

.canvas-placeholder {
  font-size: 26rpx;
  color: $color-text-tertiary;
  position: relative;
  z-index: 1;
}

/* Card */
.card-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  color: $color-text-primary;
  margin-bottom: 32rpx;
}

/* Slider rows */
.slider-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 28rpx;
}

.slider-row:last-child {
  margin-bottom: 0;
}

.slider-label {
  width: 96rpx;
  flex-shrink: 0;
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.slider {
  flex: 1;
  margin: 0;
}

.slider-value {
  width: 72rpx;
  flex-shrink: 0;
  text-align: right;
  font-size: 26rpx;
  font-family: 'Courier New', monospace;
  color: $color-text-secondary;
}

/* Pills */
.pill-group {
  flex: 1;
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}

.pill {
  padding: 10rpx 24rpx;
  font-size: 24rpx;
  border-radius: 9999rpx;
  background-color: $color-bg-surface;
  color: $color-text-secondary;
  border: 2rpx solid transparent;
  line-height: 1;
}

.pill.active {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  color: #FFFFFF;
  border-color: transparent;
}

/* CTA */
.cta-spacer {
  height: 200rpx;
}

.fixed-cta {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 32rpx 48rpx 48rpx;
  background: linear-gradient(to top, $color-bg-canvas 60%, transparent);
  z-index: 100;
}
</style>
