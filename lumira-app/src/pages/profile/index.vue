<template>
  <view class="lumira-container">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">我的</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 个人头部卡片 -->
      <view class="hero-card fade-up">
        <view class="hero-deco-1"></view>
        <view class="hero-deco-2"></view>

        <!-- 头像 -->
        <view class="avatar-wrap">
          <image class="avatar" src="https://picsum.photos/seed/733872/200/200" mode="aspectFill" />
          <view class="avatar-badge">
            <text class="ph ph-caret-up avatar-badge-icon"></text>
          </view>
        </view>

        <!-- 名字 -->
        <text class="hero-name">小美</text>

        <!-- 等级徽章 -->
        <view class="level-badge">
          <text class="ph ph-medal level-badge-icon"></text>
          <text class="level-badge-text">Lv.{{ growthData.level }} {{ growthData.levelName }}</text>
        </view>

        <!-- 经验进度 -->
        <view class="xp-wrap">
          <view class="xp-head">
            <text class="xp-label">经验</text>
            <text class="xp-value">{{ growthData.currentXp }} / {{ growthData.nextLevelXp }} XP</text>
          </view>
          <view class="xp-track">
            <view class="xp-fill" :style="{ width: growthData.progressPercent + '%' }"></view>
          </view>
          <text class="xp-tip">还差 {{ growthData.remainingXp }} XP 升级</text>
        </view>
      </view>

      <!-- 统计 Bento -->
      <view class="lumira-card stats-card fade-up fade-up-d1">
        <view class="stats-grid">
          <view class="stats-cell stats-cell-mid">
            <text class="stats-num">{{ totalPhotos }}</text>
            <text class="stats-label">拍摄作品</text>
          </view>
          <view class="stats-cell stats-cell-mid">
            <text class="stats-num">{{ usedTemplateCount }}</text>
            <text class="stats-label">使用模板</text>
          </view>
          <view class="stats-cell">
            <text class="stats-num">{{ favoriteCount }}</text>
            <text class="stats-label">收藏</text>
          </view>
        </view>
      </view>

      <!-- 碎片收集 -->
      <view class="lumira-card fragment-card fade-up fade-up-d2" @click="goFragments">
        <view class="lumira-section-title">
          <view class="fragment-title-wrap">
            <text class="ph ph-puzzle-piece fragment-title-icon"></text>
            <text class="fragment-title">碎片收集</text>
          </view>
          <text class="fragment-count">{{ fragmentCollected }}/{{ fragmentTotal }} 已集</text>
        </view>
        <view class="fragment-list">
          <view class="fragment-item" v-for="f in fragments" :key="f.name">
            <view class="fragment-row">
              <view class="fragment-name-wrap">
                <view class="fragment-icon-wrap">
                  <text class="ph fragment-icon" :class="f.icon"></text>
                </view>
                <text class="fragment-name">{{ f.name }}</text>
              </view>
              <text class="fragment-rate">{{ f.cur }}/5</text>
            </view>
            <view class="lumira-progress">
              <view class="lumira-progress-fill" :style="{ width: f.percent + '%' }"></view>
            </view>
          </view>
        </view>
        <view class="fragment-footer">
          <text class="fragment-footer-text">查看全部 · 导出海报</text>
          <text class="ph ph-caret-right fragment-footer-arrow"></text>
        </view>
      </view>

      <!-- 快捷入口 -->
      <view class="quick-row fade-up fade-up-d3">
        <view class="lumira-btn-ghost quick-btn" @click="goPage('/pages/profile/growth')">
          <text class="ph ph-trophy"></text>
          <text>成长中心</text>
        </view>
        <view class="lumira-btn-ghost quick-btn" @click="goPage('/pages/profile/invite')">
          <text class="ph ph-gift"></text>
          <text>邀请有礼</text>
        </view>
        <view class="lumira-btn-ghost quick-btn" @click="goPage('/pages/profile/academy')">
          <text class="ph ph-book-open"></text>
          <text>摄影美学院</text>
        </view>
      </view>

      <!-- 菜单列表 -->
      <view class="lumira-card menu-card fade-up fade-up-d4">
        <view class="lumira-list">
          <view class="lumira-list-item" @click="goPage('/pages/gallery/index')">
            <view class="lumira-list-icon">
              <text class="ph ph-image"></text>
            </view>
            <view class="lumira-list-text">
              <text class="lumira-list-title">我的相册</text>
            </view>
            <text class="lumira-list-arrow"><text class="ph ph-caret-right"></text></text>
          </view>
          <view class="lumira-list-item" @click="goPage('/pages/profile/my-templates')">
            <view class="lumira-list-icon">
              <text class="ph ph-stack"></text>
            </view>
            <view class="lumira-list-text">
              <text class="lumira-list-title">我的模板</text>
            </view>
            <text class="lumira-list-arrow"><text class="ph ph-caret-right"></text></text>
          </view>
          <view class="lumira-list-item">
            <view class="lumira-list-icon">
              <text class="ph ph-map-trifold"></text>
            </view>
            <view class="lumira-list-text">
              <text class="lumira-list-title">场景管理</text>
            </view>
            <text class="lumira-list-arrow"><text class="ph ph-caret-right"></text></text>
          </view>
          <view class="lumira-list-item">
            <view class="lumira-list-icon">
              <text class="ph ph-download-simple"></text>
            </view>
            <view class="lumira-list-text">
              <text class="lumira-list-title">导入模板</text>
            </view>
            <text class="lumira-list-arrow"><text class="ph ph-caret-right"></text></text>
          </view>
          <view class="lumira-list-item" @click="goPage('/pages/profile/settings')">
            <view class="lumira-list-icon">
              <text class="ph ph-gear"></text>
            </view>
            <view class="lumira-list-text">
              <text class="lumira-list-title">设置</text>
            </view>
            <text class="lumira-list-arrow"><text class="ph ph-caret-right"></text></text>
          </view>
          <view class="lumira-list-item lumira-list-item-last">
            <view class="lumira-list-icon">
              <text class="ph ph-info"></text>
            </view>
            <view class="lumira-list-text">
              <text class="lumira-list-title">关于如画</text>
            </view>
            <text class="lumira-list-arrow"><text class="ph ph-caret-right"></text></text>
          </view>
        </view>
      </view>
    </view>

    <FloatingTabBar active="profile" />
  </view>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useGrowth } from '@/composables/useGrowth'
