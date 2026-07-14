<template>
  <view v-if="visible" class="filter-picker-mask" @click.stop="close">
    <view class="filter-picker" @click.stop>
      <view class="picker-header">
        <text class="picker-title">滤镜</text>
        <view class="picker-close" @click="close">
          <text class="ph ph-x" />
        </view>
      </view>

      <scroll-view scroll-y class="picker-body">
        <!-- 系统滤镜区 -->
        <view class="filter-group">
          <text class="group-title">系统滤镜</text>
          <scroll-view scroll-x class="filter-list">
            <view class="filter-list-inner">
              <view
                v-for="f in systemFilterOptions"
                :key="f.id"
                class="filter-item"
                :class="{ active: currentSystemFilter === f.id }"
                @click="selectSystemFilter(f.id)"
              >
                <view class="filter-thumb" :style="thumbStyle(f.filter)">
                  <image
                    class="thumb-img"
                    src="https://picsum.photos/seed/filter-thumb/120/120"
                    mode="aspectFill"
                  />
                </view>
                <text class="filter-name">{{ f.name }}</text>
              </view>
            </view>
          </scroll-view>
        </view>

        <!-- LUT 预设区 -->
        <view class="filter-group">
          <text class="group-title">LUT 预设</text>
          <scroll-view scroll-x class="filter-list">
            <view class="filter-list-inner">
              <view
                v-for="f in lutOptions"
                :key="f.id"
                class="filter-item"
                :class="{ active: currentLut === f.id }"
                @click="selectLut(f.id)"
              >
                <view class="filter-thumb" :style="thumbStyle(f.filter)">
                  <image
                    class="thumb-img"
                    src="https://picsum.photos/seed/lut-thumb/120/120"
                    mode="aspectFill"
                  />
                </view>
                <text class="filter-name">{{ f.name }}</text>
              </view>
            </view>
          </scroll-view>
        </view>
      </scroll-view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import {
  getSystemFilterOptions,
  getLutOptions
} from '@/utils/filterRecipe'
import type { SystemFilter, LutPreset } from '@/types/template'

const props = defineProps<{
  visible: boolean
  currentSystemFilter: SystemFilter
  currentLut: LutPreset
  disabled: boolean
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'select-system-filter', value: SystemFilter): void
  (e: 'select-lut', value: LutPreset): void
}>()

const systemFilterOptions = computed(() => getSystemFilterOptions())
const lutOptions = computed(() => getLutOptions())

const close = () => {
  emit('update:visible', false)
}

const selectSystemFilter = (id: SystemFilter) => {
  if (props.disabled) {
    uni.showToast({ title: '已切换至原相机模式，请先退出', icon: 'none' })
    return
  }
  emit('select-system-filter', id)
}

const selectLut = (id: LutPreset) => {
  if (props.disabled) {
    uni.showToast({ title: '已切换至原相机模式，请先退出', icon: 'none' })
    return
  }
  emit('select-lut', id)
}

const thumbStyle = (filter: string) => {
  if (!filter) return {}
  return { filter, webkitFilter: filter }
}
</script>

<style lang="scss" scoped>
.filter-picker-mask {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 200;
  display: flex;
  align-items: flex-end;
}

.filter-picker {
  width: 100%;
  max-height: 70vh;
  background: #1a1816;
  border-radius: 32rpx 32rpx 0 0;
  display: flex;
  flex-direction: column;
}

.picker-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28rpx 32rpx 16rpx;
  border-bottom: 1rpx solid rgba(255, 255, 255, 0.08);
}

.picker-title {
  font-size: 32rpx;
  color: #fff;
  font-weight: 600;
}

.picker-close .ph {
  font-size: 36rpx;
  color: rgba(255, 255, 255, 0.7);
}

.picker-body {
  padding: 16rpx 0 32rpx;
}

.filter-group {
  margin-top: 16rpx;
}

.group-title {
  display: block;
  padding: 0 32rpx 16rpx;
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.6);
  font-weight: 500;
}

.filter-list {
  white-space: nowrap;
}

.filter-list-inner {
  display: inline-flex;
  gap: 16rpx;
  padding: 0 32rpx;
}

.filter-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
  width: 120rpx;
}

.filter-thumb {
  width: 120rpx;
  height: 120rpx;
  border-radius: 16rpx;
  overflow: hidden;
  border: 3rpx solid transparent;
}

.filter-item.active .filter-thumb {
  border-color: #ffcc00;
}

.thumb-img {
  width: 100%;
  height: 100%;
}

.filter-name {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.85);
}

.filter-item.active .filter-name {
  color: #ffcc00;
  font-weight: 600;
}
</style>
