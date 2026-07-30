<template>
  <view class="lumira-container">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left loc">
        <text class="ph ph-map-pin loc-icon"></text>
        <text class="loc-text">上海</text>
      </view>
      <text class="lumira-nav-title">如画</text>
      <view class="lumira-nav-right">
        <text class="ph ph-bell nav-icon"></text>
        <text class="ph ph-qr-code nav-icon"></text>
      </view>
    </view>

    <!-- 今日灵感卡片 -->
    <view class="section hero-wrap fade-up">
      <view class="hero-card">
        <view class="hero-deco"></view>
        <view class="hero-body">
          <view class="hero-date">
            <text class="ph ph-calendar-blank hero-date-icon"></text>
            <text class="hero-date-text">7月9日 星期二 · 光线极佳</text>
          </view>
          <text class="hero-title">今日灵感</text>
          <text class="hero-desc">捕捉每一束光，让日常成为习惯</text>
          <view class="hero-btn" @click="goCapture">
            <text class="ph ph-camera"></text>
            <text class="hero-btn-text">开始拍摄</text>
          </view>
          <view class="hero-weather">
            <text class="ph ph-sun hero-weather-icon"></text>
            <text class="hero-weather-text">17°C 晴 · 黄金时刻 16:30</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 快捷入口 -->
    <view class="section quick-row fade-up fade-up-d1">
      <view class="quick-item" @click="goCapture">
        <view class="quick-circle quick-circle-gold">
          <text class="ph ph-camera"></text>
        </view>
        <text class="quick-label">拍摄</text>
      </view>
      <view class="quick-item" @click="goTab('/pages/templates/index')">
        <view class="quick-circle quick-circle-green">
          <text class="ph ph-book-open"></text>
        </view>
        <text class="quick-label">模板</text>
      </view>
      <view class="quick-item" @click="goTab('/pages/challenge/index')">
        <view class="quick-circle quick-circle-gold">
          <text class="ph ph-sparkle"></text>
        </view>
        <text class="quick-label">灵感</text>
      </view>
      <view class="quick-item" @click="goPage('/pages/gallery/index')">
        <view class="quick-circle quick-circle-red">
          <text class="ph ph-images"></text>
        </view>
        <text class="quick-label">相册</text>
      </view>
    </view>

    <!-- 连续打卡 -->
    <view class="section section-pad fade-up fade-up-d2">
      <view class="lumira-card">
        <view class="streak-head">
          <view class="streak-title-wrap">
            <text class="ph ph-fire streak-icon"></text>
            <text class="streak-title">连续打卡</text>
          </view>
          <view class="streak-num-wrap">
            <text class="streak-num">{{ streak }}</text>
            <text class="streak-unit">天</text>
          </view>
        </view>
        <view class="streak-week">
          <view class="streak-day" v-for="(d, i) in weekDays" :key="i">
            <view class="streak-dot" :class="{ done: d.done, today: d.today }">
              <text v-if="d.done" class="ph ph-check streak-check"></text>
              <text v-else class="streak-day-num">{{ d.label }}</text>
            </view>
            <text class="streak-day-label">{{ d.label }}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 今日拍摄小贴士 -->
    <view class="section fade-up fade-up-d3">
      <view class="tip-card">
        <view class="tip-head">
          <view class="tip-icon-wrap">
            <text class="ph ph-lightbulb tip-icon"></text>
          </view>
          <view class="tip-body">
            <text class="tip-title">今日拍摄小贴士</text>
            <text class="tip-text">{{ currentTip.text }}</text>
            <text v-if="currentTip.sub" class="tip-sub">{{ currentTip.sub }}</text>
          </view>
        </view>
        <view class="tip-btns">
          <view class="tip-btn-brand" @click="goCapture">
            <text class="ph ph-camera tip-btn-icon"></text>
            <text>试试</text>
          </view>
          <view class="tip-btn-ghost" @click="refreshTip">
            <text class="ph ph-arrow-clockwise tip-btn-icon"></text>
            <text>换一批</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 场景推荐 -->
    <view class="section fade-up fade-up-d4">
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="section-title-text">场景推荐</text>
          <text class="lumira-tag lumira-tag-green">为你而选</text>
        </view>
        <view class="section-link-row">
          <text class="lumira-section-link" @click="goAllScenes">查看全部</text>
          <text class="lumira-section-link" @click="goSceneFav">收藏</text>
          <text class="lumira-section-link" @click="goSceneManage">管理</text>
        </view>
      </view>
      <view class="scene-grid section-pad">
        <ScenePresetView
          v-for="(s, index) in scenes"
          :key="s.id"
          :scene="s"
          variant="card"
          textField="vibe"
          :imageSrc="`https://picsum.photos/seed/scene-home-${s.id}/400/600`"
          :badgeText="getSceneBadge(s, index)"
          :badgeBrand="index === 2"
          @click="goSceneDetail($event)"
        >
          <template #footer>
            <view class="scene-stat">
              <text class="ph ph-images-square scene-stat-icon"></text>
              <text class="scene-stat-num">{{ getPhotoCountByScene(s.id) }}</text>
            </view>
          </template>
        </ScenePresetView>
      </view>
    </view>

    <!-- 最近拍摄 -->
    <view class="section fade-up">
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="section-title-text">最近拍摄</text>
          <text v-if="recents.length > 0" class="lumira-tag lumira-tag-gold">
            <text class="ph ph-sparkle"></text>
            <text>{{ recents.length }} 张作品</text>
          </text>
        </view>
        <text class="lumira-section-link" @click="goPage('/pages/gallery/index')">全部</text>
      </view>
      <view v-if="recents.length > 0" class="recent-grid section-pad">
        <view class="recent-card lumira-card-hover" v-for="r in recents" :key="r.name + r.img" @click="goPage('/pages/gallery/index')">
          <view class="recent-img-wrap">
            <image class="recent-img" :src="r.img" mode="aspectFill" />
            <view class="recent-tag">
              <text class="ph recent-tag-icon" :class="r.icon"></text>
              <text class="recent-tag-text">{{ r.cat }}</text>
            </view>
            <view v-if="r.match" class="recent-match">
              <text class="recent-match-text">{{ r.match }}</text>
            </view>
            <view v-if="r.progress" class="recent-progress">
              <text class="recent-progress-text">{{ r.progress }}</text>
            </view>
          </view>
          <view class="recent-info">
            <text class="recent-name">{{ r.name }}</text>
            <view class="recent-steps">
              <text class="ph ph-footprints recent-steps-icon"></text>
              <text class="recent-steps-text">{{ r.steps }} 步</text>
            </view>
          </view>
        </view>
      </view>
      <view v-else class="recent-empty section-pad">
        <text class="ph ph-camera empty-icon"></text>
        <text class="empty-title">还没有作品</text>
        <text class="empty-desc">点击下方拍摄按钮，记录你的第一张作品</text>
        <view class="lumira-btn-brand empty-btn" @click="goCapture">
          <text class="ph ph-camera"></text>
          <text>开始拍摄</text>
        </view>
      </view>
    </view>

    <!-- 统计 -->
    <view class="section fade-up fade-up-d1 section-pad">
      <view class="lumira-card">
        <view class="stats-head">
          <text class="ph ph-chart-line stats-head-icon"></text>
          <text class="stats-head-title">保持记录，养成习惯</text>
        </view>
        <view class="stats-grid">
          <view class="stats-item">
            <text class="lumira-stat-num">{{ favoriteCount }}</text>
            <text class="lumira-stat-label">收藏</text>
          </view>
          <view class="stats-item stats-item-mid">
            <text class="lumira-stat-num">{{ totalXp }}</text>
            <text class="lumira-stat-label">总经验</text>
          </view>
          <view class="stats-item">
            <text class="lumira-stat-num">{{ totalPhotos }}</text>
            <text class="lumira-stat-label">作品</text>
          </view>
        </view>
      </view>
    </view>

    <FloatingTabBar active="home" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import ScenePresetView from '@/components/ScenePresetView.vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'
