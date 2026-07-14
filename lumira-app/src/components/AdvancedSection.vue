<template>
  <view class="advanced-section">
    <view class="advanced-toggle" @click="toggleOpen">
      <text class="advanced-title">{{ title }}</text>
      <text class="ph advanced-caret" :class="open ? 'ph-caret-up' : 'ph-caret-down'" />
    </view>
    <view v-if="open" class="advanced-content">
      <slot />
    </view>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  title: string
  open: boolean
}>()

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
}>()

const toggleOpen = () => {
  emit('update:open', !props.open)
}
</script>

<style lang="scss" scoped>
.advanced-section {
  margin-top: 16rpx;
  border-top: 1rpx solid rgba(255, 255, 255, 0.08);
  padding-top: 16rpx;
}

.advanced-toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16rpx 20rpx;
  background: rgba(255, 255, 255, 0.04);
  border-radius: 12rpx;
}

.advanced-title {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.75);
  font-weight: 500;
}

.advanced-caret {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.6);
}

.advanced-content {
  padding-top: 16rpx;
}
</style>
