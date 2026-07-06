<template>
  <view class="import-page">
    <!-- Top bar -->
    <view class="top-bar">
      <view class="back-btn" @tap="onBack">
        <text class="back-text">←</text>
      </view>
      <text class="top-title">导入模板</text>
      <view class="top-placeholder"></view>
    </view>

    <scroll-view class="content" scroll-y>
      <!-- File selector -->
      <view class="section">
        <text class="section-title">选择文件</text>
        <view class="file-pick" @tap="onPickFile">
          <text class="file-pick-text">{{ fileName || '点击选择 JSON 文件' }}</text>
        </view>
      </view>

      <!-- Preview -->
      <view class="section">
        <text class="section-title">预览</text>
        <view class="preview-card">
          <view class="preview-frame">
            <text v-if="!previewData" class="preview-empty">未选择文件</text>
            <view v-else class="preview-info">
              <text class="preview-name">{{ previewData.name }}</text>
              <text class="preview-category">{{ previewData.category }}</text>
            </view>
          </view>
        </view>
      </view>

      <view class="bottom-pad"></view>
    </scroll-view>

    <!-- Actions -->
    <view class="actions">
      <view class="action-btn action-primary" @tap="onConfirm">
        <text class="action-text-primary">确认导入</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()

const fileName = ref<string>('')
const previewData = ref<any>(null)

const onPickFile = () => {
  // skeleton: uni file picker
  // #ifdef MP-WEIXIN
  uni.chooseMessageFile({
    count: 1,
    type: 'file',
    extension: ['json'],
    success: (res) => {
      const file = res.tempFiles[0]
      fileName.value = file.name
      readPreview(file.path)
    },
  })
  // #endif
  // #ifndef MP-WEIXIN
  fileName.value = 'template.json'
  previewData.value = { name: '示例模板', category: '人像' }
  // #endif
}

const readPreview = (path: string) => {
  // skeleton: read & parse json
  previewData.value = { name: '导入模板', category: '通用' }
}

const onConfirm = () => {
  if (!previewData.value) {
    uni.showToast({ title: '请先选择文件', icon: 'none' })
    return
  }
  templatesStore.importFromJson(previewData.value)
  uni.showToast({ title: '导入成功', icon: 'success' })
  setTimeout(() => {
    uni.navigateBack()
  }, 600)
}

const onBack = () => {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.import-page {
  position: relative;
  width: 100%;
  height: 100vh;
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

.content {
  flex: 1;
}

.section {
  padding: var(--space-3) var(--space-5) var(--space-5);
}

.section-title {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
  display: block;
  margin-bottom: var(--space-3);
}

.file-pick {
  width: 100%;
  height: 56px;
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  border: 1px dashed var(--color-border);
  display: flex;
  align-items: center;
  justify-content: center;
}

.file-pick-text {
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
}

.preview-card {
  width: 100%;
}

.preview-frame {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.preview-empty {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.preview-info {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.preview-name {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
}

.preview-category {
  font-size: var(--font-size-tag);
  color: var(--color-brand-primary);
  margin-top: var(--space-2);
}

.bottom-pad {
  height: var(--space-6);
}

.actions {
  padding: var(--space-3) var(--space-5) var(--space-7);
}

.action-btn {
  width: 100%;
  height: 48px;
  border-radius: var(--radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-primary {
  background: var(--color-brand-primary);
}

.action-text-primary {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}
</style>
