<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">7月摄影手帐</text>
      <view class="lumira-nav-right">
        <view class="lumira-btn-ghost export-btn">
          <text>导出</text>
        </view>
      </view>
    </view>

    <!-- Content -->
    <view class="page-body">
      <!-- Cover Section -->
      <view class="cover-section fade-up">
        <text class="ph ph-book cover-book-icon"></text>
        <text class="cover-title">我的 7 月摄影手帐</text>
        <text class="cover-subtitle">Lumira · Monthly Digest</text>
        <!-- Month Stats -->
        <view class="cover-stats">
          <template v-for="(s, i) in coverStats" :key="i">
            <view v-if="i > 0" class="cover-divider"></view>
            <view class="cover-stat">
              <text class="lumira-stat-num cover-stat-num">{{ s.num }}</text>
              <text class="lumira-stat-label">{{ s.label }}</text>
            </view>
          </template>
        </view>
      </view>

      <!-- Photo Grid (Magazine Style) -->
      <view class="photo-grid-section fade-up fade-up-d2">
        <view class="lumira-section-title grid-title">
          <text class="section-title-text">月份照片墙</text>
          <text class="mono-text">共 32 张</text>
        </view>
        <view class="digest-gallery">
          <view class="digest-photo-wrap" :class="p.ratio" v-for="(p, i) in galleryPhotos" :key="i">
            <image class="digest-photo" :src="p.img" mode="aspectFill" />
          </view>
        </view>
      </view>

      <!-- Selected Photos -->
      <view class="selected-section fade-up fade-up-d3">
        <view class="lumira-section-title grid-title">
          <text class="section-title-text">本月精选</text>
          <text class="mono-text">3 张</text>
        </view>
        <view class="selected-list">
          <view class="selected-card" v-for="(s, i) in selectedPhotos" :key="i">
            <view class="selected-img-wrap">
              <image class="selected-img" :src="s.img" mode="aspectFill" />
            </view>
            <view class="selected-body">
              <view class="selected-row">
                <text class="selected-title">{{ s.title }}</text>
                <text class="mono-text selected-date">{{ s.date }}</text>
              </view>
              <text class="lumira-tag lumira-tag-gold selected-tag">{{ s.tag }}</text>
            </view>
          </view>
        </view>
      </view>

      <!-- Month Summary -->
      <view class="summary-section fade-up fade-up-d4">
        <view class="lumira-card summary-card">
          <text class="summary-card-title">7月拍摄总结</text>
          <view class="summary-grid">
            <view class="summary-stat" v-for="(s, i) in summaryStats" :key="i">
              <text class="summary-stat-num">{{ s.num }}</text>
              <text class="summary-stat-label">{{ s.label }}</text>
            </view>
          </view>
          <view class="summary-quote-box">
            <text class="summary-quote">{{ monthQuote }}</text>
          </view>
        </view>
      </view>

      <!-- Scene Tags -->
      <view class="scene-tags-section fade-up fade-up-d5">
        <view class="lumira-section-title grid-title">
          <text class="section-title-text">场景足迹</text>
        </view>
        <view class="scene-tags">
          <view class="scene-tag-pill" v-for="(t, i) in sceneTags" :key="i">
            <text class="ph scene-tag-icon" :class="t.icon"></text>
            <text class="scene-tag-text">{{ t.label }}</text>
            <text class="scene-tag-count">{{ t.count }}</text>
          </view>
        </view>
      </view>

      <!-- CTA -->
      <view class="cta-section fade-in fade-up-d5">
        <view class="lumira-btn-primary cta-primary">
          <text class="ph ph-camera"></text>
          <text>生成手帐长图</text>
        </view>
        <view class="lumira-btn-outline cta-outline">
          <text>分享手帐</text>
        </view>
      </view>

      <!-- Footer Branding -->
      <view class="footer-branding fade-in">
        <text class="footer-text">如你所见，皆成画卷 · 如画 Lumira</text>
      </view>

      <!-- Bottom Spacing -->
      <view class="bottom-spacing"></view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const coverStats = ref([
  { num: '32', label: '张照片' },
  { num: '8', label: '个模板' },
  { num: '4', label: '个场景' }
])

const galleryPhotos = ref([
  { img: 'https://picsum.photos/seed/733872/400/400', ratio: 'ratio-34' },
  { img: 'https://picsum.photos/seed/774095/400/400', ratio: 'ratio-11' },
  { img: 'https://picsum.photos/seed/1038002/400/400', ratio: 'ratio-45' },
  { img: 'https://picsum.photos/seed/312415/400/400', ratio: 'ratio-11' },
  { img: 'https://picsum.photos/seed/457882/400/400', ratio: 'ratio-11' },
  { img: 'https://picsum.photos/seed/312415/400/400', ratio: 'ratio-34' },
  { img: 'https://picsum.photos/seed/1038002/400/400', ratio: 'ratio-11' },
  { img: 'https://picsum.photos/seed/733872/400/400', ratio: 'ratio-34' }
])

const selectedPhotos = ref([
  { img: 'https://picsum.photos/seed/733872/400/400', title: '河畔金色的午后', date: '7月12日', tag: '日系胶片' },
  { img: 'https://picsum.photos/seed/774095/400/400', title: '城市夜雨', date: '7月18日', tag: '黑金电影' },
  { img: 'https://picsum.photos/seed/1239291/400/400', title: '山间晨雾', date: '7月25日', tag: '日系清新' }
])

