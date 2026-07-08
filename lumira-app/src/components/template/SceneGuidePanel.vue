<script setup lang="ts">
import type { SceneGuide } from '@/types/template'

interface SceneGuidePanelProps {
  guide: SceneGuide
}

defineProps<SceneGuidePanelProps>()
</script>

<template>
  <view class="scene-guide-panel">
    <text class="panel-title">场景指南</text>
    <view class="guide-items">
      <view v-if="guide.lightingTip" class="guide-item">
        <text class="guide-icon">💡</text>
        <text class="guide-label">光线：{{ guide.lightingTip }}</text>
      </view>
      <view v-if="guide.shootingDistance" class="guide-item">
        <text class="guide-icon">📏</text>
        <text class="guide-label">距离：{{ guide.shootingDistance }}</text>
      </view>
      <view v-if="guide.props && guide.props.length > 0" class="guide-item">
        <text class="guide-icon">🎩</text>
        <text class="guide-label">道具：{{ guide.props.join('、') }}</text>
      </view>
      <view v-if="guide.tips" class="guide-item">
        <text class="guide-icon">📝</text>
        <text class="guide-label">{{ guide.tips }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.scene-guide-panel {
  margin-bottom: var(--space-5);
}

.panel-title {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--space-3);
}

.guide-items {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.guide-item {
  display: flex;
  align-items: flex-start;
  gap: var(--space-2);
}

.guide-icon {
  font-size: var(--font-size-body);
  line-height: 1.6;
  flex-shrink: 0;
}

.guide-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
  line-height: var(--line-height-body);
}
</style>