import { useShootingTip, type ShootingTip } from '@/composables/useShootingTip'
import { useChallenge } from '@/composables/useChallenge'
import { useGrowth } from '@/composables/useGrowth'
import { useTemplate } from '@/composables/useTemplate'
import type { AnyScene, SceneCategory, Target } from '@/types/template'

const { customScenes, isCustomScene, getPhotoCountByScene, photos, allScenes } = useSceneManager()
const { getShootingTip, getNextShootingTip } = useShootingTip()
const currentTip = ref<ShootingTip>(getShootingTip())

function refreshTip() {
  currentTip.value = getNextShootingTip(currentTip.value)
}

// 连续打卡：使用 useChallenge 的真实数据
const { streak, weeklyStatus, autoCheckChallenge } = useChallenge()

// 成长数据：用于底部统计卡
const { totalPhotos, favoriteCount, totalXp } = useGrowth()

// 模板数据：用于最近拍摄分类映射
const { getAllTemplates } = useTemplate()

// 每次显示页面时自动检查挑战完成情况
onShow(() => {
  const usedTemplateIds = [...new Set(photos.value.map(p => p.templateId).filter(Boolean) as string[])]
  const usedSceneIds = [...new Set(photos.value.map(p => p.sceneId).filter(Boolean) as string[])]
  autoCheckChallenge(photos.value.length, usedTemplateIds, usedSceneIds)
})

