<template>
  <view class="lumira-container">
    <!-- NAVBAR (Tab页，无返回按钮) -->
    <view class="lumira-nav">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">模板库</text>
      <view class="lumira-nav-right">
        <text class="ph ph-magnifying-glass nav-icon"></text>
      </view>
    </view>

    <!-- HERO -->
    <view class="hero-wrap fade-up">
      <view class="hero-card">
        <view class="hero-deco"></view>
        <view class="hero-deco-2"></view>
        <view class="hero-body">
          <text class="hero-title">模板库</text>
          <text class="hero-desc">108 个模板等你探索</text>
          <view class="hero-pill">
            <text class="ph ph-lock-simple-open hero-pill-icon"></text>
            <text class="hero-pill-text">已解锁 {{ unlockedCount }} 个</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 分类横滑pill -->
    <view class="cat-scroll fade-up fade-up-d1">
      <scroll-view scroll-x class="cat-scroll-inner" :show-scrollbar="false">
        <view class="cat-pill" :class="{ active: activeCategory === 'all' }" @click="activeCategory = 'all'">
          <text class="cat-pill-text">全部</text>
        </view>
        <view class="cat-pill" :class="{ active: activeCategory === cat }" v-for="cat in categories" :key="cat" @click="activeCategory = cat">
          <text class="cat-pill-text">{{ cat }}</text>
        </view>
      </scroll-view>
    </view>

    <!-- 免费模板 -->
    <view class="section fade-up fade-up-d2">
      <view class="lumira-section-title section-pad">
        <view class="title-left">
          <text class="title-text">免费模板</text>
          <text class="lumira-tag lumira-tag-green">免费</text>
        </view>
        <text class="lumira-section-link">全部</text>
      </view>
      <view class="tpl-grid section-pad">
        <view class="tpl-card lumira-card-hover" v-for="t in freeTemplates" :key="t.name" @click="goDetail">
          <view class="tpl-img-wrap">
            <image class="tpl-img" :src="t.img" mode="aspectFill" />
            <view class="tpl-badge-free">
              <text class="tpl-badge-free-text">免费</text>
            </view>
          </view>
          <view class="tpl-info">
            <text class="tpl-name">{{ t.name }}</text>
            <view class="tpl-meta">
              <text class="tpl-cat">{{ t.category }}</text>
              <text class="tpl-steps">{{ t.steps }} 步</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 精选模板 -->
    <view class="section fade-up fade-up-d3">
      <view class="lumira-section-title section-pad">
        <view class="title-left">
          <text class="title-text">精选模板</text>
          <text class="lumira-tag lumira-tag-gold">精选</text>
        </view>
        <text class="lumira-section-link">全部</text>
      </view>
      <view class="tpl-grid section-pad">
        <view class="tpl-card lumira-card-hover" v-for="t in premiumTemplates" :key="t.name" @click="t.unlocked ? goDetail() : goUnlock()">
          <view class="tpl-img-wrap">
            <image class="tpl-img" :src="t.img" mode="aspectFill" />
            <view class="tpl-badge-premium">
              <text class="ph ph-star tpl-badge-icon"></text>
              <text class="tpl-badge-text">精选</text>
            </view>
            <view v-if="!t.unlocked" class="tpl-lock">
              <text class="ph ph-lock tpl-lock-icon"></text>
            </view>
            <view v-else class="tpl-unlocked">
              <text class="ph ph-check tpl-unlocked-icon"></text>
            </view>
          </view>
          <view class="tpl-info">
            <text class="tpl-name">{{ t.name }}</text>
            <view class="tpl-meta">
              <text class="tpl-cat">{{ t.category }}</text>
              <text class="tpl-steps">{{ t.steps }} 步</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 大师模板 -->
    <view class="section fade-up fade-up-d4">
      <view class="lumira-section-title section-pad">
        <view class="title-left">
          <text class="title-text">大师模板</text>
          <text class="lumira-tag lumira-tag-gold">大师</text>
        </view>
        <text class="lumira-section-link">全部</text>
      </view>
      <view class="tpl-grid section-pad">
        <view class="tpl-card lumira-card-hover" v-for="t in masterTemplates" :key="t.name" @click="goUnlock">
          <view class="tpl-img-wrap">
            <image class="tpl-img" :src="t.img" mode="aspectFill" />
            <view class="tpl-badge-master">
              <text class="ph ph-diamond tpl-badge-icon"></text>
              <text class="tpl-badge-text">大师</text>
            </view>
            <view class="tpl-lock">
              <text class="ph ph-lock tpl-lock-icon"></text>
            </view>
          </view>
          <view class="tpl-info">
            <text class="tpl-name">{{ t.name }}</text>
            <view class="tpl-meta">
              <text class="tpl-cat">{{ t.category }}</text>
              <text class="tpl-steps">{{ t.steps }} 步</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 精选合集 -->
    <view class="section fade-up fade-up-d5">
      <view class="lumira-section-title section-pad">
        <view class="title-left">
          <text class="title-text">精选合集</text>
        </view>
        <text class="lumira-section-link">全部</text>
      </view>
      <view class="col-list section-pad">
        <view class="col-card lumira-card-hover" v-for="col in collections" :key="col.name" @click="goDetail">
          <view class="col-img-wrap">
            <image class="col-img" :src="col.img" mode="aspectFill" />
          </view>
          <view class="col-body">
            <text class="col-name">{{ col.name }}</text>
            <text class="col-desc">{{ col.desc }}</text>
            <text class="col-count">{{ col.count }} 个模板</text>
          </view>
          <text class="ph ph-caret-right col-arrow"></text>
        </view>
      </view>
    </view>

    <!-- 本周新上架 -->
    <view class="section fade-up">
      <view class="lumira-section-title section-pad">
        <view class="title-left">
          <text class="title-text">本周新上架</text>
        </view>
        <text class="lumira-section-link">全部</text>
      </view>
      <view class="section-pad">
        <view class="new-tag-row">
          <text class="lumira-tag lumira-tag-gold">
            <text class="ph ph-sparkle"></text>
            <text>本周新增 6 个模板</text>
          </text>
        </view>
        <view class="new-list">
          <view class="new-card lumira-card-hover" v-for="n in newTemplates" :key="n.name" @click="goDetail">
            <view class="new-img-wrap">
              <image class="new-img" :src="n.img" mode="aspectFill" />
            </view>
            <view class="new-body">
              <view class="new-title-row">
                <text class="new-name">{{ n.name }}</text>
                <text class="new-badge">NEW</text>
              </view>
              <text class="new-desc">{{ n.desc }}</text>
            </view>
            <text class="ph ph-caret-right new-arrow"></text>
          </view>
        </view>
      </view>
    </view>

    <FloatingTabBar active="templates" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import FloatingTabBar from '@/components/FloatingTabBar.vue'

