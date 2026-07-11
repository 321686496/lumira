<template>
  <view class="param-panel" :class="{ 'is-visible': visible }">
    <!-- 遮罩层 -->
    <view class="param-panel-mask" v-if="visible" @click="emit('close')" />

    <!-- 面板主体 -->
    <view class="param-panel-body" :class="{ 'is-visible': visible }">
      <!-- 拖拽手柄（点击关闭） -->
      <view class="panel-handle" @click="emit('close')">
        <view class="handle-bar" />
      </view>

      <!-- 模板概要 -->
      <view class="panel-summary">
        <view class="summary-name">{{ template.meta.name }}</view>
        <view class="summary-desc">{{ template.meta.description }}</view>
      </view>

      <!-- Tab 切换栏 -->
      <view class="panel-tabs">
        <view
          v-for="(tab, idx) in tabs"
          :key="tab.key"
          class="tab-item"
          :class="{ active: activeTab === idx }"
          @click="activeTab = idx"
        >
          <text class="ph" :class="tab.icon" />
          <text class="tab-label">{{ tab.label }}</text>
        </view>
      </view>

      <!-- 滚动内容区 -->
      <scroll-view scroll-y class="panel-content">
        <!-- 相机 Tab -->
        <view v-if="activeTab === 0" class="tab-pane">
          <!-- 曝光补偿 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">曝光补偿 EV</text>
              <text class="slider-value">{{ evDisplay }}</text>
            </view>
            <slider
              :value="template.camera.exposureCompensation"
              :min="-3"
              :max="3"
              :step="0.3"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateCamera('exposureCompensation', e.detail.value)"
            />
          </view>

          <!-- ISO -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">ISO</text>
              <text class="slider-value">{{ template.camera.iso === 0 ? '自动' : template.camera.iso }}</text>
            </view>
            <slider
              :value="template.camera.iso"
              :min="0"
              :max="6400"
              :step="50"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateCamera('iso', e.detail.value)"
            />
          </view>

          <!-- 快门速度 -->
          <view class="param-row">
            <view class="param-label">快门速度</view>
            <view class="param-value">{{ template.camera.shutterSpeed }}</view>
          </view>

          <!-- 白平衡 -->
          <view class="param-row">
            <view class="param-label">白平衡</view>
            <view class="param-value">
              {{ wbLabel(template.camera.whiteBalance, template.camera.whiteBalanceK) }}
            </view>
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">色温 K</text>
              <text class="slider-value">{{ template.camera.whiteBalanceK }}K</text>
            </view>
            <slider
              :value="template.camera.whiteBalanceK"
              :min="2500"
              :max="8000"
              :step="100"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateCamera('whiteBalanceK', e.detail.value)"
            />
          </view>
          <view class="pill-row">
            <view
              v-for="wb in wbOptions"
              :key="wb.value"
              class="pill-option"
              :class="{ active: template.camera.whiteBalance === wb.value }"
              @click="updateCamera('whiteBalance', wb.value)"
            >
              {{ wb.label }}
            </view>
          </view>

          <!-- 闪光 -->
          <view class="param-row">
            <view class="param-label">闪光</view>
            <view class="param-value">{{ flashLabel(template.camera.flashMode) }}</view>
          </view>
          <view class="pill-row">
            <view
              v-for="f in flashOptions"
              :key="f.value"
              class="pill-option"
              :class="{ active: template.camera.flashMode === f.value }"
              @click="updateCamera('flashMode', f.value)"
            >
              {{ f.label }}
            </view>
          </view>

          <!-- 对焦 -->
          <view class="param-row">
            <view class="param-label">对焦</view>
            <view class="param-value">{{ focusLabel(template.camera.focusMode) }}</view>
          </view>
          <view class="pill-row">
            <view
              v-for="f in focusOptions"
              :key="f.value"
              class="pill-option"
              :class="{ active: template.camera.focusMode === f.value }"
              @click="updateCamera('focusMode', f.value)"
            >
              {{ f.label }}
            </view>
          </view>

          <!-- 镜头建议 -->
          <view class="param-row">
            <view class="param-label">镜头建议</view>
            <view class="param-value">{{ lensLabel(template.camera.lensSuggestion) }}</view>
          </view>
        </view>

        <!-- 构图 Tab -->
        <view v-if="activeTab === 1" class="tab-pane">
          <view class="param-row">
            <view class="param-label">构图类型</view>
            <view class="param-value">{{ overlayTypeLabel(template.composition.overlayType) }}</view>
          </view>
          <view class="param-row" v-if="template.composition.gridType">
            <view class="param-label">网格细分</view>
            <view class="param-value">
              {{ ({ thirds: '三分', quarters: '四分', golden_spiral: '黄金螺旋' } as Record<string, string>)[template.composition.gridType] || template.composition.gridType }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">宽高比</view>
            <view class="param-value">{{ template.composition.aspectRatio }}</view>
          </view>
          <view class="param-row">
            <view class="param-label">主体建议框</view>
            <view class="param-value">
              {{ Math.round(template.composition.subjectFrame.x * 100) }}%, {{ Math.round(template.composition.subjectFrame.y * 100) }}%
            </view>
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">叠图透明度</text>
              <text class="slider-value">{{ Math.round(template.composition.opacity * 100) }}%</text>
            </view>
            <slider
              :value="template.composition.opacity * 100"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateComposition('opacity', e.detail.value / 100)"
            />
          </view>
          <view class="desc-block" v-if="template.composition.description">
            <view class="desc-title">构图说明</view>
            <view class="desc-text">{{ template.composition.description }}</view>
          </view>
        </view>

        <!-- 场景 Tab -->
        <view v-if="activeTab === 2" class="tab-pane">
          <view class="param-row">
            <view class="param-label">光线方向</view>
            <view class="param-value">{{ template.sceneGuide.lightDirection }}</view>
          </view>
          <view class="param-row">
            <view class="param-label">拍摄距离</view>
            <view class="param-value">{{ template.sceneGuide.shootingDistance }}</view>
          </view>
          <view class="param-row">
            <view class="param-label">背景建议</view>
            <view class="param-value">{{ template.sceneGuide.background }}</view>
          </view>
          <view class="param-row">
            <view class="param-label">最佳时间</view>
            <view class="param-value">{{ template.sceneGuide.bestTime }}</view>
          </view>
          <view class="tag-list-block" v-if="template.sceneGuide.props.length">
            <view class="desc-title">道具建议</view>
            <view class="tag-list">
              <view class="prop-tag" v-for="(item, idx) in template.sceneGuide.props" :key="idx">
                {{ item }}
              </view>
            </view>
          </view>
          <view class="desc-block" v-if="template.sceneGuide.tips.length">
            <view class="desc-title">拍摄贴士</view>
            <view class="tips-list">
              <view class="tips-item" v-for="(tip, idx) in template.sceneGuide.tips" :key="idx">
                <text class="ph ph-circle tips-dot" />
                <text class="tips-text">{{ tip }}</text>
              </view>
            </view>
          </view>
        </view>

        <!-- 姿势 Tab -->
        <view v-if="activeTab === 3" class="tab-pane">
          <view class="silhouette-preview">
            <view class="silhouette-wrap">
              <image
                v-if="template.pose.silhouette.type === 'image'"
                :src="template.pose.silhouette.data"
                class="silhouette-img"
                mode="aspectFit"
              />
              <view v-else class="silhouette-placeholder">
                <text class="ph ph-person silhouette-icon" />
              </view>
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">剪影类型</view>
            <view class="param-value">
              {{ ({ builtin: '内置', image: '图片', svg: 'SVG' } as Record<string, string>)[template.pose.silhouette.type] || template.pose.silhouette.type }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">位置</view>
            <view class="param-value">
              {{ Math.round(template.pose.position.x * 100) }}%, {{ Math.round(template.pose.position.y * 100) }}%
            </view>
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">缩放</text>
              <text class="slider-value">{{ template.pose.scale.toFixed(2) }}</text>
            </view>
            <slider
              :value="template.pose.scale"
              :min="0.3"
              :max="3"
              :step="0.05"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePose('scale', e.detail.value)"
            />
          </view>
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">旋转</text>
              <text class="slider-value">{{ template.pose.rotation }}°</text>
            </view>
            <slider
              :value="template.pose.rotation"
              :min="-180"
              :max="180"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePose('rotation', e.detail.value)"
            />
          </view>
          <view class="desc-block" v-if="template.pose.description">
            <view class="desc-title">姿势描述</view>
            <view class="desc-text">{{ template.pose.description }}</view>
          </view>
        </view>

        <!-- 后期 Tab -->
        <view v-if="activeTab === 4" class="tab-pane">
          <view class="param-row">
            <view class="param-label">裁剪比</view>
            <view class="param-value">{{ template.postProcess.cropRatio }}</view>
          </view>

          <!-- LUT 预设 -->
          <view class="param-row">
            <view class="param-label">LUT 预设</view>
            <view class="param-value">{{ lutLabel(template.postProcess.lut) }}</view>
          </view>
          <view class="pill-row">
            <view
              v-for="lut in lutOptions"
              :key="lut.value"
              class="pill-option"
              :class="{ active: template.postProcess.lut === lut.value }"
              @click="updatePostProcess('lut', lut.value)"
            >
              {{ lut.label }}
            </view>
          </view>

          <!-- 亮度 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">亮度</text>
              <text class="slider-value">{{ template.postProcess.color.brightness }}</text>
            </view>
            <slider
              :value="template.postProcess.color.brightness"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('brightness', e.detail.value)"
            />
          </view>
          <!-- 对比度 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">对比度</text>
              <text class="slider-value">{{ template.postProcess.color.contrast }}</text>
            </view>
            <slider
              :value="template.postProcess.color.contrast"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('contrast', e.detail.value)"
            />
          </view>
          <!-- 饱和度 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">饱和度</text>
              <text class="slider-value">{{ template.postProcess.color.saturation }}</text>
            </view>
            <slider
              :value="template.postProcess.color.saturation"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('saturation', e.detail.value)"
            />
          </view>
          <!-- 色温 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">色温</text>
              <text class="slider-value">{{ template.postProcess.color.temperature }}</text>
            </view>
            <slider
              :value="template.postProcess.color.temperature"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('temperature', e.detail.value)"
            />
          </view>
          <!-- 色调 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">色调</text>
              <text class="slider-value">{{ template.postProcess.color.tint }}</text>
            </view>
            <slider
              :value="template.postProcess.color.tint"
              :min="-100"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updateColor('tint', e.detail.value)"
            />
          </view>
          <!-- 磨皮 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">磨皮</text>
              <text class="slider-value">{{ template.postProcess.smoothStrength }}</text>
            </view>
            <slider
              :value="template.postProcess.smoothStrength"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePostProcess('smoothStrength', e.detail.value)"
            />
          </view>
          <!-- 锐化 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">锐化</text>
              <text class="slider-value">{{ template.postProcess.sharpen }}</text>
            </view>
            <slider
              :value="template.postProcess.sharpen"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePostProcess('sharpen', e.detail.value)"
            />
          </view>
          <!-- 暗角 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">暗角</text>
              <text class="slider-value">{{ template.postProcess.vignette }}</text>
            </view>
            <slider
              :value="template.postProcess.vignette"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePostProcess('vignette', e.detail.value)"
            />
          </view>
          <!-- 颗粒 -->
          <view class="slider-block">
            <view class="slider-header">
              <text class="param-label">颗粒</text>
              <text class="slider-value">{{ template.postProcess.grain }}</text>
            </view>
            <slider
              :value="template.postProcess.grain"
              :min="0"
              :max="100"
              :step="1"
              activeColor="var(--color-brand)"
              backgroundColor="var(--color-divider)"
              block-color="var(--color-brand)"
              @change="(e: any) => updatePostProcess('grain', e.detail.value)"
            />
          </view>
        </view>
      </scroll-view>

      <!-- 底部一键应用按钮 -->
      <view class="panel-footer">
        <view
          class="apply-btn"
          :class="{ 'is-applied': applied }"
          @click="!applied && emit('apply')"
        >
          <text class="ph" :class="applied ? 'ph-check-circle' : 'ph-sparkle'" />
          <text>{{ applied ? '已应用模板参数' : '一键应用模板参数' }}</text>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { PhotoTemplate, WhiteBalance, FlashMode, FocusMode, LutPreset } from '@/types/template'

const props = defineProps<{
  template: PhotoTemplate
  visible: boolean
  applied: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'apply'): void
  (e: 'update:opacity', value: number): void
  (e: 'update:template', template: PhotoTemplate): void
}>()

const tabs = [
  { key: 'camera', label: '相机', icon: 'ph-camera' },
  { key: 'composition', label: '构图', icon: 'ph-frame-corners' },
  { key: 'scene', label: '场景', icon: 'ph-sun' },
  { key: 'pose', label: '姿势', icon: 'ph-person' },
  { key: 'post', label: '后期', icon: 'ph-magic-wand' }
]

const activeTab = ref(0)

// 选项列表
const wbOptions: { value: WhiteBalance; label: string }[] = [
  { value: 'daylight', label: '日光' },
  { value: 'cloudy', label: '阴天' },
  { value: 'shade', label: '阴影' },
  { value: 'tungsten', label: '钨丝灯' },
  { value: 'fluorescent', label: '荧光灯' },
  { value: 'custom', label: '自定义' }
]
const flashOptions: { value: FlashMode; label: string }[] = [
  { value: 'off', label: '关闭' },
  { value: 'on', label: '常开' },
  { value: 'auto', label: '自动' },
  { value: 'torch', label: '手电筒' }
]
const focusOptions: { value: FocusMode; label: string }[] = [
  { value: 'auto', label: '自动' },
  { value: 'manual', label: '手动' },
  { value: 'continuous', label: '连续' }
]
const lutOptions: { value: LutPreset; label: string }[] = [
  { value: 'none', label: '原图' },
  { value: 'cinematic', label: '电影感' },
  { value: 'vintage', label: '复古' },
  { value: 'bw', label: '黑白' },
  { value: 'warm_film', label: '暖色' },
  { value: 'cool_film', label: '冷色' },
  { value: 'pastel', label: '柔色' },
  { value: 'fuji', label: '富士' }
]

const evDisplay = computed(() => {
  const ev = props.template.camera.exposureCompensation
  return ev > 0 ? `+${ev.toFixed(1)}` : ev.toFixed(1)
})

const overlayTypeLabel = (t: string) => ({
  rule_of_thirds: '三分法',
  golden_ratio: '黄金比例',
  diagonal: '对角线',
  grid: '网格',
  leading_lines: '引导线',
  center: '中心',
  none: '无'
}[t] || t)

const wbLabel = (wb: string, k: number) => ({
  daylight: `日光 ${k}K`,
  cloudy: `阴天 ${k}K`,
  shade: `阴影 ${k}K`,
  tungsten: `钨丝灯 ${k}K`,
  fluorescent: '荧光灯',
  custom: `自定义 ${k}K`
}[wb] || wb)

const flashLabel = (f: string) => ({
  off: '关闭',
  on: '常开',
  auto: '自动',
  torch: '手电筒'
}[f] || f)

const focusLabel = (f: string) => ({
  auto: '自动',
  manual: '手动',
  continuous: '连续'
}[f] || f)

const lensLabel = (l: string) => ({
  wide: '广角',
  main: '主摄',
  telephoto: '长焦',
  ultra_wide: '超广角'
}[l] || l)

const lutLabel = (l: string) => ({
  none: '无',
  cinematic: '电影感',
  vintage: '复古',
  bw: '黑白',
  warm_film: '暖色胶片',
  cool_film: '冷色胶片',
  pastel: '柔色',
  fuji: '富士'
}[l] || l)

// ===== 参数修改方法 =====

/** 深拷贝并触发更新 */
function cloneTemplate(): PhotoTemplate {
  return JSON.parse(JSON.stringify(props.template))
}

function updateCamera<K extends keyof PhotoTemplate['camera']>(key: K, value: PhotoTemplate['camera'][K]) {
  const tpl = cloneTemplate()
  tpl.camera[key] = value
  emit('update:template', tpl)
}

function updateComposition<K extends keyof PhotoTemplate['composition']>(key: K, value: PhotoTemplate['composition'][K]) {
  const tpl = cloneTemplate()
  tpl.composition[key] = value
  emit('update:template', tpl)
}

function updatePose<K extends keyof PhotoTemplate['pose']>(key: K, value: PhotoTemplate['pose'][K]) {
  const tpl = cloneTemplate()
  tpl.pose[key] = value
  emit('update:template', tpl)
}

function updatePostProcess<K extends keyof PhotoTemplate['postProcess']>(key: K, value: PhotoTemplate['postProcess'][K]) {
  const tpl = cloneTemplate()
  tpl.postProcess[key] = value
  emit('update:template', tpl)
}

function updateColor<K extends keyof PhotoTemplate['postProcess']['color']>(key: K, value: PhotoTemplate['postProcess']['color'][K]) {
  const tpl = cloneTemplate()
  tpl.postProcess.color[key] = value
  emit('update:template', tpl)
}
</script>

<style lang="scss" scoped>
.param-panel {
  position: fixed;
  inset: 0;
  z-index: 1000;
  pointer-events: none;
}

.param-panel-mask {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  pointer-events: auto;
  animation: fadeIn 0.25s ease;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.param-panel-body {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 60vh;
  background-color: var(--color-surface);
  border-radius: 32rpx 32rpx 0 0;
  box-shadow: 0 -8rpx 32rpx rgba(0, 0, 0, 0.12);
  transform: translateY(100%);
  transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
  display: flex;
  flex-direction: column;
  pointer-events: auto;
  overflow-x: hidden;
  box-sizing: border-box;

  &.is-visible {
    transform: translateY(0);
  }
}

/* 拖拽手柄 */
.panel-handle {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20rpx 0 8rpx;
  flex-shrink: 0;
}

.handle-bar {
  width: 80rpx;
  height: 8rpx;
  border-radius: 9999rpx;
  background-color: var(--color-divider);
}

/* 模板概要 */
.panel-summary {
  padding: 12rpx 40rpx 20rpx;
  flex-shrink: 0;
  box-sizing: border-box;
}

.summary-name {
  font-family: var(--font-cn-title);
  font-size: 36rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  line-height: 1.3;
}

.summary-desc {
  font-size: 24rpx;
  color: var(--color-text-tertiary);
  margin-top: 8rpx;
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* Tab 切换栏 */
.panel-tabs {
  display: flex;
  padding: 0 20rpx;
  border-bottom: 1rpx solid var(--color-divider);
  flex-shrink: 0;
  overflow-x: auto;
  box-sizing: border-box;
}

.tab-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6rpx;
  padding: 16rpx 0;
  color: var(--color-text-tertiary);
  position: relative;
  transition: color 0.2s ease;

  .ph {
    font-size: 36rpx;
    line-height: 1;
  }

  .tab-label {
    font-size: 22rpx;
    letter-spacing: 0.04em;
  }

  &.active {
    color: var(--color-brand);

    &::after {
      content: '';
      position: absolute;
      bottom: -1rpx;
      left: 50%;
      transform: translateX(-50%);
      width: 48rpx;
      height: 4rpx;
      border-radius: 9999rpx;
      background-color: var(--color-brand);
    }
  }
}

/* 滚动内容区 */
.panel-content {
  flex: 1;
  overflow: hidden;
  padding: 20rpx 40rpx;
  box-sizing: border-box;
}

.tab-pane {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

/* 参数行 */
.param-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12rpx;
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.param-label {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

.param-value {
  flex: 1;
  min-width: 0;
  text-align: right;
  font-size: 26rpx;
  color: var(--color-text-primary);
  font-weight: 500;
  word-break: break-all;
}

/* 滑块块 */
.slider-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.slider-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12rpx;
}

.slider-value {
  font-size: 26rpx;
  color: var(--color-text-primary);
  font-weight: 500;
}

/* 选项 pill 行 */
.pill-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8rpx;
  padding: 12rpx 0 20rpx;
  border-bottom: 1rpx solid var(--color-divider);
}

.pill-option {
  padding: 10rpx 20rpx;
  border-radius: 9999rpx;
  background-color: var(--color-surface-alt);
  font-size: 24rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

.pill-option.active {
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: #fff;
  font-weight: 500;
}

/* 描述块 */
.desc-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.desc-title {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  margin-bottom: 12rpx;
}

.desc-text {
  font-size: 26rpx;
  color: var(--color-text-primary);
  line-height: 1.6;
  word-break: break-all;
}

/* 标签列表 */
.tag-list-block {
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}

.prop-tag {
  display: inline-flex;
  align-items: center;
  padding: 8rpx 20rpx;
  border-radius: 9999rpx;
  font-size: 22rpx;
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
}

/* 贴士列表 */
.tips-list {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.tips-item {
  display: flex;
  align-items: flex-start;
  gap: 12rpx;
}

.tips-dot {
  font-size: 24rpx;
  color: var(--color-brand);
  margin-top: 4rpx;
  line-height: 1;
}

.tips-text {
  font-size: 26rpx;
  color: var(--color-text-primary);
  line-height: 1.6;
  flex: 1;
  min-width: 0;
}

/* 剪影预览 */
.silhouette-preview {
  display: flex;
  justify-content: center;
  padding: 20rpx 0;
  margin-bottom: 12rpx;
}

.silhouette-wrap {
  width: 240rpx;
  height: 320rpx;
  background-color: var(--color-canvas-deep);
  border-radius: 20rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.silhouette-img {
  width: 80%;
  height: 80%;
  opacity: 0.7;
}

.silhouette-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
}

.silhouette-icon {
  font-size: 120rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

/* 底部按钮 */
.panel-footer {
  padding: 20rpx 40rpx;
  padding-bottom: calc(20rpx + env(safe-area-inset-bottom, 0));
  flex-shrink: 0;
  border-top: 1rpx solid var(--color-divider);
  box-sizing: border-box;
}

.apply-btn {
  height: 96rpx;
  border-radius: 16rpx;
  background: linear-gradient(135deg, var(--color-brand) 0%, var(--color-brand-deep) 100%);
  color: var(--color-text-inverse);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  font-size: 30rpx;
  font-weight: 500;
  letter-spacing: 0.04em;
  transition: transform 0.15s ease, background 0.3s ease;

  .ph {
    font-size: 32rpx;
  }

  &:active {
    transform: scale(0.97);
  }

  &.is-applied {
    background: linear-gradient(135deg, var(--color-success) 0%, var(--color-success) 100%);
  }
}
</style>
