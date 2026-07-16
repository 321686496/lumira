<template>
  <!-- list 变体：横向布局（图标左 + 文字右 + actions 插槽 + 箭头） -->
  <view
    v-if="variant === 'list'"
    class="scene-preset-view spv-list"
    :class="'size-' + size"
    @click="onClick"
  >
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
    <view v-if="$slots.actions" class="spv-actions">
      <slot name="actions" />
    </view>
    <text class="ph ph-caret-right spv-arrow"></text>
  </view>

  <!-- card 变体：竖向卡片（图片 + 标签 + 文字区） -->
  <view
    v-else
    class="scene-preset-view spv-card lumira-card-hover"
    @click="onClick"
  >
    <view class="spv-card-img-wrap">
      <image class="spv-card-img" :src="resolvedImageSrc" mode="aspectFill" />
      <view v-if="badgeText" class="spv-card-badge" :class="{ 'spv-card-badge-brand': badgeBrand }">
        <text v-if="badgeIcon" class="ph spv-card-badge-icon" :class="badgeIcon"></text>
        <text class="spv-card-badge-text">{{ badgeText }}</text>
      </view>
    </view>
    <view class="spv-card-body">
      <view class="spv-title-row">
        <text class="spv-card-name">{{ scene.name }}</text>
        <view v-if="isCustom" class="spv-custom-tag">
          <text class="spv-custom-tag-text">自定义</text>
        </view>
      </view>
      <text v-if="scene.vibe" class="spv-card-vibe">{{ scene.vibe }}</text>
      <text v-if="scene.description" class="spv-card-desc">{{ scene.description }}</text>
      <view v-if="hasStats" class="spv-card-stats">
        <text v-if="photoCount !== undefined" class="spv-stat-item">📷 {{ photoCount }}</text>
        <text v-if="achievementLevel && achievementLevel > 0" class="spv-stat-item">🏆 Lv.{{ achievementLevel }}</text>
      </view>
      <slot name="footer" />
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
  variant?: 'list' | 'card'
  imageSrc?: string
  badgeText?: string
  badgeIcon?: string
  badgeBrand?: boolean
  photoCount?: number
  achievementLevel?: number
}>(), {
  size: 'full',
  variant: 'list',
  badgeBrand: false
})

const emit = defineEmits<{
  click: [id: string]
}>()

const { isCustomScene } = useSceneManager()

const isCustom = computed(() => isCustomScene(props.scene))

/** 图片源：优先使用传入的 imageSrc，否则回退到场景示例图首张 */
const resolvedImageSrc = computed(() => {
  if (props.imageSrc) return props.imageSrc
  const examples = props.scene.exampleImages
  if (examples && examples.length > 0) return examples[0]
  return ''
})

const hasStats = computed(() => {
  return (props.photoCount !== undefined) || (props.achievementLevel !== undefined && props.achievementLevel > 0)
})

const onClick = () => {
  emit('click', props.scene.id)
}
</script>

<style lang="scss" scoped>
/* ===== list 变体 ===== */
.spv-list {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx;
  border-radius: 24rpx;
  background-color: var(--color-surface);
  border: 2rpx solid var(--color-divider);
}

.spv-list:active {
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

.spv-actions {
  flex-shrink: 0;
  display: flex;
  align-items: center;
}

.spv-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

/* ===== card 变体 ===== */
.spv-card {
  display: flex;
  flex-direction: column;
  border-radius: 28rpx;
  overflow: hidden;
  border: 2rpx solid var(--color-divider);
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex);
}

.spv-card:active {
  opacity: 0.85;
}

.spv-card-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 133.33%;
  overflow: hidden;
  border-radius: 24rpx;
}

.spv-card-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.spv-card-badge {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  background-color: rgba(26, 26, 26, 0.6);
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
  display: flex;
  align-items: center;
  gap: 6rpx;
}

.spv-card-badge-brand {
  background-color: var(--color-brand);
}

.spv-card-badge-icon {
  font-size: 22rpx;
  color: #fff;
}

.spv-card-badge-text {
  font-size: 20rpx;
  font-weight: 500;
  color: #fff;
  letter-spacing: 0.04em;
}

.spv-card-body {
  padding: 24rpx 28rpx 28rpx;
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.spv-card-name {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.spv-card-desc {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

.spv-card-vibe {
  display: block;
  font-size: 24rpx;
  color: #C9A876;
  font-style: italic;
  line-height: 1.4;
}

.spv-card-stats {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-top: 4rpx;
  flex-wrap: wrap;
}

.spv-stat-item {
  font-size: 22rpx;
  color: #6B635A;
  line-height: 1.2;
}
</style>
