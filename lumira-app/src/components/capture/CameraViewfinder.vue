<script setup lang="ts">
import type { OverlayLayer as OverlayLayerType } from '@/types/overlay'
import OverlayLayer from './OverlayLayer.vue'

interface CameraViewfinderProps {
  overlay: OverlayLayerType | null
}

defineProps<CameraViewfinderProps>()
</script>

<template>
  <view class="camera-viewfinder">
    <view class="viewfinder-frame">
      <view class="camera-placeholder">
        <text class="placeholder-icon">◐</text>
        <text class="placeholder-text">取景框</text>
        <text class="placeholder-hint">将主体对准框内</text>
      </view>
      <OverlayLayer :layer="overlay" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.camera-viewfinder {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 100px var(--space-4) 180px;
}

.viewfinder-frame {
  position: relative;
  width: 100%;
  max-width: 320px;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: #2A2A2A;
  overflow: hidden;
  border: 1px solid rgba(201, 169, 110, 0.2);
}

.camera-placeholder {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
}

.placeholder-icon {
  font-size: 36px;
  color: rgba(201, 169, 110, 0.3);
}

.placeholder-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: rgba(255, 255, 255, 0.4);
}

.placeholder-hint {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.25);
}
</style>
