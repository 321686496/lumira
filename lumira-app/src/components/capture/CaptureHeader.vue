<script setup lang="ts">
interface CaptureHeaderProps {
  templateName: string
}

defineProps<CaptureHeaderProps>()

const emit = defineEmits<{
  (e: 'on-back'): void
  (e: 'on-settings'): void
}>()
</script>

<template>
  <view class="capture-header">
    <view class="header-btn" @click="emit('on-back')">
      <text class="btn-icon">←</text>
    </view>
    <view class="header-center">
      <text class="template-name">{{ templateName }}</text>
    </view>
    <view class="header-btn" @click="emit('on-settings')">
      <text class="btn-icon">⚙</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.capture-header {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-4) var(--space-3);
  display: flex;
  align-items: center;
  justify-content: space-between;
  z-index: 10;
}

.header-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--color-capture-bar);
  backdrop-filter: blur(12px);
  &:active { opacity: 0.7; }
}

.btn-icon {
  font-size: 22px;
  color: var(--color-capture-text-bright);
  line-height: 1;
}

.header-center {
  padding: var(--space-1) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-capture-bar);
  backdrop-filter: blur(12px);
}

.template-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-capture-text-bright);
  font-weight: var(--weight-medium);
}
</style>
