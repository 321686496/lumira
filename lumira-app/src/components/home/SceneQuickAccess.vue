<script setup lang="ts">
import type { SceneDef } from '@/data/scenes'

interface SceneQuickAccessProps {
  scenes: SceneDef[]
}

defineProps<SceneQuickAccessProps>()

const emit = defineEmits<{
  (e: 'on-scene-click', sceneKey: string): void
}>()
</script>

<template>
  <view class="scene-quick-access">
    <text class="section-title">拍摄场景</text>
    <view class="scenes-grid">
      <view
        v-for="scene in scenes"
        :key="scene.key"
        class="scene-pill"
        @click="emit('on-scene-click', scene.key)"
      >
        <text class="scene-emoji">{{ scene.emoji }}</text>
        <text class="scene-label">{{ scene.label }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.scene-quick-access {
  padding: 0 var(--space-5);
  margin-bottom: var(--space-7);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
  margin-bottom: var(--space-3);
  display: block;
}

.scenes-grid {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}

.scene-pill {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  padding: var(--space-2) var(--space-3);
  background: var(--color-tag-gold-bg);
  border-radius: var(--radius-pill);
  transition: transform var(--duration-fast) ease;

  &:active { transform: scale(0.96); }
}

.scene-emoji {
  font-size: var(--font-size-body);
  line-height: 1;
}

.scene-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-tag-gold-text);
}
</style>
