<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import PhotoGrid from '@/components/gallery/PhotoGrid.vue'
import AppEmpty from '@/components/AppEmpty.vue'
import { useGalleryStore } from '@/stores/gallery'

const galleryStore = useGalleryStore()
const photos = computed(() => galleryStore.photos)

onShow(() => {
  galleryStore.loadPhotos()
})

const handlePhotoClick = (id: string) => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}

const handlePhotoLongpress = (id: string) => {
  uni.showActionSheet({
    itemList: ['删除'],
    success: (res) => {
      if (res.tapIndex === 0) {
        uni.showModal({
          title: '确认删除',
          content: '删除后无法恢复',
          success: (modalRes) => {
            if (modalRes.confirm) {
              galleryStore.deletePhoto(id)
            }
          },
        })
      }
    },
  })
}

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
</script>

<template>
  <view class="gallery-page">
    <view class="page-header">
      <text class="page-title">相册</text>
      <text class="page-sub">{{ photos.length }} 张照片</text>
    </view>

    <scroll-view scroll-y class="gallery-scroll" :show-scrollbar="false">
      <PhotoGrid
        v-if="photos.length > 0"
        :photos="photos"
        :columns="3"
        @on-photo-click="handlePhotoClick"
        @on-photo-longpress="handlePhotoLongpress"
      />

      <AppEmpty
        v-else
        title="还没有照片"
        description="去拍第一张吧"
        @on-action="() => uni.navigateTo({ url: '/pages/capture/index' })"
      />

      <view class="bottom-spacer" />
    </scroll-view>

    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.gallery-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.page-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.page-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-display);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-display);
  line-height: var(--line-height-display);
}

.page-sub {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}

.gallery-scroll {
  flex: 1;
  width: 100%;
}

.bottom-spacer {
  height: 120px;
}
</style>
