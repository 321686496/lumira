<template>
  <view class="capture-page">
    <!-- 顶部沉浸式深色标题栏（自定义，不走 lumira-nav） -->
    <view class="capture-nav">
      <view class="status-spacer" :style="{ height: statusBarHeight + 'px' }"></view>
      <view class="nav-main">
        <view class="nav-back" @click="back">
          <text class="ph ph-caret-left" />
        </view>
        <view class="nav-center">
          <text class="nav-title">{{ currentTemplate?.meta.name || '拍摄' }}</text>
          <text class="nav-sub" v-if="currentTemplate">{{ categoryLabel }} · {{ currentTemplate.composition.aspectRatio }}</text>
        </view>
        <view class="nav-actions">
          <view class="nav-action" @click="goSceneGuide">
            <text class="ph ph-question" />
          </view>
          <view class="nav-action" :class="{ active: flashOn }" @click="toggleFlash">
            <text class="ph" :class="flashOn ? 'ph-lightning' : 'ph-lightning-slash'" />
          </view>
        </view>
      </view>
    </view>

    <!-- 取景器（占位图） -->
    <view class="viewfinder">
      <image class="viewfinder-bg" src="https://picsum.photos/seed/capture-viewfinder/400/600" mode="aspectFill" />
      <view class="viewfinder-mask" />

      <!-- 构图叠图 -->
      <CompositionOverlay
        v-if="currentTemplate"
        :composition="currentTemplate.composition"
        :overlay-opacity-override="panelExpanded ? 0.2 : undefined"
      />

      <!-- 姿势剪影叠图 -->
      <view
        v-if="currentTemplate && hasSilhouette"
        class="silhouette-layer"
        :style="silhouetteLayerStyle"
      >
        <PoseSilhouette :pose="currentTemplate.pose" />
      </view>

      <!-- 顶部参数 pill 栏 -->
      <view class="param-pill-bar" v-if="currentTemplate">
        <view class="param-pill" @click="openPanel('camera')">
          <text class="pill-label">EV</text>
          <text class="pill-value">{{ evDisplay }}</text>
        </view>
        <view class="param-pill" @click="openPanel('camera')">
          <text class="pill-label">WB</text>
          <text class="pill-value">{{ wbDisplay }}</text>
        </view>
        <view class="param-pill apply-pill" :class="{ applied }" @click="toggleApply">
          <text class="ph" :class="applied ? 'ph-check' : 'ph-magic-wand'" />
          <text class="pill-text">{{ applied ? '已应用' : '一键应用' }}</text>
        </view>
      </view>
    </view>

    <!-- 底部控制区 -->
    <view class="capture-bottom">
      <!-- 快门行 -->
      <view class="shutter-row">
        <view class="last-photo" @click="goPreview">
          <image class="last-photo-img" src="https://picsum.photos/seed/last-photo/100/100" mode="aspectFill" />
        </view>
        <view class="shutter-btn" @click="onShutter">
          <view class="shutter-inner" />
        </view>
        <view class="flip-btn" @click="flipCamera">
          <text class="ph ph-arrows-clockwise" />
        </view>
      </view>

      <!-- 模板快速切换横滑 -->
      <scroll-view class="template-strip" scroll-x>
        <view class="strip-list">
          <view
            v-for="tpl in recentTemplates"
            :key="tpl.meta.id"
            class="strip-item"
            :class="{ active: tpl.meta.id === currentTemplateId }"
            @click="switchTemplate(tpl.meta.id)"
          >
            <image class="strip-img" :src="tpl.meta.cover" mode="aspectFill" />
            <text class="strip-name">{{ tpl.meta.name }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <!-- 半屏参数面板 -->
    <ParamPanel
      v-if="currentTemplate"
      :template="currentTemplate"
      :visible="panelExpanded"
      :applied="applied"
      @close="panelExpanded = false"
      @apply="toggleApply"
      @update:opacity="onOpacityUpdate"
    />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import CompositionOverlay from '@/components/CompositionOverlay.vue'
import PoseSilhouette from '@/components/PoseSilhouette.vue'
import ParamPanel from '@/components/ParamPanel.vue'

const { loadTemplate, recentTemplates, pushRecent, loadRecent } = useTemplate()

const statusBarHeight = uni.getSystemInfoSync().statusBarHeight || 20
const currentTemplateId = ref('')
const currentTemplate = computed(() =>
  currentTemplateId.value ? loadTemplate(currentTemplateId.value) : null
)
const panelExpanded = ref(false)
const applied = ref(false)
const flashOn = ref(false)

onLoad((options) => {
  if (options?.templateId) {
    currentTemplateId.value = options.templateId
    pushRecent(options.templateId)
  }
  loadRecent()
  // 如果没有 templateId，使用第一个最近模板或第一个内置模板
  if (!currentTemplateId.value && recentTemplates.value.length > 0) {
    currentTemplateId.value = recentTemplates.value[0].meta.id
  }
})

const hasSilhouette = computed(() => {
  const pose = currentTemplate.value?.pose
  if (!pose) return false
  if (pose.silhouette.type === 'builtin' && pose.silhouette.data === 'none') return false
  return true
})

// 剪影叠图层定位样式
const silhouetteLayerStyle = computed(() => {
  const pose = currentTemplate.value?.pose
  if (!pose) return {}
  return {
    left: `${pose.position.x * 100}%`,
    top: `${pose.position.y * 100}%`,
    transform: `translate(-50%, -50%)`
  }
})

const evDisplay = computed(() => {
  const ev = currentTemplate.value?.camera.exposureCompensation
  if (ev === undefined) return ''
  return ev > 0 ? `+${ev}` : `${ev}`
})

const wbDisplay = computed(() => {
  const k = currentTemplate.value?.camera.whiteBalanceK
  return k ? `${k}K` : ''
})

const categoryLabel = computed(() => {
  const cat = currentTemplate.value?.meta.category
  const map: Record<string, string> = {
    portrait: '人像', landscape: '风光', food: '美食',
    street: '街拍', night: '夜景', macro: '微距', 'still-life': '静物'
  }
  return cat ? (map[cat] || cat) : ''
})

const openPanel = (_tab: string) => {
  panelExpanded.value = true
}

const toggleApply = () => {
  applied.value = !applied.value
  uni.showToast({
    title: applied.value ? '已应用模板参数' : '已重置参数',
    icon: 'none'
  })
}

const onOpacityUpdate = (v: number) => {
  // 透明度变化通过 prop 传入，不需要额外处理
  console.log('opacity update', v)
}

const switchTemplate = (id: string) => {
  currentTemplateId.value = id
  applied.value = false
  pushRecent(id)
}

const back = () => uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/home/index' }) })
const goSceneGuide = () => uni.navigateTo({ url: '/pages/capture/scene-guide' })
const goPreview = () => uni.navigateTo({ url: '/pages/capture/preview' })
const onShutter = () => uni.navigateTo({ url: '/pages/capture/preview' })
const flipCamera = () => uni.showToast({ title: '翻转镜头', icon: 'none' })
const toggleFlash = () => { flashOn.value = !flashOn.value }
</script>

<style lang="scss" scoped>
.capture-page {
  width: 100%;
  height: 100vh;
  background: #181614;
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* ===== 沉浸式标题栏 ===== */
.capture-nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  background: transparent;
}

.capture-nav::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 200rpx;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.4), transparent);
  pointer-events: none;
  z-index: -1;
}

