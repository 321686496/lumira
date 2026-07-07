<script setup lang="ts">
import type { CameraParams } from '@/types/camera'

interface ParameterBarProps {
  params: CameraParams
  isLevel: boolean
}

const props = defineProps<ParameterBarProps>()

const evDisplay = () => {
  const ev = props.params.evBias
  return ev > 0 ? `+${ev}` : String(ev)
}

const wbDisplay = () => {
  const wb = props.params.whiteBalance
  if (wb === 'auto') return 'AUTO'
  if (wb === 'daylight') return '日光'
  if (wb === 'cloudy') return '阴天'
  return String(wb)
}
</script>

<template>
  <view class="parameter-bar" @click="() => {}">
    <text class="param-item">⊹ {{ isLevel ? '水平' : '倾斜' }}</text>
    <text class="param-sep">·</text>
    <text class="param-item">EV {{ evDisplay() }}</text>
    <text class="param-sep">·</text>
    <text class="param-item">WB {{ wbDisplay() }}</text>
  </view>
</template>

<style lang="scss" scoped>
.parameter-bar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-capture-bar);
  backdrop-filter: blur(12px);
  align-self: center;
}

.param-item {
  font-family: var(--font-mono);
  font-size: var(--font-size-caption);
  color: var(--color-capture-text-bright);
  font-weight: var(--weight-medium);
}

.param-sep {
  font-size: var(--font-size-caption);
  color: rgba(255, 255, 255, 0.3);
}
</style>
