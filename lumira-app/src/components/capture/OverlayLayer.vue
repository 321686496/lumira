<script setup lang="ts">
import type { OverlayLayer as OverlayLayerType } from '@/types/overlay'
import RuleOfThirdsGrid from './RuleOfThirdsGrid.vue'
import GuideLines from './GuideLines.vue'
import PoseOverlay from './PoseOverlay.vue'

interface OverlayLayerProps {
  layer: OverlayLayerType | null
}

defineProps<OverlayLayerProps>()
</script>

<template>
  <view v-if="layer && layer.visible" class="overlay-layer">
    <RuleOfThirdsGrid v-if="layer.composition?.type === 'rule_of_thirds'" />
    <GuideLines v-if="layer.composition?.lines?.length" :lines="layer.composition.lines" />
    <PoseOverlay v-if="layer.pose" :pose="layer.pose" />
  </view>
</template>

<style lang="scss" scoped>
.overlay-layer {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
  z-index: 100;
  transition: opacity var(--duration-normal) ease;
}
</style>
