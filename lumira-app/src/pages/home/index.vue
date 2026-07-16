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
            <text class="streak-num">7</text>
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
            <text class="tip-text">侧逆光人像：让模特侧向镜头，让自然光从侧面打在脸上，显瘦又自然。</text>
            <text class="tip-sub">— 适合午后窗边或户外树下</text>
          </view>
        </view>
        <view class="tip-btns">
          <view class="tip-btn-brand" @click="goCapture">
            <text class="ph ph-camera tip-btn-icon"></text>
            <text>试试</text>
          </view>
          <view class="tip-btn-ghost">
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
          <text class="lumira-section-link" @click="goSceneFav">收藏</text>
          <text class="lumira-section-link" @click="goSceneManage">管理</text>
        </view>
      </view>
      <view class="scene-grid section-pad">
        <view class="scene-card lumira-card-hover" v-for="s in scenes" :key="s.name" @click="goPage(`/pages/capture/scene-guide?scene=${s.scene}`)">
          <view class="scene-img-wrap">
            <image class="scene-img" :src="s.img" mode="aspectFill" />
            <view class="scene-badge" :class="{ 'scene-badge-brand': s.brand }">
              <text class="scene-badge-text">{{ s.tag }}</text>
            </view>
          </view>
          <view class="scene-info">
            <text class="scene-name">{{ s.name }}</text>
            <text class="scene-desc">{{ s.desc }}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 最近拍摄 -->
    <view class="section fade-up">
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="section-title-text">最近拍摄</text>
          <text class="lumira-tag lumira-tag-gold">
            <text class="ph ph-sparkle"></text>
            <text>为你甄选</text>
          </text>
        </view>
        <text class="lumira-section-link" @click="goPage('/pages/gallery/index')">全部</text>
      </view>
      <view class="recent-grid section-pad">
        <view class="recent-card lumira-card-hover" v-for="r in recents" :key="r.name" @click="goPage('/pages/gallery/detail')">
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
            <text class="lumira-stat-num">12</text>
            <text class="lumira-stat-label">收藏</text>
          </view>
          <view class="stats-item stats-item-mid">
            <text class="lumira-stat-num">8.5k</text>
            <text class="lumira-stat-label">获赞</text>
          </view>
          <view class="stats-item">
            <text class="lumira-stat-num">47</text>
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
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import { useSceneManager } from '@/composables/useSceneManager'

const { customScenes } = useSceneManager()

const weekDays = ref([
  { label: '一', done: true, today: false },
  { label: '二', done: true, today: false },
  { label: '三', done: true, today: false },
  { label: '四', done: true, today: false },
  { label: '五', done: true, today: false },
  { label: '六', done: true, today: false },
  { label: '日', done: false, today: true }
])

const scenes = computed(() => {
  const customs = customScenes.value.slice(0, 4).map(c => ({
    name: c.name,
    desc: c.description,
    img: `https://picsum.photos/seed/scene-home-${c.id}/400/600`,
    tag: '我的场景',
    brand: false,
    scene: c.id
  }))
  const presets = SCENE_PRESETS.slice(0, 4).map((p, i) => ({
    name: p.name,
    desc: p.description,
    img: `https://picsum.photos/seed/scene-home-${p.id}/400/600`,
    tag: i === 0 ? '你最常去' : i === 2 ? '新场景推荐' : `${p.name}拍摄`,
    brand: i === 2,
    scene: p.id
  }))
  return [...customs, ...presets].slice(0, 4)
})

const recents = ref([
  { name: '自然光人像', cat: '人像', icon: 'ph-user', img: 'https://picsum.photos/seed/recent-portrait/400/600', steps: 12, match: '98% 匹配', progress: '' },
  { name: '复古胶片感', cat: '胶片', icon: 'ph-film-strip', img: 'https://picsum.photos/seed/recent-film/400/600', steps: 8, match: '', progress: '' },
  { name: '窗边咖啡时光', cat: '咖啡馆半身', icon: 'ph-coffee', img: 'https://picsum.photos/seed/recent-cafe/400/600', steps: 15, match: '', progress: '' },
  { name: '氛围感人像', cat: '人像氛围', icon: 'ph-sparkle', img: 'https://picsum.photos/seed/recent-mood/400/600', steps: 15, match: '', progress: '进行中' },
  { name: '黄金时刻风光', cat: '风光', icon: 'ph-mountain', img: 'https://picsum.photos/seed/recent-landscape/400/600', steps: 10, match: '', progress: '' }
])

const goTab = (url: string) => uni.reLaunch({ url })
const goPage = (url: string) => uni.navigateTo({ url })
const goCapture = () => uni.navigateTo({ url: '/pages/capture/index' })
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

.scene-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: 2rpx solid var(--color-divider);
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex);
}

.scene-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 133.33%;
  overflow: hidden;
  border-radius: 24rpx;
}

.scene-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.scene-badge {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  background-color: rgba(26, 26, 26, 0.6);
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
}

.scene-badge-brand {
  background-color: var(--color-brand);
}

.scene-badge-text {
  font-size: 20rpx;
  font-weight: 500;
  color: #fff;
  letter-spacing: 0.04em;
}

.scene-info {
  padding: 24rpx 28rpx 28rpx;
}

.scene-name {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.scene-desc {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
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
</style>
