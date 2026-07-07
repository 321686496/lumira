<script setup lang="ts">
interface ShutterButtonProps {
  active?: boolean
}

withDefaults(defineProps<ShutterButtonProps>(), {
  active: false,
})

const emit = defineEmits<{
  (e: 'on-capture'): void
}>()
</script>

<template>
  <view class="shutter-button" :class="{ active }" @click="emit('on-capture')">
    <view class="shutter-outer">
      <view class="shutter-inner"></view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.shutter-button {
  display: flex;
  align-items: center;
  justify-content: center;
  &:active .shutter-outer {
    transform: scale(0.92);
  }
}

.shutter-outer {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 4px solid #FFFFFF;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform var(--duration-fast) ease;
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.1);
}

.shutter-inner {
  width: 58px;
  height: 58px;
  border-radius: 50%;
  background: var(--color-brand-primary);
}
</style>
