<script setup lang="ts">
interface Props {
  message: string
  actionText?: string
}

defineProps<Props>()

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
    <text class="empty-message">{{ message }}</text>
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

.empty-message {
  font-size: var(--font-size-body);
  color: var(--color-text-tertiary);
  text-align: center;
  line-height: 1.5;
}

.empty-action {
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-button);
  border: 1px solid var(--color-brand-primary);
  transition: opacity 0.15s ease;

  &:active {
    opacity: 0.7;
  }
}

.action-text {
  font-size: var(--font-size-caption);
  color: var(--color-brand-primary);
  font-weight: 500;
  line-height: 1;
}
</style>