const summaryStats = ref([
  { num: '12', label: '天有拍摄' },
  { num: '5', label: '个地点' },
  { num: '日系', label: '最常用风格' },
  { num: '傍晚', label: '最佳时段' }
])

const monthQuote = '"这个月你记录了 32 个美好瞬间，\n偏爱日系胶片风，最常在傍晚按下快门。"'

const sceneTags = ref([
  { icon: 'ph-buildings', label: '城市', count: 14 },
  { icon: 'ph-flower', label: '自然', count: 8 },
  { icon: 'ph-house', label: '室内', count: 6 },
  { icon: 'ph-bowl-food', label: '美食', count: 4 }
])

const back = () => uni.navigateBack()
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.export-btn {
  padding: 12rpx 24rpx;
  font-size: 26rpx;
}

.page-body {
  padding: 16rpx 48rpx 0;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.mono-text {
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
  color: $color-text-secondary;
  letter-spacing: 0.02em;
}

/* ===== Cover Section ===== */
.cover-section {
  text-align: center;
  padding: 48rpx 0 64rpx;
}

.cover-book-icon {
  font-size: 64rpx;
  color: $color-brand-primary;
  margin-bottom: 24rpx;
}

.cover-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 52rpx;
  font-weight: 600;
  line-height: 1.3;
  margin-bottom: 16rpx;
  color: $color-text-primary;
}

.cover-subtitle {
  display: block;
  font-size: 28rpx;
  color: $color-brand-primary;
  font-family: 'Noto Serif SC', serif;
  letter-spacing: 0.02em;
}

.cover-stats {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 48rpx;
  margin-top: 40rpx;
  padding: 32rpx 0;
  border-top: 2rpx solid $color-border;
  border-bottom: 2rpx solid $color-border;
}

.cover-stat {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.cover-stat-num {
  font-size: 48rpx;
}

.cover-divider {
  width: 2rpx;
  height: 48rpx;
  background-color: $color-border;
}

/* ===== Photo Grid ===== */
.photo-grid-section {
  padding: 16rpx 0 64rpx;
}

.grid-title {
  margin-bottom: 28rpx;
}

.digest-gallery {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
}

.digest-photo-wrap {
  width: 100%;
  height: 0;
  border-radius: 16rpx;
  overflow: hidden;
  position: relative;
}

.ratio-34 {
  padding-bottom: 133.33%;
}

.ratio-11 {
  padding-bottom: 100%;
}

.ratio-45 {
  padding-bottom: 125%;
}

.digest-photo {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

/* ===== Selected Photos ===== */
.selected-section {
  margin-bottom: 64rpx;
}

.selected-list {
  display: flex;
  flex-direction: column;
  gap: 32rpx;
}

.selected-card {
  border-radius: 24rpx;
  overflow: hidden;
  border: 2rpx solid $color-border;
  background-color: $color-bg-card;
}

.selected-img-wrap {
  width: 100%;
  height: 0;
  padding-bottom: 56.25%;
  position: relative;
}

.selected-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.selected-body {
  padding: 24rpx 32rpx;
}

.selected-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.selected-title {
  font-size: 26rpx;
  font-weight: 500;
  color: $color-text-primary;
}

.selected-date {
  font-size: 24rpx;
}

.selected-tag {
  margin-top: 12rpx;
}

/* ===== Month Summary ===== */
.summary-section {
  margin-bottom: 64rpx;
}

.summary-card {
  padding: 48rpx;
}

.summary-card-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 36rpx;
  font-weight: 600;
  margin-bottom: 40rpx;
  color: $color-text-primary;
}

.summary-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 32rpx;
}

.summary-stat {
  padding: 24rpx;
  background-color: $color-bg-surface;
  border-radius: 16rpx;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.summary-stat-num {
  font-size: 48rpx;
  font-family: 'Noto Serif SC', serif;
  font-weight: 600;
  color: $color-brand-primary;
}

.summary-stat-label {
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-top: 4rpx;
}

.summary-quote-box {
  margin-top: 32rpx;
  padding: 24rpx;
  background-color: $color-bg-surface;
  border-radius: 16rpx;
}

.summary-quote {
  font-size: 26rpx;
  color: $color-text-secondary;
  line-height: 1.6;
  font-family: 'Noto Serif SC', serif;
  text-align: center;
  white-space: pre-line;
}

/* ===== Scene Tags ===== */
.scene-tags-section {
  margin-bottom: 64rpx;
}

.scene-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.scene-tag-pill {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  border: 2rpx solid $color-border;
  background-color: $color-bg-card;
  font-size: 26rpx;
  color: $color-text-secondary;
}

.scene-tag-icon {
  font-size: 26rpx;
  color: $color-brand-primary;
}

.scene-tag-text {
  font-size: 26rpx;
}

.scene-tag-count {
  font-size: 22rpx;
  color: $color-text-tertiary;
  margin-left: 4rpx;
}

/* ===== CTA ===== */
.cta-section {
  margin-bottom: 48rpx;
}

.cta-primary {
  margin-bottom: 24rpx;
}

/* ===== Footer ===== */
.footer-branding {
  text-align: center;
  padding: 32rpx 0 16rpx;
  border-top: 2rpx solid $color-border;
}

.footer-text {
  font-size: 22rpx;
  color: $color-text-tertiary;
  letter-spacing: 0.04em;
}

.bottom-spacing {
  height: 32rpx;
}
</style>
