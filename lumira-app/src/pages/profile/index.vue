<script setup lang="ts">
import { useTabBarVariant } from '@/composables/useThemeComponent'
import { useGalleryStore } from '@/stores/gallery'
import { useTemplatesStore } from '@/stores/templates'

const galleryStore = useGalleryStore()
const templatesStore = useTemplatesStore()
const tabBarVariant = useTabBarVariant()

const goSettings = () => {
  uni.navigateTo({ url: '/pages/profile/settings' })
}

const goGallery = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const goTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const goImport = () => {
  uni.navigateTo({ url: '/pages/templates/import' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  }
}
</script>

<template>
  <view class="profile-page">
    <view class="profile-header">
      <view class="avatar-area">
        <view class="avatar-placeholder">
          <text class="avatar-icon">◍</text>
        </view>
        <view class="user-info">
          <text class="user-name">如画用户</text>
          <text class="user-tagline">用镜头记录生活</text>
        </view>
      </view>
    </view>

    <view class="stats-row">
      <view class="stat-block" @click="goGallery">
        <text class="stat-num">{{ galleryStore.photoCount }}</text>
        <text class="stat-lbl">拍摄</text>
      </view>
      <view class="stat-block" @click="goTemplates">
        <text class="stat-num">{{ templatesStore.templateCount }}</text>
        <text class="stat-lbl">模板</text>
      </view>
    </view>

    <view class="menu-section">
      <view class="menu-item" @click="goSettings">
        <text class="menu-label">设置</text>
        <text class="menu-arrow">→</text>
      </view>
      <view class="menu-item" @click="goImport">
        <text class="menu-label">导入模板</text>
        <text class="menu-arrow">→</text>
      </view>
    </view>

    <component :is="tabBarVariant" current="profile" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.profile-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  padding-bottom: 120px;
}

.profile-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-5);
}

.avatar-area {
  display: flex;
  align-items: center;
  gap: var(--space-4);
}

.avatar-placeholder {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  display: flex;
  align-items: center;
  justify-content: center;
}

.avatar-icon {
  font-size: 28px;
  color: var(--color-text-tertiary);
}

.user-info {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.user-name {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-title);
}

.user-tagline {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.stats-row {
  display: flex;
  gap: var(--space-4);
  padding: 0 var(--space-5) var(--space-6);
}

.stat-block {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--space-4);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  &:active { opacity: 0.85; }
}

.stat-num {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  line-height: 1;
}

.stat-lbl {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.menu-section {
  padding: 0 var(--space-5);
}

.menu-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) 0;
  border-bottom: 1px solid var(--color-border);
  &:active { opacity: 0.7; }
}

.menu-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.menu-arrow {
  font-size: 16px;
  color: var(--color-text-tertiary);
}
</style>
