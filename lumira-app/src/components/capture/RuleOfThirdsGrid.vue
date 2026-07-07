<script setup lang="ts">
</script>

<template>
  <view class="rule-of-thirds">
    <view class="grid-line grid-line-h" style="top: 33.33%"></view>
    <view class="grid-line grid-line-h" style="top: 66.66%"></view>
    <view class="grid-line grid-line-v" style="left: 33.33%"></view>
    <view class="grid-line grid-line-v" style="left: 66.66%"></view>
  </view>
</template>

<style lang="scss" scoped>
.rule-of-thirds {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.grid-line {
  position: absolute;
  background: var(--color-capture-overlay-line);
}

.grid-line-h {
  left: 0;
  right: 0;
  height: 1px;
}

.grid-line-v {
  top: 0;
  bottom: 0;
  width: 1px;
}
</style>
