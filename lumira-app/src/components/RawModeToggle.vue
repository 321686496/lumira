<template>
  <view
    class="raw-toggle-pill"
    :class="{ active: rawMode }"
    @click.stop="toggle"
  >
    <text class="ph ph-camera" />
    <text class="pill-text">{{ rawMode ? '原相机' : (hasTemplate ? '模板' : '自由') }}</text>
  </view>
</template>

<script setup lang="ts">
const props = defineProps<{
  rawMode: boolean
  hasTemplate: boolean
}>()

const emit = defineEmits<{
  (e: 'update:rawMode', value: boolean): void
}>()

const toggle = () => {
  emit('update:rawMode', !props.rawMode)
}
</script>

<style lang="scss" scoped>
.raw-toggle-pill {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 20rpx;
  border-radius: 999rpx;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}

.raw-toggle-pill .ph {
  font-size: 26rpx;
  color: #fff;
}

.raw-toggle-pill .pill-text {
  font-size: 24rpx;
  color: #fff;
  font-weight: 500;
}

.raw-toggle-pill.active {
  background: rgba(255, 204, 0, 0.9);
}

.raw-toggle-pill.active .ph,
.raw-toggle-pill.active .pill-text {
  color: #181614;
}
</style>