.status-spacer {
  width: 100%;
}

.nav-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 32rpx;
  height: 96rpx;
}

.nav-back .ph {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.35);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 36rpx;
  color: #fff;
}

.nav-center {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.nav-title {
  font-size: 32rpx;
  font-weight: 600;
  color: #fff;
  text-shadow: 0 1rpx 4rpx rgba(0, 0, 0, 0.3);
}

.nav-sub {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 4rpx;
}

.nav-actions {
  display: flex;
  align-items: center;
}

.nav-action {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.35);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32rpx;
  color: #fff;
  margin-left: 12rpx;
}

.nav-action.active {
  background: rgba(201, 169, 110, 0.7);
}

/* ===== 取景器 ===== */
.viewfinder {
  flex: 1;
  position: relative;
  overflow: hidden;
}

.viewfinder-bg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.viewfinder-mask {
  position: absolute;
  inset: 0;
  background: rgba(24, 22, 20, 0.35);
}

/* ===== 剪影叠图层 ===== */
.silhouette-layer {
  position: absolute;
  width: 40%;
  aspect-ratio: 1 / 1.6;
  z-index: 3;
  pointer-events: none;
  opacity: 0.7;
}

/* ===== 参数 pill 栏 ===== */
.param-pill-bar {
  position: absolute;
  top: 240rpx;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 16rpx;
  z-index: 5;
}

.param-pill {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}

.pill-label {
  font-size: 20rpx;
  color: rgba(255, 255, 255, 0.6);
}

.pill-value {
  font-size: 24rpx;
  color: #fff;
  font-family: 'Courier New', monospace;
}

.apply-pill {
  background: rgba(201, 169, 110, 0.8);
}

.apply-pill.applied {
  background: rgba(122, 139, 92, 0.8);
}

.pill-text {
  font-size: 24rpx;
  color: #fff;
}

/* ===== 底部控制区 ===== */
.capture-bottom {
  position: relative;
  z-index: 50;
  background: rgba(24, 22, 20, 0.85);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  padding: 32rpx 40rpx;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
}

/* ===== 快门行 ===== */
.shutter-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 56rpx;
}

.last-photo {
  width: 100rpx;
  height: 100rpx;
  border-radius: 20rpx;
  overflow: hidden;
  border: 3rpx solid rgba(255, 255, 255, 0.15);
}

.last-photo-img {
  width: 100%;
  height: 100%;
}

.shutter-btn {
  width: 152rpx;
  height: 152rpx;
  border-radius: 50%;
  border: 6rpx solid var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
}

.shutter-inner {
  width: 116rpx;
  height: 116rpx;
  border-radius: 50%;
  background: #fff;
}

.flip-btn {
  width: 84rpx;
  height: 84rpx;
  border-radius: 50%;
  border: 3rpx solid rgba(255, 255, 255, 0.25);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
}

/* ===== 模板横滑 ===== */
.template-strip {
  margin-top: 32rpx;
  white-space: nowrap;
}

.strip-list {
  display: inline-flex;
  gap: 16rpx;
}

.strip-item {
  width: 100rpx;
  height: 100rpx;
  border-radius: 20rpx;
  overflow: hidden;
  position: relative;
  border: 3rpx solid rgba(255, 255, 255, 0.15);
  flex-shrink: 0;
}

.strip-item.active {
  border: 4rpx solid var(--color-brand);
  box-shadow: 0 0 24rpx rgba(var(--color-brand-rgb), 0.4);
}

.strip-img {
  width: 100%;
  height: 100%;
}

.strip-name {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(transparent, rgba(0, 0, 0, 0.75));
  padding: 16rpx 0 6rpx;
  text-align: center;
  color: #fff;
  font-size: 16rpx;
}
</style>
