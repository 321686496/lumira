<script setup lang="ts">
import { onReady } from '@dcloudio/uni-app'

const MIN_DISPLAY = 1500
const MAX_DISPLAY = 3000

onReady(() => {
  const startTime = Date.now()
  const timer = setTimeout(() => {
    const elapsed = Date.now() - startTime
    const remaining = Math.max(0, MIN_DISPLAY - elapsed)
    setTimeout(() => {
      uni.reLaunch({ url: '/pages/home/index' })
    }, remaining)
  }, 0)

  // 安全兜底：最长不超过 MAX_DISPLAY
  setTimeout(() => {
    clearTimeout(timer)
    uni.reLaunch({ url: '/pages/home/index' })
  }, MAX_DISPLAY)
})
</script>

<template>
  <view class="splash-page">
    <view class="splash-content">
      <!-- LOGO 符号标：取景框 + 斜光 -->
      <view class="logo-symbol">
        <!-- 四角 L 形取景标记 -->
        <view class="corner corner-tl"></view>
        <view class="corner corner-tr"></view>
        <view class="corner corner-bl"></view>
        <view class="corner corner-br"></view>
        <!-- 斜光带 -->
        <view class="light-beam"></view>
        <!-- 焦点光点 -->
        <view class="focus-dot"></view>
      </view>
    </view>
    <view class="splash-bottom">
      <text class="brand-name">如画 Lumira</text>
      <text class="brand-tagline">如你所见，皆成画卷</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.splash-page {
  width: 100vw;
  height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.splash-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn var(--duration-slow) var(--ease-default) both;
}

.logo-symbol {
  position: relative;
  width: 80px;
  height: 80px;
}

/* 四角 L 形取景标记 */
.corner {
  position: absolute;
  width: 18px;
  height: 18px;
  border-color: var(--color-brand-primary);
  border-style: solid;
  border-width: 0;
}

.corner-tl {
  top: 0;
  left: 0;
  border-top-width: 2.5px;
  border-left-width: 2.5px;
}

.corner-tr {
  top: 0;
  right: 0;
  border-top-width: 2.5px;
  border-right-width: 2.5px;
}

.corner-bl {
  bottom: 0;
  left: 0;
  border-bottom-width: 2.5px;
  border-left-width: 2.5px;
}

.corner-br {
  bottom: 0;
  right: 0;
  border-bottom-width: 2.5px;
  border-right-width: 2.5px;
}

/* 斜光带：从左上到右下 */
.light-beam {
  position: absolute;
  top: -5%;
  left: -5%;
  width: 141%;
  height: 12%;
  background: linear-gradient(
    135deg,
    var(--color-brand-primary) 0%,
    transparent 100%
  );
  opacity: 0.5;
  transform: rotate(-45deg);
  transform-origin: center;
}

/* 焦点光点 */
.focus-dot {
  position: absolute;
  bottom: 18%;
  right: 18%;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--color-brand-primary);
}

.splash-bottom {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  padding-bottom: calc(var(--space-8) + env(safe-area-inset-bottom));
  animation: fadeIn var(--duration-slow) var(--ease-default) 200ms both;
}

.brand-name {
  font-family: var(--font-serif);
  font-size: var(--font-size-title);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-title);
  line-height: var(--line-height-title);
}

.brand-tagline {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  line-height: var(--line-height-caption);
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
</style>
