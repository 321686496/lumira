<script setup lang="ts">
import type { Inspiration } from '@/data/inspirations'

interface DailyInspirationProps {
  inspiration: Inspiration
}

defineProps<DailyInspirationProps>()

const emit = defineEmits<{
  (e: 'on-try', category: string): void
}>()
</script>

<template>
  <view class="daily-inspiration">
    <view class="section-header">
      <text class="section-title">💡 今日灵感</text>
    </view>
    <view class="inspiration-card">
      <text class="inspiration-text">{{ inspiration.emoji }} "{{ inspiration.text }}"</text>
      <view class="try-btn" @click="emit('on-try', inspiration.relatedCategory)">
        <text class="try-text">试试看 →</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.daily-inspiration {
  padding: 0 var(--space-5);
  margin-bottom: var(--space-7);
}

.section-header {
  margin-bottom: var(--space-3);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
}

.inspiration-card {
  padding: var(--space-5);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
}

.inspiration-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
  line-height: var(--line-height-body);
  display: block;
}

.try-btn {
  margin-top: var(--space-4);
  display: inline-flex;
  padding: var(--space-2) var(--space-4);
  border: 1px solid var(--color-brand-primary);
  border-radius: var(--radius-button);
  transition: transform var(--duration-fast) ease;

  &:active {
    transform: scale(0.98);
  }
}

.try-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-brand-primary);
}
</style>
