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

// 仅返回 transform 和 color，不返回定位（定位由外部容器控制）
const wrapperStyle = computed(() => {
  const { scale, rotation } = props.pose
  return {
    transform: `scale(${scale}) rotate(${rotation}deg)`,
    color: 'rgba(255, 255, 255, 0.9)'
  }
})
</script>

<style lang="scss" scoped>
.pose-silhouette-wrap {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

/* 显式声明容器尺寸，打破 SVG width:100% 的循环依赖 */
.pose-svg-builtin,
.pose-svg-inline {
  width: 100%;
  height: 100%;
  display: block;
}

:deep(svg) {
  width: 100%;
  height: 100%;
  display: block;
}

.pose-image {
  width: 100%;
  height: 100%;
}
</style>
