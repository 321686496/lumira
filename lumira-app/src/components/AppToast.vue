<script setup lang="ts">
interface Props {
  message: string
  type?: 'info' | 'success' | 'error'
  visible: boolean
}

withDefaults(defineProps<Props>(), {
  type: 'info'
})

const emit = defineEmits<{
  (e: 'on-dismiss'): void
}>()

const handleDismiss = () => {
  emit('on-dismiss')
}
</script>

<template>
  <view
    v-if="visible"
    class="app-toast"
    :class="`type-${type}`"
    @click="handleDismiss"
  >
    <view class="toast-inner">
      <text class="toast-icon">
        {{ type === 'success' ? '✓' : type === 'error' ? '!' : 'i' }}
      </text>
      <text class="toast-message">{{ message }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.app-toast {
  position: fixed;
  top: calc(var(--space-4) + env(safe-area-inset-top));
  left: 50%;
  transform: translateX(-50%);
  z-index: 1000;
  animation: toast-in 0.2s ease;

  &.type-info .toast-inner {
    background: var(--color-text-primary);
  }
  &.type-success .toast-inner {
    background: var(--color-brand-secondary);
  }
  &.type-error .toast-inner {
    background: var(--color-danger);
  }
}

.toast-inner {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-floating);
  max-width: 80vw;
}

.toast-icon {
  font-size: var(--font-size-caption);
  color: var(--color-bg-card);
  font-weight: 700;
  line-height: 1;
}

.toast-message {
  font-size: var(--font-size-caption);
  color: var(--color-bg-card);
  line-height: 1.4;
}

@keyframes toast-in {
  from {
    opacity: 0;
    transform: translateX(-50%) translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateX(-50%) translateY(0);
  }
}
</style>
