<template>
  <view
    class="apply-pill"
    :class="{ applied }"
    @click.stop="onClick"
  >
    <text class="ph" :class="applied ? 'ph-check' : 'ph-sparkle'" />
    <text class="pill-text">{{ applied ? '已应用' : '一键应用' }}</text>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  applied: boolean
}>()

const emit = defineEmits<{
  (e: 'apply'): void
}>()

const onClick = () => {
  if (props.applied) {
    uni.showToast({ title: '参数已是模板原值', icon: 'none' })
    return
  }
  emit('apply')
}
</script>

<style lang="scss" scoped>
.apply-pill {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 20rpx;
  border-radius: 999rpx;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}

.apply-pill .ph {
  font-size: 26rpx;
  color: #fff;
}

.apply-pill .pill-text {
  font-size: 24rpx;
  color: #fff;
  font-weight: 500;
}

.apply-pill.applied {
  background: rgba(76, 175, 80, 0.85);
}

.apply-pill.applied .ph {
  color: #fff;
}
</style>
