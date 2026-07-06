<template>
  <view class="detail-page">
    <!-- Top bar -->
    <view class="top-bar">
      <view class="back-btn" @tap="onBack">
        <text class="back-text">←</text>
      </view>
      <text class="top-title">模板详情</text>
      <view class="top-placeholder"></view>
    </view>

    <scroll-view class="detail-scroll" scroll-y>
      <!-- Overlay preview -->
      <view class="preview-card">
        <view class="preview-frame">
          <text class="preview-text">叠图预览</text>
          <text class="preview-hint">{{ template?.name ?? '模板' }}</text>
        </view>
      </view>

      <!-- Info -->
      <view class="info-block">
        <text class="tpl-name">{{ template?.name ?? '未命名模板' }}</text>
        <text class="tpl-category">{{ template?.category ?? '' }}</text>
        <text class="tpl-desc">{{ template?.description ?? '暂无描述' }}</text>
      </view>

      <view class="bottom-pad"></view>
    </scroll-view>

    <!-- Action buttons -->
    <view class="actions">
      <view class="action-btn action-secondary" @tap="onEdit">
        <text class="action-text-secondary">编辑</text>
      </view>
      <view class="action-btn action-secondary" @tap="onShare">
        <text class="action-text-secondary">导出分享</text>
      </view>
      <view class="action-btn action-primary" @tap="onShoot">
        <text class="action-text-primary">用此模板拍摄</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()
const templateId = ref<string>('')

const template = computed(() => {
  if (!templateId.value) return null
  return templatesStore.getResolvedTemplate(templateId.value)
})

onLoad((options) => {
  templateId.value = (options?.id as string) ?? ''
})

const onBack = () => {
  uni.navigateBack()
}

const onShoot = () => {
  if (template.value) {
    templatesStore.setCategory(template.value.category)
  }
  uni.switchTab({ url: '/pages/capture/index' })
}

const onEdit = () => {
  uni.navigateTo({ url: `/pages/templates/editor?id=${templateId.value}` })
}

const onShare = () => {
  uni.showToast({ title: '已生成分享', icon: 'success' })
}
</script>

<style lang="scss" scoped>
.detail-page {
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

.detail-scroll {
  flex: 1;
}

.preview-card {
  padding: var(--space-3) var(--space-5);
}

.preview-frame {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.preview-text {
  font-size: var(--font-size-heading);
  color: var(--color-text-secondary);
}

.preview-hint {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.info-block {
  padding: var(--space-5);
  display: flex;
  flex-direction: column;
}

.tpl-name {
  font-size: var(--font-size-title);
  color: var(--color-text-primary);
}

.tpl-category {
  font-size: var(--font-size-tag);
  color: var(--color-brand-primary);
  margin-top: var(--space-2);
}

.tpl-desc {
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
  margin-top: var(--space-3);
  line-height: 1.6;
}

.bottom-pad {
  height: var(--space-6);
}

.actions {
  display: flex;
  align-items: center;
  padding: var(--space-3) var(--space-5) var(--space-7);
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
