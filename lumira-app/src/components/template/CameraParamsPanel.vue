<script setup lang="ts">
import type { TemplateCameraConfig } from '@/types/template'

interface CameraParamsPanelProps {
  params: TemplateCameraConfig
}

const props = defineProps<CameraParamsPanelProps>()

const evDisplay = () => {
  const ev = props.params.evBias ?? 0
  return ev > 0 ? `+${ev}` : String(ev)
}
</script>

<template>
  <view class="camera-params-panel">
    <text class="panel-title">相机参数建议</text>
    <view class="params-grid">
      <view class="param-item">
        <text class="param-value">EV {{ evDisplay() }}</text>
        <text class="param-label">曝光补偿</text>
      </view>
      <view v-if="params.iso" class="param-item">
        <text class="param-value">ISO {{ params.iso }}</text>
        <text class="param-label">感光度</text>
      </view>
      <view v-if="params.shutterSpeed" class="param-item">
        <text class="param-value">{{ params.shutterSpeed }}</text>
        <text class="param-label">快门速度</text>
      </view>
      <view v-if="params.whiteBalanceKelvin" class="param-item">
        <text class="param-value">WB {{ params.whiteBalanceKelvin }}K</text>
        <text class="param-label">白平衡</text>
      </view>
      <view v-if="params.lensSuggestion" class="param-item">
        <text class="param-value">{{ params.lensSuggestion === 'main' ? '主摄' : params.lensSuggestion === 'wide' ? '广角' : '长焦' }}</text>
        <text class="param-label">镜头建议</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.camera-params-panel {
  margin-bottom: var(--space-5);
}

.panel-title {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--space-3);
}

.params-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}

.param-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--space-3) var(--space-4);
  background: var(--color-bg-surface);
  border-radius: var(--radius-button);
  min-width: 80px;
}

.param-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-mono);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  line-height: var(--line-height-mono);
}

.param-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}
</style>
