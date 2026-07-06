<template>
  <view class="settings-page">
    <!-- Top bar -->
    <view class="top-bar">
      <view class="back-btn" @tap="onBack">
        <text class="back-text">←</text>
      </view>
      <text class="top-title">设置</text>
      <view class="top-placeholder"></view>
    </view>

    <scroll-view class="content-scroll" scroll-y>
      <view class="section">
        <text class="section-title">拍摄</text>
        <view class="section-card">
          <view class="setting-item" @tap="onSaveQuality">
            <text class="setting-label">保存画质</text>
            <text class="setting-value">{{ saveQuality }}</text>
          </view>
          <view class="setting-item">
            <text class="setting-label">网格默认显示</text>
            <switch
              :checked="defaultGridDisplay"
              color="var(--color-brand-primary)"
              @change="onGridToggle"
            />
          </view>
          <view class="setting-item">
            <text class="setting-label">叠图透明度</text>
            <text class="setting-value">{{ defaultOverlayOpacity }}%</text>
          </view>
          <view class="setting-item" @tap="onDefaultCamera">
            <text class="setting-label">默认摄像头</text>
            <text class="setting-value">{{ defaultCamera }}</text>
          </view>
        </view>
      </view>

      <view class="section">
        <text class="section-title">其他</text>
        <view class="section-card">
          <view class="setting-item" @tap="onWatermark">
            <text class="setting-label">水印</text>
            <text class="setting-value">未开启</text>
          </view>
          <view class="setting-item" @tap="onClearCache">
            <text class="setting-label">清除缓存</text>
            <text class="setting-value">›</text>
          </view>
          <view class="setting-item" @tap="onAbout">
            <text class="setting-label">关于</text>
            <text class="setting-value">›</text>
          </view>
        </view>
      </view>

      <view class="bottom-pad"></view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useSettingsStore } from '@/stores/settings'

const settingsStore = useSettingsStore()

const saveQuality = computed(() => settingsStore.saveQuality ?? '原画质')
const defaultGridDisplay = computed(() => settingsStore.defaultGridDisplay ?? false)
const defaultOverlayOpacity = computed(() => settingsStore.defaultOverlayOpacity ?? 80)
const defaultCamera = computed(() => settingsStore.defaultCamera ?? '后置')

onShow(() => {
  settingsStore.loadSettings()
})

const onSaveQuality = () => {
  uni.showActionSheet({
    itemList: ['原画质', '高质量', '标准'],
    success: (res) => {
      const labels = ['原画质', '高质量', '标准']
      settingsStore.setSaveQuality(labels[res.tapIndex])
    },
  })
}

const onGridToggle = (e: any) => {
  settingsStore.setDefaultGridDisplay(e.detail.value)
}

const onDefaultCamera = () => {
  uni.showActionSheet({
    itemList: ['后置', '前置'],
    success: (res) => {
      settingsStore.defaultCamera = res.tapIndex === 0 ? '后置' : '前置'
    },
  })
}

const onWatermark = () => {
  uni.showToast({ title: '开发中', icon: 'none' })
}

const onClearCache = () => {
  settingsStore.clearCache()
  uni.showToast({ title: '已清除', icon: 'success' })
}

const onAbout = () => {
  uni.showToast({ title: '如画 Lumira', icon: 'none' })
}

const onBack = () => {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.settings-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
}

.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-5) var(--space-4) var(--space-3);
}

.back-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.back-text {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
}

.top-title {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
}

.top-placeholder {
  width: 40px;
  height: 40px;
}

.content-scroll {
  flex: 1;
}

.section {
  padding: var(--space-2) var(--space-5) var(--space-5);
}

.section-title {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  display: block;
  margin-bottom: var(--space-2);
  padding-left: var(--space-2);
}

.section-card {
  background: var(--color-bg-card);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  overflow: hidden;
}

.setting-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--color-border);
}

.setting-item:last-child {
  border-bottom: none;
}

.setting-label {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.setting-value {
  font-size: var(--font-size-body);
  color: var(--color-text-tertiary);
}

.bottom-pad {
  height: var(--space-6);
}
</style>
