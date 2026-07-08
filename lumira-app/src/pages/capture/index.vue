<script setup lang="ts">
import { computed } from 'vue'
import { onLoad, onShow, onHide } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import CaptureHeader from '@/components/capture/CaptureHeader.vue'
import CameraViewfinder from '@/components/capture/CameraViewfinder.vue'
import ParameterBar from '@/components/capture/ParameterBar.vue'
import ShutterButton from '@/components/ShutterButton.vue'
import { useCaptureStore } from '@/stores/capture'
import type { OverlayLayer } from '@/types/overlay'

const captureStore = useCaptureStore()

const currentTemplateName = computed(() =>
  captureStore.activeTemplateId ? `模板 #${captureStore.activeTemplateId.slice(0, 6)}` : '自由拍摄'
)

const overlay = computed<OverlayLayer | null>(() => ({
  composition: undefined,
  pose: undefined,
  opacity: captureStore.overlaySettings.opacity,
  visible: captureStore.overlaySettings.showComposition || captureStore.overlaySettings.showPose,
}))

onLoad((query) => {
  if (query?.templateId) {
    captureStore.setActiveTemplate(query.templateId)
  }
})

onShow(() => {
  captureStore.setActive(true)
})

onHide(() => {
  captureStore.setActive(false)
})

const onBack = () => {
  uni.navigateBack()
}

const openParameters = () => {
  uni.navigateTo({ url: '/pages/capture/parameters' })
}

const onShutter = () => {
  uni.navigateTo({ url: '/pages/capture/preview?photoId=tmp' })
}

const goToGallery = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const goToTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
</script>

<template>
  <view class="capture-page">
    <CaptureHeader
      :template-name="currentTemplateName"
      @on-back="onBack"
      @on-settings="openParameters"
    />

    <CameraViewfinder :overlay="overlay" />

    <view class="bottom-controls">
      <ParameterBar
        :params="captureStore.cameraParameters"
        :is-level="captureStore.isLevel"
      />

      <view class="shutter-row">
        <view class="shutter-side" @click="goToGallery">
          <view class="side-icon-wrap">
            <text class="side-icon">▦</text>
          </view>
          <text class="side-label">相册</text>
        </view>

        <ShutterButton @on-capture="onShutter" />

        <view class="shutter-side" @click="goToTemplates">
          <view class="side-icon-wrap">
            <text class="side-icon">▦</text>
          </view>
          <text class="side-label">模板</text>
        </view>
      </view>
    </view>

    <FloatingTabBar current="capture" theme="dark" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.capture-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: var(--color-capture-bg);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.bottom-controls {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 0 var(--space-4) calc(var(--space-6) + env(safe-area-inset-bottom));
  z-index: 10;
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.shutter-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--space-4);
}

.shutter-side {
  width: 64px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  &:active { opacity: 0.6; }
}

.side-icon-wrap {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.1);
}

.side-icon {
  font-size: 18px;
  color: rgba(255, 255, 255, 0.7);
}

.side-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: rgba(255, 255, 255, 0.5);
}
</style>
