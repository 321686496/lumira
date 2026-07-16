<template>
  <view class="category-nav">
    <template v-for="(layer, idx) in layers" :key="idx">
      <view v-if="shouldShowLayer(idx)" class="category-layer">
        <text v-if="layer.label" class="layer-label">{{ layer.label }}</text>
        <scroll-view scroll-x class="category-scroll" :show-scrollbar="false">
          <view class="category-inner">
            <view
              class="category-pill"
              :class="{ 'category-pill-active': layer.selected === null }"
              @click="onSelect(idx, null)"
            >
              <text class="category-pill-text">全部</text>
            </view>
            <view
              v-for="opt in layer.options"
              :key="opt.value"
              class="category-pill"
              :class="{ 'category-pill-active': layer.selected === opt.value }"
              @click="onSelect(idx, opt.value)"
            >
              <text class="category-pill-text">{{ opt.label }}</text>
            </view>
          </view>
        </scroll-view>
      </view>
    </template>
  </view>
</template>

<script setup lang="ts">
interface CategoryOption {
  value: string
  label: string
}
interface CategoryLayer {
  label: string
  options: CategoryOption[]
  selected: string | null
}

const props = defineProps<{
  layers: CategoryLayer[]
}>()

const emit = defineEmits<{
  select: [layerIndex: number, value: string | null]
}>()

function shouldShowLayer(idx: number): boolean {
  if (idx === 0) return true
  // 前一层有选中时才显示下一层
  return props.layers[idx - 1].selected !== null
}

function onSelect(idx: number, value: string | null) {
  emit('select', idx, value)
}
</script>

<style lang="scss" scoped>
.category-nav {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.category-layer {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.layer-label {
  font-size: 22rpx;
  color: #6B635A;
  padding-left: 24rpx;
}

.category-scroll {
  white-space: nowrap;
}

.category-inner {
  display: inline-flex;
  align-items: center;
  gap: 16rpx;
  padding: 0 24rpx;
}

.category-pill {
  display: inline-flex;
  align-items: center;
  padding: 12rpx 24rpx;
  border-radius: 32rpx;
  background: rgba(0, 0, 0, 0.05);
  flex-shrink: 0;
}

.category-pill-active {
  background: #2A2520;
}

.category-pill-text {
  font-size: 24rpx;
  color: #2A2520;
  line-height: 1.2;
}

.category-pill-active .category-pill-text {
  color: #FFFFFF;
}
</style>
