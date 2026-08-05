<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">设置</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 通用 -->
      <text class="group-title">通用</text>
      <view class="setting-group neu-card">
        <view class="setting-item" @click="goTheme">
          <view class="setting-icon-wrap">
            <text class="ph ph-palette"></text>
          </view>
          <text class="setting-label">主题选择</text>
          <view class="setting-right">
            <text class="setting-value setting-value-brand">{{ currentThemeName }}</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item" @click="goTheme">
          <view class="setting-icon-wrap">
            <text class="ph ph-shapes"></text>
          </view>
          <text class="setting-label">风格选择</text>
          <view class="setting-right">
            <text class="setting-value setting-value-brand">{{ currentStyleName }}</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-translate"></text>
          </view>
          <text class="setting-label">语言</text>
          <view class="setting-right">
            <text class="setting-value">简体中文</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
      </view>

      <!-- 显示 -->
      <text class="group-title">显示</text>
      <view class="setting-group neu-card">
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-grid-four"></text>
          </view>
          <text class="setting-label">网格显示</text>
          <view class="neu-toggle" :class="{ active: gridOn }" @click="gridOn = !gridOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-ruler"></text>
          </view>
          <text class="setting-label">水平仪</text>
          <view class="neu-toggle" :class="{ active: levelOn }" @click="levelOn = !levelOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 拍摄 -->
      <text class="group-title">拍摄</text>
      <view class="setting-group neu-card">
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-frame-corners"></text>
          </view>
          <text class="setting-label">默认分辨率</text>
          <view class="setting-right">
            <text class="setting-value">4K</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-droplet"></text>
          </view>
          <text class="setting-label">水印</text>
          <view class="neu-toggle" :class="{ active: watermarkOn }" @click="watermarkOn = !watermarkOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
        <view class="setting-item setting-item-last">
          <view class="setting-icon-wrap">
            <text class="ph ph-speaker-high"></text>
          </view>
          <text class="setting-label">快门声音</text>
          <view class="neu-toggle" :class="{ active: shutterOn }" @click="shutterOn = !shutterOn">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 关于 -->
      <text class="group-title">关于</text>
      <view class="setting-group neu-card">
        <view class="setting-item" @click="handleVersionTap">
          <view class="setting-icon-wrap">
            <text class="ph ph-app-window"></text>
          </view>
          <text class="setting-label">版本号</text>
          <view class="setting-right">
            <text class="setting-value setting-value-mono">v2.0.0</text>
          </view>
        </view>
        <view class="setting-item" @click="goRedeem">
          <view class="setting-icon-wrap">
            <text class="ph ph-key"></text>
          </view>
          <text class="setting-label">兑换码</text>
          <view class="setting-right">
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item">
          <view class="setting-icon-wrap">
            <text class="ph ph-trash"></text>
          </view>
          <text class="setting-label">清除缓存</text>
          <view class="setting-right">
            <text class="setting-value">128 MB</text>
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
        <view class="setting-item setting-item-last">
          <view class="setting-icon-wrap">
            <text class="ph ph-info"></text>
          </view>
          <text class="setting-label">关于如画</text>
          <view class="setting-right">
            <text class="ph ph-caret-right setting-arrow"></text>
          </view>
        </view>
      </view>

      <!-- 底部版本信息 -->
      <view class="version-footer">
        <text class="version-text">如画 Lumira v2.0.0</text>
        <text class="version-sub">东方新拟态 · 用镜头书写日常的诗</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS, STYLE_METAS } from '@/theme/theme-configs'

const { currentTheme, currentStyle } = useTheme()
const currentThemeName = computed(() => THEME_METAS[currentTheme.value].label)
const currentStyleName = computed(() => STYLE_METAS[currentStyle.value].label)

const gridOn = ref(false)
const levelOn = ref(true)
const shutterOn = ref(true)
const watermarkOn = ref(true)

const tapCount = ref(0)
let tapTimer: ReturnType<typeof setTimeout> | null = null

const handleVersionTap = () => {
  tapCount.value++
  if (tapTimer) clearTimeout(tapTimer)
  tapTimer = setTimeout(() => { tapCount.value = 0 }, 3000)
  // 彩蛋：连续点击 7 次版本号跳转到兑换码页
  if (tapCount.value >= 7) {
    tapCount.value = 0
    uni.navigateTo({ url: '/pages/profile/redeem' })
  }
}

const back = () => uni.navigateBack()
const goTheme = () => uni.navigateTo({ url: '/pages/profile/settings/theme' })
const goRedeem = () => uni.navigateTo({ url: '/pages/profile/redeem' })
</script>

<style scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.page-body {
  padding: 24rpx 40rpx 48rpx;
}

/* 分组标题 */
.group-title {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 0 8rpx;
  margin-bottom: 16rpx;
  margin-top: 32rpx;
}

.group-title:first-child {
  margin-top: 0;
}

/* 设置组 */
.setting-group {
  overflow: hidden;
  margin-bottom: 8rpx;
}

.setting-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 40rpx;
  border-bottom: 1rpx solid var(--color-divider);
}

.setting-item:active {
  background-color: var(--color-surface-alt);
}

.setting-item-last {
  border-bottom: none;
}

/* 图标容器（凹陷） */
.setting-icon-wrap {
  width: 72rpx;
  height: 72rpx;
  border-radius: 16rpx;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-concave-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.setting-icon-wrap .ph {
  font-size: 36rpx;
  color: var(--color-brand);
}

.setting-label {
  flex: 1;
  font-size: 30rpx;
  color: var(--color-text-primary);
}

.setting-right {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.setting-value {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}

.setting-value-brand {
  color: var(--color-brand-text);
}

.setting-value-mono {
  font-family: 'Courier New', monospace;
}

.setting-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
}

/* 底部版本 */
.version-footer {
  text-align: center;
  padding: 64rpx 0 32rpx;
}

.version-text {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

.version-sub {
  display: block;
  font-size: 20rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}
</style>
