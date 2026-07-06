<template>
  <view class="editor-page">
    <!-- Top bar -->
    <view class="top-bar">
      <view class="back-btn" @tap="onBack">
        <text class="back-text">←</text>
      </view>
      <text class="top-title">模板编辑器</text>
      <text class="preview-toggle" @tap="onPreviewToggle">{{ previewMode ? '编辑' : '预览' }}</text>
    </view>

    <!-- Canvas area -->
    <view class="canvas-area">
      <view class="canvas-frame">
        <text class="canvas-text">{{ previewMode ? '预览模式' : '编辑画布' }}</text>
        <text class="canvas-hint">{{ templateId ? `模板 #${templateId}` : '新建模板' }}</text>
      </view>
    </view>

    <!-- Control panel -->
    <scroll-view class="control-panel" scroll-y>
      <view class="control-group">
        <text class="control-label">模板名称</text>
        <input class="control-input" placeholder="输入模板名称" />
      </view>

      <view class="control-group">
        <text class="control-label">分类</text>
        <input class="control-input" placeholder="选择分类" />
      </view>

      <view class="control-group">
        <text class="control-label">叠图透明度</text>
        <slider
          class="control-slider"
          :min="0"
          :max="100"
          :step="1"
          :value="overlayOpacity"
          activeColor="var(--color-brand-primary)"
          @change="onOpacityChange"
        />
      </view>
    </scroll-view>

    <!-- Bottom actions -->
    <view class="actions">
      <view class="action-btn action-primary" @tap="onSave">
        <text class="action-text-primary">保存</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()
const templateId = ref<string>('')
const previewMode = ref<boolean>(false)
const overlayOpacity = ref<number>(80)

onLoad((options) => {
  templateId.value = (options?.id as string) ?? ''
})

const onPreviewToggle = () => {
  previewMode.value = !previewMode.value
}

const onOpacityChange = (e: any) => {
  overlayOpacity.value = e.detail.value
}

const onSave = () => {
  uni.showToast({ title: '已保存', icon: 'success' })
  setTimeout(() => {
    uni.navigateBack()
  }, 600)
}

const onBack = () => {
  uni.navigateBack()
}
</script>

<style lang="scss" scoped>
.editor-page {
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

.preview-toggle {
  font-size: var(--font-size-body);
  color: var(--color-brand-primary);
}

.canvas-area {
  padding: var(--space-3) var(--space-5);
}

.canvas-frame {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  border: 1px dashed var(--color-border);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.canvas-text {
  font-size: var(--font-size-heading);
  color: var(--color-text-secondary);
}

.canvas-hint {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.control-panel {
  flex: 1;
  padding: var(--space-4) var(--space-5);
}

.control-group {
  margin-bottom: var(--space-5);
}

.control-label {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
  display: block;
  margin-bottom: var(--space-2);
}

.control-input {
  width: 100%;
  height: 44px;
  padding: 0 var(--space-3);
  background: var(--color-bg-card);
  border-radius: var(--radius-card);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
  border: 1px solid var(--color-border);
}

.control-slider {
  width: 100%;
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
