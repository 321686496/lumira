<script setup lang="ts">
import { computed } from 'vue'
import type { Component } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useThemeStore } from '@/stores/theme'
import { useTabBarVariant } from '@/composables/useThemeComponent'
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
const themeStore = useThemeStore()
const { inspiration } = useDailyInspiration()
const { scenes } = useSceneGuide()

const recentPhotos = computed(() => galleryStore.photos.slice(0, 6))
const featuredTemplates = computed(() => templatesStore.allTemplates.slice(0, 6))
const photoCount = computed(() => galleryStore.photoCount)
const templateCount = computed(() => templatesStore.templateCount)

const tabBarVariant = useTabBarVariant()

const sectionMap: Record<string, Component> = {
  brand: BrandHeader,
  inspiration: DailyInspiration,
  recent: RecentPhotos,
  featured: FeaturedTemplates,
  scene: SceneQuickAccess,
  stats: StatsSummary,
}

const sectionProps = computed<Record<string, Record<string, unknown>>>(() => ({
  brand: {},
  inspiration: { inspiration: inspiration.value },
  recent: { photos: recentPhotos.value, totalCount: photoCount.value },
  featured: { templates: featuredTemplates.value },
  scene: { scenes },
  stats: { photoCount: photoCount.value, templateCount: templateCount.value },
}))

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
      <component
        v-for="sectionId in themeStore.layout.homeSectionOrder"
        :key="sectionId"
        :is="sectionMap[sectionId]"
        v-bind="sectionProps[sectionId]"
        @on-try="handleInspirationTry"
        @on-photo-click="handlePhotoClick"
        @on-view-all="handleViewAllPhotos"
        @on-template-click="handleTemplateClick"
        @on-view-all-templates="handleViewAllTemplates"
        @on-scene-click="handleSceneClick"
        @on-click="handleStatsClick"
      />
      <view class="bottom-spacer" />
    </scroll-view>
    <component :is="tabBarVariant" current="home" theme="light" @on-switch="handleTabSwitch" />
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
