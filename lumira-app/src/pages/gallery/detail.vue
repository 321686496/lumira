<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import AdjustmentPanel from '@/components/image/AdjustmentPanel.vue'
import CompareToggle from '@/components/image/CompareToggle.vue'
import type { ColorAdjustment } from '@/types/template'

const photoId = ref('')
const showOriginal = ref(false)

onLoad((query) => {
  if (query?.id) {
    photoId.value = query.id
  }
})

const handleColorChange = (_params: Partial<ColorAdjustment>) => {
  // TODO: 接入 ImageProcessingService 后实现实时预览
}

const handleLutSelect = (_name: string) => {
  // TODO: 接入 ImageProcessingService 后实现
}

const handleSmoothChange = (_value: number) => {
  // TODO: 接入 ImageProcessingService 后实现
}

const handleSharpenChange = (_value: number) => {
  // TODO: 接入 ImageProcessingService 后实现
}

const toggleCompare = () => {
  showOriginal.value = !showOriginal.value
}

const handleReset = () => {
  uni.showToast({ title: '已重置', icon: 'none' })
}

const handleExport = () => {
  uni.showToast({ title: '导出成功', icon: 'success' })
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="editor-page">
    <view class="editor-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">✕</text>
      </view>
      <CompareToggle :show-original="showOriginal" @on-toggle="toggleCompare" />
    </view>

    <view class="editor-canvas">
      <view class="image-frame">
        <text class="image-placeholder">🖼️ 照片编辑画布</text>
      </view>
    </view>

    <view class="editor-tools">
      <AdjustmentPanel
        @on-color-change="handleColorChange"
        @on-lut-select="handleLutSelect"
        @on-smooth-change="handleSmoothChange"
        @on-sharpen-change="handleSharpenChange"
      />
    </view>

    <view class="editor-actions">
      <view class="action-btn reset-btn" @click="handleReset">
        <text class="action-text">重置</text>
      </view>
      <view class="action-btn export-btn" @click="handleExport">
        <text class="action-text">导出</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.editor-page {
  min-height: 100vh;
  background: var(--color-capture-bg);
  display: flex;
  flex-direction: column;
}

.editor-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
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
  font-size: 18px;
  color: #FFFFFF;
}

.editor-canvas {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--space-5);
}

.image-frame {
  width: 100%;
  max-width: 360px;
  aspect-ratio: 3 / 4;
  background: #2A2A2A;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.image-placeholder {
  font-size: 20px;
  color: rgba(255, 255, 255, 0.4);
}

.editor-tools {
  max-height: 280px;
  overflow-y: auto;
}

.editor-actions {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5) calc(var(--space-6) + env(safe-area-inset-bottom));
}

.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-button);
  &:active { opacity: 0.85; }
}

.reset-btn {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.export-btn {
  background: var(--color-brand-primary);
}

.action-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}
</style>
