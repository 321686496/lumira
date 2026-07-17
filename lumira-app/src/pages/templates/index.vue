<template>
  <view class="lumira-container">
    <!-- NAVBAR (Tab 页，无返回按钮，右上角导航入口) -->
    <view class="lumira-nav">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">模板</text>
      <view class="lumira-nav-right" @click="goAll">
        <text class="ph ph-squares-four nav-icon"></text>
      </view>
    </view>

    <!-- HERO 推荐区 -->
    <view class="hero-wrap fade-up">
      <text class="hero-title">今日为你推荐</text>
      <scroll-view scroll-x class="rec-scroll" :show-scrollbar="false">
        <view class="rec-list">
          <view
            v-for="rec in recommendations"
            :key="rec.template.meta.id"
            class="rec-card lumira-card-hover"
            @click="goTemplateDetail(rec.template.meta.id)"
          >
            <view class="rec-img-wrap">
              <image
                class="rec-img"
                :src="rec.template.meta.cover || 'https://picsum.photos/seed/' + rec.template.meta.id + '/240/320'"
                mode="aspectFill"
              />
              <view class="rec-source-badge" :class="'source-' + rec.source">
                <text class="rec-source-text">{{ sourceLabel(rec.source) }}</text>
              </view>
            </view>
            <text class="rec-name">{{ rec.template.meta.name }}</text>
            <text class="rec-reason">{{ rec.reason }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <!-- 拍摄偏好（仅有照片时显示） -->
    <view v-if="userPreference.totalPhotos > 0" class="pref-section fade-up fade-up-d1">
      <text class="section-title">你的拍摄偏好</text>
      <view class="pref-card">
        <view class="pref-row">
          <text class="pref-label">累计作品</text>
          <text class="pref-val">{{ userPreference.totalPhotos }} 张</text>
        </view>
        <view v-if="userPreference.topCategory" class="pref-row">
          <text class="pref-label">最常用分类</text>
          <text class="pref-val">{{ categoryLabel(userPreference.topCategory) }} · {{ userPreference.topCategoryPercentage }}%</text>
        </view>
      </view>
    </view>

    <!-- 更多模板 -->
    <view class="other-section fade-up fade-up-d2">
      <view class="section-header">
        <text class="section-title">更多模板</text>
        <text class="section-link" @click="goAll">查看全部 ›</text>
      </view>
      <view v-if="otherTemplates.length" class="other-grid">
        <view
          v-for="tpl in otherTemplates.slice(0, 6)"
          :key="tpl.meta.id"
          class="other-card lumira-card-hover"
          @click="goTemplateDetail(tpl.meta.id)"
        >
          <view class="other-img-wrap">
            <image
              class="other-img"
              :src="tpl.meta.cover || 'https://picsum.photos/seed/' + tpl.meta.id + '/200/200'"
              mode="aspectFill"
            />
            <view v-if="tpl.meta.price === 0" class="other-badge-free">
              <text class="other-badge-text">免费</text>
            </view>
          </view>
          <view class="other-info">
            <text class="other-name">{{ tpl.meta.name }}</text>
            <text class="other-cat">{{ categoryLabel(tpl.meta.category) }}</text>
          </view>
        </view>
      </view>
      <view v-else class="empty-state">
        <text class="ph ph-folder-open empty-icon"></text>
        <text class="empty-text">暂无更多模板</text>
      </view>
    </view>

    <view class="bottom-spacer"></view>

    <FloatingTabBar active="templates" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useRecommendation } from '@/composables/useRecommendation'
import type { Target } from '@/types/template'

const { getRecommendedTemplates, getOtherTemplates, userPreference } = useRecommendation()

// 刷新触发器：onShow 时自增，触发 recommendations 重算
// （getRecommendedTemplates 内部读 photos / recentTemplates / getAllTemplates，需触发响应式）
const refreshTick = ref(0)
onShow(() => {
  refreshTick.value++
})

const recommendations = computed(() => {
  void refreshTick.value
  return getRecommendedTemplates(4)
})

const otherTemplates = computed(() => {
  void refreshTick.value
  const recIds = recommendations.value.map(r => r.template.meta.id)
  return getOtherTemplates(recIds)
})

