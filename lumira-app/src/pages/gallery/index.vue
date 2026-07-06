<template>
  <view class="gallery-page">
    <scroll-view class="photo-scroll" scroll-y>
      <!-- Empty state -->
      <AppEmpty v-if="!hasPhotos" text="还没有照片，去拍摄第一张吧" />

      <!-- Photo grid -->
      <view v-else class="photo-grid">
        <view
          v-for="photo in photos"
          :key="photo.id"
          class="grid-item"
          @tap="onPhotoTap(photo.id)"
        >
          <view class="photo-card">
            <image
              v-if="photo.imagePath"
              class="photo-img"
              :src="photo.imagePath"
              mode="aspectFill"
            />
            <view v-else class="photo-placeholder">
              <text class="placeholder-text">照片</text>
            </view>
          </view>
        </view>
      </view>
      <view class="bottom-pad"></view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { onShow } from '@dcloudio/uni-app'
import AppEmpty from '@/components/AppEmpty.vue'
import { useGalleryStore } from '@/stores/gallery'

const galleryStore = useGalleryStore()

const photos = galleryStore.photos
const photoCount = galleryStore.photoCount
const hasPhotos = galleryStore.hasPhotos

onShow(() => {
  galleryStore.loadPhotos()
})

const onPhotoTap = (id: string | number) => {
  galleryStore.setCurrentPhoto(String(id))
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}
</script>

<style lang="scss" scoped>
.gallery-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
}

.photo-scroll {
  flex: 1;
}

.photo-grid {
  display: flex;
  flex-wrap: wrap;
  padding: 0 var(--space-5);
  gap: var(--space-2);
}

.grid-item {
  width: calc((100% - var(--space-2) * 2) / 3);
}

.photo-card {
  width: 100%;
  aspect-ratio: 1;
  border-radius: var(--radius-card);
  overflow: hidden;
  background: var(--color-bg-card);
}

.photo-img {
  width: 100%;
  height: 100%;
}

.photo-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-text {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.bottom-pad {
  height: var(--space-5);
}
</style>
