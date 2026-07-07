<script setup lang="ts">
import { ref } from 'vue'
import type { CompositionOverlay, PoseReference } from '@/types/template'

interface OverlayPreviewProps {
  composition?: CompositionOverlay
  pose?: PoseReference
}

const props = defineProps<OverlayPreviewProps>()

const showOverlay = ref(true)

const toggleOverlay = () => {
  showOverlay.value = !showOverlay.value
}
</script>

<template>
  <view class="overlay-preview">
    <view class="preview-frame">
      <!-- 叠图内容区 -->
      <view v-if="showOverlay" class="overlay-layer">
        <view v-if="composition?.ruleOfThirds" class="thirds-grid">
          <view class="grid-line grid-line-h" style="top: 33.33%"></view>
          <view class="grid-line grid-line-h" style="top: 66.66%"></view>
          <view class="grid-line grid-line-v" style="left: 33.33%"></view>
          <view class="grid-line grid-line-v" style="left: 66.66%"></view>
        </view>
      </view>
      <view class="preview-placeholder">
        <text class="preview-text">叠图预览</text>
      </view>
    </view>
    <view class="toggle-btn" @click="toggleOverlay">
      <text class="toggle-text">{{ showOverlay ? '隐藏叠图' : '显示叠图' }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.overlay-preview {
  margin-bottom: var(--space-5);
}

.preview-frame {
  position: relative;
  width: 100%;
  aspect-ratio: 4 / 3;
  background: var(--color-bg-surface);
  border-radius: var(--radius-card);
  overflow: hidden;
  border: 1px solid var(--color-border);
}

.overlay-layer {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
  z-index: 1;
}

.thirds-grid {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
}

.grid-line {
  position: absolute;
  background: var(--color-brand-primary);
  opacity: 0.35;
}

.grid-line-h {
  left: 0;
  right: 0;
  height: 1px;
}

.grid-line-v {
  top: 0;
  bottom: 0;
  width: 1px;
}

.preview-placeholder {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}

.preview-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.toggle-btn {
  margin-top: var(--space-2);
  display: inline-flex;
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-button);
  &:active { opacity: 0.7; }
}

.toggle-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-secondary);
}
</style>