const weekDays = computed(() => weeklyStatus.value)

const scenes = computed<AnyScene[]>(() => {
  // 优先展示用户已拍过照片的场景（按拍摄数排序），不足 4 个再用预设补
  const shotScenes = allScenes.value
    .map(s => ({ scene: s, count: getPhotoCountByScene(s.id) }))
    .filter(x => x.count > 0)
    .sort((a, b) => b.count - a.count)
    .map(x => x.scene)
  const customs = customScenes.value.slice(0, 4)
  const presets = SCENE_PRESETS.slice(0, 4)
  return [...shotScenes, ...customs, ...presets].slice(0, 4)
})

const getSceneBadge = (s: AnyScene, index: number): string => {
  if (isCustomScene(s)) return '我的场景'
  const count = getPhotoCountByScene(s.id)
  if (count > 0 && index === 0) return '你最常去'
  if (index === 2) return '新场景推荐'
  return `${s.name}拍摄`
}

// 场景分类标签映射
const sceneCategoryLabelMap: Record<SceneCategory, string> = {
  light: '光线氛围',
  outdoor: '室外环境',
  indoor: '室内空间',
  mood: '情绪氛围',
}

const sceneCategoryLabel = (cat: SceneCategory): string => {
  return sceneCategoryLabelMap[cat] || '场景'
}

// 模板分类标签映射
const categoryLabelMap: Record<Target, string> = {
  portrait: '人像',
  landscape: '风光',
  food: '美食',
  night: '夜景',
  street: '街拍',
  macro: '微距',
  'still-life': '静物'
}

// 最近拍摄：基于真实照片数据
const recents = computed(() => {
  const allTpls = getAllTemplates()
  const sceneMap = new Map<string, AnyScene>()
  allScenes.value.forEach(s => sceneMap.set(s.id, s))

  return photos.value.slice(0, 5).map((p, idx) => {
    // 优先用模板分类，其次场景分类
    let cat = '作品'
    let icon = 'ph-image'
    let name = `作品 ${idx + 1}`
    let steps = 0

    if (p.templateId) {
      const tpl = allTpls.find(t => t.meta.id === p.templateId)
      if (tpl) {
        name = tpl.meta.name
        cat = categoryLabelMap[tpl.meta.category] || '作品'
        icon = 'ph-palette'
        steps = (tpl.sceneGuide?.tips || []).length || 8
      }
    } else if (p.sceneId) {
      const scene = sceneMap.get(p.sceneId)
      if (scene) {
        name = scene.name
        cat = sceneCategoryLabel(scene.category)
        icon = 'ph-mountains'
        steps = (scene.tips || []).length || 6
      }
    }

    // 第一张展示匹配度徽标，进行中的概念以最近 3 天内的照片标记
    const isLatest = idx === 0
    const isRecent = Date.now() - p.createdAt < 3 * 24 * 3600 * 1000
    return {
      name,
      cat,
      icon,
      img: p.dataUrl || `https://picsum.photos/seed/photo-${p.id}/400/600`,
      steps,
      match: isLatest ? '最新' : '',
      progress: isRecent && !isLatest ? '新作品' : '',
    }
  })
})

