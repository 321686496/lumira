<script setup lang="ts">
import type { CropRect } from '@/types/photo'

interface CropFrameProps {
  rect: CropRect
}

defineProps<CropFrameProps>()

const emit = defineEmits<{
  (e: 'on-change', rect: CropRect): void
}>()
</script>

<template>
  <view class="crop-frame">
    <view class="crop-area" :style="{
      left: `${rect.x * 100}%`,
      top: `${rect.y * 100}%`,
      width: `${rect.w * 100}%`,
      height: `${rect.h * 100}%`,
    }">
      <view class="crop-corner crop-tl"></view>
      <view class="crop-corner crop-tr"></view>
      <view class="crop-corner crop-bl"></view>
      <view class="crop-corner crop-br"></view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.crop-frame {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  background: rgba(0, 0, 0, 0.5);
}

.crop-area {
  position: absolute;
  border: 2px solid var(--color-brand-primary);
  background: transparent;
}

.crop-corner {
  position: absolute;
  width: 16px;
  height: 16px;
  border-color: #FFFFFF;
  border-style: solid;
}

.crop-tl { top: -2px; left: -2px; border-width: 3px 0 0 3px; }
.crop-tr { top: -2px; right: -2px; border-width: 3px 3px 0 0; }
.crop-bl { bottom: -2px; left: -2px; border-width: 0 0 3px 3px; }
.crop-br { bottom: -2px; right: -2px; border-width: 0 3px 3px 0; }
</style>
