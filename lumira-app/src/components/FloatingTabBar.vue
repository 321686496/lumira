<template>
  <view class="floating-tabbar">
    <view class="tabbar-item" :class="{ active: active === 'home' }" @click="goTab('/pages/home/index')">
      <text class="ph ph-house"></text>
      <text class="tabbar-label">首页</text>
    </view>
    <view class="tabbar-item" :class="{ active: active === 'templates' }" @click="goTab('/pages/templates/index')">
      <text class="ph ph-squares-four"></text>
      <text class="tabbar-label">模板</text>
    </view>
    <view class="tabbar-center" @click="goCapture">
      <text class="ph ph-camera"></text>
    </view>
    <view class="tabbar-item" :class="{ active: active === 'challenge' }" @click="goTab('/pages/challenge/index')">
      <text class="ph ph-target"></text>
      <text class="tabbar-label">挑战</text>
    </view>
    <view class="tabbar-item" :class="{ active: active === 'profile' }" @click="goTab('/pages/profile/index')">
      <text class="ph ph-user"></text>
      <text class="tabbar-label">我的</text>
    </view>
  </view>
</template>

<script setup lang="ts">
defineProps<{
  active: string
}>()

const goTab = (url: string) => {
  uni.reLaunch({ url })
}

const goCapture = () => {
  uni.navigateTo({ url: '/pages/capture/index' })
}
</script>

<style scoped>
.tabbar-item .ph {
  font-size: 44rpx;
  line-height: 1;
}

.tabbar-center .ph {
  font-size: 48rpx;
  line-height: 1;
}
</style>
