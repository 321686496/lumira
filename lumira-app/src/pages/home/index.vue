<script setup lang="ts">
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useTemplatesStore } from '@/stores/templates'
import { useGalleryStore } from '@/stores/gallery'

const templatesStore = useTemplatesStore()
const galleryStore = useGalleryStore()

// 推荐模板（取前 6 个）
const recommendedTemplates = computed(() => templatesStore.allTemplates.slice(0, 6))

// 近期作品（取前 6 张）
const recentPhotos = computed(() => galleryStore.photos.slice(0, 6))

// 当前时段问候语
const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 6) return '夜深了'
  if (hour < 12) return '早上好'
  if (hour < 14) return '中午好'
  if (hour < 18) return '下午好'
  return '晚上好'
})

// Tab 切换
const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    // 拍摄页用 navigateTo 进入，作为独立全屏页面
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'mine') {
    // 主页面切换用 reLaunch，避免页面栈堆积
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}

// 跳转模板库
const goTemplates = () => {
  uni.navigateTo({ url: '/pages/templates/index' })
}

// 跳转模板详情
const goTemplateDetail = (id: string) => {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}

// 跳转相册
const goGallery = () => {
  uni.navigateTo({ url: '/pages/gallery/index' })
}

// 跳转照片编辑
const goPhotoDetail = (id: string) => {
  uni.navigateTo({ url: `/pages/gallery/detail?id=${id}` })
}

// 跳转导入模板
const goImport = () => {
  uni.navigateTo({ url: '/pages/templates/import' })
}

onShow(() => {
  templatesStore.loadTemplates()
  galleryStore.loadPhotos()
})
</script>

<template>
  <view class="home-page">
    <!-- 顶部标题区 -->
    <view class="home-header">
      <view class="header-row">
        <view class="header-greeting">
          <text class="greeting-text">{{ greeting }}</text>
          <text class="greeting-title">如画</text>
        </view>
        <view class="header-logo">
          <text class="logo-text">LUMIRA</text>
        </view>
      </view>
      <text class="greeting-sub">用模板，拍好每一张</text>
    </view>

    <scroll-view scroll-y class="home-scroll" :show-scrollbar="false">
      <!-- 快捷功能入口 -->
      <view class="quick-actions">
        <view class="action-card action-capture" @click="handleTabSwitch('capture')">
          <view class="action-icon-wrap">
            <text class="action-icon">◉</text>
          </view>
          <text class="action-label">开始拍摄</text>
          <text class="action-hint">点击进入取景</text>
        </view>
        <view class="action-card action-import" @click="goImport">
          <view class="action-icon-wrap">
            <text class="action-icon">＋</text>
          </view>
          <text class="action-label">导入模板</text>
          <text class="action-hint">.pptpl 文件</text>
        </view>
      </view>

      <!-- 模板推荐区 -->
      <view class="section">
        <view class="section-header">
          <view class="section-title-wrap">
            <text class="section-title">模板推荐</text>
            <text class="section-count">{{ recommendedTemplates.length }} 个精选</text>
          </view>
          <view class="section-more" @click="goTemplates">
            <text class="more-text">全部</text>
            <text class="more-arrow">›</text>
          </view>
        </view>

        <!-- 模板横向滚动 -->
        <scroll-view scroll-x class="templates-scroll" :show-scrollbar="false">
          <view class="templates-row">
            <view
              v-for="tmpl in recommendedTemplates"
              :key="tmpl.id"
              class="template-card"
              @click="goTemplateDetail(tmpl.id)"
            >
              <view class="template-cover">
                <image v-if="tmpl.coverPath" :src="tmpl.coverPath" mode="aspectFill" class="cover-image" />
                <view v-else class="cover-placeholder">
                  <text class="placeholder-icon">▦</text>
                </view>
              </view>
              <view class="template-info">
                <text class="template-name">{{ tmpl.name }}</text>
              </view>
            </view>

            <!-- 空态 -->
            <view v-if="recommendedTemplates.length === 0" class="empty-card" @click="goImport">
              <view class="empty-icon-wrap">
                <text class="empty-icon">＋</text>
              </view>
              <text class="empty-title">导入第一个模板</text>
              <text class="empty-hint">支持 .pptpl 格式</text>
            </view>
          </view>
        </scroll-view>
      </view>

      <!-- 近期作品区 -->
      <view class="section">
        <view class="section-header">
          <view class="section-title-wrap">
            <text class="section-title">近期作品</text>
            <text class="section-count">{{ galleryStore.photoCount }} 张照片</text>
          </view>
          <view class="section-more" @click="goGallery">
            <text class="more-text">全部</text>
            <text class="more-arrow">›</text>
          </view>
        </view>

        <!-- 作品网格 -->
        <view v-if="recentPhotos.length > 0" class="photos-grid">
          <view
            v-for="photo in recentPhotos"
            :key="photo.id"
            class="photo-item"
            @click="goPhotoDetail(photo.id)"
          >
            <image :src="photo.imagePath" mode="aspectFill" class="photo-image" />
          </view>
        </view>

        <!-- 空态 -->
        <view v-else class="empty-photos" @click="handleTabSwitch('capture')">
          <view class="empty-photos-icon-wrap">
            <text class="empty-photos-icon">◐</text>
          </view>
          <text class="empty-photos-title">还没有作品</text>
          <text class="empty-photos-hint">去拍第一张照片吧</text>
        </view>
      </view>

      <!-- 底部留白 -->
      <view class="bottom-spacer" />
    </scroll-view>

    <!-- 悬浮 Tab 栏 -->
    <FloatingTabBar current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.home-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  width: 100%;
}

