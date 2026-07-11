<template>
  <view class="pose-silhouette-wrap" :style="wrapperStyle">
    <!-- builtin 类型：从内置库查找 SVG -->
    <view
      v-if="silhouette.type === 'builtin' && svgContent"
      class="pose-svg-builtin"
      v-html="svgContent"
    />

    <!-- image 类型：base64 图片 -->
    <image
      v-else-if="silhouette.type === 'image'"
      :src="silhouette.data"
      class="pose-image"
      mode="aspectFit"
    />

    <!-- svg 类型：内联 SVG 字符串 -->
    <view
      v-else-if="silhouette.type === 'svg'"
      class="pose-svg-inline"
      v-html="silhouette.data"
    />
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { BUILTIN_SILHOUETTES } from '@/data/silhouettes'
import type { Pose } from '@/types/template'

const props = defineProps<{
  pose: Pose
}>()

const silhouette = computed(() => props.pose.silhouette)

const svgContent = computed(() => {
  if (silhouette.value.type === 'builtin') {
    return BUILTIN_SILHOUETTES[silhouette.value.data] || ''
  }
  return ''
})

const wrapperStyle = computed(() => {
  const { position, scale, rotation } = props.pose
  return {
    left: `${position.x * 100}%`,
    top: `${position.y * 100}%`,
    transform: `translate(-50%, -50%) scale(${scale}) rotate(${rotation}deg)`,
    opacity: 0.55
  }
})
</script>

<style lang="scss" scoped>
.pose-silhouette-wrap {
  position: absolute;
  width: 40%;
  aspect-ratio: 1 / 1.6;
  z-index: 3;
  pointer-events: none;
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

:deep(svg) {
  width: 100%;
  height: 100%;
  fill: rgba(255, 255, 255, 0.7);
}

.pose-image {
  width: 100%;
  height: 100%;
  opacity: 0.7;
}
</style>
