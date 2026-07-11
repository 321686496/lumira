<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">主题与风格</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- UI 风格选择 -->
      <text class="section-title">UI 风格</text>
      <view class="style-grid">
        <view
          class="style-card"
          :class="{ selected: currentStyle === s.id }"
          v-for="s in styles"
          :key="s.id"
          @click="selectStyle(s.id)"
        >
          <view class="style-preview" :class="'preview-' + s.id">
            <view class="preview-card"></view>
            <view class="preview-circle"></view>
          </view>
          <view class="style-info">
            <text class="style-name">{{ s.label }}</text>
            <text class="style-desc">{{ s.description }}</text>
          </view>
          <view v-if="currentStyle === s.id" class="style-check">
            <text class="ph ph-check check-icon"></text>
          </view>
        </view>
      </view>

      <!-- 颜色主题选择 -->
      <text class="section-title">颜色主题</text>
      <view class="theme-grid">
        <view
          class="theme-card"
          :class="{ selected: currentTheme === t.id }"
          v-for="t in themes"
          :key="t.id"
          @click="selectTheme(t.id)"
        >
          <view class="theme-swatch" :style="{ backgroundColor: t.colors.canvas }">
            <view class="swatch-brand" :style="{ backgroundColor: t.colors.brand }"></view>
          </view>
          <view class="theme-info">
            <text class="theme-name">{{ t.label }}</text>
            <view class="color-dots">
              <view class="color-dot" v-for="(c, i) in t.previewColors" :key="i" :style="{ backgroundColor: c }"></view>
            </view>
          </view>
          <view v-if="currentTheme === t.id" class="theme-check">
            <text class="ph ph-check check-icon"></text>
          </view>
        </view>
      </view>

      <!-- 跟随系统 -->
      <view class="sys-card neu-card">
        <view class="sys-row">
          <view class="sys-info">
            <text class="sys-title">跟随系统</text>
            <text class="sys-desc">根据系统深浅色自动切换主题（仅影响颜色，不影响风格）</text>
          </view>
          <view class="neu-toggle" :class="{ active: followSystem }" @click="toggleFollowSystem">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 底部说明 -->
      <view class="bottom-note">
        <text class="bottom-note-text">风格与主题可任意组合，切换即时生效</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS, THEME_IDS, STYLE_METAS, STYLE_IDS } from '@/theme/theme-configs'
import type { ThemeId, StyleId } from '@/theme/theme-configs'

const { currentTheme, currentStyle, followSystem, setTheme, setStyle, setFollowSystem } = useTheme()

const styles = computed(() => STYLE_IDS.map(id => STYLE_METAS[id]))

const themes = computed(() => THEME_IDS.map(id => {
  const meta = THEME_METAS[id]
  return {
    ...meta,
    previewColors: [
      meta.colors.canvas,
      meta.colors.brand,
      meta.colors.textPrimary,
      meta.colors.textSecondary
    ]
  }
}))

const selectStyle = (id: StyleId) => {
  setStyle(id)
  uni.showToast({ title: `已切换至${STYLE_METAS[id].label}风格`, icon: 'none', duration: 1000 })
}

const selectTheme = (id: ThemeId) => {
  setTheme(id)
  uni.showToast({ title: `已切换至${THEME_METAS[id].label}`, icon: 'none', duration: 1000 })
}

const toggleFollowSystem = () => {
  setFollowSystem(!followSystem.value)
}

const back = () => uni.navigateBack()
</script>

<style scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.page-body {
  padding: 24rpx 40rpx 48rpx;
}

/* 区块标题 */
.section-title {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 0 8rpx;
  margin-bottom: 16rpx;
  margin-top: 32rpx;
}

.section-title:first-child {
  margin-top: 0;
}

/* ===== 风格网格 ===== */
.style-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  margin-bottom: 8rpx;
}

