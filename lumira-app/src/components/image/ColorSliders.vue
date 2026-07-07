<script setup lang="ts">
import type { ColorAdjustment } from '@/types/template'

interface ColorSlidersProps {
  value: ColorAdjustment
}

const props = defineProps<ColorSlidersProps>()

const emit = defineEmits<{
  (e: 'on-change', params: Partial<ColorAdjustment>): void
}>()

const sliders = [
  { key: 'brightness' as const, label: '亮度', min: -100, max: 100 },
  { key: 'contrast' as const, label: '对比度', min: -100, max: 100 },
  { key: 'saturation' as const, label: '饱和度', min: -100, max: 100 },
  { key: 'temperature' as const, label: '色温', min: -100, max: 100 },
  { key: 'tint' as const, label: '色调', min: -100, max: 100 },
]
</script>

<template>
  <view class="color-sliders">
    <view v-for="slider in sliders" :key="slider.key" class="slider-row">
      <text class="slider-label">{{ slider.label }}</text>
      <slider
        :value="props.value[slider.key]"
        :min="slider.min"
        :max="slider.max"
        :step="1"
        activeColor="var(--color-brand-primary)"
        backgroundColor="var(--color-border)"
        block-size="18"
        @change="(e: any) => emit('on-change', { [slider.key]: e.detail.value })"
      />
      <text class="slider-value">{{ props.value[slider.key] > 0 ? '+' : '' }}{{ props.value[slider.key] }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.color-sliders {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.slider-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.slider-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  min-width: 48px;
}

.slider-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-primary);
  min-width: 36px;
  text-align: right;
}
</style>