const categoryLabelMap: Record<Target, string> = {
  portrait: '人像',
  landscape: '风光',
  food: '美食',
  night: '夜景',
  street: '街拍',
  macro: '微距',
  'still-life': '静物'
}

function categoryLabel(cat: Target): string {
  return categoryLabelMap[cat] || cat
}

function sourceLabel(source: string): string {
  const map: Record<string, string> = {
    recent_used: '最近使用',
    scene_match: '场景匹配',
    category_match: '同分类',
    system_pick: '系统精选'
  }
  return map[source] || '推荐'
}

function goAll() {
  uni.navigateTo({ url: '/pages/templates/all' })
}

function goTemplateDetail(id: string) {
  uni.navigateTo({ url: `/pages/templates/detail?templateId=${id}` })
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

/* Hero 推荐区 */
.hero-wrap {
  padding: 24rpx 0 32rpx;
}

.hero-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 700;
  color: var(--color-text-primary);
  padding: 0 40rpx 20rpx;
  letter-spacing: -0.01em;
}

.rec-scroll {
  width: 100%;
  white-space: nowrap;
  padding: 0 40rpx;
  box-sizing: border-box;
}

.rec-list {
  display: inline-flex;
  gap: 20rpx;
  padding-bottom: 8rpx;
}

.rec-card {
  flex-shrink: 0;
  width: 260rpx;
  background-color: var(--color-surface);
  border-radius: 24rpx;
  overflow: hidden;
  display: inline-flex;
  flex-direction: column;
}

.rec-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 133.33%;
  overflow: hidden;
}

.rec-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.rec-source-badge {
  position: absolute;
  top: 12rpx;
  left: 12rpx;
  padding: 4rpx 16rpx;
  border-radius: 9999rpx;
  background-color: rgba(0, 0, 0, 0.55);
}

.rec-source-text {
  font-size: 20rpx;
  color: #ffffff;
  font-weight: 500;
}

.source-recent_used .rec-source-text { color: #F5E6CC; }
.source-scene_match { background-color: rgba(90, 122, 72, 0.85); }
.source-category_match { background-color: rgba(201, 169, 110, 0.85); }
.source-system_pick { background-color: rgba(0, 0, 0, 0.65); }

.rec-name {
  font-size: 26rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  font-family: 'Noto Serif SC', serif;
  padding: 16rpx 20rpx 4rpx;
  display: block;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.rec-reason {
  font-size: 22rpx;
  color: var(--color-text-secondary);
  padding: 0 20rpx 20rpx;
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  line-height: 1.4;
}

/* 拍摄偏好 */
.pref-section {
  padding: 16rpx 40rpx 24rpx;
}

.section-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 16rpx;
  letter-spacing: -0.01em;
}

.pref-card {
  background-color: var(--color-surface);
  border-radius: 24rpx;
  padding: 28rpx 32rpx;
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.pref-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.pref-label {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.pref-val {
  font-size: 28rpx;
  font-weight: 600;
  color: var(--color-brand);
  font-variant-numeric: tabular-nums;
}

/* 更多模板 */
.other-section {
  padding: 16rpx 40rpx 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16rpx;
}

.section-link {
  color: var(--color-brand);
  font-size: 24rpx;
  font-weight: 500;
}

.other-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
}

.other-card {
  background-color: var(--color-surface);
  border-radius: 24rpx;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.other-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 100%;
  overflow: hidden;
}

.other-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.other-badge-free {
  position: absolute;
  top: 12rpx;
  left: 12rpx;
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
  background-color: rgba(90, 122, 72, 0.85);
}

.other-badge-text {
  font-size: 20rpx;
  font-weight: 600;
  color: #ffffff;
}

.other-info {
  padding: 16rpx 20rpx 20rpx;
}

.other-name {
  display: block;
  font-size: 26rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.other-cat {
  display: block;
  font-size: 22rpx;
  color: var(--color-brand);
  margin-top: 6rpx;
}

/* 空状态 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 64rpx 40rpx;
  gap: 16rpx;
}

.empty-icon {
  font-size: 80rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

.empty-text {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}

/* 底部留白避开 FloatingTabBar */
.bottom-spacer {
  height: calc(env(safe-area-inset-bottom) + 140rpx);
}
</style>
