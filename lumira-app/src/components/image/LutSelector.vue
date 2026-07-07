<script setup lang="ts">
interface LutSelectorProps {
  current: string
  options: { name: string; value: string }[]
}

defineProps<LutSelectorProps>()

const emit = defineEmits<{
  (e: 'on-select', lutName: string): void
}>()
</script>

<template>
  <view class="lut-selector">
    <scroll-view scroll-x class="lut-scroll" :show-scrollbar="false">
      <view class="lut-row">
        <view
          v-for="opt in options"
          :key="opt.value"
          class="lut-item"
          :class="{ active: opt.value === current }"
          @click="emit('on-select', opt.value)"
        >
          <view class="lut-thumb"></view>
          <text class="lut-name">{{ opt.name }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.lut-selector {
  width: 100%;
}

.lut-scroll {
  width: 100%;
  white-space: nowrap;
}

.lut-row {
  display: inline-flex;
  gap: var(--space-3);
}

.lut-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  flex-shrink: 0;
  &:active { opacity: 0.8; }
}

.lut-thumb {
  width: 56px;
  height: 56px;
  border-radius: var(--radius-card);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);

  .active & {
    border-color: var(--color-brand-primary);
    border-width: 2px;
  }
}

.lut-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-secondary);

  .active & {
    color: var(--color-brand-primary);
    font-weight: var(--weight-medium);
  }
}
</style>
