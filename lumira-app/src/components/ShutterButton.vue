<script setup lang="ts">
interface Props {
  disabled?: boolean
  capturing?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  capturing: false
})

const emit = defineEmits<{
  (e: 'on-capture'): void
}>()

const handleCapture = () => {
  if (props.disabled || props.capturing) return
  emit('on-capture')
}
</script>

<template>
  <view
    class="shutter-button"
    :class="{ disabled, capturing }"
    @click="handleCapture"
  >
    <view class="shutter-ring">
      <view class="shutter-core" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.shutter-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 72px;
  height: 72px;
  transition: transform 0.1s ease;

  &:not(.disabled):not(.capturing):active {
    transform: scale(0.94);
  }

  &.disabled {
    opacity: 0.4;
    pointer-events: none;
  }
}

.shutter-ring {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 3px solid var(--color-brand-primary);
  background: var(--color-bg-card);
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
}

.shutter-core {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--color-brand-primary);
  transition: transform 0.15s ease, opacity 0.15s ease;
}

.capturing {
  .shutter-core {
    opacity: 0.5;
    transform: scale(0.8);
  }
}
</style>
