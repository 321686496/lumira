<template>
  <view class="preview-page">
    <!-- Top bar -->
    <view class="top-bar">
      <view class="back-btn" @tap="onBack">
        <text class="back-text">←</text>
      </view>
      <text class="top-title">预览</text>
      <view class="top-placeholder"></view>
    </view>

    <!-- Photo preview -->
    <view class="photo-area">
      <view class="photo-frame">
        <image
          v-if="photoUri"
          class="photo-img"
          :src="photoUri"
          mode="aspectFit"
        />
        <view v-else class="photo-placeholder">
          <text class="placeholder-text">已拍摄照片</text>
          <text class="placeholder-hint">photoId: {{ photoId }}</text>
        </view>
      </view>
    </view>

    <!-- Action buttons -->
    <view class="actions">
      <view class="action-btn action-secondary" @tap="onRetake">
        <text class="action-text-secondary">重拍</text>
      </view>
      <view class="action-btn action-primary" @tap="onSave">
        <text class="action-text-primary">保存</text>
      </view>
      <view class="action-btn action-secondary" @tap="onEdit">
        <text class="action-text-secondary">编辑</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const photoId = ref<string>('')
const photoUri = ref<string>('')

onLoad((options) => {
  photoId.value = (options?.photoId as string) ?? ''
})

const onBack = () => {
  uni.navigateBack()
}

const onRetake = () => {
  uni.navigateBack()
}

const onSave = () => {
  uni.showToast({ title: '已保存到相册', icon: 'success' })
}

const onEdit = () => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${photoId.value}` })
}
</script>

<style lang="scss" scoped>
.preview-page {
  position: relative;
  width: 100%;
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
}

.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-5) var(--space-4) var(--space-3);
}

.back-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.back-text {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
}

.top-title {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
}

.top-placeholder {
  width: 40px;
  height: 40px;
}

.photo-area {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-3) var(--space-4);
}

.photo-frame {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.photo-img {
  width: 100%;
  height: 100%;
}

.photo-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.placeholder-text {
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
}

.placeholder-hint {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-5) var(--space-9);
  gap: var(--space-3);
}

.action-btn {
  flex: 1;
  height: 48px;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-secondary {
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
}

.action-primary {
  background: var(--color-brand-primary);
}

.action-text-secondary {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.action-text-primary {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}
</style>
