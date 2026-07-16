<template>
  <view class="scene-preset-view" :class="'size-' + size" @click="onClick">
    <view class="spv-icon-wrap" :class="{ 'spv-icon-custom': isCustom }">
      <text class="ph spv-icon" :class="scene.icon"></text>
    </view>
    <view class="spv-text">
      <view class="spv-title-row">
        <text class="spv-name">{{ scene.name }}</text>
        <view v-if="isCustom" class="spv-custom-tag">
          <text class="spv-custom-tag-text">自定义</text>
        </view>
      </view>
      <text v-if="size === 'full' && scene.description" class="spv-desc">{{ scene.description }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useSceneManager } from '@/composables/useSceneManager'
import type { AnyScene } from '@/types/template'

const props = withDefaults(defineProps<{
  scene: AnyScene
  size?: 'full' | 'mini'
}>(), {
  size: 'full'
})

const emit = defineEmits<{
  click: [id: string]
}>()

const { isCustomScene } = useSceneManager()

const isCustom = computed(() => isCustomScene(props.scene))

const onClick = () => {
  emit('click', props.scene.id)
}
</script>

<style lang="scss" scoped>
.scene-preset-view {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx;
  border-radius: 24rpx;
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-divider);
}

.scene-preset-view:active {
  opacity: 0.7;
}

.size-mini {
  padding: 20rpx 24rpx;
  gap: 16rpx;
}

.spv-icon-wrap {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background-color: var(--color-surface-alt);
}

.size-mini .spv-icon-wrap {
  width: 64rpx;
  height: 64rpx;
  border-radius: 16rpx;
}

.spv-icon-custom {
  background-color: var(--color-brand-subtle);
}

.spv-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.spv-icon-custom .spv-icon {
  color: var(--color-brand);
}

.spv-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.spv-title-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.spv-name {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.size-mini .spv-name {
  font-size: 28rpx;
}

.spv-custom-tag {
  padding: 4rpx 16rpx;
  border-radius: 9999rpx;
  background-color: var(--color-brand-subtle);
}

.spv-custom-tag-text {
  font-size: 20rpx;
  font-weight: 600;
  color: var(--color-brand);
}

.spv-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  line-height: 1.4;
}
</style>
