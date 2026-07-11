<template>
  <view class="lumira-container no-tabbar">
    <!-- Navbar -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left back-icon"></text>
      </view>
      <text class="lumira-nav-title">模板详情</text>
      <view class="lumira-nav-right"></view>
    </view>

    <!-- Empty State -->
    <view v-if="!template" class="empty-state fade-up">
      <text class="ph ph-warning-circle empty-icon"></text>
      <text class="empty-text">模板未找到</text>
      <view class="lumira-btn-primary empty-btn" @click="back">返回</view>
    </view>

    <!-- Main Content -->
    <template v-else>
      <!-- Overlay Preview Image -->
      <view class="preview-wrap fade-up">
        <view class="preview-img-wrap" :style="{ paddingBottom: previewAspectPadding }">
          <image class="preview-img" :src="coverImage" mode="aspectFill" />
          <CompositionOverlay :composition="template.composition" />
        </view>
      </view>

      <!-- Template Name & Tags -->
      <view class="title-wrap fade-up fade-up-d1">
        <text class="tpl-title">{{ template.meta.name }}</text>
        <view class="tag-row">
          <text class="lumira-tag lumira-tag-gold">{{ categoryLabel }}</text>
          <text
            v-for="tag in template.meta.tags"
            :key="tag"
            class="lumira-tag lumira-tag-gold"
          >{{ tag }}</text>
        </view>
      </view>

      <!-- Scene Guide -->
      <view class="block-pad fade-up fade-up-d2">
        <view class="lumira-card lumira-card-svg-bg">
          <text class="card-title">场景指南</text>
          <view class="guide-list">
            <view class="guide-item">
              <text class="ph ph-lightbulb guide-icon"></text>
              <view class="guide-text">
                <text class="guide-label">光线</text>
                <text class="guide-value">{{ template.sceneGuide.lightDirection }}</text>
              </view>
            </view>
            <view class="guide-item">
              <text class="ph ph-ruler guide-icon"></text>
              <view class="guide-text">
                <text class="guide-label">距离</text>
                <text class="guide-value">{{ template.sceneGuide.shootingDistance }}</text>
              </view>
            </view>
            <view class="guide-item">
              <text class="ph ph-image guide-icon"></text>
              <view class="guide-text">
                <text class="guide-label">背景</text>
                <text class="guide-value">{{ template.sceneGuide.background }}</text>
              </view>
            </view>
            <view class="guide-item">
              <text class="ph ph-magic-wand guide-icon"></text>
              <view class="guide-text">
                <text class="guide-label">道具</text>
                <text class="guide-value">{{ propsText }}</text>
              </view>
            </view>
            <view class="guide-item">
              <text class="ph ph-clock guide-icon"></text>
              <view class="guide-text">
                <text class="guide-label">最佳时间</text>
                <text class="guide-value">{{ template.sceneGuide.bestTime }}</text>
              </view>
            </view>
            <view
              v-for="(tip, idx) in template.sceneGuide.tips"
              :key="'tip-' + idx"
              class="guide-item"
            >
              <text class="ph ph-notepad guide-icon"></text>
              <view class="guide-text">
                <text class="guide-label">Tips</text>
                <text class="guide-value">{{ tip }}</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- Camera Parameters -->
      <view class="block-pad-top fade-up fade-up-d3">
        <view class="lumira-card lumira-card-svg-bg">
          <text class="card-title">相机参数建议</text>
          <view class="param-mono">
            <text class="param-line">{{ cameraLine1 }}</text>
            <text class="param-line">{{ cameraLine2 }}</text>
            <text class="param-line">{{ cameraLine3 }}</text>
          </view>
        </view>
      </view>

      <!-- Post Process Parameters -->
      <view class="block-pad-top fade-up fade-up-d4">
        <view class="lumira-card lumira-card-svg-bg">
          <text class="card-title">后期参数</text>
          <view class="param-mono">
            <text class="param-line">{{ postLine1 }}</text>
            <text class="param-line">{{ postLine2 }}</text>
            <text class="param-line">{{ postLine3 }}</text>
            <text class="param-line">{{ postLine4 }}</text>
          </view>
        </view>
      </view>

      <!-- Pose Reference -->
      <view v-if="hasSilhouette" class="block-pad-top fade-up fade-up-d5">
        <view class="lumira-card lumira-card-svg-bg">
          <text class="card-title">姿势参考</text>
          <view class="pose-preview-wrap">
            <PoseSilhouette :pose="template.pose" />
          </view>
          <text class="pose-desc">{{ template.pose.description }}</text>
        </view>
      </view>

      <!-- Unlock Status -->
      <view class="block-pad-top fade-up fade-up-d5">
        <view class="unlock-status">
          <text class="ph ph-check-circle unlock-icon"></text>
          <text class="unlock-text">{{ unlockText }}</text>
        </view>
      </view>

      <!-- Reference Source -->
      <view class="ref-source-wrap">
        <text class="ref-source">参数参考来源：{{ template.meta.referenceSource }}</text>
      </view>

      <!-- Spacer for fixed CTA -->
      <view class="cta-spacer"></view>
    </template>

    <!-- Fixed Bottom CTA -->
    <view v-if="template" class="fixed-cta">
      <view class="lumira-btn-primary" @click="goCapture">套用此模板拍摄</view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import CompositionOverlay from '@/components/CompositionOverlay.vue'
