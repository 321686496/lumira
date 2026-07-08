<script setup lang="ts">
import { useSettingsStore } from '@/stores/settings'

const settingsStore = useSettingsStore()

const goBack = () => {
  uni.navigateBack()
}

const toggleGrid = () => {
  settingsStore.updateSetting('showGrid', !settingsStore.settings.showGrid)
}

const toggleLevel = () => {
  settingsStore.updateSetting('showLevelIndicator', !settingsStore.settings.showLevelIndicator)
}

const toggleSound = () => {
  settingsStore.updateSetting('shutterSound', !settingsStore.settings.shutterSound)
}

const clearCache = () => {
  uni.showModal({
    title: '清除缓存',
    content: '确定清除所有缓存数据？',
    success: (res) => {
      if (res.confirm) {
        uni.showToast({ title: '已清除', icon: 'success' })
      }
    },
  })
}
</script>

<template>
  <view class="settings-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">设置</text>
    </view>

    <view class="settings-list">
      <view class="setting-row">
        <text class="setting-label">取景器网格</text>
        <switch :checked="settingsStore.settings.showGrid" @change="toggleGrid" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row">
        <text class="setting-label">水平仪</text>
        <switch :checked="settingsStore.settings.showLevelIndicator" @change="toggleLevel" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row">
        <text class="setting-label">快门声音</text>
        <switch :checked="settingsStore.settings.shutterSound" @change="toggleSound" color="var(--color-brand-primary)" />
      </view>
      <view class="setting-row" @click="clearCache">
        <text class="setting-label">清除缓存</text>
        <text class="setting-arrow">→</text>
      </view>
    </view>

    <view class="app-info">
      <text class="app-version">如画 Lumira v1.0.0</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.settings-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
}

.page-nav {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  &:active { opacity: 0.6; }
}

.nav-icon {
  font-size: 22px;
  color: var(--color-text-primary);
}

.nav-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.settings-list {
  padding: 0 var(--space-5);
}

.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) 0;
  border-bottom: 1px solid var(--color-border);
}

.setting-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.setting-arrow {
  font-size: 16px;
  color: var(--color-text-tertiary);
}

.app-info {
  padding: var(--space-8) var(--space-5);
  text-align: center;
}

.app-version {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}
</style>
