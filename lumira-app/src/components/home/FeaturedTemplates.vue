<script setup lang="ts">
import type { LocalTemplate } from '@/types/template'

interface FeaturedTemplatesProps {
  templates: LocalTemplate[]
}

defineProps<FeaturedTemplatesProps>()

const emit = defineEmits<{
  (e: 'on-template-click', id: string): void
  (e: 'on-view-all'): void
}>()
</script>

<template>
  <view class="featured-templates">
    <view class="section-header">
      <text class="section-title">推荐模板</text>
      <view class="section-more" @click="emit('on-view-all')">
        <text class="more-text">查看全部 →</text>
      </view>
    </view>

    <scroll-view scroll-x class="templates-scroll" :show-scrollbar="false">
      <view class="templates-row">
        <view
          v-for="tmpl in templates"
          :key="tmpl.id"
          class="template-card"
          @click="emit('on-template-click', tmpl.id)"
        >
          <view class="template-cover">
            <image v-if="tmpl.coverPath" :src="tmpl.coverPath" mode="aspectFill" class="cover-image" />
            <view v-else class="cover-placeholder">
              <text class="placeholder-icon">▦</text>
            </view>
          </view>
          <text class="template-name">{{ tmpl.name }}</text>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.featured-templates {
  margin-bottom: var(--space-7);
}

.section-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 0 var(--space-5);
  margin-bottom: var(--space-3);
}

.section-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-heading);
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

.templates-scroll {
  width: 100%;
  white-space: nowrap;
}

.templates-row {
  display: inline-flex;
  gap: var(--space-3);
  padding: 0 var(--space-5);
}

.template-card {
  display: flex;
  flex-direction: column;
  width: 140px;
  gap: var(--space-2);
  flex-shrink: 0;
  &:active { opacity: 0.8; }
}

.template-cover {
  width: 140px;
  height: 180px;
  border-radius: var(--radius-card);
  background: var(--color-bg-surface);
  overflow: hidden;
  border: 1px solid var(--color-border);
}

.cover-image {
  width: 100%;
  height: 100%;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-icon {
  font-size: var(--font-size-display);
  color: var(--color-text-tertiary);
  opacity: 0.3;
}

.template-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  padding: 0 var(--space-0);
}
</style>
