<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">灵感</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- Today's Mood Card -->
      <view class="mood-card lumira-card fade-up">
        <view class="mood-head">
          <text class="ph ph-sun-horizon mood-head-icon"></text>
          <text class="mood-head-title">今日心情</text>
        </view>
        <view class="mood-pills">
          <view class="mood-pill" :class="m.cls" v-for="m in moods" :key="m.label">
            <text class="ph mood-pill-icon" :class="m.icon"></text>
            <text class="mood-pill-label">{{ m.label }}</text>
            <text class="mood-pill-count">{{ m.count }}</text>
          </view>
        </view>
      </view>

      <!-- Outfit Diary Card -->
      <view class="lumira-card fade-up fade-up-d1 section-card">
        <view class="lumira-section-title">
          <view class="section-title-left">
            <text class="ph ph-t-shirt section-title-icon"></text>
            <text class="section-title-text">穿搭日记</text>
          </view>
          <text class="lumira-section-link">
            <text>查看日记</text>
            <text class="ph ph-caret-right"></text>
          </text>
        </view>
        <view class="streak-row">
          <view class="streak-num-wrap">
            <text class="lumira-stat-num streak-num-brand">7</text>
            <text class="streak-unit">天</text>
          </view>
          <text class="streak-text">连续打卡</text>
          <view class="streak-tag-wrap">
            <text class="lumira-tag lumira-tag-gold">
              <text class="ph ph-fire"></text>
              <text>连续打卡</text>
            </text>
          </view>
        </view>
        <view class="outfit-photos">
          <view class="outfit-photo-col" v-for="(p, i) in outfitPhotos" :key="i">
            <view class="outfit-img-wrap">
              <image class="outfit-img" :src="p.img" mode="aspectFill" />
              <text class="outfit-date">{{ p.date }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Recommended Scenes -->
      <view class="lumira-card fade-up fade-up-d2 section-card">
        <view class="lumira-section-title recommend-title-wrap">
          <view class="recommend-title-left">
            <view class="section-title-left">
              <text class="ph ph-compass section-title-icon"></text>
              <text class="section-title-text">根据你的喜好推荐</text>
            </view>
            <text class="recommend-sub">基于你最近 30 天的拍摄记录</text>
          </view>
        </view>
        <view class="scene-grid">
          <ScenePresetView
            v-for="s in scenes"
            :key="s.id"
            :scene="s"
            variant="card"
            :imageSrc="`https://picsum.photos/seed/scene-inspiration-${s.id}/400/533`"
            :badgeText="s.name"
            :badgeIcon="s.icon"
            @click="goSceneDetail($event)"
          >
            <template #footer>
              <view class="scene-tag-wrap">
                <text class="lumira-tag" :class="getSceneTagInfo(s).tagCls">{{ getSceneTagInfo(s).tag }}</text>
                <view class="scene-stat">
                  <text class="ph ph-images-square scene-stat-icon"></text>
                  <text class="scene-stat-num">{{ getPhotoCountByScene(s.id) }}</text>
                </view>
              </view>
            </template>
          </ScenePresetView>
        </view>
        <view class="more-link-wrap" @click="goSceneManage">
          <text class="more-link">
            <text>发现更多场景</text>
            <text class="ph ph-arrow-right"></text>
          </text>
        </view>
      </view>

      <!-- Check-in Section -->
      <view class="lumira-card fade-up fade-up-d3 section-card">
        <view class="lumira-section-title">
          <view class="section-title-left">
            <text class="ph ph-map-pin section-title-icon"></text>
            <text class="section-title-text">探店打卡</text>
          </view>
        </view>
        <view class="checkin-stat-row">
          <text class="lumira-stat-num checkin-stat-num">23</text>
          <text class="checkin-stat-label">个探店足迹</text>
        </view>
        <view class="checkin-list">
          <view class="checkin-item" v-for="(c, i) in checkins" :key="i">
            <view class="checkin-icon" :class="c.iconCls">
              <text class="ph checkin-icon-i" :class="c.icon"></text>
            </view>
            <view class="checkin-text">
              <text class="checkin-title">{{ c.title }}</text>
              <text class="checkin-desc">{{ c.desc }}</text>
            </view>
            <text class="ph ph-caret-right checkin-arrow"></text>
          </view>
        </view>
      </view>

      <!-- Load More -->
      <view class="load-more fade-up fade-up-d4">
        <view class="lumira-btn-ghost">
          <text class="ph ph-sparkle"></text>
          <text>加载更多灵感</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import ScenePresetView from '@/components/ScenePresetView.vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'
import type { AnyScene } from '@/types/template'

const { customScenes, isCustomScene, getPhotoCountByScene } = useSceneManager()

const moods = ref([
  { cls: 'mood-happy', icon: 'ph-smiley', label: '开心', count: 12 },
  { cls: 'mood-cool', icon: 'ph-heart', label: '甜酷', count: 8 },
  { cls: 'mood-gentle', icon: 'ph-flower', label: '温柔', count: 15 },
  { cls: 'mood-retro', icon: 'ph-film-strip', label: '复古', count: 6 },
  { cls: 'mood-fresh', icon: 'ph-leaf', label: '清新', count: 9 },
  { cls: 'mood-arts', icon: 'ph-book-open', label: '文艺', count: 4 },
  { cls: 'mood-heal', icon: 'ph-teddy-bear', label: '治愈', count: 7 }
])

const outfitPhotos = ref([
  { img: 'https://picsum.photos/seed/1926769/400/533', date: '7月8日' },
  { img: 'https://picsum.photos/seed/1926769/400/533', date: '7月7日' }
])

const scenes = computed<AnyScene[]>(() => {
  const customs = customScenes.value.slice(0, 4)
  const presets = SCENE_PRESETS.slice(0, 4)
  return [...customs, ...presets].slice(0, 4)
})

const getSceneTagInfo = (s: AnyScene): { tag: string; tagCls: string } => {
  if (isCustomScene(s)) return { tag: '我的场景', tagCls: 'lumira-tag-gold' }
  const presetIndex = SCENE_PRESETS.slice(0, 4).findIndex(p => p.id === s.id)
  if (presetIndex === 0) return { tag: '你最常去', tagCls: 'lumira-tag-gold' }
  if (presetIndex === 2) return { tag: '新场景推荐', tagCls: 'lumira-tag-red' }
  return { tag: `${s.name}拍摄`, tagCls: 'lumira-tag-green' }
}

const goSceneDetail = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-detail?sceneId=${id}` })
const goSceneManage = () => uni.navigateTo({ url: '/pages/capture/scene-manage' })

const checkins = ref([
  { iconCls: 'checkin-icon-coffee', icon: 'ph-coffee', title: 'Manner Coffee 武康路店', desc: '2天前' },
  { iconCls: 'checkin-icon-flower', icon: 'ph-flower', title: '野兽派花园', desc: '5天前' },
  { iconCls: 'checkin-icon-museum', icon: 'ph-building-columns', title: '上海当代艺术博物馆', desc: '1周前' }
])
</script>

<style lang="scss" scoped>
.page-body {
  padding: 40rpx 48rpx;
}

.section-card {
  margin-bottom: 40rpx;
}

.section-title-left {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.section-title-icon {
  font-size: 36rpx;
  color: $color-brand-primary;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

/* ===== 今日心情卡片 ===== */
.mood-card {
  margin-bottom: 40rpx;
  background: linear-gradient(135deg, #FDF6EC 0%, #F8EDD8 100%);
  border-color: transparent;
}

.mood-head {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 32rpx;
}

.mood-head-icon {
  font-size: 40rpx;
  color: $color-brand-primary;
}

.mood-head-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.mood-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.mood-pill {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  border: 2rpx solid;
  font-size: 26rpx;
}

.mood-pill-icon {
  font-size: 26rpx;
}

.mood-pill-label {
  font-size: 26rpx;
}

.mood-pill-count {
  font-size: 22rpx;
  opacity: 0.5;
  margin-left: 4rpx;
}

.mood-happy {
  background-color: #FFF5E6;
  border-color: #FFE4B8;
  color: #B8860B;
}

.mood-cool {
  background-color: #F0E6FF;
  border-color: #D4B8FF;
  color: #7B5EA7;
}

.mood-gentle {
  background-color: #FFF0F0;
  border-color: #FFD0D0;
  color: #C47C7C;
}

.mood-retro {
  background-color: #F5E6D0;
  border-color: #D4B896;
  color: #8B6B3D;
}

.mood-fresh {
  background-color: #E8F5E4;
  border-color: #B8D4A8;
  color: #5A7A48;
}

.mood-arts {
  background-color: #EDE8E0;
  border-color: #C8BFB0;
  color: #6B5E4E;
}

.mood-heal {
  background-color: #FFF0E0;
  border-color: #FFD8B0;
  color: #C4783C;
}

/* ===== 穿搭日记卡片 ===== */
.streak-row {
  display: flex;
  align-items: center;
  gap: 24rpx;
  margin-bottom: 32rpx;
}

.streak-num-wrap {
  display: flex;
  align-items: baseline;
  gap: 8rpx;
}

.streak-num-brand {
  color: $color-brand-primary;
}

.streak-unit {
  font-size: 26rpx;
  color: $color-text-secondary;
}

.streak-text {
  font-size: 26rpx;
  color: $color-text-secondary;
}

.streak-tag-wrap {
  margin-left: auto;
}

.outfit-photos {
  display: flex;
  gap: 20rpx;
}

.outfit-photo-col {
  flex: 1;
}

.outfit-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 133.33%;
  overflow: hidden;
  border-radius: 20rpx;
}

.outfit-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.outfit-date {
  position: absolute;
  bottom: 16rpx;
  left: 16rpx;
  font-size: 22rpx;
  color: #fff;
  background: rgba(0, 0, 0, 0.4);
  padding: 4rpx 16rpx;
  border-radius: 9999rpx;
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}

/* ===== 推荐场景卡片 ===== */
.recommend-title-wrap {
  margin-bottom: 0;
}

.recommend-title-left {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.recommend-sub {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

.scene-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20rpx;
  margin-top: 32rpx;
}

.scene-tag-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  margin-top: 20rpx;
}

.scene-stat {
  display: inline-flex;
  align-items: center;
  gap: 6rpx;
}

.scene-stat-icon {
  font-size: 24rpx;
  color: #C9A876;
}

.scene-stat-num {
  font-size: 22rpx;
  color: #6B635A;
  font-weight: 500;
}

.more-link-wrap {
  text-align: center;
  margin-top: 40rpx;
}

.more-link {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  font-size: 26rpx;
  color: $color-brand-primary;
}

/* ===== 探店打卡 ===== */
.checkin-stat-row {
  display: flex;
  align-items: baseline;
  gap: 12rpx;
  margin-bottom: 32rpx;
}

.checkin-stat-num {
  font-size: 48rpx;
}

.checkin-stat-label {
  font-size: 26rpx;
  color: $color-text-secondary;
}

.checkin-list {
  display: flex;
  flex-direction: column;
}

.checkin-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 24rpx 0;
  border-bottom: 2rpx solid $color-border;
}

.checkin-item:last-child {
  border-bottom: none;
  padding-bottom: 0;
}

.checkin-item:first-child {
  padding-top: 0;
}

.checkin-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 24rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.checkin-icon-i {
  font-size: 40rpx;
}

.checkin-icon-coffee {
  background-color: #FFF5E6;

  .checkin-icon-i {
    color: #B8860B;
  }
}

.checkin-icon-flower {
  background-color: #FFF0F0;

  .checkin-icon-i {
    color: #C47C7C;
  }
}

.checkin-icon-museum {
  background-color: #EDE8E0;

  .checkin-icon-i {
    color: #6B5E4E;
  }
}

.checkin-text {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.checkin-title {
  font-size: 28rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.checkin-desc {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

.checkin-arrow {
  font-size: 32rpx;
  color: $color-text-tertiary;
  flex-shrink: 0;
}

/* ===== 加载更多 ===== */
.load-more {
  text-align: center;
  padding: 16rpx 0 32rpx;
}
</style>
