<template>
  <view class="lumira-container no-tabbar">
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">摄影美学院</text>
      <view class="lumira-nav-right"></view>
    </view>
    <view class="empty-state">
      <text class="ph ph-graduation-cap empty-icon"></text>
      <text class="empty-text">摄影美学院即将上线</text>
    </view>
  </view>
</template>

<script setup lang="ts">
const back = () => uni.navigateBack()
</script>

<style scoped>
.back-icon { font-size: 40rpx; color: #1A1A1A; }
.empty-state { display: flex; flex-direction: column; align-items: center; padding: 300rpx 0; }
.empty-icon { font-size: 96rpx; color: #E5E0D8; margin-bottom: 24rpx; }
.empty-text { font-family: 'Noto Serif SC', serif; font-size: 28rpx; color: #9C9690; }
</style>
