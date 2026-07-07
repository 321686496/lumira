<script setup lang="ts">
interface StatsSummaryProps {
  photoCount: number
  templateCount: number
}

defineProps<StatsSummaryProps>()

const emit = defineEmits<{
  (e: 'on-click'): void
}>()
</script>

<template>
  <view class="stats-summary" @click="emit('on-click')">
    <view class="stat-item">
      <text class="stat-value">{{ photoCount }}</text>
      <text class="stat-label">拍摄张数</text>
    </view>
    <view class="stat-divider"></view>
    <view class="stat-item">
      <text class="stat-value">{{ templateCount }}</text>
      <text class="stat-label">使用模板</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.stats-summary {
  margin: 0 var(--space-5) var(--space-7);
  padding: var(--space-5) var(--space-4);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;

  &:active { opacity: 0.85; }
}

.stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stat-value {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  line-height: 1;
}

.stat-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.stat-divider {
  width: 1px;
  height: 32px;
  background: var(--color-border);
}
</style>
