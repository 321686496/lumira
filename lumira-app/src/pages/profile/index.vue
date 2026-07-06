<script setup lang="ts">
import { reactive } from 'vue'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useGalleryStore } from '@/stores/gallery'
import { useTemplatesStore } from '@/stores/templates'

const galleryStore = useGalleryStore()
const templatesStore = useTemplatesStore()

const stats = reactive({
  shots: 0,
  templates: 0,
  favorites: 0,
})

// 加载统计
const loadStats = () => {
  stats.shots = galleryStore.photoCount
  stats.templates = templatesStore.templateCount
}

const goAlbum = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

const goImport = () => {
  uni.navigateTo({ url: '/pages/templates/import' })
}

const goMyTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

const goSettings = () => {
  uni.navigateTo({ url: '/pages/profile/settings' })
}

const goAbout = () => {
  uni.navigateTo({ url: '/pages/profile/settings' })
}

// Tab 切换
const onTabSwitch = (key: string) => {
  if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  }
}

import { onShow } from '@dcloudio/uni-app'
onShow(() => {
  galleryStore.loadPhotos()
  templatesStore.loadTemplates()
  loadStats()
})
</script>

<template>
  <view class="profile-page">
    <!-- 顶部标题区 -->
    <view class="profile-header">
      <view class="header-row">
        <text class="page-title">我的</text>
        <text class="logo-text">LUMIRA</text>
      </view>
    </view>

    <scroll-view class="content-scroll" scroll-y :show-scrollbar="false">
      <!-- 用户卡片 -->
      <view class="user-card">
        <view class="avatar">
          <text class="avatar-text">画</text>
        </view>
        <view class="user-info">
          <text class="user-name">如画用户</text>
          <text class="user-id">设备 #{{ 'LUMIRA' }}</text>
        </view>
      </view>

      <!-- 统计卡片 -->
      <view class="stats-card">
        <view class="stat-item">
          <text class="stat-value">{{ stats.shots }}</text>
          <text class="stat-label">拍摄张数</text>
        </view>
        <view class="stat-divider"></view>
        <view class="stat-item">
          <text class="stat-value">{{ stats.templates }}</text>
          <text class="stat-label">使用模板</text>
        </view>
        <view class="stat-divider"></view>
        <view class="stat-item">
          <text class="stat-value">{{ stats.favorites }}</text>
          <text class="stat-label">收藏</text>
        </view>
      </view>

      <!-- 功能列表 -->
      <view class="section-label">内容</view>
      <view class="entry-list">
        <view class="entry-item" @tap="goAlbum">
          <view class="entry-left">
            <view class="entry-icon-wrap">
              <text class="entry-icon">▦</text>
            </view>
            <text class="entry-text">我的相册</text>
          </view>
          <view class="entry-right">
            <text class="entry-count">{{ stats.shots }}</text>
            <text class="entry-arrow">›</text>
          </view>
        </view>
        <view class="entry-item" @tap="goMyTemplates">
          <view class="entry-left">
            <view class="entry-icon-wrap">
              <text class="entry-icon">▦</text>
            </view>
            <text class="entry-text">我的模板</text>
          </view>
          <view class="entry-right">
            <text class="entry-count">{{ stats.templates }}</text>
            <text class="entry-arrow">›</text>
          </view>
        </view>
        <view class="entry-item" @tap="goImport">
          <view class="entry-left">
            <view class="entry-icon-wrap">
              <text class="entry-icon">＋</text>
            </view>
            <text class="entry-text">导入模板</text>
          </view>
          <view class="entry-right">
            <text class="entry-arrow">›</text>
          </view>
        </view>
      </view>

      <view class="section-label">其他</view>
      <view class="entry-list">
        <view class="entry-item" @tap="goSettings">
          <view class="entry-left">
            <view class="entry-icon-wrap">
              <text class="entry-icon">⚙</text>
            </view>
            <text class="entry-text">设置</text>
          </view>
          <view class="entry-right">
            <text class="entry-arrow">›</text>
          </view>
        </view>
        <view class="entry-item" @tap="goAbout">
          <view class="entry-left">
            <view class="entry-icon-wrap">
              <text class="entry-icon">ⓘ</text>
            </view>
            <text class="entry-text">关于如画</text>
          </view>
          <view class="entry-right">
            <text class="entry-arrow">›</text>
          </view>
        </view>
      </view>

      <view class="bottom-pad"></view>
    </scroll-view>

    <FloatingTabBar current="mine" @on-switch="onTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.profile-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* 顶部标题区 */
.profile-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
  flex-shrink: 0;
}

.header-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.page-title {
  font-size: 40px;
  font-weight: 700;
  color: var(--color-text-primary);
  font-family: 'Noto Serif SC', serif;
  line-height: 1.1;
  letter-spacing: 2px;
}

.logo-text {
  font-size: var(--font-size-tag);
  color: var(--color-brand-secondary);
  letter-spacing: 3px;
  font-weight: 500;
}

.content-scroll {
  flex: 1;
  width: 100%;
}

/* 用户卡片 */
.user-card {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  margin: 0 var(--space-5) var(--space-4);
  padding: var(--space-4);
  background: var(--color-bg-card);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
}

.avatar {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.avatar-text {
  font-size: 24px;
  color: #FFFFFF;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
}

.user-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.user-name {
  font-size: var(--font-size-heading);
  color: var(--color-text-primary);
  font-weight: 600;
}

.user-id {
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

/* 统计卡片 */
.stats-card {
  margin: 0 var(--space-5) var(--space-5);
  padding: var(--space-5) var(--space-3);
  background: var(--color-bg-card);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  display: flex;
  align-items: center;
}

.stat-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.stat-value {
  font-size: 28px;
  color: var(--color-text-primary);
  font-weight: 700;
  font-family: 'Noto Serif SC', serif;
  line-height: 1;
}

.stat-label {
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
  margin-top: var(--space-2);
}

.stat-divider {
  width: 1px;
  height: 32px;
  background: var(--color-border);
}

/* 区块标签 */
.section-label {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  padding: 0 var(--space-5);
  margin-bottom: var(--space-2);
  margin-top: var(--space-2);
  font-weight: 500;
}

/* 功能列表 */
.entry-list {
  margin: 0 var(--space-5) var(--space-4);
  background: var(--color-bg-card);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  overflow: hidden;
}

.entry-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-4) var(--space-4);
  border-bottom: 1px solid var(--color-border);

  &:last-child {
    border-bottom: none;
  }

  &:active {
    background: var(--color-bg-surface);
  }
}

.entry-left {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.entry-icon-wrap {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
  background: var(--color-bg-surface);
}

.entry-icon {
  font-size: 18px;
  color: var(--color-brand-primary);
  line-height: 1;
}

.entry-text {
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.entry-right {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.entry-count {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.entry-arrow {
  font-size: var(--font-size-heading);
  color: var(--color-text-tertiary);
  line-height: 1;
}

.bottom-pad {
  height: 120px;
}
</style>
