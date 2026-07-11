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
          <text class="hero-desc">{{ allTemplatesCount }} 个模板等你探索</text>
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
        <view
          class="cat-pill"
          :class="{ active: activeCategory === cat.value }"
          v-for="cat in categories"
          :key="cat.value"
          @click="activeCategory = cat.value"
        >
          <text class="cat-pill-text">{{ cat.label }}</text>
        </view>
      </scroll-view>
    </view>

    <!-- "我的"分类操作入口按钮行 -->
    <view v-if="activeCategory === 'custom'" class="action-row fade-up fade-up-d2">
      <view class="action-btn lumira-btn-ghost" @click="handleImport">
        <text class="ph ph-download-simple action-btn-icon"></text>
        <text class="action-btn-text">导入模板</text>
      </view>
      <view class="action-btn lumira-btn-ghost" @click="goEditor">
        <text class="ph ph-plus action-btn-icon"></text>
        <text class="action-btn-text">新建模板</text>
      </view>
    </view>

    <!-- 模板网格 -->
    <view v-if="displayTemplates.length" class="tpl-grid section-pad fade-up fade-up-d2">
      <view
        class="tpl-card lumira-card-hover"
        v-for="t in displayTemplates"
        :key="t.meta.id"
        @click="goDetail(t.meta.id)"
      >
        <view class="tpl-img-wrap">
          <image class="tpl-img" :src="coverUrl(t)" mode="aspectFill" />
          <view v-if="t.meta.price === 0" class="tpl-badge-free">
            <text class="tpl-badge-free-text">免费</text>
          </view>
          <view v-else class="tpl-badge-premium">
            <text class="ph ph-star tpl-badge-icon"></text>
            <text class="tpl-badge-text">精选 ¥{{ t.meta.price }}</text>
          </view>
        </view>
        <view class="tpl-info">
          <text class="tpl-name">{{ t.meta.name }}</text>
          <view class="tpl-meta">
            <text class="tpl-cat">{{ categoryLabel(t.meta.category) }}</text>
            <text v-if="activeCategory === 'custom'" class="tpl-custom-tag">自定义</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 空状态 -->
    <view v-else class="empty-state-wrap fade-up fade-up-d2">
      <text class="ph ph-folder-open empty-icon"></text>
      <text class="empty-text">{{
        activeCategory === 'custom' ? '还没有自定义模板' : '该分类暂无模板'
      }}</text>
      <view v-if="activeCategory === 'custom'" class="empty-btn" @click="goEditor">
        去创建
      </view>
    </view>

    <FloatingTabBar active="templates" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow, onLoad } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import { useTemplate } from '@/composables/useTemplate'
import { useTemplateIO } from '@/composables/useTemplateIO'
import type { PhotoTemplate, Target } from '@/types/template'

const { getFreeTemplates, getPaidTemplates, getCustomTemplates } = useTemplate()
const { importTemplate } = useTemplateIO()

type CategoryValue = Target | 'all' | 'custom'

// 场景推荐页传入的 scene 参数 → 模板分类映射
const sceneToCategory: Record<string, Target> = {
  cafe: 'portrait',
  street: 'street',
  food: 'food',
  home: 'still-life'
}

const categories: { value: CategoryValue; label: string }[] = [
  { value: 'all', label: '全部' },
  { value: 'portrait', label: '人像' },
  { value: 'landscape', label: '风光' },
  { value: 'food', label: '美食' },
  { value: 'night', label: '夜景' },
  { value: 'street', label: '街拍' },
  { value: 'macro', label: '微距' },
  { value: 'still-life', label: '静物' },
  { value: 'custom', label: '我的' }
]

const activeCategory = ref<CategoryValue>('all')

// 接收场景推荐页传入的 scene 参数，自动切换到对应分类
onLoad((options) => {
  if (options?.scene && sceneToCategory[options.scene]) {
    activeCategory.value = sceneToCategory[options.scene]
  }
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

// 内置模板（静态，仅加载一次）
const freeTemplates = getFreeTemplates()
const paidTemplates = getPaidTemplates()
const builtinTemplates: PhotoTemplate[] = [...freeTemplates, ...paidTemplates]

// 自定义模板（本地存储，需在 onShow 时刷新）
const customTemplates = ref<PhotoTemplate[]>([])

function reloadCustom() {
  customTemplates.value = getCustomTemplates()
}

onShow(() => {
  reloadCustom()
})

const allTemplatesCount = builtinTemplates.length
const unlockedCount = freeTemplates.length + paidTemplates.length

const displayTemplates = computed<PhotoTemplate[]>(() => {
  const cat = activeCategory.value
  if (cat === 'all') return builtinTemplates
  if (cat === 'custom') return customTemplates.value
  return builtinTemplates.filter(t => t.meta.category === cat)
})

function coverUrl(t: PhotoTemplate): string {
  return t.meta.cover || `https://picsum.photos/seed/${t.meta.id}/400/600`
}

function goDetail(id: string) {
  uni.navigateTo({ url: `/pages/templates/detail?templateId=${id}` })
}

function goEditor() {
  uni.navigateTo({ url: '/pages/templates/editor' })
}

async function handleImport() {
  const tpl = await importTemplate()
  if (tpl) {
    reloadCustom()
  }
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.section-pad {
  padding: 0 40rpx;
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

/* "我的"分类操作按钮行 */
.action-row {
  display: flex;
  gap: 20rpx;
  padding: 0 40rpx 24rpx;
}

.action-btn {
  flex: 1;
  justify-content: center;
  padding: 24rpx 0;
}

.action-btn-icon {
  font-size: 32rpx;
}

.action-btn-text {
  font-size: 28rpx;
  font-weight: 500;
}

/* 模板网格 */
.tpl-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  padding-bottom: 48rpx;
}

.tpl-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: none;
  background-color: var(--color-canvas);
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

.tpl-badge-icon {
  font-size: 22rpx;
  color: #fff;
}

.tpl-badge-text {
  font-size: 22rpx;
  font-weight: 600;
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
  gap: 12rpx;
  margin-top: 12rpx;
}

.tpl-cat {
  font-size: 22rpx;
  color: var(--color-brand);
}

.tpl-custom-tag {
  font-size: 20rpx;
  color: var(--color-brand);
  background-color: rgba(201, 169, 110, 0.12);
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
}

/* 空状态 */
.empty-state-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 40rpx 48rpx;
  gap: 24rpx;
}

.empty-icon {
  font-size: 96rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

.empty-text {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
}

.empty-btn {
  padding: 16rpx 48rpx;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  color: #fff;
  font-size: 26rpx;
  font-weight: 500;
}
</style>
