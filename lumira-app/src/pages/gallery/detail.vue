<template>
  <view class="workbench-page">
    <!-- Top bar -->
    <view class="top-bar">
      <view class="back-btn" @tap="onBack">
        <text class="back-text">←</text>
      </view>
      <text class="top-title">编辑</text>
      <text class="export-btn" @tap="onExport">导出</text>
    </view>

    <!-- Image canvas -->
    <view class="canvas-area">
      <view class="canvas-frame">
        <image
          v-if="photoUri"
          class="canvas-img"
          :src="photoUri"
          mode="aspectFit"
        />
        <view v-else class="canvas-placeholder">
          <text class="placeholder-text">照片画布</text>
          <text class="placeholder-hint">id: {{ photoId }}</text>
        </view>
      </view>
    </view>

    <!-- Tool tabs -->
    <scroll-view class="tool-tabs" scroll-x>
      <view class="tool-list">
        <view
          v-for="tool in tools"
          :key="tool.key"
          class="tool-pill"
          :class="{ active: activeTool === tool.key }"
          @tap="onToolTap(tool.key)"
        >
          <text class="tool-text" :class="{ active: activeTool === tool.key }">{{ tool.label }}</text>
        </view>
      </view>
    </scroll-view>

    <!-- Sliders panel -->
    <view class="slider-panel">
      <view class="slider-row">
        <view class="slider-label-row">
          <text class="slider-label">{{ currentToolLabel }}</text>
          <text class="slider-value">{{ sliderValue }}</text>
        </view>
        <slider
          class="slider"
          :min="0"
          :max="100"
          :step="1"
          :value="sliderValue"
          activeColor="var(--color-brand-primary)"
          @change="onSliderChange"
        />
      </view>
    </view>

    <!-- Bottom actions -->
    <view class="bottom-actions">
      <view class="action-btn action-secondary" @tap="onReset">
        <text class="action-text-secondary">重置</text>
      </view>
      <view class="action-btn action-primary" @tap="onExport">
        <text class="action-text-primary">导出</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useImageProcessing } from '@/composables/useImageProcessing'

const imageProcessing = useImageProcessing()

const photoId = ref<string>('')
const photoUri = ref<string>('')
const activeTool = ref<string>('color')
const sliderValue = ref<number>(50)

const tools = [
  { key: 'color', label: '调色' },
  { key: 'lut', label: 'LUT' },
  { key: 'crop', label: '裁剪' },
  { key: 'smooth', label: '磨皮' },
  { key: 'sharpen', label: '锐化' },
]

const currentToolLabel = computed(() => {
  return tools.find((t) => t.key === activeTool.value)?.label ?? ''
})

onLoad((options) => {
  photoId.value = (options?.id as string) ?? ''
})

const onToolTap = (key: string) => {
  activeTool.value = key
  sliderValue.value = 50
}

const onSliderChange = (e: any) => {
  sliderValue.value = e.detail.value
}

const onReset = () => {
  sliderValue.value = 50
}

const onExport = () => {
  uni.showToast({ title: '已导出', icon: 'success' })
}

const onBack = () => {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.workbench-page {
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

.export-btn {
  font-size: var(--font-size-body);
  color: var(--color-brand-primary);
}

.canvas-area {
  flex: 1;
  padding: var(--space-3) var(--space-4);
  display: flex;
  align-items: center;
  justify-content: center;
}

.canvas-frame {
  width: 100%;
  height: 100%;
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.canvas-img {
  width: 100%;
  height: 100%;
}

.canvas-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.placeholder-text {
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
}

.placeholder-hint {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.tool-tabs {
  flex-shrink: 0;
  padding: var(--space-2) var(--space-4);
}

.tool-list {
  display: inline-flex;
  gap: var(--space-2);
}

.tool-pill {
  padding: var(--space-2) var(--space-4);
  border-radius: 999px;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
}

.tool-pill.active {
  background: var(--color-brand-primary);
  border-color: var(--color-brand-primary);
}

.tool-text {
  font-size: var(--font-size-tag);
  color: var(--color-text-secondary);
}

.tool-text.active {
  color: var(--color-text-primary);
}

.slider-panel {
  flex-shrink: 0;
  padding: var(--space-3) var(--space-5);
}

.slider-row {
  width: 100%;
}

.slider-label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--space-2);
}

.slider-label {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.slider-value {
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.slider {
  width: 100%;
}

.bottom-actions {
  display: flex;
  padding: var(--space-3) var(--space-5) var(--space-7);
  gap: var(--space-3);
}

.action-btn {
  flex: 1;
  height: 48px;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-secondary {
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
}

.action-primary {
  background: var(--color-brand-primary);
}

.action-text-secondary {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.action-text-primary {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}
</style>
