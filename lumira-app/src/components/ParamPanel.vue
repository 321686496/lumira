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
          <view class="param-row">
            <view class="param-label">曝光补偿</view>
            <view class="param-value">
              {{ template.camera.exposureCompensation > 0 ? '+' : '' }}{{ template.camera.exposureCompensation }} EV
            </view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">ISO</view>
            <view class="param-value">
              {{ template.camera.isoMode === 'auto' ? '自动' : '手动' }} · {{ template.camera.iso }}
            </view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">快门速度</view>
            <view class="param-value">{{ template.camera.shutterSpeed }}</view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">白平衡</view>
            <view class="param-value">
              {{ wbLabel(template.camera.whiteBalance, template.camera.whiteBalanceK) }}
            </view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">闪光</view>
            <view class="param-value">{{ flashLabel(template.camera.flashMode) }}</view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">对焦</view>
            <view class="param-value">{{ focusLabel(template.camera.focusMode) }}</view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row">
            <view class="param-label">镜头建议</view>
            <view class="param-value">{{ lensLabel(template.camera.lensSuggestion) }}</view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
          </view>
          <view class="param-row" v-if="template.camera.filterPreset">
            <view class="param-label">滤镜预设</view>
            <view class="param-value">{{ template.camera.filterPreset }}</view>
            <view class="param-tag" :class="applied ? 'tag-applied' : 'tag-suggest'">
              {{ applied ? '已应用' : '建议' }}
            </view>
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
              @change="onOpacityChange"
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
              <view
                v-else
                class="silhouette-placeholder"
              >
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
          <view class="param-row">
            <view class="param-label">缩放</view>
            <view class="param-value">{{ template.pose.scale.toFixed(2) }}</view>
          </view>
          <view class="param-row">
            <view class="param-label">旋转</view>
            <view class="param-value">{{ template.pose.rotation }}°</view>
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
          <view class="param-row">
            <view class="param-label">LUT 预设</view>
            <view class="param-value">{{ lutLabel(template.postProcess.lut) }}</view>
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
            />
          </view>
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
              disabled
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
import { ref } from 'vue'
import type { PhotoTemplate } from '@/types/template'

defineProps<{
  template: PhotoTemplate
  visible: boolean
  applied: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'apply'): void
  (e: 'update:opacity', value: number): void
}>()

const tabs = [
  { key: 'camera', label: '相机', icon: 'ph-camera' },
  { key: 'composition', label: '构图', icon: 'ph-frame-corners' },
  { key: 'scene', label: '场景', icon: 'ph-sun' },
  { key: 'pose', label: '姿势', icon: 'ph-person' },
  { key: 'post', label: '后期', icon: 'ph-magic-wand' }
]

const activeTab = ref(0)

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

const onOpacityChange = (e: any) => {
  emit('update:opacity', e.detail.value / 100)
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
  text-align: right;
  font-size: 26rpx;
  color: var(--color-text-primary);
  font-weight: 500;
  margin-left: 20rpx;
  word-break: break-all;
}

.param-tag {
  font-size: 20rpx;
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
  margin-left: 16rpx;
  flex-shrink: 0;
}

.tag-suggest {
  background-color: var(--color-brand-subtle);
  color: var(--color-brand-text);
}

.tag-applied {
  background-color: var(--color-success-subtle);
  color: var(--color-success);
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