const categories = ref(['人像', '风光', '美食', '夜景', '街拍', '旅行'])
const activeCategory = ref('all')

const freeTemplates = ref([
  { name: '自然光人像', category: '人像', img: 'https://picsum.photos/seed/tpl-free-1/400/600', steps: 12 },
  { name: '三分法构图', category: '构图', img: 'https://picsum.photos/seed/tpl-free-2/400/600', steps: 10 },
  { name: '街拍光影', category: '街拍', img: 'https://picsum.photos/seed/tpl-free-3/400/600', steps: 8 },
  { name: '美食特写', category: '美食', img: 'https://picsum.photos/seed/tpl-free-4/400/600', steps: 6 },
  { name: '黄金时刻', category: '风光', img: 'https://picsum.photos/seed/tpl-free-5/400/600', steps: 14 },
  { name: '夜景灯光', category: '夜景', img: 'https://picsum.photos/seed/tpl-free-6/400/600', steps: 16 }
])

const premiumTemplates = ref([
  { name: '日系胶片', category: '人像', img: 'https://picsum.photos/seed/tpl-prem-1/400/600', steps: 18, unlocked: true },
  { name: '法式复古', category: '人像', img: 'https://picsum.photos/seed/tpl-prem-2/400/600', steps: 20, unlocked: true },
  { name: '氛围感写真', category: '人像', img: 'https://picsum.photos/seed/tpl-prem-3/400/600', steps: 15, unlocked: true },
  { name: '电影调色', category: '风光', img: 'https://picsum.photos/seed/tpl-prem-4/400/600', steps: 22, unlocked: false },
  { name: '胶片质感', category: '街拍', img: 'https://picsum.photos/seed/tpl-prem-5/400/600', steps: 16, unlocked: false },
  { name: '光影人像', category: '人像', img: 'https://picsum.photos/seed/tpl-prem-6/400/600', steps: 19, unlocked: false }
])