.style-card {
  position: relative;
  background-color: var(--color-canvas);
  border-radius: 32rpx;
  box-shadow: var(--shadow-convex);
  padding: 32rpx;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.style-card:active {
  transform: scale(0.97);
}

.style-card.selected {
  box-shadow: var(--shadow-concave);
  border: 2rpx solid var(--color-brand);
}

/* 风格预览区 */
.style-preview {
  height: 120rpx;
  border-radius: 16rpx;
  background-color: var(--color-surface-alt);
  position: relative;
  overflow: hidden;
  margin-bottom: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.preview-card {
  width: 80rpx;
  height: 56rpx;
  border-radius: 8rpx;
  background-color: var(--color-surface);
}

.preview-circle {
  position: absolute;
  right: 16rpx;
  bottom: 16rpx;
  width: 32rpx;
  height: 32rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
}

/* 每种风格的预览样式 */
.preview-neumorphism .preview-card {
  box-shadow: 3px 3px 6px rgba(0,0,0,0.1), -3px -3px 6px rgba(255,255,255,0.8);
}

.preview-flat .preview-card {
  border: 1rpx solid var(--color-divider);
  box-shadow: none;
}

.preview-flat .preview-circle {
  box-shadow: none;
}

.preview-glass {
  background: linear-gradient(135deg, var(--color-brand-subtle) 0%, var(--color-surface-alt) 100%);
}

.preview-glass .preview-card {
  background-color: rgba(255, 255, 255, 0.55);
  backdrop-filter: blur(8px);
  border: 1rpx solid rgba(255,255,255,0.3);
  box-shadow: 0 4px 16px rgba(0,0,0,0.08);
}

.preview-female .preview-card {
  background-color: rgba(255, 255, 255, 0.75);
  backdrop-filter: blur(8px);
  border-radius: 24rpx;
  box-shadow: 0 4px 16px rgba(var(--color-brand-rgb), 0.15);
}

.preview-female .preview-circle {
  box-shadow: 0 0 0 4rpx rgba(var(--color-brand-rgb), 0.3);
  animation: female-pulse 2s ease-in-out infinite;
}

.style-info {
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.style-name {
  font-family: var(--font-cn-title);
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.style-desc {
  font-size: 20rpx;
  color: var(--color-text-tertiary);
  line-height: 1.5;
}

.style-check {
  position: absolute;
  top: 16rpx;
  right: 16rpx;
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-brand);
}

/* ===== 主题网格 ===== */
.theme-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  margin-bottom: 8rpx;
}

.theme-card {
  position: relative;
  background-color: var(--color-canvas);
  border-radius: 24rpx;
  box-shadow: var(--shadow-convex-subtle);
  padding: 24rpx;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
  overflow: hidden;
}

.theme-card:active {
  transform: scale(0.97);
}

.theme-card.selected {
  box-shadow: var(--shadow-concave);
  border: 2rpx solid var(--color-brand);
}

.theme-swatch {
  height: 96rpx;
  border-radius: 16rpx;
  margin-bottom: 16rpx;
  position: relative;
  overflow: hidden;
}

.swatch-brand {
  position: absolute;
  right: 16rpx;
  bottom: 16rpx;
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
}

.theme-info {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.theme-name {
  font-family: var(--font-cn-title);
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.color-dots {
  display: flex;
  gap: 8rpx;
}

.color-dot {
  width: 20rpx;
  height: 20rpx;
  border-radius: 50%;
}

.theme-check {
  position: absolute;
  top: 16rpx;
  right: 16rpx;
  width: 40rpx;
  height: 40rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-brand);
}

/* 通用选中图标 */
.check-icon {
  font-size: 22rpx;
  color: var(--color-text-inverse);
}

/* ===== 跟随系统 ===== */
.sys-card {
  padding: 32rpx;
  margin-top: 24rpx;
}

.sys-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sys-info {
  flex: 1;
}

.sys-title {
  display: block;
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.sys-desc {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
  line-height: 1.5;
}

/* 底部说明 */
.bottom-note {
  text-align: center;
  padding: 48rpx 0;
}

.bottom-note-text {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  line-height: 1.8;
}
</style>