import PoseSilhouette from '@/components/PoseSilhouette.vue'
import type { PhotoTemplate } from '@/types/template'

const { loadTemplate } = useTemplate()
const template = ref<PhotoTemplate | null>(null)

onLoad((options) => {
  const id = options?.templateId
  if (id) {
    template.value = loadTemplate(id)
  }
})

const coverImage = computed(() => {
  const t = template.value
  if (!t) return ''
  return t.meta.cover || `https://picsum.photos/seed/${t.meta.id}/800/600`
})

const previewAspectPadding = computed(() => {
  const ratio = template.value?.composition.aspectRatio || '4:3'
  const parts = ratio.split(':')
  const w = Number(parts[0]) || 4
  const h = Number(parts[1]) || 3
  return `${(h / w) * 100}%`
})

const hasSilhouette = computed(() => {
  const pose = template.value?.pose
  if (!pose) return false
  if (pose.silhouette.type === 'builtin' && pose.silhouette.data === 'none') return false
  return true
})

const categoryLabel = computed(() => {
  const cat = template.value?.meta.category
  if (!cat) return ''
  const map: Record<string, string> = {
    portrait: '人像', landscape: '风光', food: '美食',
    street: '街拍', night: '夜景', macro: '微距', 'still-life': '静物'
  }
  return map[cat] || cat
})

const wbLabel = computed(() => {
  const wb = template.value?.camera.whiteBalance
  if (!wb) return ''
  const map: Record<string, string> = {
    daylight: '日光', cloudy: '阴天', shade: '阴影',
    tungsten: '白炽灯', fluorescent: '荧光灯', custom: '自定义'
  }
  return map[wb] || wb
})

const flashLabel = computed(() => {
  const f = template.value?.camera.flashMode
  if (!f) return ''
  const map: Record<string, string> = {
    off: '关闭', on: '开启', auto: '自动', torch: '常亮'
  }
  return map[f] || f
})

const focusLabel = computed(() => {
  const f = template.value?.camera.focusMode
  if (!f) return ''
  const map: Record<string, string> = {
    auto: '自动', manual: '手动', continuous: '连续'
  }
  return map[f] || f
})

const lensLabel = computed(() => {
  const l = template.value?.camera.lensSuggestion
  if (!l) return ''
  const map: Record<string, string> = {
    wide: '广角', main: '主摄', telephoto: '长焦', ultra_wide: '超广角'
  }
  return map[l] || l
})

const lutLabel = computed(() => {
  const l = template.value?.postProcess.lut
  if (!l) return ''
  const map: Record<string, string> = {
    none: '无', cinematic: '电影感', vintage: '复古', bw: '黑白',
    warm_film: '暖色胶片', cool_film: '冷色胶片', pastel: '柔色', fuji: '富士'
  }
  return map[l] || l
})

const evDisplay = computed(() => {
  const ev = template.value?.camera.exposureCompensation
  if (ev === undefined || ev === null) return ''
  return ev > 0 ? `+${ev}` : `${ev}`
})

const wbDisplay = computed(() => {
  const k = template.value?.camera.whiteBalanceK
  return k ? `${k}K` : ''
})

const propsText = computed(() => {
  return (template.value?.sceneGuide.props || []).join('、')
})

const cameraLine1 = computed(() => {
  const c = template.value?.camera
  if (!c) return ''
  return `EV ${evDisplay.value}  ISO ${c.iso}  ${c.shutterSpeed}s`
})

const cameraLine2 = computed(() => {
  const c = template.value?.camera
  if (!c) return ''
  return `WB: ${wbLabel.value} ${wbDisplay.value}  镜头: ${lensLabel.value}`
})

