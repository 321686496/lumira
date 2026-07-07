<script setup lang="ts">
interface SmoothSliderProps {
  value: number
}

defineProps<SmoothSliderProps>()

const emit = defineEmits<{
  (e: 'on-change', value: number): void
}>()
</script>

<template>
  <view class="smooth-slider">
    <text class="slider-label">磨皮强度</text>
    <slider
      :value="value"
      :min="0"
      :max="100"
      :step="1"
      activeColor="var(--color-brand-primary)"
      backgroundColor="var(--color-border)"
      block-size="18"
      @change="(e: any) => emit('on-change', e.detail.value)"
    />
    <text class="slider-value">{{ value }}</text>
  </view>
</template>

<style lang="scss" scoped>
.smooth-slider {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.slider-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  min-width: 60px;
}

.slider-value {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-primary);
  min-width: 28px;
  text-align: right;
}
</style>
