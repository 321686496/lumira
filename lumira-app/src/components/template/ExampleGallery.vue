<script setup lang="ts">
interface ExampleGalleryProps {
  examples: string[]
}

defineProps<ExampleGalleryProps>()
</script>

<template>
  <view class="example-gallery">
    <text class="panel-title">示例作品</text>
    <scroll-view scroll-x class="examples-scroll" :show-scrollbar="false">
      <view class="examples-row">
        <view v-for="(ex, idx) in examples" :key="idx" class="example-item">
          <image :src="ex" mode="aspectFill" class="example-image" />
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style lang="scss" scoped>
.example-gallery {
  margin-bottom: var(--space-5);
}

.panel-title {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  margin-bottom: var(--space-3);
}

.examples-scroll {
  width: 100%;
  white-space: nowrap;
}

.examples-row {
  display: inline-flex;
  gap: var(--space-3);
}

.example-item {
  width: 120px;
  height: 160px;
  border-radius: var(--radius-card);
  overflow: hidden;
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  flex-shrink: 0;
}

.example-image {
  width: 100%;
  height: 100%;
}
</style>