const goTab = (url: string) => uni.reLaunch({ url })
const goPage = (url: string) => uni.navigateTo({ url })
const goCapture = () => uni.navigateTo({ url: '/pages/capture/index' })
const goSceneDetail = (id: string) => uni.navigateTo({ url: `/pages/capture/scene-detail?sceneId=${id}` })
const goAllScenes = () => uni.navigateTo({ url: '/pages/scenes/index' })
const goSceneManage = () => uni.navigateTo({ url: '/pages/capture/scene-manage' })
const goSceneFav = () => uni.navigateTo({ url: '/pages/capture/scene-manage?tab=fav' })
</script>

<style lang="scss" scoped>
.section {
  margin-bottom: 40rpx;
}

.section-pad {
  padding: 0 40rpx;
}

.section-title-left {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.section-link-row {
  display: flex;
  gap: 24rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

/* 导航定位 */
.loc {
  gap: 8rpx;
  margin-right: 16rpx;
}

.loc-icon {
  font-size: 32rpx;
  color: var(--color-text-secondary);
}

.loc-text {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
}

.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-secondary);
}

/* 今日灵感卡片 */
.hero-wrap {
  padding: 0 40rpx 40rpx;
}

.hero-card {
  position: relative;
  border-radius: 40rpx;
  padding: 56rpx 48rpx;
  overflow: hidden;
  background: linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%);
}

.hero-deco {
  position: absolute;
  top: -60rpx;
  right: -60rpx;
  width: 280rpx;
  height: 280rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.10);
}

.hero-body {
  position: relative;
  z-index: 1;
}

.hero-date {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 20rpx;
}

.hero-date-icon {
  font-size: 28rpx;
  color: var(--color-brand);
}

.hero-date-text {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.hero-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 16rpx;
  letter-spacing: -0.01em;
}

.hero-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  line-height: 1.6;
  margin-bottom: 40rpx;
}

.hero-btn {
  display: inline-flex;
  align-items: center;
  gap: 16rpx;
  justify-content: center;
  padding: 24rpx 48rpx;
  border-radius: 16rpx;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  color: #fff;
}

.hero-btn .ph {
  font-size: 32rpx;
}

.hero-btn-text {
  font-size: 30rpx;
  font-weight: 500;
  color: #fff;
}

.hero-weather {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-top: 32rpx;
}

.hero-weather-icon {
  font-size: 28rpx;
  color: var(--color-brand);
}

.hero-weather-text {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

/* 快捷入口 */
.quick-row {
  display: flex;
  justify-content: space-around;
  padding: 0 40rpx 48rpx;
}

.quick-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12rpx;
}

