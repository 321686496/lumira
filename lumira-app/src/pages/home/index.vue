<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import BrandHeader from '@/components/home/BrandHeader.vue'
import DailyInspiration from '@/components/home/DailyInspiration.vue'
import RecentPhotos from '@/components/home/RecentPhotos.vue'
import FeaturedTemplates from '@/components/home/FeaturedTemplates.vue'
import SceneQuickAccess from '@/components/home/SceneQuickAccess.vue'
import StatsSummary from '@/components/home/StatsSummary.vue'
import { useTemplatesStore } from '@/stores/templates'
import { useGalleryStore } from '@/stores/gallery'
import { useDailyInspiration } from '@/composables/useDailyInspiration'
import { useSceneGuide } from '@/composables/useSceneGuide'

const templatesStore = useTemplatesStore()
const galleryStore = useGalleryStore()
const { inspiration } = useDailyInspiration()
const { scenes } = useSceneGuide()

const recentPhotos = computed(() => galleryStore.photos.slice(0, 6))
const featuredTemplates = computed(() => templatesStore.allTemplates.slice(0, 6))
const photoCount = computed(() => galleryStore.photoCount)
const templateCount = computed(() => templatesStore.templateCount)

onShow(() => {
  templatesStore.loadTemplates()
  galleryStore.loadPhotos()
})

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}

const handleInspirationTry = (category: string) => {
  uni.navigateTo({ url: `/pages/capture/index?category=${encodeURIComponent(category)}` })
}

const handlePhotoClick = (id: string) => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}

const handleViewAllPhotos = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const handleTemplateClick = (id: string) => {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}

const handleViewAllTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const handleSceneClick = (sceneKey: string) => {
  const scene = scenes.find((s) => s.key === sceneKey)
  if (scene) {
    uni.navigateTo({ url: `/pages/templates/index?category=${encodeURIComponent(scene.category)}` })
  }
}

const handleStatsClick = () => {
  uni.redirectTo({ url: '/pages/profile/index' })
}
</script>

<template>
  <view class="home-page">
    <scroll-view scroll-y class="home-scroll" :show-scrollbar="false">
      <BrandHeader />
      <DailyInspiration
        :inspiration="inspiration"
        @on-try="handleInspirationTry"
      />
      <RecentPhotos
        :photos="recentPhotos"
        :total-count="photoCount"
        @on-photo-click="handlePhotoClick"
        @on-view-all="handleViewAllPhotos"
      />
      <FeaturedTemplates
        :templates="featuredTemplates"
        @on-template-click="handleTemplateClick"
        @on-view-all="handleViewAllTemplates"
      />
      <SceneQuickAccess
        :scenes="scenes"
        @on-scene-click="handleSceneClick"
      />
      <StatsSummary
        :photo-count="photoCount"
        :template-count="templateCount"
        @on-click="handleStatsClick"
      />
      <view class="bottom-spacer" />
    </scroll-view>
    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.home-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  width: 100%;
}

.home-scroll {
  flex: 1;
  width: 100%;
}

.bottom-spacer {
  height: 120px;
}
</style>
