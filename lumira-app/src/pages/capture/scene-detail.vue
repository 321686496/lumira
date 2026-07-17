<template>
  <view class="scene-detail-page">
    <!-- 导航栏 -->
    <view class="detail-nav">
      <view class="nav-back" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">{{ scene?.name || '场景详情' }}</text>
      <view class="nav-fav" @click="onToggleFav">
        <text :class="['nav-fav-icon', isFav ? 'ph ph-heart' : 'ph ph-heart-straight']"></text>
      </view>
    </view>

    <scroll-view scroll-y class="detail-scroll" v-if="scene">
      <!-- 示例图轮播 -->
      <swiper class="detail-swiper" :indicator-dots="scene.exampleImages.length > 1" circular autoplay>
        <swiper-item v-for="(img, idx) in scene.exampleImages" :key="idx">
          <image class="detail-swiper-img" :src="img" mode="aspectFill" />
        </swiper-item>
      </swiper>

      <!-- 标题区 -->
      <view class="detail-header">
        <view class="detail-header-row">
          <text class="ph detail-icon" :class="scene.icon"></text>
          <text class="detail-name">{{ scene.name }}</text>
        </view>
        <text class="detail-vibe">{{ scene.vibe }}</text>
      </view>

      <!-- 氛围卡片 -->
      <view class="detail-section">
        <text class="section-title">氛围</text>
        <view class="section-card">
          <text class="section-text">{{ scene.description }}</text>
          <view class="section-meta">
            <text class="meta-item"><text class="ph ph-map-pin"></text> {{ scene.whereToShoot }}</text>
            <text class="meta-item"><text class="ph ph-clock"></text> {{ scene.bestTime }}</text>
          </view>
        </view>
      </view>

      <!-- 推荐滤镜 -->
      <view class="detail-section">
        <text class="section-title">推荐滤镜</text>
        <SceneFilterBadge :filter="scene.filter" />
      </view>

      <!-- 拍摄小贴士 -->
      <view class="detail-section">
        <text class="section-title">拍摄小贴士</text>
        <view class="section-card">
          <view v-for="(tip, idx) in scene.tips" :key="idx" class="tip-row">
            <text class="tip-dot">•</text>
            <text class="tip-text">{{ tip }}</text>
          </view>
        </view>
      </view>

      <!-- 成就 -->
      <view class="detail-section">
        <text class="section-title">我的成就</text>
        <SceneAchievementCard
          :achievement="achievement"
          :scene-name="scene.name"
          :rank="sceneRank"
          rank-label="本周"
        />
      </view>

      <view class="detail-bottom-space"></view>
    </scroll-view>

    <!-- 底部按钮 -->
    <view class="detail-bottom" v-if="scene">
      <view class="btn-primary" @click="goCapture">
        <text class="btn-primary-text">用此场景拍照</text>
      </view>
      <view class="btn-secondary" @click="goCreateKit">
        <text class="btn-secondary-text">加入组合</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import type { ScenePresetId } from '@/types/template'
import SceneFilterBadge from '@/components/SceneFilterBadge.vue'
import SceneAchievementCard from '@/components/SceneAchievementCard.vue'

const sceneId = ref<string>('')

onLoad((options) => {
  if (options?.sceneId) {
    sceneId.value = options.sceneId
  }
})

const { getSceneById, getSceneAchievement, isFavorite, toggleFavorite, weeklyRanking } = useSceneManager()

const scene = computed(() => getSceneById(sceneId.value))
const isFav = computed(() => sceneId.value ? isFavorite(sceneId.value as ScenePresetId) : false)
const achievement = computed(() => getSceneAchievement(sceneId.value))
const sceneRank = computed(() => {
  const found = weeklyRanking.value.find(r => r.scene.id === sceneId.value)
  return found?.rank
})

function goBack() {
  uni.navigateBack()
}

function onToggleFav() {
  if (sceneId.value) toggleFavorite(sceneId.value as ScenePresetId)
}

function goCapture() {
  uni.navigateTo({ url: `/pages/capture/index?scenePreset=${sceneId.value}` })
}

function goCreateKit() {
  uni.navigateTo({ url: `/pages/capture/scene-manage?tab=kit&sceneId=${sceneId.value}` })
}
</script>

<style lang="scss" scoped>
.scene-detail-page { min-height: 100vh; background: #FAF7F2; display: flex; flex-direction: column; }
.detail-nav { display: flex; align-items: center; justify-content: space-between; padding: 0 24rpx; height: 88rpx; padding-top: env(safe-area-inset-top); }
.nav-back { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.nav-back-icon { font-size: 36rpx; color: #2A2520; }
.nav-title { font-size: 32rpx; font-weight: 600; color: #2A2520; }
.nav-fav { width: 64rpx; height: 64rpx; display: flex; align-items: center; justify-content: center; }
.nav-fav-icon { font-size: 36rpx; color: #C9A876; }
.detail-scroll { flex: 1; }
.detail-swiper { width: 100%; height: 480rpx; }
.detail-swiper-img { width: 100%; height: 100%; }
.detail-header { padding: 32rpx 24rpx 16rpx; display: flex; flex-direction: column; gap: 12rpx; }
.detail-header-row { display: flex; align-items: center; gap: 16rpx; }
.detail-icon { font-size: 48rpx; }
.detail-name { font-size: 40rpx; font-weight: 700; color: #2A2520; }
.detail-vibe { font-size: 28rpx; color: #6B635A; font-style: italic; }
.detail-section { padding: 16rpx 24rpx; display: flex; flex-direction: column; gap: 16rpx; }
.section-title { font-size: 28rpx; font-weight: 600; color: #2A2520; }
.section-card { padding: 24rpx; background: rgba(0,0,0,0.04); border-radius: 20rpx; display: flex; flex-direction: column; gap: 16rpx; }
.section-text { font-size: 26rpx; color: #2A2520; line-height: 1.6; }
.section-meta { display: flex; flex-direction: column; gap: 8rpx; }
.meta-item { font-size: 24rpx; color: #6B635A; }
.tip-row { display: flex; gap: 12rpx; }
.tip-dot { font-size: 26rpx; color: #C9A876; }
.tip-text { font-size: 26rpx; color: #2A2520; flex: 1; line-height: 1.5; }
.detail-bottom-space { height: 160rpx; }
.detail-bottom { position: fixed; bottom: 0; left: 0; right: 0; display: flex; gap: 16rpx; padding: 24rpx; padding-bottom: calc(24rpx + env(safe-area-inset-bottom)); background: #FAF7F2; }
.btn-primary { flex: 1; height: 88rpx; background: #2A2520; border-radius: 44rpx; display: flex; align-items: center; justify-content: center; }
.btn-primary-text { font-size: 28rpx; color: #FFFFFF; font-weight: 600; }
.btn-secondary { flex: 1; height: 88rpx; background: rgba(201,168,118,0.15); border-radius: 44rpx; display: flex; align-items: center; justify-content: center; }
.btn-secondary-text { font-size: 28rpx; color: #C9A876; font-weight: 600; }
</style>