.quick-circle {
  width: 96rpx;
  height: 96rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.quick-circle .ph {
  font-size: 44rpx;
}

.quick-circle-gold {
  background-color: var(--color-brand-subtle);

  .ph {
    color: var(--color-brand);
  }
}

.quick-circle-green {
  background-color: var(--color-success-subtle);

  .ph {
    color: var(--color-success);
  }
}

.quick-circle-red {
  background-color: var(--color-danger-subtle);

  .ph {
    color: var(--color-danger);
  }
}

.quick-label {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

/* 连续打卡 */
.streak-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 36rpx;
}

.streak-title-wrap {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.streak-icon {
  font-size: 40rpx;
  color: var(--color-brand);
}

.streak-title {
  font-size: 30rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.streak-num-wrap {
  display: flex;
  align-items: baseline;
}

.streak-num {
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 700;
  color: var(--color-brand);
}

.streak-unit {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-left: 4rpx;
}

.streak-week {
  display: flex;
  justify-content: space-between;
}

.streak-day {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
}

.streak-dot {
  width: 56rpx;
  height: 56rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: var(--color-brand);
}

.streak-dot.today {
  background-color: rgba(201, 169, 110, 0.15);
  border: 4rpx dashed var(--color-brand);
  box-sizing: border-box;
}

.streak-check {
  color: #fff;
  font-size: 24rpx;
}

.streak-day-num {
  font-size: 20rpx;
  color: var(--color-brand);
  font-weight: 600;
}

.streak-day-label {
  font-size: 20rpx;
  color: var(--color-text-tertiary);
}

/* 小贴士 */
.tip-card {
  margin: 0 40rpx;
  border-radius: 28rpx;
  padding: 40rpx;
  border: 2rpx solid rgba(201, 169, 110, 0.15);
  background: linear-gradient(135deg, #FFFBF5 0%, #FDF6EC 100%);
  box-shadow: var(--shadow-convex);
}

.tip-head {
  display: flex;
  align-items: flex-start;
  gap: 24rpx;
  margin-bottom: 28rpx;
}

.tip-icon-wrap {
  width: 72rpx;
  height: 72rpx;
  border-radius: 20rpx;
  background-color: rgba(201, 169, 110, 0.12);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.tip-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

.tip-body {
  flex: 1;
}

.tip-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  margin-bottom: 12rpx;
  color: var(--color-text-primary);
}

.tip-text {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  line-height: 1.7;
}

.tip-sub {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}

.tip-btns {
  display: flex;
  gap: 16rpx;
}

.tip-btn-brand {
  flex: 1;
  padding: 20rpx;
  border-radius: 16rpx;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  color: #fff;
  font-size: 26rpx;
}

.tip-btn-ghost {
  flex: 1;
  padding: 20rpx;
  border-radius: 16rpx;
  background-color: var(--color-surface-alt);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  color: var(--color-text-secondary);
  font-size: 26rpx;
}

.tip-btn-icon {
  font-size: 32rpx;
}

/* 场景推荐 */
.scene-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.scene-stat {
  display: flex;
  align-items: center;
  gap: 8rpx;
  margin-top: 12rpx;
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

/* 最近拍摄 */
.recent-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.recent-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: 2rpx solid var(--color-divider);
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex);
}

.recent-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 133.33%;
  overflow: hidden;
  border-radius: 24rpx;
}

.recent-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.recent-tag {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  background-color: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(8px);
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
  display: flex;
  align-items: center;
  gap: 6rpx;
}

.recent-tag-icon {
  font-size: 20rpx;
  color: var(--color-brand);
}

.recent-tag-text {
  font-size: 20rpx;
  font-weight: 600;
  color: var(--color-brand);
}

.recent-match {
  position: absolute;
  bottom: 16rpx;
  right: 16rpx;
  background-color: rgba(26, 26, 26, 0.6);
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
}

.recent-match-text {
  font-size: 20rpx;
  font-weight: 500;
  color: #fff;
}

.recent-progress {
  position: absolute;
  bottom: 16rpx;
  right: 16rpx;
  background-color: var(--color-brand);
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
}

.recent-progress-text {
  font-size: 20rpx;
  font-weight: 500;
  color: #fff;
}

.recent-info {
  padding: 24rpx 28rpx 28rpx;
}

.recent-name {
  display: block;
  font-size: 26rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.recent-steps {
  display: flex;
  align-items: center;
  gap: 8rpx;
  margin-top: 12rpx;
}

.recent-steps-icon {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

.recent-steps-text {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

/* 统计 */
.stats-head {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 32rpx;
}

.stats-head-icon {
  font-size: 32rpx;
  color: var(--color-brand);
}

.stats-head-title {
  font-size: 26rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  text-align: center;
  gap: 32rpx;
}

.stats-item {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stats-item-mid {
  border-left: 2rpx solid var(--color-divider);
  border-right: 2rpx solid var(--color-divider);
}

.stats-item .lumira-stat-num {
  font-size: 56rpx;
}

/* 最近拍摄空状态 */
.recent-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: 56rpx;
  padding-bottom: 56rpx;
  gap: 16rpx;
}

.empty-icon {
  font-size: 96rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

.empty-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.empty-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-bottom: 16rpx;
}

.empty-btn {
  padding: 20rpx 48rpx;
  border-radius: 16rpx;
  display: inline-flex;
  align-items: center;
  gap: 12rpx;
  font-size: 28rpx;
}

.empty-btn .ph {
  font-size: 32rpx;
}
</style>
