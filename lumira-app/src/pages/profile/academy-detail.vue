<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">教程</text>
      <view class="lumira-nav-right">
        <view class="lumira-nav-btn" @click="toggleBookmark">
          <text class="ph nav-bookmark-icon" :class="bookmarked ? 'ph-bookmark-simple' : 'ph-bookmark'"></text>
        </view>
      </view>
    </view>

    <!-- 课程标题 -->
    <view class="lesson-head fade-up">
      <text class="lesson-title">第1课 · 找到你的最佳角度</text>
      <text class="lesson-meta">8分钟 · 进阶入门</text>
    </view>

    <!-- 头图 -->
    <view class="hero-img-wrap fade-up fade-up-d1">
      <image class="hero-img" src="https://picsum.photos/seed/733872/400/600" mode="aspectFill" />
    </view>

    <view class="content-body">
      <!-- 章节 1 -->
      <view class="section fade-up fade-up-d2">
        <text class="section-h2">为什么角度很重要</text>
        <text class="section-p">同样的场景、同样的光线，仅仅因为拍摄角度的不同，照片效果可能天差地别。找到你身上最自信的角度，是出片的第一步。</text>
        <text class="section-p">每个人的脸型、身材比例不同，适合的角度也不同。但有一些通用法则可以让你快速找到自己的「最佳出片位」。</text>
      </view>

      <!-- 技巧卡片 -->
      <view class="lumira-card tip-card fade-up fade-up-d3">
        <view class="tip-tag-row">
          <view class="lumira-tag lumira-tag-gold">
            <text class="ph ph-sparkle"></text>
            <text>技巧</text>
          </view>
        </view>
        <text class="tip-card-title">45度角拍摄</text>
        <text class="tip-card-p">微微侧身45度，下巴略微前伸，可以让脸部轮廓更立体。这个角度适合绝大多数脸型，尤其对圆脸非常友好。</text>
        <view class="tip-img-wrap">
          <image class="tip-img" src="https://picsum.photos/seed/733872/400/600" mode="aspectFill" />
        </view>
      </view>

      <!-- 章节 2 对比 -->
      <view class="section fade-up fade-up-d4">
        <text class="section-h2">俯拍 vs 平拍</text>
        <text class="section-p">两种最常见角度的效果对比：</text>

        <view class="compare-grid">
          <view class="compare-cell">
            <text class="ph ph-arrow-down compare-icon"></text>
            <text class="compare-name">俯拍</text>
            <text class="compare-desc">相机在眼睛上方，从上往下拍。显脸小、显头身比好。</text>
            <view class="lumira-tag lumira-tag-green compare-tag">
              <text>推荐</text>
            </view>
          </view>
          <view class="compare-cell">
            <text class="ph ph-arrows-left-right compare-icon"></text>
            <text class="compare-name">平拍</text>
            <text class="compare-desc">相机与眼睛平齐。真实还原，适合证件照、正面照。</text>
            <view class="lumira-tag lumira-tag-gold compare-tag">
              <text>中性</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 章节 3 实战练习 -->
      <view class="lumira-card practice-card fade-in">
        <view class="practice-tag-row">
          <view class="lumira-badge lumira-badge-brand">实战练习</view>
        </view>
        <text class="practice-title">试试这个练习</text>
        <text class="practice-p">打开如画，选择「街拍回眸」模板，在自然光下尝试俯拍角度，拍摄3张不同角度的照片。</text>
        <view class="practice-tags">
          <view class="lumira-tag lumira-tag-gold">
            <text class="ph ph-camera"></text>
            <text>街拍</text>
          </view>
          <view class="lumira-tag lumira-tag-green">
            <text class="ph ph-sun"></text>
            <text>自然光</text>
          </view>
          <view class="lumira-tag lumira-tag-red">
            <text class="ph ph-arrow-down"></text>
            <text>俯拍</text>
          </view>
        </view>
      </view>

      <!-- 章节 4 小贴士 -->
      <view class="section fade-in">
        <text class="section-h2">小贴士</text>
        <view class="tips-card">
          <view class="tip-line" v-for="(tip, i) in tips" :key="i">
            <text class="tip-dot">•</text>
            <text class="tip-line-text">{{ tip }}</text>
          </view>
        </view>
      </view>

      <!-- 推荐模板 -->
      <view class="recommend-section">
        <view class="lumira-section-title">
          <text class="section-title-text">推荐模板</text>
        </view>
        <view class="lumira-card lumira-card-hover recommend-card" @click="goTemplate">
          <view class="recommend-img-wrap">
            <image class="recommend-img" src="https://picsum.photos/seed/1926769/400/600" mode="aspectFill" />
          </view>
          <view class="recommend-row">
            <view class="recommend-info">
              <text class="recommend-name">街拍回眸</text>
              <text class="recommend-desc">试试用「街拍回眸」拍摄</text>
            </view>
            <view class="lumira-badge lumira-badge-brand">免费</view>
          </view>
        </view>
      </view>

      <!-- 完成按钮 -->
      <view class="complete-wrap">
        <view class="lumira-btn-primary" @click="markComplete">
          <text>标记为已学完</text>
          <text class="ph ph-check"></text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const bookmarked = ref(false)