import { useSceneManager } from '@/composables/useSceneManager'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { SceneCategory } from '@/types/template'

const {
  growthData,
  totalPhotos,
  usedTemplateCount,
  favoriteCount,
} = useGrowth()

const { photos } = useSceneManager()

/** 场景分类碎片定义 */
const FRAGMENT_DEFS: { category: SceneCategory; name: string; icon: string }[] = [
  { category: 'light', name: '光线', icon: 'ph-sun' },
  { category: 'outdoor', name: '室外', icon: 'ph-mountains' },
  { category: 'indoor', name: '室内', icon: 'ph-house' },
  { category: 'mood', name: '情绪', icon: 'ph-heart' },
]

/** 每个分类下有多个场景，拍摄 5 张解锁该分类碎片 */
const FRAGMENT_TARGET = 5

/** 计算各分类碎片进度 */
const fragments = computed(() => {
  const sceneCategoryMap = new Map<string, SceneCategory>()
  SCENE_PRESETS.forEach(s => {
    sceneCategoryMap.set(s.id, s.category)
  })

  const counts: Record<string, number> = {}
  photos.value.forEach(p => {
    if (p.sceneId) {
      const cat = sceneCategoryMap.get(p.sceneId)
      if (cat) {
        counts[cat] = (counts[cat] || 0) + 1
      }
    }
  })

  return FRAGMENT_DEFS.map(def => {
    const cur = Math.min(counts[def.category] || 0, FRAGMENT_TARGET)
    return {
      name: def.name,
      icon: def.icon,
      cur,
      percent: Math.round((cur / FRAGMENT_TARGET) * 100),
    }
  })
})

/** 已集齐的碎片数 */
const fragmentCollected = computed(() => fragments.value.filter(f => f.cur >= FRAGMENT_TARGET).length)

/** 总碎片数 */
const fragmentTotal = FRAGMENT_DEFS.length

const goPage = (url: string) => uni.navigateTo({ url })
const goFragments = () => uni.navigateTo({ url: '/pages/profile/fragments' })
</script>

<style lang="scss" scoped>
.page-body {
  padding: 48rpx 40rpx;
}

/* 头部卡片 */
.hero-card {
  position: relative;
  overflow: hidden;
  border-radius: 48rpx;
  padding: 64rpx 48rpx 48rpx;
  text-align: center;
  margin-bottom: 32rpx;
  background: linear-gradient(145deg, #FFF8EE 0%, #F5EDDB 40%, #EDE3D0 100%);
  border: 2rpx solid rgba(201, 169, 110, 0.12);
  box-shadow: 0 8rpx 48rpx rgba(201, 169, 110, 0.08), 0 2rpx 4rpx rgba(0, 0, 0, 0.02);
}

.hero-deco-1 {
  position: absolute;
  top: -80rpx;
  right: -80rpx;
  width: 240rpx;
  height: 240rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.06);
  pointer-events: none;
}