/* 顶部标题区 */
.home-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
  flex-shrink: 0;
}

.header-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.header-greeting {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.greeting-text {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  line-height: 1.4;
}

.greeting-title {
  font-size: 40px;
  font-weight: 700;
  color: var(--color-text-primary);
  font-family: 'Noto Serif SC', serif;
  line-height: 1.1;
  letter-spacing: 2px;
}

.header-logo {
  margin-top: var(--space-2);
}

.logo-text {
  font-size: var(--font-size-tag);
  color: var(--color-brand-secondary);
  letter-spacing: 3px;
  font-weight: 500;
}

.greeting-sub {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
  display: block;
}

/* 滚动区 */
.home-scroll {
  flex: 1;
  width: 100%;
}

/* 快捷功能入口 */
.quick-actions {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-3) var(--space-5) var(--space-4);
}

.action-card {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--space-4) var(--space-3);
  border-radius: var(--radius-card);
  gap: var(--space-1);
  position: relative;
  overflow: hidden;

  &:active {
    transform: scale(0.97);
  }
}

.action-capture {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  box-shadow: 0 4px 16px rgba(201, 169, 110, 0.3);

  .action-icon,
  .action-label {
    color: #FFFFFF;
  }
  .action-hint {
    color: rgba(255, 255, 255, 0.7);
  }
}

.action-import {
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  box-shadow: var(--shadow-card);

  .action-icon {
    color: var(--color-brand-primary);
  }
  .action-label {
    color: var(--color-text-primary);
  }
  .action-hint {
    color: var(--color-text-tertiary);
  }
}

.action-icon-wrap {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: var(--space-1);
}

.action-icon {
  font-size: 28px;
  line-height: 1;
}

.action-label {
  font-size: var(--font-size-body);
  font-weight: 600;
}

.action-hint {
  font-size: var(--font-size-tag);
  line-height: 1.3;
}

/* 区块 */
.section {
  margin-bottom: var(--space-5);
}

.section-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 0 var(--space-5);
  margin-bottom: var(--space-3);
}

.section-title-wrap {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
}

.section-title {
  font-size: var(--font-size-heading);
  font-weight: 600;
  color: var(--color-text-primary);
  font-family: 'Noto Serif SC', serif;
}

.section-count {
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

.section-more {
  display: flex;
  align-items: center;
  gap: 2px;
  padding: var(--space-1) var(--space-2);

  &:active {
    opacity: 0.5;
  }
}

.more-text {
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
}

.more-arrow {
  font-size: var(--font-size-body);
  color: var(--color-text-tertiary);
  line-height: 1;
}

/* 模板横向滚动 */
.templates-scroll {
  width: 100%;
  white-space: nowrap;
}

.templates-row {
  display: inline-flex;
  gap: var(--space-3);
  padding: 0 var(--space-5);
}

.template-card {
  display: flex;
  flex-direction: column;
  width: 130px;
  gap: var(--space-2);
  flex-shrink: 0;

  &:active {
    opacity: 0.8;
  }
}

.template-cover {
  width: 130px;
  height: 170px;
  border-radius: var(--radius-card);
  background: var(--color-bg-surface);
  overflow: hidden;
  border: 1px solid var(--color-border);
  box-shadow: var(--shadow-card);
}

.cover-image {
  width: 100%;
  height: 100%;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-icon {
  font-size: 36px;
  color: var(--color-text-tertiary);
  opacity: 0.3;
}

.template-info {
  padding: 0 2px;
}

.template-name {
  font-size: var(--font-size-caption);
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: block;
}

/* 模板空态卡片 */
.empty-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 130px;
  height: 200px;
  border-radius: var(--radius-card);
  border: 1px dashed var(--color-brand-secondary);
  background: var(--color-tag-gold-bg);
  gap: var(--space-2);
  flex-shrink: 0;

  &:active {
    opacity: 0.8;
  }
}

.empty-icon-wrap {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.15);
}

.empty-icon {
  font-size: 22px;
  color: var(--color-brand-secondary);
}

.empty-title {
  font-size: var(--font-size-caption);
  color: var(--color-tag-gold-text);
  font-weight: 500;
}

.empty-hint {
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

/* 作品网格 */
.photos-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-2);
  padding: 0 var(--space-5);
}

.photo-item {
  width: 100%;
  aspect-ratio: 3 / 4;
  border-radius: var(--radius-card);
  overflow: hidden;
  background: var(--color-bg-surface);
  box-shadow: var(--shadow-card);

  &:active {
    opacity: 0.85;
  }
}

.photo-image {
  width: 100%;
  height: 100%;
}

/* 作品空态 */
.empty-photos {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  margin: 0 var(--space-5);
  padding: var(--space-7) var(--space-4);
  border-radius: var(--radius-card);
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  gap: var(--space-2);

  &:active {
    opacity: 0.85;
  }
}

.empty-photos-icon-wrap {
  width: 56px;
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--color-bg-surface);
  margin-bottom: var(--space-1);
}

.empty-photos-icon {
  font-size: 28px;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

.empty-photos-title {
  font-size: var(--font-size-body);
  color: var(--color-text-secondary);
  font-weight: 500;
}

.empty-photos-hint {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

/* 底部留白 */
.bottom-spacer {
  height: 120px;
}
</style>