const completed = ref(false)

const tips = ref([
  '手机举高15-30cm，微微俯拍效果最好',
  '避免完全正面，微微转头更自然',
  '利用窗光，侧光拍出脸部立体感'
])

const toggleBookmark = () => {
  bookmarked.value = !bookmarked.value
  uni.showToast({
    title: bookmarked.value ? '已收藏' : '已取消收藏',
    icon: 'none'
  })
}

const markComplete = () => {
  if (completed.value) return
  completed.value = true
  uni.showToast({ title: '已标记为学完', icon: 'success' })
}

const goTemplate = () => uni.navigateTo({ url: '/pages/templates/detail' })
const back = () => uni.navigateBack()
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.nav-bookmark-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

/* 课程标题 */
.lesson-head {
  padding: 32rpx 48rpx 0;
}

.lesson-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 600;
  line-height: 1.3;
  color: $color-text-primary;
}

.lesson-meta {
  display: block;
  font-size: 26rpx;
  color: $color-text-tertiary;
  margin-top: 12rpx;
}

/* 头图 */
.hero-img-wrap {
  margin: 32rpx 48rpx 0;
  padding-bottom: 56.25%;
  position: relative;
  overflow: hidden;
  border-radius: 24rpx;
}

.hero-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

/* 正文 */
.content-body {
  padding: 48rpx 48rpx;
}

.section {
  margin-bottom: 56rpx;
}

.section-h2 {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  margin-bottom: 24rpx;
  color: $color-text-primary;
}

.section-p {
  display: block;
  font-size: 28rpx;
  color: $color-text-secondary;
  line-height: 1.8;
}

.section-p + .section-p {
  margin-top: 24rpx;
}

/* 技巧卡片 */
.tip-card {
  margin-bottom: 56rpx;
}

.tip-tag-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.lumira-tag .ph {
  font-size: 22rpx;
}

.tip-card-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  margin-bottom: 16rpx;
  color: $color-text-primary;
}

.tip-card-p {
  display: block;
  font-size: 26rpx;
  color: $color-text-secondary;
  line-height: 1.7;
  margin-bottom: 28rpx;
}

.tip-img-wrap {
  width: 100%;
  padding-bottom: 56.25%;
  position: relative;
  overflow: hidden;
  border-radius: 16rpx;
}

.tip-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

/* 对比 */
.compare-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.compare-cell {
  background: $color-bg-surface;
  border-radius: 24rpx;
  padding: 32rpx;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.compare-icon {
  font-size: 64rpx;
  margin-bottom: 16rpx;
  color: $color-text-primary;
}

.compare-name {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 28rpx;
  font-weight: 600;
  margin-bottom: 8rpx;
  color: $color-text-primary;
}

.compare-desc {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  line-height: 1.5;
}

.compare-tag {
  margin-top: 16rpx;
}

/* 实战练习 */
.practice-card {
  margin-bottom: 56rpx;
  border-color: $color-brand-primary;
}

.practice-tag-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.practice-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  margin-bottom: 16rpx;
  color: $color-text-primary;
}

.practice-p {
  display: block;
  font-size: 26rpx;
  color: $color-text-secondary;
  line-height: 1.7;
  margin-bottom: 24rpx;
}

.practice-tags {
  display: flex;
  gap: 16rpx;
  flex-wrap: wrap;
}

/* 小贴士 */
.tips-card {
  background: var(--color-canvas);
  border-radius: 24rpx;
  padding: 32rpx 40rpx;
}

.tip-line {
  display: flex;
  gap: 16rpx;
  align-items: flex-start;
  line-height: 2;
}

.tip-dot {
  color: $color-brand-primary;
  font-size: 28rpx;
  line-height: 2;
}

.tip-line-text {
  font-size: 26rpx;
  color: $color-text-secondary;
  line-height: 2;
  flex: 1;
}

/* 推荐模板 */
.recommend-section {
  margin-bottom: 64rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.recommend-card {
  padding: 24rpx;
}

.recommend-img-wrap {
  width: 100%;
  margin-bottom: 24rpx;
  padding-bottom: 133.33%;
  position: relative;
  overflow: hidden;
  border-radius: 16rpx;
}

.recommend-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.recommend-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.recommend-info {
  flex: 1;
}

.recommend-name {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.recommend-desc {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
  margin-top: 4rpx;
}

/* 完成按钮 */
.complete-wrap {
  padding: 0 0 48rpx;
}

.lumira-btn-primary .ph {
  font-size: 32rpx;
}
</style>
