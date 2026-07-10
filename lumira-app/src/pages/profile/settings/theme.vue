<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">主题</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 主题卡片列表 -->
      <view
        class="theme-card"
        :class="{ selected: currentTheme === t.id }"
        v-for="t in themes"
        :key="t.id"
        @click="selectTheme(t.id)"
      >
        <!-- 图标 -->
        <view class="theme-icon">
          <text class="ph" :class="t.icon"></text>
        </view>
        <!-- 文本区 -->
        <view class="theme-text">
          <text class="theme-name">{{ t.label }}</text>
          <text class="theme-desc">{{ t.description }}</text>
          <!-- 色彩预览点 -->
          <view class="color-dots">
            <view class="color-dot" v-for="(c, i) in t.previewColors" :key="i" :style="{ backgroundColor: c }"></view>
          </view>
        </view>
        <!-- 选中标记 -->
        <view v-if="currentTheme === t.id" class="theme-check">
          <text class="ph ph-check check-icon"></text>
        </view>
      </view>

      <!-- 跟随系统 -->
      <view class="sys-card neu-card">
        <view class="sys-row">
          <view class="sys-info">
            <text class="sys-title">跟随系统</text>
            <text class="sys-desc">根据系统深浅色自动切换</text>
          </view>
          <view class="neu-toggle" :class="{ active: followSystem }" @click="toggleFollowSystem">
            <view class="neu-toggle-knob"></view>
          </view>
        </view>
      </view>

      <!-- 底部说明 -->
      <view class="bottom-note">
        <text class="bottom-note-text">主题切换即时生效，所有页面同步更新</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useTheme } from '@/composables/useTheme'
import { THEME_METAS, THEME_IDS } from '@/theme/theme-configs'
import type { ThemeId } from '@/theme/theme-configs'

const { currentTheme, followSystem, setTheme, setFollowSystem } = useTheme()

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

/* 主题卡 */
.theme-card {
  position: relative;
  background-color: var(--color-canvas);
  border-radius: 32rpx;
  box-shadow: var(--shadow-convex);
  padding: 40rpx;
  margin-bottom: 24rpx;
  display: flex;
  align-items: center;
  gap: 32rpx;
  transition: box-shadow 0.2s ease;
}

.theme-card:active {
  box-shadow: var(--shadow-pressed);
}

.theme-card.selected {
  box-shadow: var(--shadow-concave);
  border: 2rpx solid var(--color-brand);
}

/* 图标 */
.theme-icon {
  width: 104rpx;
  height: 104rpx;
  border-radius: 20rpx;
  background-color: var(--color-surface-alt);
  box-shadow: var(--shadow-convex-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.theme-icon .ph {
  font-size: 48rpx;
  color: var(--color-brand);
}

.theme-card.selected .theme-icon {
  background-color: var(--color-brand-subtle);
  box-shadow: var(--shadow-concave-subtle);
}

/* 文本区 */
.theme-text {
  flex: 1;
}

.theme-name {
  display: block;
  font-family: var(--font-cn-title);
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 8rpx;
}

.theme-desc {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  line-height: 1.6;
}

/* 色彩点 */
.color-dots {
  display: flex;
  gap: 12rpx;
  margin-top: 20rpx;
}

.color-dot {
  width: 32rpx;
  height: 32rpx;
  border-radius: 50%;
  box-shadow: var(--shadow-convex-subtle);
}

/* 选中标记 */
.theme-check {
  position: absolute;
  top: 24rpx;
  right: 24rpx;
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background-color: var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-convex-brand);
}

.check-icon {
  font-size: 24rpx;
  color: var(--color-text-inverse);
}

/* 跟随系统 */
.sys-card {
  padding: 40rpx;
  margin-top: 16rpx;
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
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 4rpx;
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
