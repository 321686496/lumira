<script setup lang="ts">
import type { PoseOverlayData } from '@/types/overlay'

interface PoseOverlayProps {
  pose: PoseOverlayData | null
}

defineProps<PoseOverlayProps>()
</script>

<template>
  <view v-if="pose" class="pose-overlay" :style="{
    left: `${pose.position.x * 100}%`,
    top: `${pose.position.y * 100}%`,
    transform: `scale(${pose.scale}) rotate(${pose.rotation}deg)`,
  }">
    <image :src="pose.imageUrl" mode="aspectFit" class="pose-image" />
  </view>
</template>

<style lang="scss" scoped>
.pose-overlay {
  position: absolute;
  width: 60%;
  height: 60%;
  transform-origin: center;
  pointer-events: none;
  opacity: 0.4;
}

.pose-image {
  width: 100%;
  height: 100%;
}
</style>
