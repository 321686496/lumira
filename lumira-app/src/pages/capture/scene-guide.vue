<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-icon"></text>
      </view>
      <text class="lumira-nav-title">场景</text>
      <view class="lumira-nav-right" @click="onAdd">
        <text class="ph ph-plus nav-icon"></text>
      </view>
    </view>

    <!-- 场景分类标签 -->
    <view class="tabs-wrap fade-up">
      <view class="tabs-row">
        <view
          class="tab-pill"
          :class="{ active: tab === t.value }"
          v-for="t in tabList"
          :key="t.value"
          @click="tab = t.value"
        >
          <text class="tab-pill-text">{{ t.label }}</text>
        </view>
      </view>
    </view>

    <!-- 我的场景 -->
    <view class="section-pad fade-up fade-up-d1">
      <view class="section-title-row">
        <text class="section-title">我的场景</text>
        <text class="section-count">共 {{ myScenes.length }} 个</text>
      </view>
      <view class="scene-list">
        <view
          class="scene-item"
          v-for="s in myScenes"
          :key="s.name"
          @click="onSceneTap(s)"
        >
          <view class="scene-item-icon">
            <text class="ph scene-icon" :class="s.icon"></text>
          </view>
          <view class="scene-item-text">
            <text class="scene-item-title">{{ s.name }}</text>
            <text class="scene-item-desc">{{ s.desc }}</text>
          </view>
          <image class="scene-item-thumb" :src="s.img" mode="aspectFill" />
          <text class="ph ph-caret-right scene-item-arrow"></text>
        </view>
      </view>
    </view>

    <!-- 推荐场景 -->
    <view class="section-pad-bottom fade-up fade-up-d2">
      <view class="section-title-row">
        <text class="section-title">推荐场景</text>
        <view class="section-more" @click="onMoreRecommend">
          <text class="section-more-text">更多</text>
          <text class="ph ph-arrow-right section-more-icon"></text>
        </view>
      </view>
      <view class="scene-list">
        <view
          class="scene-item"
          v-for="r in recommendScenes"
          :key="r.name"
          @click="onSceneTap(r)"
        >
          <view class="scene-item-icon" :class="r.iconBg">
            <text class="ph scene-icon" :class="r.icon"></text>
          </view>
          <view class="scene-item-text">
            <text class="scene-item-title">{{ r.name }}</text>
            <text class="scene-item-desc">{{ r.desc }}</text>
          </view>
          <view v-if="r.badge" class="scene-badge" :class="r.badgeClass">
            <text class="scene-badge-text">{{ r.badge }}</text>
          </view>
          <text class="ph ph-caret-right scene-item-arrow"></text>
        </view>
      </view>
    </view>

    <!-- 场景小贴士（选中场景后显示） -->
    <view v-if="currentTip" class="section-pad fade-up">
      <view class="tip-detail-card">
        <view class="tip-detail-head">
          <text class="ph ph-lightbulb tip-detail-icon"></text>
          <text class="tip-detail-title">拍摄小贴士</text>
        </view>
        <view class="tip-detail-body">
          <view class="tip-detail-row">
            <text class="ph ph-sun tip-detail-row-icon"></text>
            <text class="tip-detail-row-label">光线</text>
            <text class="tip-detail-row-text">{{ currentTip.light }}</text>
          </view>
          <view class="tip-detail-row">
            <text class="ph ph-ruler tip-detail-row-icon"></text>
            <text class="tip-detail-row-label">距离</text>
            <text class="tip-detail-row-text">{{ currentTip.distance }}</text>
          </view>
          <view class="tip-detail-row">
            <text class="ph ph-info tip-detail-row-icon"></text>
            <text class="tip-detail-row-label">技巧</text>
            <text class="tip-detail-row-text">{{ currentTip.tip }}</text>
          </view>
        </view>
        <view class="tip-detail-actions">
          <view class="tip-detail-btn-ghost" @click="goTemplates">
            <text class="ph ph-book-open"></text>
            <text>查看模板</text>
          </view>
          <view class="tip-detail-btn-brand" @click="goCapture">
            <text class="ph ph-camera"></text>
            <text>开始拍摄</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 快速添加提示 -->
    <view class="section-pad-bottom fade-up fade-up-d3">
      <view class="add-card">
        <text class="ph ph-camera add-card-icon"></text>
        <text class="add-card-title">添加新场景</text>
        <text class="add-card-desc">右上角 + 号创建你的专属拍摄场景</text>
        <view class="add-card-btn" @click="onAdd">
          <text class="add-card-btn-text">+ 新建场景</text>
        </view>
      </view>
    </view>

    <view class="bottom-spacer"></view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const tab = ref('common')

// 场景 → 模板分类映射
const sceneToCategory: Record<string, string> = {
  cafe: 'portrait',
  street: 'street',
  food: 'food',
  home: 'still-life'
}

