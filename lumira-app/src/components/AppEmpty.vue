<script setup lang="ts">
interface AppEmptyProps {
  title: string
  description?: string
  actionText?: string
}

defineProps<AppEmptyProps>()

const emit = defineEmits<{
  (e: 'on-action'): void
}>()

const handleAction = () => {
  emit('on-action')
}
</script>

<template>
  <view class="app-empty">
    <view class="empty-icon">
      <text class="icon-glyph">○</text>
    </view>
    <text class="empty-title">{{ title }}</text>
    <text v-if="description" class="empty-description">{{ description }}</text>
    <view v-if="actionText" class="empty-action" @click="handleAction">
      <text class="action-text">{{ actionText }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.app-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-7) var(--space-4);
  gap: var(--space-3);
}

.empty-icon {
  width: var(--space-9);
  height: var(--space-9);
  display: flex;
  align-items: center;
  justify-content: center;
}

.icon-glyph {
  font-size: var(--font-size-display);
  color: var(--color-text-tertiary);
  opacity: 0.5;
}

.empty-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
  text-align: center;
  line-height: var(--line-height-body);
}

.empty-description {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  text-align: center;
  line-height: var(--line-height-caption);
}

.empty-action {
  margin-top: var(--space-2);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-button);
  border: 1px solid var(--color-brand-primary);
  transition: opacity var(--duration-fast) ease;

  &:active {
    opacity: 0.7;
  }
}

.action-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-brand-primary);
  font-weight: var(--weight-medium);
  line-height: 1;
}
</style>
