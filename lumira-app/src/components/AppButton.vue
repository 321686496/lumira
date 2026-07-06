<script setup lang="ts">
interface Props {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'small' | 'medium' | 'large'
  disabled?: boolean
  block?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'medium',
  disabled: false,
  block: false
})

const emit = defineEmits<{
  (e: 'on-click'): void
}>()

const handleClick = () => {
  if (props.disabled) return
  emit('on-click')
}
</script>

<template>
  <view
    class="app-button"
    :class="[`variant-${variant}`, `size-${size}`, { disabled, block }]"
    @click="handleClick"
  >
    <slot />
  </view>
</template>

<style lang="scss" scoped>
.app-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius-button);
  font-size: var(--font-size-body);
  font-weight: 500;
  line-height: 1;
  transition: transform 0.15s ease, opacity 0.15s ease;

  &.block {
    display: flex;
    width: 100%;
  }

  &:not(.disabled):active {
    transform: scale(0.98);
  }

  &.disabled {
    opacity: 0.4;
    pointer-events: none;
  }
}

.variant-primary {
  background: var(--color-text-primary);
  color: var(--color-bg-card);
}

.variant-secondary {
  background: var(--color-bg-card);
  color: var(--color-text-primary);
  border: 1px solid var(--color-border);
}

.variant-ghost {
  background: transparent;
  color: var(--color-text-primary);
}

.size-small {
  height: 32px;
  padding: 0 var(--space-3);
  font-size: var(--font-size-caption);
}

.size-medium {
  height: 40px;
  padding: 0 var(--space-4);
  font-size: var(--font-size-body);
}

.size-large {
  height: 48px;
  padding: 0 var(--space-5);
  font-size: var(--font-size-heading);
}
</style>