const masterTemplates = ref([
  { name: '电影级调色', category: '风光', img: 'https://picsum.photos/seed/tpl-master-1/400/600', steps: 25 },
  { name: '大师人像', category: '人像', img: 'https://picsum.photos/seed/tpl-master-2/400/600', steps: 28 },
  { name: '杂志封面', category: '人像', img: 'https://picsum.photos/seed/tpl-master-3/400/600', steps: 30 },
  { name: '艺术光影', category: '夜景', img: 'https://picsum.photos/seed/tpl-master-4/400/600', steps: 26 }
])

const collections = ref([
  { name: '人像摄影全攻略', desc: '从构图到后期，一站式掌握', img: 'https://picsum.photos/seed/col-1/200/200', count: 24 },
  { name: '胶片质感调色', desc: '复古胶片色彩还原指南', img: 'https://picsum.photos/seed/col-2/200/200', count: 18 },
  { name: '街拍实战手册', desc: '城市光影捕捉技巧', img: 'https://picsum.photos/seed/col-3/200/200', count: 32 }
])

const newTemplates = ref([
  { name: '夏日清新人像', desc: '明亮通透的夏日风格', img: 'https://picsum.photos/seed/new-1/200/200' },
  { name: '夕阳剪影', desc: '黄金时刻逆光拍摄', img: 'https://picsum.photos/seed/new-2/200/200' },
  { name: '雨后街景', desc: '湿润光影氛围感', img: 'https://picsum.photos/seed/new-3/200/200' }
])

const unlockedCount = computed(() => {
  const free = freeTemplates.value.length
  const prem = premiumTemplates.value.filter(t => t.unlocked).length
  return free + prem
})

const goDetail = () => uni.navigateTo({ url: '/pages/templates/detail' })
const goUnlock = () => uni.navigateTo({ url: '/pages/templates/unlock' })
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.section-pad {
  padding: 0 40rpx;
}

.section {
  margin-bottom: 48rpx;
}

.title-left {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

/* Hero */
.hero-wrap {
  padding: 0 40rpx 32rpx;
}

.hero-card {
  position: relative;
  background: linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%);
  border-radius: 40rpx;
  padding: 56rpx 48rpx;
  overflow: hidden;
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

.hero-deco-2 {
  position: absolute;
  bottom: -40rpx;
  left: -40rpx;
  width: 200rpx;
  height: 200rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.06);
}

.hero-body {
  position: relative;
  z-index: 1;
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
  margin-bottom: 24rpx;
}

.hero-pill {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 10rpx 24rpx;
  border-radius: 9999rpx;
  background-color: rgba(255, 255, 255, 0.6);
}

.hero-pill-icon {
  font-size: 26rpx;
  color: var(--color-brand);
}

.hero-pill-text {
  font-size: 24rpx;
  color: var(--color-text-secondary);
  font-weight: 500;
}

/* 分类pill */
.cat-scroll {
  padding-bottom: 24rpx;
}

.cat-scroll-inner {
  white-space: nowrap;
  padding: 0 40rpx;
}

.cat-pill {
  display: inline-flex;
  align-items: center;
  padding: 14rpx 36rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
  margin-right: 16rpx;
  box-shadow: var(--shadow-convex-subtle);
  border: none;
}

