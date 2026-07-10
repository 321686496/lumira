<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">为你推荐</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- Style Analysis Section -->
    <view class="analysis-wrap fade-up">
      <view class="analysis-card">
        <view class="analysis-head">
          <text class="ph ph-palette analysis-head-icon"></text>
          <text class="analysis-head-title">根据你的拍摄风格</text>
        </view>
        <text class="analysis-desc">分析你过往的 128 张作品，我们发现你偏爱以下风格</text>
        <view class="analysis-bars">
          <view class="analysis-bar-item" v-for="(s, i) in styleAnalysis" :key="i">
            <view class="analysis-bar-row">
              <view class="analysis-bar-label">
                <text class="ph analysis-bar-icon" :class="s.icon"></text>
                <text class="analysis-bar-name">{{ s.label }}</text>
              </view>
              <text class="analysis-bar-percent">{{ s.percent }}%</text>
            </view>
            <view class="lumira-progress">
              <view class="lumira-progress-fill" :style="{ width: s.percent + '%' }"></view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 猜你喜欢 Section -->
    <view class="recommend-section fade-up fade-up-d2">
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="ph ph-heart section-title-icon"></text>
          <text class="section-title-text">猜你喜欢</text>
        </view>
        <text class="lumira-section-link">
          <text>换一换</text>
          <text class="ph ph-arrows-clockwise"></text>
        </text>
      </view>
      <view class="section-pad">
        <view class="tpl-grid">
          <view class="tpl-card lumira-card-hover" v-for="(t, i) in guessLikes" :key="i" @click="goDetail">
            <view class="tpl-img-wrap">
              <image class="tpl-img" :src="t.img" mode="aspectFill" />
              <view class="match-badge">
                <text class="match-badge-text">{{ t.match }}</text>
              </view>
            </view>
            <view class="tpl-info">
              <text class="tpl-name">{{ t.name }}</text>
              <view class="tpl-reason-wrap">
                <text class="lumira-tag lumira-tag-green">{{ t.reason }}</text>
              </view>
              <view class="tpl-meta">
                <text class="tpl-meta-count">{{ t.count }}</text>
                <text class="tpl-meta-dot">·</text>
                <text class="lumira-tag" :class="t.levelCls">{{ t.level }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 相似用户也在拍 Section -->
    <view class="recommend-section fade-up fade-up-d3">
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="ph ph-users section-title-icon"></text>
          <text class="section-title-text">相似用户也在拍</text>
        </view>
        <text class="lumira-section-link">
          <text>查看全部</text>
          <text class="ph ph-arrow-right"></text>
        </text>
      </view>
      <view class="section-pad">
        <view class="tpl-grid">
          <view class="tpl-card lumira-card-hover" v-for="(t, i) in similarUsers" :key="i" @click="goDetail">
            <view class="tpl-img-wrap">
              <image class="tpl-img" :src="t.img" mode="aspectFill" />
            </view>
            <view class="tpl-info">
              <text class="tpl-name">{{ t.name }}</text>
              <view class="tpl-reason-wrap">
                <text class="lumira-tag lumira-tag-red">{{ t.usage }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 根据最近拍摄 Section -->
    <view class="recommend-section fade-up fade-up-d4">
      <view class="lumira-section-title section-pad">
        <view class="section-title-left">
          <text class="ph ph-clock section-title-icon"></text>
          <text class="section-title-text">根据最近拍摄</text>
        </view>
      </view>
      <view class="section-pad">
        <view class="recent-info-card">
          <view class="recent-info-img-wrap">
            <image class="recent-info-img" :src="recentShot.img" mode="aspectFill" />
          </view>
          <view class="recent-info-body">
            <text class="recent-info-title">{{ recentShot.text }}</text>
            <view class="recent-info-sub-row">
              <text class="recent-info-sub">{{ recentShot.sub }}</text>
              <text class="ph ph-arrow-right recent-info-arrow"></text>
            </view>
          </view>
        </view>
        <view class="tpl-grid">
          <view class="tpl-card lumira-card-hover" v-for="(t, i) in recentTemplates" :key="i" @click="goDetail">
            <view class="tpl-img-wrap">
              <image class="tpl-img" :src="t.img" mode="aspectFill" />
            </view>
            <view class="tpl-info">
              <text class="tpl-name">{{ t.name }}</text>
              <view class="tpl-reason-wrap">
                <text class="lumira-tag lumira-tag-green">{{ t.theme }}</text>
              </view>
              <view class="tpl-meta">
                <text class="tpl-meta-match">{{ t.match }}</text>
                <text class="tpl-meta-count">· {{ t.count }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- Bottom Spacer -->
    <view class="bottom-spacer"></view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const styleAnalysis = ref([
  { icon: 'ph-flower', label: '温柔', percent: 68 },
  { icon: 'ph-leaf', label: '清新', percent: 45 },
  { icon: 'ph-camera', label: '复古', percent: 32 }
])

const guessLikes = ref([
  { img: 'https://picsum.photos/seed/1038002/400/600', name: '牡丹花下', match: '匹配 96%', reason: '因为你喜欢温柔风格', count: '12 张', level: '易 新手', levelCls: 'lumira-tag-green' },
  { img: 'https://picsum.photos/seed/326473/400/600', name: '茶园春色', match: '匹配 92%', reason: '因为你喜欢清新品味', count: '9 张', level: '易 新手', levelCls: 'lumira-tag-green' },
  { img: 'https://picsum.photos/seed/1926769/400/600', name: '民国风情', match: '匹配 89%', reason: '因为你喜欢复古调性', count: '14 张', level: '中 进阶', levelCls: 'lumira-tag-gold' },
  { img: 'https://picsum.photos/seed/1239291/400/600', name: '白纱轻舞', match: '匹配 94%', reason: '因为你喜欢温柔风格', count: '11 张', level: '易 新手', levelCls: 'lumira-tag-green' },
  { img: 'https://picsum.photos/seed/326473/400/600', name: '植物园记', match: '匹配 87%', reason: '因为你喜欢清新品味', count: '13 张', level: '中 构图', levelCls: 'lumira-tag-gold' },
  { img: 'https://picsum.photos/seed/1926769/400/600', name: '旧上海', match: '匹配 85%', reason: '因为你喜欢复古调性', count: '16 张', level: '难 大师', levelCls: 'lumira-tag-gold' }
])

const similarUsers = ref([
  { img: 'https://picsum.photos/seed/326473/400/600', name: '晨雾森林', usage: '1,200+ 用户使用' },
  { img: 'https://picsum.photos/seed/1038002/400/600', name: '向日葵田', usage: '980+ 用户使用' },
  { img: 'https://picsum.photos/seed/172217/400/400', name: '书香午后', usage: '850+ 用户使用' },
  { img: 'https://picsum.photos/seed/457882/400/600', name: '海边栈道', usage: '720+ 用户使用' }
])

const recentShot = ref({
  img: 'https://picsum.photos/seed/2074130/400/600',
  text: '你昨天在咖啡馆拍了 3 张照片',
  sub: '试试这些咖啡馆模板吧'
})

const recentTemplates = ref([
  { img: 'https://picsum.photos/seed/2074130/400/600', name: '咖啡角落', theme: '咖啡馆主题', match: '匹配 91%', count: '10 张' },
  { img: 'https://picsum.photos/seed/2074130/400/600', name: '拉花艺术', theme: '咖啡馆主题', match: '匹配 86%', count: '8 张' },
  { img: 'https://picsum.photos/seed/2074130/400/600', name: '窗边阅读', theme: '咖啡馆主题', match: '匹配 88%', count: '12 张' },
  { img: 'https://picsum.photos/seed/2074130/400/600', name: '咖啡物语', theme: '咖啡馆主题', match: '匹配 82%', count: '6 张' }
])

const back = () => uni.navigateBack()
const goDetail = () => uni.navigateTo({ url: '/pages/templates/detail' })
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.section-pad {
  padding: 0 48rpx;
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

/* ===== Style Analysis ===== */
.analysis-wrap {
  padding: 48rpx 48rpx 0;
}

.analysis-card {
  background-color: $color-tag-gold-bg;
  border-radius: $radius-card;
  padding: 40rpx;
  border: 2rpx solid transparent;
}

.analysis-head {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 28rpx;
}

.analysis-head-icon {
  font-size: 36rpx;
  color: $color-text-primary;
}

.analysis-head-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.analysis-desc {
  display: block;
  font-size: 26rpx;
  color: $color-text-secondary;
  margin-bottom: 32rpx;
  line-height: 1.6;
}

.analysis-bars {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.analysis-bar-item {
  display: flex;
  flex-direction: column;
}

.analysis-bar-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12rpx;
}

.analysis-bar-label {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.analysis-bar-icon {
  font-size: 26rpx;
  color: $color-text-primary;
}

.analysis-bar-name {
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.analysis-bar-percent {
  font-size: 24rpx;
  color: $color-brand-primary;
  font-weight: 600;
}

/* ===== Recommend Sections ===== */
.recommend-section {
  margin-top: 56rpx;
}

/* ===== Template Grid ===== */
.tpl-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.tpl-card {
  display: flex;
  flex-direction: column;
}

.tpl-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 150%;
  overflow: hidden;
  border-radius: 20rpx;
}

.tpl-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.match-badge {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  background-color: $color-brand-primary;
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
}

.match-badge-text {
  font-size: 20rpx;
  font-weight: 600;
  color: #fff;
  letter-spacing: 0.04em;
}

.tpl-info {
  margin-top: 16rpx;
}

.tpl-name {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 28rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.tpl-reason-wrap {
  margin-top: 8rpx;
}

.tpl-meta {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-top: 8rpx;
}

.tpl-meta-count {
  font-size: 22rpx;
  color: $color-text-tertiary;
}

.tpl-meta-dot {
  font-size: 22rpx;
  color: $color-text-tertiary;
}

.tpl-meta-match {
  font-size: 22rpx;
  color: $color-brand-primary;
  font-weight: 500;
}

/* ===== Recent Info Card ===== */
.recent-info-card {
  background-color: $color-bg-surface;
  border-radius: $radius-card;
  padding: 32rpx;
  margin-bottom: 32rpx;
  display: flex;
  align-items: center;
  gap: 24rpx;
}

.recent-info-img-wrap {
  width: 112rpx;
  height: 112rpx;
  border-radius: 16rpx;
  overflow: hidden;
  flex-shrink: 0;
}

.recent-info-img {
  width: 100%;
  height: 100%;
}

.recent-info-body {
  flex: 1;
}

.recent-info-title {
  display: block;
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.recent-info-sub-row {
  display: flex;
  align-items: center;
  gap: 8rpx;
  margin-top: 4rpx;
}

.recent-info-sub {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

.recent-info-arrow {
  font-size: 24rpx;
  color: $color-text-tertiary;
}

.bottom-spacer {
  height: 64rpx;
}
</style>
