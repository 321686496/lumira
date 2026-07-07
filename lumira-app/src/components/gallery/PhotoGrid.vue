<script setup lang="ts">
import type { LocalPhoto } from '@/types/photo'

interface PhotoGridProps {
  photos: LocalPhoto[]
  columns?: number
}

withDefaults(defineProps<PhotoGridProps>(), {
  columns: 3,
})

const emit = defineEmits<{
  (e: 'on-photo-click', id: string): void
  (e: 'on-photo-longpress', id: string): void
}>()
</script>

<template>
  <view class="photo-grid" :style="{ gridTemplateColumns: `repeat(${columns}, 1fr)` }">
    <view
      v-for="photo in photos"
      :key="photo.id"
      class="grid-item"
      @click="emit('on-photo-click', photo.id)"
      @longpress="emit('on-photo-longpress', photo.id)"
    >
      <image :src="photo.imagePath" mode="aspectFill" class="grid-image" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.photo-grid {
  display: grid;
  gap: 2px;
  padding: 0 var(--space-5);
}

.grid-item {
  aspect-ratio: 1;
  overflow: hidden;
  background: var(--color-bg-surface);
  &:active { opacity: 0.85; }
}

.grid-image {
  width: 100%;
  height: 100%;
}
</style>