.cat-pill.active {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  box-shadow: var(--shadow-pressed);
}

.cat-pill-text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.cat-pill.active .cat-pill-text {
  color: #fff;
  font-weight: 500;
}

/* 模板网格 */
.tpl-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.tpl-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: none;
  background-color: var(--color-surface);
  box-shadow: var(--shadow-convex);
}

.tpl-img-wrap {
  width: 100%;
  padding-bottom: 133.33%;
  position: relative;
  overflow: hidden;
}

.tpl-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.tpl-badge-free {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  background-color: rgba(90, 122, 72, 0.85);
}

.tpl-badge-free-text {
  font-size: 22rpx;
  font-weight: 600;
  color: #fff;
}

.tpl-badge-premium {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  background-color: rgba(201, 169, 110, 0.85);
  display: flex;
  align-items: center;
  gap: 6rpx;
}

.tpl-badge-master {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  background-color: rgba(26, 26, 26, 0.75);
  display: flex;
  align-items: center;
  gap: 6rpx;
}

.tpl-badge-icon {
  font-size: 22rpx;
  color: #fff;
}

.tpl-badge-text {
  font-size: 22rpx;
  font-weight: 600;
  color: #fff;
}

.tpl-lock {
  position: absolute;
  bottom: 16rpx;
  right: 16rpx;
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background-color: rgba(26, 26, 26, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
}

.tpl-lock-icon {
  font-size: 24rpx;
  color: #fff;
}

.tpl-unlocked {
  position: absolute;
  bottom: 16rpx;
  right: 16rpx;
  width: 48rpx;
  height: 48rpx;
  border-radius: 50%;
  background-color: rgba(90, 122, 72, 0.85);
  display: flex;
  align-items: center;
  justify-content: center;
}

.tpl-unlocked-icon {
  font-size: 24rpx;
  color: #fff;
}

.tpl-info {
  padding: 24rpx 28rpx 28rpx;
}

.tpl-name {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.tpl-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 12rpx;
}

.tpl-cat {
  font-size: 22rpx;
  color: var(--color-brand);
}

.tpl-steps {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
}

/* 合集列表 */
.col-list {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.col-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: 2rpx solid var(--color-divider);
  background-color: var(--color-surface);
  box-shadow: var(--shadow-convex);
  display: flex;
  padding: 24rpx;
  gap: 24rpx;
  align-items: center;
}

.col-img-wrap {
  width: 120rpx;
  height: 120rpx;
  border-radius: 20rpx;
  overflow: hidden;
  flex-shrink: 0;
}

.col-img {
  width: 100%;
  height: 100%;
}

.col-body {
  flex: 1;
  min-width: 0;
}

.col-name {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.col-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}

.col-count {
  display: block;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  margin-top: 12rpx;
}

.col-arrow {
  color: var(--color-text-tertiary);
  font-size: 36rpx;
  flex-shrink: 0;
}

/* 新模板 */
.new-tag-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 8rpx 0 16rpx;
  margin-bottom: 24rpx;
}

.new-list {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.new-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: 2rpx solid var(--color-divider);
  background-color: var(--color-surface);
  box-shadow: var(--shadow-convex);
  display: flex;
  padding: 24rpx;
  gap: 24rpx;
  align-items: center;
}

.new-img-wrap {
  width: 128rpx;
  height: 128rpx;
  border-radius: 20rpx;
  overflow: hidden;
  flex-shrink: 0;
}

.new-img {
  width: 100%;
  height: 100%;
}

.new-body {
  flex: 1;
  min-width: 0;
}

.new-title-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.new-name {
  font-size: 28rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.new-badge {
  font-size: 20rpx;
  color: var(--color-brand);
  background-color: rgba(201, 169, 110, 0.12);
  padding: 4rpx 12rpx;
  border-radius: 9999rpx;
}

.new-desc {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
}

.new-arrow {
  color: var(--color-text-tertiary);
  font-size: 36rpx;
  flex-shrink: 0;
}
</style>
