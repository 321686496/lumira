<template>
  <view class="kit-card">
    <view class="kit-icons">
      <text class="kit-icon">{{ sceneIcon }}</text>
      <text class="kit-link">+</text>
      <text class="kit-icon">{{ templateIcon }}</text>
    </view>
    <text class="kit-name">{{ kit.name }}</text>
    <text class="kit-meta">{{ sceneName }} · {{ templateName }}</text>
    <text class="kit-count" v-if="kit.useCount > 0">使用 {{ kit.useCount }} 次</text>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { ShootKit, AnyScene, PhotoTemplate } from '@/types/template'

const props = defineProps<{
  kit: ShootKit
  scene?: AnyScene
  template?: PhotoTemplate
}>()

const sceneIcon = computed(() => props.scene?.icon || '📍')

const templateIcon = computed(() => (props.template ? '📓' : '📸'))

const sceneName = computed(() => props.scene?.name || '?')

const templateName = computed(() => props.template?.meta.name || '?')
</script>

<style lang="scss" scoped>
.kit-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  padding: 20rpx;
  background: rgba(0, 0, 0, 0.04);
  border-radius: 20rpx;
  min-width: 180rpx;
}

.kit-icons {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.kit-icon {
  font-size: 36rpx;
  line-height: 1;
}

.kit-link {
  font-size: 24rpx;
  color: #6B635A;
}

.kit-name {
  font-size: 24rpx;
  font-weight: 600;
  color: #2A2520;
  text-align: center;
}

.kit-meta {
  font-size: 20rpx;
  color: #6B635A;
  text-align: center;
}

.kit-count {
  font-size: 20rpx;
  color: #C9A876;
}
</style>
