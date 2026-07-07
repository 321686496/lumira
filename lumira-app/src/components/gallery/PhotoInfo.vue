<script setup lang="ts">
import type { LocalPhoto } from '@/types/photo'

interface PhotoInfoProps {
  photo: LocalPhoto
}

defineProps<PhotoInfoProps>()

const emit = defineEmits<{
  (e: 'on-edit'): void
  (e: 'on-delete'): void
  (e: 'on-share'): void
}>()
</script>

<template>
  <view class="photo-info">
    <view class="info-row">
      <text class="info-label">模板</text>
      <text class="info-value">{{ photo.templateId || '自由拍摄' }}</text>
    </view>
    <view class="info-row">
      <text class="info-label">时间</text>
      <text class="info-value">{{ photo.createdAt }}</text>
    </view>
    <view class="info-actions">
      <view class="info-action" @click="emit('on-edit')">
        <text class="action-label">编辑</text>
      </view>
      <view class="info-action" @click="emit('on-share')">
        <text class="action-label">分享</text>
      </view>
      <view class="info-action danger" @click="emit('on-delete')">
        <text class="action-label">删除</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.photo-info {
  padding: var(--space-4) var(--space-5);
  border-top: 1px solid var(--color-border);
}

.info-row {
  display: flex;
  justify-content: space-between;
  padding: var(--space-2) 0;
}

.info-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.info-value {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.info-actions {
  display: flex;
  gap: var(--space-4);
  margin-top: var(--space-3);
  padding-top: var(--space-3);
  border-top: 1px solid var(--color-border);
}

.info-action {
  padding: var(--space-2) var(--space-3);
  border-radius: var(--radius-button);
  background: var(--color-bg-surface);
  &:active { opacity: 0.7; }
}

.action-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.info-action.danger .action-label {
  color: var(--color-status-error);
}
</style>