const cameraLine3 = computed(() => {
  const c = template.value?.camera
  if (!c) return ''
  return `闪光: ${flashLabel.value}  对焦: ${focusLabel.value}`
})

function formatSigned(n: number): string {
  return n > 0 ? `+${n}` : `${n}`
}

const postLine1 = computed(() => {
  const p = template.value?.postProcess
  if (!p) return ''
  return `裁剪: ${p.cropRatio}    LUT: ${lutLabel.value}`
})

const postLine2 = computed(() => {
  const c = template.value?.postProcess.color
  if (!c) return ''
  return `亮度: ${formatSigned(c.brightness)}  对比: ${formatSigned(c.contrast)}  饱和: ${formatSigned(c.saturation)}`
})

const postLine3 = computed(() => {
  const c = template.value?.postProcess.color
  if (!c) return ''
  return `色温: ${formatSigned(c.temperature)}  色调: ${formatSigned(c.tint)}`
})

const postLine4 = computed(() => {
  const p = template.value?.postProcess
  if (!p) return ''
  return `磨皮: ${p.smoothStrength}  锐化: ${p.sharpen}  暗角: ${p.vignette}  颗粒: ${p.grain}`
})

const unlockText = computed(() => {
  const price = template.value?.meta.price ?? 0
  return price === 0 ? '免费' : `精选 ¥${price}`
})

const back = () => uni.navigateBack()
const goCapture = () => uni.navigateTo({ url: `/pages/capture/index?templateId=${template.value!.meta.id}` })
</script>

<style lang="scss" scoped>
.back-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 200rpx 48rpx;
  gap: 32rpx;
}

.empty-icon {
  font-size: 96rpx;
  color: var(--color-text-tertiary);
}

.empty-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  color: var(--color-text-secondary);
}

.empty-btn {
  min-width: 240rpx;
  text-align: center;
}

.preview-wrap {
  padding: 0 48rpx 40rpx;
}

.preview-img-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 75%;
  border-radius: 28rpx;
  overflow: hidden;
}

.preview-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.title-wrap {
  padding: 0 48rpx;
}

.tpl-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 20rpx;
}

.tag-row {
  display: flex;
  gap: 12rpx;
  flex-wrap: wrap;
}

.block-pad {
  padding: 48rpx 48rpx 0;
}

.block-pad-top {
  padding: 32rpx 48rpx 0;
}

.card-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 28rpx;
}

.guide-list {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.guide-item {
  display: flex;
  gap: 16rpx;
  align-items: flex-start;
}

.guide-icon {
  flex-shrink: 0;
  font-size: 32rpx;
  color: var(--color-brand);
  margin-top: 4rpx;
}

.guide-text {
  flex: 1;
  min-width: 0;
}

.guide-label {
  font-size: 26rpx;
  font-weight: 500;
  color: var(--color-text-primary);
}

.guide-value {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  margin-left: 8rpx;
  word-break: break-all;
}

.param-mono {
  line-height: 2;
  overflow-x: hidden;
  word-break: break-all;
}

.param-line {
  display: block;
  font-family: 'Courier New', monospace;
  font-size: 24rpx;
  color: var(--color-text-secondary);
  letter-spacing: 0.02em;
  white-space: normal;
  word-break: break-all;
  overflow-wrap: break-word;
}

/* 卡片溢出保护 */
.lumira-card {
  box-sizing: border-box;
  max-width: 100%;
}

.pose-preview-wrap {
  position: relative;
  width: 100%;
  padding-bottom: 100%;
  border-radius: 28rpx;
  overflow: hidden;
  background: linear-gradient(135deg, rgba(201, 169, 110, 0.08), rgba(201, 169, 110, 0.02));
  margin-bottom: 24rpx;
}

.pose-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  line-height: 1.6;
  word-break: break-all;
}

.unlock-status {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.unlock-icon {
  font-size: 32rpx;
  color: var(--color-success);
}

.unlock-text {
  font-size: 26rpx;
  color: var(--color-text-secondary);
}

.ref-source-wrap {
  padding: 32rpx 48rpx 0;
}

.ref-source {
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  line-height: 1.6;
  word-break: break-all;
}

.cta-spacer {
  height: 200rpx;
}

.fixed-cta {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 32rpx 48rpx 48rpx;
  background: linear-gradient(to top, var(--color-canvas) 60%, transparent);
  z-index: 100;
  box-sizing: border-box;
  width: 100%;
  overflow-x: hidden;
}
</style>
