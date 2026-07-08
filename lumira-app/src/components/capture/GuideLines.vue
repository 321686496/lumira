<script setup lang="ts">
import type { OverlayLine } from '@/types/overlay'

interface GuideLinesProps {
  lines: OverlayLine[]
}

defineProps<GuideLinesProps>()
</script>

<template>
  <view class="guide-lines">
    <view
      v-for="(line, idx) in lines"
      :key="idx"
      class="guide-line"
      :style="{
        top: `${line.start.y * 100}%`,
        left: `${line.start.x * 100}%`,
        width: line.type === 'horizontal' ? '100%' : '1px',
        height: line.type === 'vertical' ? '100%' : '1px',
        borderStyle: line.type === 'dashed' ? 'dashed' : 'solid',
      }"
    ></view>
  </view>
</template>

<style lang="scss" scoped>
.guide-lines {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.guide-line {
  position: absolute;
  border-color: var(--color-capture-overlay-line);
  border-width: 0;
  border-top-width: 1px;
  border-left-width: 1px;
}
</style>
