<template>
  <view class="capture-page">
    <!-- 顶部沉浸式深色标题栏 -->
    <view class="capture-nav">
      <view class="status-spacer" :style="{ height: statusBarHeight + 'px' }"></view>
      <view class="nav-main">
        <view class="nav-back" @click="back">
          <text class="ph ph-caret-left" />
        </view>
        <view class="nav-center">
          <text class="nav-title">{{ template?.meta.name || '模板预览' }}</text>
          <text class="nav-sub" v-if="template">{{ categoryLabel }} · {{ template.composition.aspectRatio }}</text>
        </view>
        <view class="nav-actions">
          <view class="nav-action" :class="{ active: flashOn }" @click="toggleFlash">
            <text class="ph" :class="flashOn ? 'ph-lightning' : 'ph-lightning-slash'" />
          </view>
        </view>
      </view>
    </view>

    <!-- 取景器 -->
    <view class="viewfinder" ref="viewfinderRef">
      <view class="viewfinder-frame" :style="viewfinderFrameStyle">
        <image class="viewfinder-bg" :src="template?.meta?.cover" mode="aspectFill" :style="viewfinderFilterStyle" />
        <view class="viewfinder-mask" />
        <CompositionOverlay v-if="template" :composition="template.composition" />
        <!-- 可拖动的剪影叠图 -->
        <view
          v-if="template && hasSilhouette"
          class="silhouette-drag-layer"
          ref="silhouetteDragLayerRef"
          @touchstart="onSilhouetteDragStart"
          @touchmove="onSilhouetteDragMove"
          @touchend="onSilhouetteDragEnd"
          @touchcancel="onSilhouetteDragEnd"
        >
          <view class="silhouette-drag-handle" :style="silhouetteDragStyle">
            <PoseSilhouette :pose="template.pose" />
          </view>
          <view class="drag-hint" v-if="!isDraggingSilhouette">
            <text class="ph ph-hand-grabbing"></text>
            <text>拖动调整剪影位置</text>
          </view>
        </view>
      </view>

      <!-- 参数 pill 栏 -->
      <view class="param-pill-bar" v-if="template">
        <view class="param-pill">
          <text class="pill-label">EV</text>
          <text class="pill-value">{{ evDisplay }}</text>
        </view>
        <view class="param-pill">
          <text class="pill-label">ISO</text>
          <text class="pill-value">{{ template.camera.iso }}</text>
        </view>
        <view class="param-pill">
          <text class="pill-label">SS</text>
          <text class="pill-value">{{ template.camera.shutterSpeed }}</text>
        </view>
        <view class="param-pill">
          <text class="pill-label">WB</text>
          <text class="pill-value">{{ wbDisplay }}</text>
        </view>
      </view>
    </view>

    <!-- 参数调整面板 -->
    <view class="adjust-panel" :class="{ expanded: panelExpanded }" v-if="template">
      <view class="panel-header" @click="panelExpanded = !panelExpanded">
        <text class="ph" :class="panelExpanded ? 'ph-caret-down' : 'ph-caret-up'" />
        <text class="panel-title">参数调整</text>
        <text class="panel-hint">实时调整模板参数</text>
      </view>

      <scroll-view v-if="panelExpanded" scroll-y class="panel-scroll">
        <!-- 构图区 -->
        <view class="adjust-section">
          <text class="section-title">构图</text>
          <view class="adjust-row">
            <text class="row-label">叠图透明度</text>
            <slider :value="template.composition.opacity * 100" :min="0" :max="100" :step="5"
                    activeColor="#C9A96E" @change="onOpacityChange" />
          </view>
        </view>

        <!-- 相机参数区 -->
        <view class="adjust-section">
          <text class="section-title">相机参数</text>
          <view class="adjust-row">
            <text class="row-label">曝光补偿</text>
            <slider :value="template.camera.exposureCompensation" :min="-3" :max="3" :step="0.3"
                    activeColor="#C9A96E" @change="onEvChange" />
            <text class="row-value">{{ formatEv(template.camera.exposureCompensation) }} EV</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">ISO</text>
            <slider :value="template.camera.iso" :min="50" :max="6400" :step="50"
                    activeColor="#C9A96E" @change="onIsoChange" />
            <text class="row-value">{{ template.camera.iso }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">色温 K</text>
            <slider :value="template.camera.whiteBalanceK" :min="2500" :max="10000" :step="100"
                    activeColor="#C9A96E" @change="onWbKChange" />
            <text class="row-value">{{ template.camera.whiteBalanceK }}K</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">白平衡</text>
            <view class="seg-btns">
              <view v-for="wb in wbOptions" :key="wb.value"
                    class="seg-btn" :class="{ active: template.camera.whiteBalance === wb.value }"
                    @click="template!.camera.whiteBalance = wb.value">
                <text>{{ wb.label }}</text>
              </view>
            </view>
          </view>
          <view class="adjust-row">
            <text class="row-label">闪光</text>
            <view class="seg-btns">
              <view v-for="fm in flashOptions" :key="fm.value"
                    class="seg-btn" :class="{ active: template.camera.flashMode === fm.value }"
                    @click="template!.camera.flashMode = fm.value">
                <text>{{ fm.label }}</text>
              </view>
            </view>
          </view>
          <view class="adjust-row">
            <text class="row-label">对焦</text>
            <view class="seg-btns">
              <view v-for="fm in focusOptions" :key="fm.value"
                    class="seg-btn" :class="{ active: template.camera.focusMode === fm.value }"
                    @click="template!.camera.focusMode = fm.value">
                <text>{{ fm.label }}</text>
              </view>
            </view>
          </view>
        </view>

        <!-- 后期参数区 -->
        <view class="adjust-section">
          <text class="section-title">后期调色</text>
          <view class="adjust-row">
            <text class="row-label">LUT 预设</text>
            <view class="seg-btns">
              <view v-for="lut in lutOptions" :key="lut.value"
                    class="seg-btn" :class="{ active: template.postProcess.lut === lut.value }"
                    @click="template!.postProcess.lut = lut.value">
                <text>{{ lut.label }}</text>
              </view>
            </view>
          </view>
          <view class="adjust-row">
            <text class="row-label">亮度</text>
            <slider :value="template.postProcess.color.brightness" :min="-100" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onColorChange('brightness', $event)" />
            <text class="row-value">{{ formatSigned(template.postProcess.color.brightness) }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">对比度</text>
            <slider :value="template.postProcess.color.contrast" :min="-100" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onColorChange('contrast', $event)" />
            <text class="row-value">{{ formatSigned(template.postProcess.color.contrast) }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">饱和度</text>
            <slider :value="template.postProcess.color.saturation" :min="-100" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onColorChange('saturation', $event)" />
            <text class="row-value">{{ formatSigned(template.postProcess.color.saturation) }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">色温</text>
            <slider :value="template.postProcess.color.temperature" :min="-100" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onColorChange('temperature', $event)" />
            <text class="row-value">{{ formatSigned(template.postProcess.color.temperature) }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">磨皮</text>
            <slider :value="template.postProcess.smoothStrength" :min="0" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onPostChange('smoothStrength', $event)" />
            <text class="row-value">{{ template.postProcess.smoothStrength }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">锐化</text>
            <slider :value="template.postProcess.sharpen" :min="0" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onPostChange('sharpen', $event)" />
            <text class="row-value">{{ template.postProcess.sharpen }}</text>
          </view>
          <view class="adjust-row">
            <text class="row-label">暗角</text>
            <slider :value="template.postProcess.vignette" :min="0" :max="100" :step="1"
                    activeColor="#C9A96E" @change="onPostChange('vignette', $event)" />
            <text class="row-value">{{ template.postProcess.vignette }}</text>
          </view>
        </view>
      </scroll-view>
    </view>

    <!-- 底部操作栏 -->
    <view class="preview-footer">
      <view class="sync-btn" @click="onSyncBack">
        <text class="ph ph-arrow-counter-clockwise"></text>
        <text>同步调整到编辑器</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, nextTick, onMounted, onUnmounted } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import { buildCssFilter } from '@/utils/filterRecipe'
import CompositionOverlay from '@/components/CompositionOverlay.vue'
import PoseSilhouette from '@/components/PoseSilhouette.vue'
import type { PhotoTemplate, WhiteBalance, FlashMode, FocusMode, LutPreset } from '@/types/template'

const { loadDraft, loadTemplate, saveAdjustment } = useTemplate()
const template = ref<PhotoTemplate | null>(null)

const statusBarHeight = uni.getSystemInfoSync().statusBarHeight || 20
const panelExpanded = ref(false)
const flashOn = ref(false)

// ===== 剪影拖动状态 =====
const viewfinderRef = ref<any>(null)
const silhouetteDragLayerRef = ref<any>(null)
const isDraggingSilhouette = ref(false)
// 拖动起始记录
let dragStartClientX = 0
let dragStartClientY = 0
let dragStartPosX = 0.5
let dragStartPosY = 0.5
let viewfinderRect: DOMRect | null = null

// 使用 left/top 百分比（相对父容器）+ translate(-50%, -50%) 居中
// 与 detail.vue 的 poseLayerStyle 保持一致，确保位置在所有页面一致
const silhouetteDragStyle = computed(() => {
  const pose = template.value?.pose
  if (!pose) return {}
  return {
    left: `${pose.position.x * 100}%`,
    top: `${pose.position.y * 100}%`,
    transform: 'translate(-50%, -50%)'
  }
})

// 取景器画面比例（与模板的 composition.aspectRatio 一致）
const viewfinderFrameStyle = computed(() => {
  const ratio = template.value?.composition.aspectRatio || '3:4'
  const parts = ratio.split(':')
  const w = Number(parts[0]) || 3
  const h = Number(parts[1]) || 4
  // 竖向比例 (h > w): 高度撑满，宽度按比例；横向比例 (w > h): 宽度撑满，高度按比例
  if (h >= w) {
    return { height: '100%', aspectRatio: `${w} / ${h}` }
  }
  return { width: '100%', aspectRatio: `${w} / ${h}` }
})

// 实时滤镜预览样式（应用到取景器背景图）
const viewfinderFilterStyle = computed(() => {
  if (!template.value) return {}
  const filter = buildCssFilter(template.value.camera, template.value.postProcess)
  return filter ? { filter, webkitFilter: filter } : {}
})

function getDragXY(e: any): { x: number; y: number } {
  if (e.touches && e.touches.length > 0) {
    return { x: e.touches[0].clientX, y: e.touches[0].clientY }
  }
  if (e.changedTouches && e.changedTouches.length > 0) {
    return { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }
  }
  return { x: e.clientX ?? 0, y: e.clientY ?? 0 }
}

function onSilhouetteDragStart(e: any) {
  if (!template.value) return
  isDraggingSilhouette.value = true
  const { x, y } = getDragXY(e)
  dragStartClientX = x
  dragStartClientY = y
  dragStartPosX = template.value.pose.position.x
  dragStartPosY = template.value.pose.position.y
  // 通过 Vue ref 获取元素 rect（跨平台，避免 document.querySelector 在 App-Plus 失败）
  const layerRef = silhouetteDragLayerRef.value
  const el = layerRef?.$el || layerRef
  viewfinderRect = el?.getBoundingClientRect?.() || null
  if (e?.preventDefault) e.preventDefault()
}

function onSilhouetteDragMove(e: any) {
  if (!isDraggingSilhouette.value || !viewfinderRect) return
  if (e.preventDefault) e.preventDefault()
  const { x, y } = getDragXY(e)
  const dx = (x - dragStartClientX) / viewfinderRect.width
  const dy = (y - dragStartClientY) / viewfinderRect.height
  // 与位置滑块范围一致 (0~1)，允许剪影拖到画面边缘（超出部分由 overflow:hidden 裁剪）
  const newX = Math.max(0, Math.min(1, dragStartPosX + dx))
  const newY = Math.max(0, Math.min(1, dragStartPosY + dy))
  if (template.value) {
    template.value.pose.position = { x: newX, y: newY }
  }
}

function onSilhouetteDragEnd() {
  if (!isDraggingSilhouette.value) return
  isDraggingSilhouette.value = false
  viewfinderRect = null
}

// @touchstart/@touchmove/@touchend 已绑定到 <view> 元素，跨平台可靠
// 仅 H5 桌面端需要 mouse 事件（mouse 需通过原生 addEventListener 绑定）
onMounted(() => {
  nextTick(() => {
    const layerRef = silhouetteDragLayerRef.value
    const el = layerRef?.$el || layerRef
    if (el?.addEventListener) {
      el.addEventListener('mousedown', onSilhouetteDragStart as any)
    } else {
      const layerEl = document.querySelector('.silhouette-drag-layer')
      if (layerEl) layerEl.addEventListener('mousedown', onSilhouetteDragStart as any)
    }
  })
  // mouse 事件需 document 级（拖动时鼠标可能离开元素）
  document.addEventListener('mousemove', onSilhouetteDragMove)
  document.addEventListener('mouseup', onSilhouetteDragEnd)
})
onUnmounted(() => {
  const layerRef = silhouetteDragLayerRef.value
  const el = layerRef?.$el || layerRef
  if (el?.removeEventListener) {
    el.removeEventListener('mousedown', onSilhouetteDragStart as any)
  } else {
    const layerEl = document.querySelector('.silhouette-drag-layer')
    if (layerEl) layerEl.removeEventListener('mousedown', onSilhouetteDragStart as any)
  }
  document.removeEventListener('mousemove', onSilhouetteDragMove)
  document.removeEventListener('mouseup', onSilhouetteDragEnd)
})

onLoad((options) => {
  if (options?.draftId) {
    const draft = loadDraft(options.draftId)
    if (draft) template.value = draft
  } else if (options?.templateId) {
    const tpl = loadTemplate(options.templateId)
    if (tpl) template.value = JSON.parse(JSON.stringify(tpl)) as PhotoTemplate
  }
  if (!template.value) {
    uni.showToast({ title: '模板加载失败', icon: 'none' })
    setTimeout(() => uni.navigateBack(), 1000)
  }
})

// ===== 计算属性 =====
const hasSilhouette = computed(() => {
  const pose = template.value?.pose
  if (!pose) return false
  if (pose.silhouette.type === 'builtin' && pose.silhouette.data === 'none') return false
  return true
})

const evDisplay = computed(() => {
  const ev = template.value?.camera.exposureCompensation
  if (ev === undefined) return ''
  return ev > 0 ? `+${ev}` : `${ev}`
})

const wbDisplay = computed(() => {
  const k = template.value?.camera.whiteBalanceK
  return k ? `${k}K` : ''
})

const categoryLabel = computed(() => {
  const cat = template.value?.meta.category
  const map: Record<string, string> = {
    portrait: '人像', landscape: '风光', food: '美食',
    street: '街拍', night: '夜景', macro: '微距', 'still-life': '静物'
  }
  return cat ? (map[cat] || cat) : ''
})

// ===== 选项数据 =====
const wbOptions: { label: string; value: WhiteBalance }[] = [
  { label: '日光', value: 'daylight' },
  { label: '阴天', value: 'cloudy' },
  { label: '阴影', value: 'shade' },
  { label: '白炽灯', value: 'tungsten' },
  { label: '自定义', value: 'custom' }
]

const flashOptions: { label: string; value: FlashMode }[] = [
  { label: '关', value: 'off' },
  { label: '开', value: 'on' },
  { label: '自动', value: 'auto' },
  { label: '常亮', value: 'torch' }
]

const focusOptions: { label: string; value: FocusMode }[] = [
  { label: '自动', value: 'auto' },
  { label: '手动', value: 'manual' },
  { label: '连续', value: 'continuous' }
]

const lutOptions: { label: string; value: LutPreset }[] = [
  { label: '原图', value: 'none' },
  { label: '电影感', value: 'cinematic' },
  { label: '复古', value: 'vintage' },
  { label: '黑白', value: 'bw' },
  { label: '暖色', value: 'warm_film' },
  { label: '冷色', value: 'cool_film' },
  { label: '柔色', value: 'pastel' },
  { label: '富士', value: 'fuji' }
]

// ===== 格式化 =====
function formatEv(v: number): string {
  return v > 0 ? `+${v.toFixed(1)}` : v.toFixed(1)
}

function formatSigned(v: number): string {
  return v > 0 ? `+${v}` : String(v)
}

// ===== Slider 事件处理器 =====
function onEvChange(e: { detail: { value: number } }) {
  template.value!.camera.exposureCompensation = Number(e.detail.value.toFixed(1))
}

function onIsoChange(e: { detail: { value: number } }) {
  template.value!.camera.iso = e.detail.value
}

function onWbKChange(e: { detail: { value: number } }) {
  template.value!.camera.whiteBalanceK = e.detail.value
}

function onOpacityChange(e: { detail: { value: number } }) {
  template.value!.composition.opacity = e.detail.value / 100
}

function onColorChange(key: 'brightness' | 'contrast' | 'saturation' | 'temperature' | 'tint', e: { detail: { value: number } }) {
  template.value!.postProcess.color[key] = e.detail.value
}

function onPostChange(key: 'smoothStrength' | 'sharpen' | 'vignette' | 'grain', e: { detail: { value: number } }) {
  template.value!.postProcess[key] = e.detail.value
}

// ===== 同步到编辑器 =====
function onSyncBack() {
  if (!template.value) return
  saveAdjustment(template.value)
  uni.showToast({ title: '已同步到编辑器', icon: 'success' })
  setTimeout(() => uni.navigateBack(), 800)
}

// ===== 导航 =====
function back() {
  uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/home/index' }) })
}

function toggleFlash() {
  flashOn.value = !flashOn.value
}
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
  display: flex;
  align-items: center;
  justify-content: center;
}

.viewfinder-frame {
  position: relative;
  max-width: 100%;
  max-height: 100%;
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

/* ===== 剪影拖动层 ===== */
.silhouette-drag-layer {
  position: absolute;
  inset: 0;
  z-index: 4;
  touch-action: none;
  cursor: grab;
}

.silhouette-drag-layer:active {
  cursor: grabbing;
}

.silhouette-drag-handle {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 40%;
  aspect-ratio: 1 / 1.6;
  pointer-events: none;
  transition: transform 0.05s ease-out;
}

.drag-hint {
  position: absolute;
  bottom: 24rpx;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 24rpx;
  border-radius: 9999rpx;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.8);
  white-space: nowrap;
  pointer-events: none;

  .ph {
    font-size: 26rpx;
  }
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

/* ===== 参数调整面板 ===== */
.adjust-panel {
  position: relative;
  z-index: 50;
  background: rgba(24, 22, 20, 0.9);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-top: 1rpx solid rgba(255, 255, 255, 0.08);
  flex-shrink: 0;
  overflow-x: hidden;
  box-sizing: border-box;
}

.panel-header {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 24rpx 32rpx;
  box-sizing: border-box;
}

.panel-header .ph {
  font-size: 28rpx;
  color: rgba(255, 255, 255, 0.6);
}

.panel-title {
  font-size: 28rpx;
  font-weight: 600;
  color: #fff;
}

.panel-hint {
  font-size: 22rpx;
  color: rgba(255, 255, 255, 0.4);
  margin-left: auto;
}

.panel-scroll {
  max-height: 600rpx;
  padding: 0 32rpx 24rpx;
  box-sizing: border-box;
}

/* ===== 调整区 ===== */
.adjust-section {
  padding: 16rpx 0;
  border-bottom: 1rpx solid rgba(255, 255, 255, 0.06);
}

.adjust-section:last-child {
  border-bottom: none;
}

.section-title {
  display: block;
  font-size: 24rpx;
  color: rgba(201, 169, 110, 0.9);
  margin-bottom: 8rpx;
  letter-spacing: 0.04em;
}

.adjust-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 16rpx 0;
  flex-wrap: wrap;
}

.row-label {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.7);
  flex-shrink: 0;
  width: 140rpx;
}

.adjust-row slider {
  flex: 1;
  min-width: 0;
}

.row-value {
  font-size: 24rpx;
  color: #fff;
  font-family: 'Courier New', monospace;
  flex-shrink: 0;
  min-width: 80rpx;
  text-align: right;
}

/* ===== 选项按钮组 ===== */
.seg-btns {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  flex: 1;
}

.seg-btn {
  padding: 10rpx 24rpx;
  border-radius: 9999rpx;
  background: rgba(255, 255, 255, 0.08);
  border: 1rpx solid rgba(255, 255, 255, 0.12);
  display: flex;
  align-items: center;
  justify-content: center;
}

.seg-btn.active {
  background: rgba(201, 169, 110, 0.9);
  border-color: #C9A96E;
}

.seg-btn text {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.7);
}

.seg-btn.active text {
  color: #fff;
}

/* ===== 底部操作栏 ===== */
.preview-footer {
  position: relative;
  z-index: 50;
  background: rgba(24, 22, 20, 0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  padding: 24rpx 32rpx;
  padding-bottom: calc(env(safe-area-inset-bottom, 0) + 24rpx);
  flex-shrink: 0;
  box-sizing: border-box;
}

.sync-btn {
  height: 96rpx;
  border-radius: 16rpx;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  font-size: 30rpx;
  font-weight: 500;
  letter-spacing: 0.04em;
  color: #fff;
  transition: transform 0.15s ease;
}

.sync-btn .ph {
  font-size: 32rpx;
}

.sync-btn:active {
  transform: scale(0.97);
}
</style>
