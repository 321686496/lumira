<template>
  <view class="splash-container">
    <view class="splash-logo fade-in">
      <text class="ph ph-aperture logo-icon"></text>
    </view>
    <view class="splash-text fade-up fade-up-d1">
      <text class="splash-title">如画 Lumira</text>
      <text class="splash-caption">如你所见，皆成画卷</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'

const redirect = () => {
  setTimeout(() => {
    uni.reLaunch({ url: '/pages/home/index' })
  }, 1800)
}

onMounted(redirect)
onShow(redirect)
</script>

<style scoped>
.splash-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background-color: #FAF7F2;
}

.splash-logo {
  margin-bottom: 48rpx;
}

.logo-icon {
  font-size: 120rpx;
  color: #C9A96E;
  line-height: 1;
}

.splash-text {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12rpx;
}

.splash-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 48rpx;
  font-weight: 600;
  color: #1A1A1A;
  letter-spacing: -0.01em;
}

.splash-caption {
  font-size: 26rpx;
  color: #9C9690;
  letter-spacing: 0.04em;
}
</style>