// 场景拍摄小贴士
const sceneTips: Record<string, { light: string; distance: string; tip: string }> = {
  cafe: { light: '柔和自然光，靠窗位置最佳', distance: '1-2米半身特写', tip: '利用咖啡杯作为道具，捕捉自然互动瞬间' },
  street: { light: '利用城市光影对比，黄金时刻最佳', distance: '3-5米环境人像', tip: '寻找街角光影、橱窗反光增加故事感' },
  food: { light: '暖色温灯光或自然侧光', distance: '30-50cm俯拍或45度', tip: '注意白平衡，让美食色彩还原自然' },
  home: { light: '窗边柔光或室内暖灯', distance: '1-3米生活场景', tip: '保持画面简洁，突出居家温馨氛围' }
}

const selectedScene = ref<string>('')

onLoad((options) => {
  if (options?.scene) {
    selectedScene.value = options.scene
    updateTip(options.scene)
    // 切换到推荐场景tab
    tab.value = 'recommend'
  }
})

const tabList = [
  { label: '常用场景', value: 'common' },
  { label: '收藏场景', value: 'fav' },
  { label: '推荐场景', value: 'recommend' }
]

const myScenes = ref([
  { name: '咖啡馆', desc: '已拍摄 23 张 · 今天 14:30', icon: 'ph-coffee', img: 'https://picsum.photos/seed/2074130/400/600', scene: 'cafe' },
  { name: '花店', desc: '已拍摄 12 张 · 昨天 10:15', icon: 'ph-flower', img: 'https://picsum.photos/seed/1038002/400/600', scene: 'flower' },
  { name: '海边', desc: '已拍摄 8 张 · 3天前', icon: 'ph-waves', img: 'https://picsum.photos/seed/457882/400/600', scene: 'beach' },
  { name: '街拍', desc: '已拍摄 31 张 · 2天前', icon: 'ph-buildings', img: 'https://picsum.photos/seed/172217/400/400', scene: 'street' },
  { name: '探店', desc: '已拍摄 15 张 · 5天前', icon: 'ph-shopping-bag', img: 'https://picsum.photos/seed/1080696/400/600', scene: 'food' },
  { name: '居家', desc: '已拍摄 19 张 · 昨天 20:00', icon: 'ph-house', img: 'https://picsum.photos/seed/1571460/400/600', scene: 'home' },
  { name: '纪念日', desc: '已拍摄 5 张 · 1周前', icon: 'ph-cake', img: 'https://picsum.photos/seed/774909/400/600', scene: 'anniversary' },
  { name: '合照', desc: '已拍摄 11 张 · 4天前', icon: 'ph-users', img: 'https://picsum.photos/seed/774909/400/600', scene: 'group' }
])

const recommendScenes = ref([
  { name: '露营', desc: '热门场景 · 适合户外人像', icon: 'ph-tent', iconBg: 'icon-bg-green', badge: '推荐', badgeClass: 'badge-brand', scene: 'camping' },
  { name: '露台黄昏', desc: '新上架 · 逆光/剪影首选', icon: 'ph-sunset', iconBg: 'icon-bg-gold', badge: 'NEW', badgeClass: 'badge-red', scene: 'sunset' },
  { name: '雨天文案', desc: '氛围感 · 情绪片必备', icon: 'ph-rainbow-cloud', iconBg: 'icon-bg-surface', badge: '', badgeClass: '', scene: 'rainy' }
])

const currentTip = ref<{ light: string; distance: string; tip: string } | null>(null)

// 当选中场景时显示对应小贴士
const updateTip = (scene: string) => {
  currentTip.value = sceneTips[scene] || null
}

const back = () => uni.navigateBack()

const onAdd = () => {
  uni.showToast({ title: '新建场景', icon: 'none' })
}

const onMoreRecommend = () => {
  uni.showToast({ title: '更多推荐', icon: 'none' })
}

const onSceneTap = (s: { name: string; scene: string }) => {
  selectedScene.value = s.scene
  updateTip(s.scene)
}

// 从场景进入模板列表（带场景筛选）或直接拍摄
const goTemplates = () => {
  if (!selectedScene.value) return
  const cat = sceneToCategory[selectedScene.value]
  if (cat) {
    uni.navigateTo({ url: `/pages/templates/index?scene=${selectedScene.value}` })
  } else {
    uni.navigateTo({ url: '/pages/templates/index' })
  }
}

const goCapture = () => {
  uni.navigateTo({ url: '/pages/capture/index' })
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

/* ===== 分类标签 ===== */
.tabs-wrap {
  padding: 32rpx 48rpx 0;
}

.tabs-row {
  display: flex;
  gap: 16rpx;
}

.tab-pill {
  padding: 16rpx 40rpx;
  border-radius: 9999rpx;
  border: 3rpx solid var(--color-divider);
  background-color: var(--color-surface);
}

.tab-pill.active {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  border-color: transparent;
}

.tab-pill-text {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text-secondary);
  white-space: nowrap;
}

