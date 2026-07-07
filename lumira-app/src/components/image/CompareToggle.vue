<script setup lang="ts">
interface CompareToggleProps {
  showOriginal: boolean
}

defineProps<CompareToggleProps>()

const emit = defineEmits<{
  (e: 'on-toggle'): void
}>()
</script>

<template>
  <view class="compare-toggle" @click="emit('on-toggle')">
    <text class="toggle-text">⇄ {{ showOriginal ? '效果' : '原图' }}</text>
  </view>
</template>

<style lang="scss" scoped>
.compare-toggle {
  padding: var(--space-2) var(--space-3);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: var(--radius-button);
  &:active { opacity: 0.7; }
}

.toggle-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: #FFFFFF;
  font-weight: var(--weight-medium);
}
</style>
