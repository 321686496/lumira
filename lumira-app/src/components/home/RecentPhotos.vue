<script setup lang="ts">
import type { LocalPhoto } from '@/types/photo'

interface RecentPhotosProps {
  photos: LocalPhoto[]
  totalCount: number
}

defineProps<RecentPhotosProps>()

const emit = defineEmits<{
  (e: 'on-photo-click', id: string): void
  (e: 'on-view-all'): void
}>()
</script>

<template>
  <view class="recent-photos">
    <view class="section-header">
      <view class="section-title-wrap">
        <text class="section-title">最近拍摄</text>
        <text class="section-count">{{ totalCount }} 张</text>
      </view>
      <view class="section-more" @click="emit('on-view-all')">
        <text class="more-text">查看全部 →</text>
      </view>
    </view>

    <scroll-view scroll-x class="photos-scroll" :show-scrollbar="false">
      <view class="photos-row">
        <view
          v-for="photo in photos"
          :key="photo.id"
          class="photo-item"
          @click="emit('on-photo-click', photo.id)"
        >
          <image :src="photo.imagePath" mode="aspectFill" class="photo-image" />
        </view>
      </view>
    </scroll-view>

    <view v-if="photos.length === 0" class="empty-state">
      <text class="empty-text">还没有作品，去拍第一张吧</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.recent-photos {
  margin-bottom: var(--space-7);
}

.section-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 0 var(--space-5);
  margin-bottom: var(--space-3);
}

.section-title-wrap {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
}

.section-count {
  font-family: var(--font-mono);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

.section-more {
  padding: var(--space-1) var(--space-2);
  &:active { opacity: 0.5; }
}

.more-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-brand-primary);
}

.photos-scroll {
  width: 100%;
  white-space: nowrap;
}

.photos-row {
  display: inline-flex;
  gap: var(--space-3);
  padding: 0 var(--space-5);
}

.photo-item {
  width: 100px;
  height: 130px;
  border-radius: var(--radius-card);
  overflow: hidden;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  flex-shrink: 0;

  &:active { opacity: 0.85; }
}

.photo-image {
  width: 100%;
  height: 100%;
}

.empty-state {
  padding: var(--space-7) var(--space-5);
  text-align: center;
}

.empty-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}
</style>
