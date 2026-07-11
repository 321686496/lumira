<template>
  <view class="composition-overlay" :style="{ opacity: overlayOpacity }">
    <!-- 三分法 -->
    <view v-if="overlayType === 'rule_of_thirds'" class="grid-thirds">
      <view class="line-v" v-for="i in 2" :key="'v' + i" :style="{ left: i * 33.333 + '%' }" />
      <view class="line-h" v-for="i in 2" :key="'h' + i" :style="{ top: i * 33.333 + '%' }" />
    </view>

    <!-- 黄金比例 -->
    <view v-else-if="overlayType === 'golden_ratio'" class="grid-golden">
      <view class="line-v" style="left: 38.2%" />
      <view class="line-v" style="left: 61.8%" />
      <view class="line-h" style="top: 38.2%" />
      <view class="line-h" style="top: 61.8%" />
    </view>

    <!-- 对角线 -->
    <view v-else-if="overlayType === 'diagonal'" class="grid-diagonal">
      <view class="line-diag from-tl" />
      <view class="line-diag from-tr" />
    </view>

    <!-- 网格 -->
    <view v-else-if="overlayType === 'grid'" :class="'grid-' + gridType">
      <template v-if="gridType === 'thirds'">
        <view class="line-v" v-for="i in 2" :key="'v' + i" :style="{ left: i * 33.333 + '%' }" />
        <view class="line-h" v-for="i in 2" :key="'h' + i" :style="{ top: i * 33.333 + '%' }" />
      </template>
      <template v-else-if="gridType === 'quarters'">
        <view class="line-v" v-for="i in 3" :key="'v' + i" :style="{ left: i * 25 + '%' }" />
        <view class="line-h" v-for="i in 3" :key="'h' + i" :style="{ top: i * 25 + '%' }" />
      </template>
      <template v-else-if="gridType === 'golden_spiral'">
        <view class="line-v" style="left: 38.2%" />
        <view class="line-v" style="left: 61.8%" />
        <view class="line-h" style="top: 38.2%" />
        <view class="line-h" style="top: 61.8%" />
        <view class="line-diag from-tl" />
      </template>
    </view>

    <!-- 引导线 -->
    <view v-else-if="overlayType === 'leading_lines'" class="leading-lines">
      <view class="line-diag from-bl" />
      <view class="line-diag from-br" />
    </view>

    <!-- 中心十字 -->
    <view v-else-if="overlayType === 'center'" class="grid-center">
      <view class="line-v" style="left: 50%" />
      <view class="line-h" style="top: 50%" />
    </view>

    <!-- 主体建议框 -->
    <view
      v-if="overlayType !== 'none'"
      class="subject-frame"
      :style="{
        left: subjectFrame.x * 100 + '%',
        top: subjectFrame.y * 100 + '%',
        width: subjectFrame.w * 100 + '%',
        height: subjectFrame.h * 100 + '%'
      }"
    />
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Composition } from '@/types/template'

const props = defineProps<{
  composition: Composition
  /** 外部覆盖透明度（如面板展开时降低） */
  overlayOpacityOverride?: number
}>()

const overlayType = computed(() => props.composition.overlayType)
const gridType = computed(() => props.composition.gridType || 'thirds')
const subjectFrame = computed(() => props.composition.subjectFrame)
const overlayOpacity = computed(() => props.overlayOpacityOverride ?? props.composition.opacity)
</script>

<style lang="scss" scoped>
.composition-overlay {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 2;
  transition: opacity 0.3s ease;
}

.line-v,
.line-h,
.line-diag {
  position: absolute;
  background: rgba(255, 255, 255, 0.6);
}

.line-v {
  top: 0;
  bottom: 0;
  width: 1rpx;
}

.line-h {
  left: 0;
  right: 0;
  height: 1rpx;
}

.line-diag {
  width: 1rpx;
  height: 141.4%;
  transform-origin: top left;
}

.from-tl {
  top: 0;
  left: 0;
  transform: rotate(45deg);
}

.from-tr {
  top: 0;
  right: 0;
  transform: rotate(-45deg) translateX(100%);
  transform-origin: top right;
}

.from-bl {
  bottom: 0;
  left: 0;
  transform: rotate(-45deg);
  transform-origin: bottom left;
  height: 141.4%;
}

.from-br {
  bottom: 0;
  right: 0;
  transform: rotate(45deg) translateX(-100%);
  transform-origin: bottom right;
  height: 141.4%;
}

.subject-frame {
  position: absolute;
  border: 2rpx dashed rgba(201, 169, 110, 0.8);
  border-radius: 8rpx;
  box-shadow: 0 0 0 1rpx rgba(0, 0, 0, 0.2);
}
</style>
