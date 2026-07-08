<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const photoId = ref('')
const showOriginal = ref(false)

onLoad((query) => {
  if (query?.photoId) {
    photoId.value = query.photoId
  }
})

const toggleCompare = () => {
  showOriginal.value = !showOriginal.value
}

const goEdit = () => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${photoId.value}` })
}

const retake = () => {
  uni.navigateBack()
}

const savePhoto = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="preview-page">
    <view class="preview-nav">
      <view class="nav-btn" @click="retake">
        <text class="nav-text">重拍</text>
      </view>
      <view class="nav-btn compare-btn" @click="toggleCompare">
        <text class="nav-text">{{ showOriginal ? '效果' : '原图' }}</text>
      </view>
    </view>

    <view class="preview-content">
      <view class="photo-frame">
        <text class="photo-placeholder">📸 照片预览</text>
      </view>
    </view>

    <view class="preview-actions">
      <view class="action-btn edit-btn" @click="goEdit">
        <text class="action-text">后期编辑</text>
      </view>
      <view class="action-btn save-btn" @click="savePhoto">
        <text class="action-text">保存</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.preview-page {
  min-height: 100vh;
  background: var(--color-capture-bg);
  display: flex;
  flex-direction: column;
}

.preview-nav {
  display: flex;
  justify-content: space-between;
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5);
}

.nav-btn {
  padding: var(--space-2) var(--space-4);
  &:active { opacity: 0.7; }
}

.nav-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: #FFFFFF;
}

.preview-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--space-5);
}

.photo-frame {
  width: 100%;
  max-width: 360px;
  aspect-ratio: 3 / 4;
  background: #2A2A2A;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.photo-placeholder {
  font-size: 20px;
  color: rgba(255, 255, 255, 0.4);
}

.preview-actions {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5) calc(var(--space-6) + env(safe-area-inset-bottom));
}

.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-4);
  border-radius: var(--radius-button);
  &:active { opacity: 0.85; }
}

.edit-btn {
  background: var(--color-brand-primary);
}

.save-btn {
  background: var(--color-text-primary);
}

.action-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-semibold);
  color: #FFFFFF;
}
</style>
