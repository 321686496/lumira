<template>
  <view class="filter-badge">
    <text class="filter-icon">🎞</text>
    <view class="filter-info">
      <view class="filter-name-row">
        <text class="filter-name">{{ lutName }}</text>
        <text v-if="systemFilterLabel" class="filter-systemFilter">{{ systemFilterLabel }}</text>
      </view>
      <text class="filter-reason">{{ filter.reason }}</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { SceneFilter } from '@/types/template'
import { getLutLabel, getSystemFilterLabel } from '@/utils/filterRecipe'

const props = defineProps<{ filter: SceneFilter }>()

const lutName = computed(() => getLutLabel(props.filter.lut))

const systemFilterLabel = computed(() => {
  if (!props.filter.systemFilter || props.filter.systemFilter === 'none') return ''
  return getSystemFilterLabel(props.filter.systemFilter)
})
</script>

<style lang="scss" scoped>
.filter-badge {
  display: flex;
  align-items: flex-start;
  gap: 16rpx;
  padding: 24rpx;
  background: rgba(0, 0, 0, 0.04);
  border-radius: 20rpx;
}

.filter-icon {
  font-size: 40rpx;
  line-height: 1;
}

.filter-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8rpx;
  min-width: 0;
}

.filter-name-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
  flex-wrap: wrap;
}

.filter-name {
  font-size: 28rpx;
  font-weight: 600;
  color: #2A2520;
}

.filter-systemFilter {
  font-size: 22rpx;
  color: #C9A876;
  padding: 2rpx 12rpx;
  border-radius: 9999rpx;
  background: rgba(201, 168, 118, 0.12);
}

.filter-reason {
  font-size: 24rpx;
  color: #6B635A;
  line-height: 1.5;
}
</style>