.hero-deco-2 {
  position: absolute;
  bottom: -60rpx;
  left: -40rpx;
  width: 160rpx;
  height: 160rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.04);
  pointer-events: none;
}

.avatar-wrap {
  position: relative;
  display: inline-block;
  margin-bottom: 32rpx;
}

.avatar {
  width: 176rpx;
  height: 176rpx;
  border-radius: 50%;
  border: 6rpx solid #fff;
  box-shadow: 0 8rpx 32rpx rgba(201, 169, 110, 0.2);
}

.avatar-badge {
  position: absolute;
  bottom: 4rpx;
  right: 4rpx;
  width: 44rpx;
  height: 44rpx;
  border-radius: 50%;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  border: 5rpx solid #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}

.avatar-badge-icon {
  color: #fff;
  font-size: 20rpx;
}

.hero-name {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 48rpx;
  font-weight: 600;
  color: #3D2817;
  margin-bottom: 20rpx;
  letter-spacing: 0.02em;
}

.level-badge {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 10rpx 28rpx;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, #F5EDDB 0%, #EDE0C8 100%);
  border: 2rpx solid rgba(140, 115, 64, 0.15);
  margin-bottom: 40rpx;
}

.level-badge-icon {
  font-size: 26rpx;
  color: #8C7340;
}

.level-badge-text {
  font-size: 24rpx;
  font-weight: 600;
  color: #8C7340;
  letter-spacing: 0.04em;
}

.xp-wrap {
  max-width: 520rpx;
  margin: 0 auto;
}

.xp-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16rpx;
}

.xp-label {
  font-size: 24rpx;
  color: #8C7340;
  font-weight: 500;
}

.xp-value {
  font-size: 24rpx;
  color: #8C7340;
  font-family: 'Courier New', monospace;
  font-weight: 600;
}

.xp-track {
  width: 100%;
  height: 12rpx;
  border-radius: 6rpx;
  background: rgba(201, 169, 110, 0.18);
  overflow: hidden;
}

.xp-fill {
  height: 100%;
  background: linear-gradient(90deg, #C9A96E 0%, #D4B57A 100%);
  border-radius: 6rpx;
}

.xp-tip {
  display: block;
  font-size: 22rpx;
  color: #B89860;
  margin-top: 16rpx;
  letter-spacing: 0.02em;
}

/* 统计 Bento */
.stats-card {
  margin-bottom: 32rpx;
  padding: 0;
  overflow: hidden;
}

.stats-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  text-align: center;
}

.stats-cell {
  padding: 44rpx 16rpx;
  position: relative;
}

.stats-cell-mid::after {
  content: '';
  position: absolute;
  right: 0;
  top: 48rpx;
  bottom: 48rpx;
  width: 2rpx;
  background: var(--color-divider);
}

.stats-num {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 52rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1;
}

.stats-label {
  display: block;
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 12rpx;
  letter-spacing: 0.04em;
}

/* 碎片收集 */
.fragment-card {
  margin-bottom: 32rpx;
}

.fragment-title-wrap {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.fragment-title-icon {
  font-size: 32rpx;
  color: var(--color-brand);
}

.fragment-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.fragment-count {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.fragment-list {
  display: flex;
  flex-direction: column;
  gap: 32rpx;
}

.fragment-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12rpx;
}

.fragment-name-wrap {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.fragment-icon-wrap {
  width: 56rpx;
  height: 56rpx;
  border-radius: 16rpx;
  background: rgba(201, 169, 110, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
}

.fragment-icon {
  font-size: 28rpx;
  color: var(--color-brand);
}

.fragment-name {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  font-weight: 500;
}

.fragment-rate {
  font-size: 24rpx;
  font-family: 'Courier New', monospace;
  color: var(--color-text-tertiary);
  font-weight: 600;
}

/* 快捷入口 */
.quick-row {
  display: flex;
  gap: 16rpx;
  margin-bottom: 32rpx;
}

.quick-btn {
  flex: 1;
  justify-content: center;
}

.quick-btn .ph {
  font-size: 32rpx;
}

/* 菜单列表 */
.menu-card {
  padding: 16rpx 32rpx;
}

.lumira-list {
  display: flex;
  flex-direction: column;
}

.lumira-list-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 0;
  border-bottom: 2rpx solid var(--color-divider);
}

.lumira-list-item-last {
  border-bottom: none;
}

.lumira-list-item:active {
  opacity: 0.7;
}

.lumira-list-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background: var(--color-surface-alt);
}

.lumira-list-icon .ph {
  font-size: 40rpx;
  color: var(--color-brand);
}

.lumira-list-text {
  flex: 1;
  min-width: 0;
}

.lumira-list-title {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.lumira-list-arrow {
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

.lumira-list-arrow .ph {
  font-size: 28rpx;
}
</style>