.tab-pill.active .tab-pill-text {
  color: #ffffff;
}

/* ===== 区块通用 ===== */
.section-pad {
  padding: 48rpx 48rpx 0;
}

.section-pad-bottom {
  padding: 0 48rpx 0;
  margin-top: 48rpx;
}

.section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 32rpx;
}

.section-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.section-count {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.section-more {
  display: flex;
  align-items: center;
  gap: 4rpx;
}

.section-more-text {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
}

.section-more-icon {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

/* ===== 场景列表 ===== */
.scene-list {
  display: flex;
  flex-direction: column;
}

.scene-item {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 32rpx 0;
  border-bottom: 2rpx solid var(--color-divider);
}

.scene-list .scene-item:last-child {
  border-bottom: none;
}

.scene-item:active {
  opacity: 0.7;
}

.scene-item-icon {
  width: 80rpx;
  height: 80rpx;
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  background-color: var(--color-surface-alt);
}

.icon-bg-green {
  background-color: var(--color-success-subtle);
}

.icon-bg-gold {
  background-color: var(--color-brand-subtle);
}

.icon-bg-surface {
  background-color: var(--color-surface-alt);
}

.scene-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.icon-bg-green .scene-icon {
  color: var(--color-success);
}

.icon-bg-gold .scene-icon {
  color: var(--color-brand-text);
}

.scene-item-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 4rpx;
}

.scene-item-title {
  font-size: 30rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.scene-item-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
}

.scene-item-thumb {
  width: 80rpx;
  height: 80rpx;
  border-radius: 16rpx;
  flex-shrink: 0;
}

.scene-item-arrow {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
}

/* ===== 场景徽章 ===== */
.scene-badge {
  flex-shrink: 0;
  padding: 6rpx 16rpx;
  border-radius: 9999rpx;
}

.badge-brand {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
}

.badge-red {
  background-color: var(--color-danger-subtle);
}

.scene-badge-text {
  font-size: 22rpx;
  font-weight: 600;
  letter-spacing: 0.04em;
}

.badge-brand .scene-badge-text {
  color: #ffffff;
}

.badge-red .scene-badge-text {
  color: var(--color-danger);
}

/* ===== 添加新场景卡片 ===== */
.add-card {
  background-color: var(--color-surface-alt);
  border-radius: 28rpx;
  padding: 40rpx;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.add-card-icon {
  font-size: 56rpx;
  color: var(--color-brand);
  margin-bottom: 16rpx;
}

.add-card-title {
  font-size: 28rpx;
  font-weight: 500;
  color: var(--color-text-primary);
  margin-bottom: 8rpx;
}

.add-card-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-bottom: 28rpx;
}

.add-card-btn {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  border-radius: 9999rpx;
  padding: 16rpx 40rpx;
}

.add-card-btn:active {
  transform: scale(0.97);
}

.add-card-btn-text {
  font-size: 26rpx;
  font-weight: 500;
  color: #ffffff;
}

.bottom-spacer {
  height: 48rpx;
}

/* ===== 场景小贴士卡片 ===== */
.tip-detail-card {
  background-color: var(--color-surface);
  border-radius: 28rpx;
  padding: 40rpx;
  box-shadow: var(--shadow-convex);
}

.tip-detail-head {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-bottom: 32rpx;
}

.tip-detail-icon {
  font-size: 36rpx;
  color: var(--color-brand);
}

.tip-detail-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: var(--color-text-primary);
}

.tip-detail-body {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  margin-bottom: 40rpx;
}

.tip-detail-row {
  display: flex;
  align-items: flex-start;
  gap: 12rpx;
}

.tip-detail-row-icon {
  font-size: 28rpx;
  color: var(--color-brand);
  flex-shrink: 0;
  margin-top: 2rpx;
}

.tip-detail-row-label {
  font-size: 26rpx;
  color: var(--color-text-tertiary);
  flex-shrink: 0;
  width: 64rpx;
}

.tip-detail-row-text {
  font-size: 26rpx;
  color: var(--color-text-primary);
  line-height: 1.5;
  flex: 1;
}

.tip-detail-actions {
  display: flex;
  gap: 20rpx;
}

.tip-detail-btn-ghost,
.tip-detail-btn-brand {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  padding: 24rpx 0;
  border-radius: 9999rpx;
  font-size: 28rpx;
  font-weight: 500;
}

.tip-detail-btn-ghost {
  background-color: var(--color-surface-alt);
  color: var(--color-text-primary);
}

.tip-detail-btn-brand {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
}

.tip-detail-btn-ghost .ph,
.tip-detail-btn-brand .ph {
  font-size: 30rpx;
}
</style>
