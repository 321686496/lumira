<template>
  <view class="capture-page" :class="{ 'is-landscape': isLandscape }">
    <!-- 顶部沉浸式深色标题栏 -->
    <view class="capture-nav">
      <view class="status-spacer" :style="{ height: statusBarHeight + 'px' }"></view>
      <view class="nav-main" :style="landscapeZoomStyle">
        <view class="nav-back" @click="back">
          <text class="ph ph-caret-left" />
        </view>
        <view class="nav-center">
          <text class="nav-title">{{ currentTemplate?.meta.name || '拍摄' }}</text>
          <text class="nav-sub" v-if="currentTemplate">{{ categoryLabel }} · {{ currentTemplate.composition.aspectRatio }}</text>
        </view>
        <view class="nav-actions">
          <view
            v-if="currentTemplate"
            class="nav-action"
            :class="{ active: showTemplate }"
            @click="toggleTemplate"
          >
            <text class="ph ph-frame-corners" />
          </view>
          <view
            v-if="currentTemplate && hasSilhouette"
            class="nav-action"
            :class="{ active: showSilhouette }"
            @click="toggleSilhouette"
          >
            <text class="ph ph-person" />
          </view>
          <view class="nav-action" @click="goSceneGuide">
            <text class="ph ph-question" />
          </view>
          <view class="nav-action" :class="{ active: flashOn }" @click="toggleFlash">
            <text class="ph" :class="flashOn ? 'ph-lightning' : 'ph-lightning-slash'" />
          </view>
        </view>
      </view>
    </view>

    <!-- 取景器 -->
    <view class="viewfinder" @click="onViewfinderTap">
      <!-- 真实相机预览 (H5) -->
      <video
        v-if="camera.platform === 'h5'"
        ref="videoRef"
        class="viewfinder-video"
        :style="viewfinderFilterStyle"
        autoplay
        playsinline
        muted
      />
      <!-- 占位图（无相机权限或非 H5 平台） -->
      <image
        v-if="camera.platform !== 'h5' || !camera.isReady.value"
        class="viewfinder-bg"
        src="https://picsum.photos/seed/capture-viewfinder/400/600"
        mode="aspectFill"
        :style="viewfinderFilterStyle"
      />
      <view class="viewfinder-mask" />

      <!-- 权限错误提示 -->
      <view v-if="camera.error.value" class="camera-error">
        <text class="ph ph-warning-circle camera-error-icon"></text>
        <text class="camera-error-text">{{ camera.error.value }}</text>
        <view class="camera-error-btn" @click="retryCamera">
          <text class="ph ph-arrow-clockwise"></text>
          <text>重试</text>
        </view>
      </view>

      <!-- 构图叠图 -->
      <CompositionOverlay
        v-if="currentTemplate && showTemplate"
        :composition="currentTemplate.composition"
        :overlay-opacity-override="panelExpanded ? 0.2 : undefined"
        class="overlay-anim"
      />

      <!-- 姿势剪影叠图 -->
      <view
        v-if="currentTemplate && hasSilhouette && showSilhouette"
        class="silhouette-layer overlay-anim"
        :style="silhouetteLayerStyle"
      >
        <PoseSilhouette :pose="currentTemplate.pose" />
      </view>

      <!-- 顶部参数 pill 栏 -->
      <view class="param-pill-bar" v-if="currentTemplate" :style="landscapeZoomStyle">
        <view class="param-pill" @click.stop="openPanel('camera')">
          <text class="pill-label">EV</text>
          <text class="pill-value">{{ evDisplay }}</text>
        </view>
        <view class="param-pill" @click.stop="openPanel('camera')">
          <text class="pill-label">WB</text>
          <text class="pill-value">{{ wbDisplay }}</text>
        </view>
        <view class="param-pill apply-pill" :class="{ applied }" @click.stop="toggleApply">
          <text class="ph" :class="applied ? 'ph-check' : 'ph-magic-wand'" />
          <text class="pill-text">{{ applied ? '已应用' : '一键应用' }}</text>
        </view>
      </view>

      <!-- 水平仪 (v2) -->
      <view class="level-indicator" v-if="levelEnabled">
        <view class="level-track">
          <view class="level-center"></view>
          <view class="level-bubble" :style="{ transform: `translateX(${levelAngle * 2}px)` }"></view>
        </view>
      </view>
    </view>

    <!-- 底部控制区 -->
    <view class="capture-bottom" :style="landscapeZoomStyle">
      <view class="shutter-row">
        <view class="last-photo" @click="goPreview">
          <image v-if="lastPhoto" class="last-photo-img" :src="lastPhoto" mode="aspectFill" />
          <view v-else class="last-photo-empty">
            <text class="ph ph-image"></text>
          </view>
        </view>
        <view class="shutter-btn" :class="{ capturing: isCapturing }" @click="onShutter">
          <view class="shutter-inner" />
        </view>
        <view class="flip-btn" @click="flipCamera">
          <text class="ph ph-arrows-clockwise" />
        </view>
      </view>

      <scroll-view class="template-strip" :scroll-x="!isLandscape" :scroll-y="isLandscape">
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

    <ParamPanel
      v-if="editableTemplate"
      :template="editableTemplate"
      :visible="panelExpanded"
      :applied="applied"
      @close="panelExpanded = false"
      @apply="toggleApply"
      @update:opacity="onOpacityUpdate"
      @update:template="onTemplateUpdate"
    />
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { onLoad, onUnload } from '@dcloudio/uni-app'
import { useTemplate } from '@/composables/useTemplate'
import { useCamera } from '@/composables/useCamera'
import { buildCssFilter } from '@/utils/filterRecipe'
import type { PhotoTemplate } from '@/types/template'
import CompositionOverlay from '@/components/CompositionOverlay.vue'
import PoseSilhouette from '@/components/PoseSilhouette.vue'
import ParamPanel from '@/components/ParamPanel.vue'

const { loadTemplate, recentTemplates, pushRecent, loadRecent } = useTemplate()
const camera = useCamera()

const statusBarHeight = uni.getSystemInfoSync().statusBarHeight || 20
const currentTemplateId = ref('')
const originalTemplate = computed<PhotoTemplate | null>(() =>
  currentTemplateId.value ? loadTemplate(currentTemplateId.value) : null
)
// 可编辑副本：ParamPanel 直接修改此对象，实时反映到预览
const editableTemplate = ref<PhotoTemplate | null>(null)

const panelExpanded = ref(false)
const applied = ref(false)
const flashOn = ref(false)
const isCapturing = ref(false)
const lastPhoto = ref('')

// 显隐控制
const showTemplate = ref(true)
const showSilhouette = ref(true)

// 横竖屏自适应
const isLandscape = ref(false)
const landscapeScale = ref(1)
let resizeListener: ((res: { size: { windowWidth: number; windowHeight: number } }) => void) | null = null

// 水平仪 (v2)
const levelEnabled = ref(true)
const levelAngle = ref(0)

// 双击检测
let lastTapTime = 0
const DBL_TAP_THRESHOLD = 300

// 视频元素 ref
const videoRef = ref<HTMLVideoElement | null>(null)

// 计算横屏缩放比例
const updateOrientation = (windowWidth: number, windowHeight: number) => {
  isLandscape.value = windowWidth > windowHeight
  if (isLandscape.value) {
    landscapeScale.value = windowHeight / windowWidth
  } else {
    landscapeScale.value = 1
  }
}

const landscapeZoomStyle = computed(() => {
  if (!isLandscape.value) return {}
  return { zoom: landscapeScale.value }
})

// 当前生效的相机 + 后期参数（用于滤镜）
const activeCamera = computed(() => {
  if (applied.value && editableTemplate.value) {
    return editableTemplate.value.camera
  }
  // 未应用时仅显示原始相机参数（不应用滤镜）
  return {} as Record<string, unknown>
})

const activePost = computed(() => {
  if (applied.value && editableTemplate.value) {
    return editableTemplate.value.postProcess
  }
  return {} as Record<string, unknown>
})

// 实时滤镜样式（应用到视频/占位图）
const viewfinderFilterStyle = computed(() => {
  if (!applied.value || !editableTemplate.value) return {}
  const filter = buildCssFilter(
    editableTemplate.value.camera,
    editableTemplate.value.postProcess
  )
  return filter ? { filter, webkitFilter: filter } : {}
})

onMounted(async () => {
  // 启动相机预览
  await camera.startPreview()
  // 绑定视频元素
  if (videoRef.value) {
    camera.bindVideoElement(videoRef.value)
    // 确保视频播放
    videoRef.value.play().catch(() => {})
  }
})

onLoad((options) => {
  if (options?.templateId) {
    currentTemplateId.value = options.templateId
    pushRecent(options.templateId)
  }
  loadRecent()

  // 横竖屏检测
  const sysInfo = uni.getSystemInfoSync()
  updateOrientation(sysInfo.windowWidth, sysInfo.windowHeight)
  resizeListener = (res) => {
    updateOrientation(res.size.windowWidth, res.size.windowHeight)
  }
  uni.onWindowResize(resizeListener)
})

// 监听原始模板变化，创建可编辑副本
watch(originalTemplate, (tpl) => {
  if (tpl) {
    // 深拷贝创建可编辑副本
    editableTemplate.value = JSON.parse(JSON.stringify(tpl))
  } else {
    editableTemplate.value = null
  }
}, { immediate: true })

onUnload(() => {
  // 退出时清空当前模板状态
  currentTemplateId.value = ''
  applied.value = false
  showTemplate.value = true
  showSilhouette.value = true
  // 释放相机资源
  camera.release()
  if (resizeListener) {
    uni.offWindowResize(resizeListener)
    resizeListener = null
  }
})

const currentTemplate = editableTemplate

const hasSilhouette = computed(() => {
  const pose = currentTemplate.value?.pose
  if (!pose) return false
  if (pose.silhouette.type === 'builtin' && pose.silhouette.data === 'none') return false
  return true
})

const silhouetteLayerStyle = computed(() => {
  const pose = currentTemplate.value?.pose
  if (!pose) return {}
  return {
    left: `${pose.position.x * 100}%`,
    top: `${pose.position.y * 100}%`,
    transform: 'translate(-50%, -50%)'
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
  if (editableTemplate.value) {
    editableTemplate.value.composition.opacity = v
  }
}

// ParamPanel 修改参数时触发
const onTemplateUpdate = (tpl: PhotoTemplate) => {
  editableTemplate.value = tpl
}

const switchTemplate = (id: string) => {
  currentTemplateId.value = id
  applied.value = false
  pushRecent(id)
}

const toggleTemplate = () => {
  showTemplate.value = !showTemplate.value
}

const toggleSilhouette = () => {
  showSilhouette.value = !showSilhouette.value
}

const back = () => uni.navigateBack({ fail: () => uni.reLaunch({ url: '/pages/home/index' }) })
const goSceneGuide = () => uni.navigateTo({ url: '/pages/capture/scene-guide' })
const goPreview = () => uni.navigateTo({ url: '/pages/capture/preview' })

const onShutter = async () => {
  if (isCapturing.value) return
  isCapturing.value = true

  // v2: 快门振动反馈
  uni.vibrateShort({ type: 'light', fail: () => {} })

  try {
    // 拍照：截帧 + 应用所有滤镜 + 烘焙为 dataURL
    const cameraParams = applied.value && editableTemplate.value
      ? editableTemplate.value.camera
      : {}
    const postParams = applied.value && editableTemplate.value
      ? editableTemplate.value.postProcess
      : {}

    const result = await camera.capture(cameraParams, postParams)
    lastPhoto.value = result.dataUrl

    // 跳转到预览页（携带 dataURL）
    // dataURL 太长不能放 URL，使用全局变量传递
    ;(uni as unknown as { _lastCaptureData?: string })._lastCaptureData = result.dataUrl
    uni.navigateTo({ url: '/pages/capture/preview' })
  } catch (err) {
    uni.showToast({
      title: '拍照失败: ' + (err as Error).message,
      icon: 'none'
    })
  } finally {
    isCapturing.value = false
  }
}

const flipCamera = async () => {
  await camera.switchCamera()
  uni.showToast({ title: `已切换至${camera.facing.value === 'front' ? '前置' : '后置'}镜头`, icon: 'none' })
}

const toggleFlash = () => {
  flashOn.value = !flashOn.value
  camera.setFlash(flashOn.value ? 'torch' : 'off')
}

const retryCamera = async () => {
  await camera.release()
  await camera.startPreview()
  if (videoRef.value) {
    camera.bindVideoElement(videoRef.value)
    videoRef.value.play().catch(() => {})
  }
}

// 双击取景器切换摄像头 (v2手势)
const onViewfinderTap = () => {
  const now = Date.now()
  if (now - lastTapTime < DBL_TAP_THRESHOLD) {
    flipCamera()
    lastTapTime = 0
  } else {
    lastTapTime = now
  }
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
  position: relative;
  height: 72rpx;
  padding: 0 24rpx;
}

.nav-back {
  position: absolute;
  left: 24rpx;
  top: 50%;
  transform: translateY(-50%);
}

.nav-back .ph {
  width: 56rpx;
  height: 56rpx;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.35);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32rpx;
  color: #fff;
}

.nav-center {
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  max-width: 400rpx;
}

.nav-title {
  font-size: 30rpx;
  font-weight: 600;
  color: #fff;
  text-shadow: 0 1rpx 4rpx rgba(0, 0, 0, 0.3);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

.nav-sub {
  font-size: 20rpx;
  color: rgba(255, 255, 255, 0.7);
  margin-top: 2rpx;
  white-space: nowrap;
}

.nav-actions {
  position: absolute;
  right: 24rpx;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.nav-action {
  width: 56rpx;
  height: 56rpx;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.35);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28rpx;
  color: rgba(255, 255, 255, 0.8);
  flex-shrink: 0;
}

.nav-action.active {
  background: rgba(201, 169, 110, 0.7);
  color: #fff;
}

/* ===== 取景器 ===== */
.viewfinder {
  flex: 1;
  position: relative;
  overflow: hidden;
}

.viewfinder-video,
.viewfinder-bg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.viewfinder-video {
  object-fit: cover;
}

.viewfinder-mask {
  position: absolute;
  inset: 0;
  background: rgba(24, 22, 20, 0.15);
  pointer-events: none;
}

/* ===== 相机错误提示 ===== */
.camera-error {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16rpx;
  padding: 40rpx;
  z-index: 10;
}

.camera-error-icon {
  font-size: 80rpx;
  color: rgba(255, 255, 255, 0.6);
}

.camera-error-text {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.8);
  text-align: center;
}

.camera-error-btn {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 16rpx 32rpx;
  border-radius: 9999rpx;
  background: rgba(201, 169, 110, 0.8);
  color: #fff;
  font-size: 26rpx;
}

/* ===== 叠图动画 ===== */
.overlay-anim {
  animation: overlayFadeIn 200ms ease-out;
}

@keyframes overlayFadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
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
  top: 200rpx;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 12rpx;
  z-index: 5;
  max-width: 90%;
}

.param-pill {
  display: flex;
  align-items: center;
  gap: 6rpx;
  padding: 10rpx 20rpx;
  border-radius: 9999rpx;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  flex-shrink: 0;
  white-space: nowrap;
}

.pill-label {
  font-size: 20rpx;
  color: rgba(255, 255, 255, 0.6);
  white-space: nowrap;
}

.pill-value {
  font-size: 22rpx;
  color: #fff;
  font-family: 'Courier New', monospace;
  white-space: nowrap;
}

.apply-pill {
  background: rgba(201, 169, 110, 0.8);
}

.apply-pill.applied {
  background: rgba(122, 139, 92, 0.8);
}

.pill-text {
  font-size: 22rpx;
  color: #fff;
  white-space: nowrap;
}

/* ===== 水平仪 (v2) ===== */
.level-indicator {
  position: absolute;
  bottom: 40rpx;
  left: 50%;
  transform: translateX(-50%);
  z-index: 4;
}

.level-track {
  width: 160rpx;
  height: 6rpx;
  border-radius: 3rpx;
  background: rgba(255, 255, 255, 0.2);
  position: relative;
}

.level-center {
  position: absolute;
  left: 50%;
  top: -4rpx;
  transform: translateX(-50%);
  width: 4rpx;
  height: 14rpx;
  border-radius: 2rpx;
  background: rgba(201, 169, 110, 0.8);
}

.level-bubble {
  position: absolute;
  top: -6rpx;
  left: 50%;
  transform: translateX(-50%);
  width: 18rpx;
  height: 18rpx;
  border-radius: 50%;
  background: #C9A96E;
  box-shadow: 0 0 8rpx rgba(201, 169, 110, 0.5);
  transition: transform 100ms ease-out;
}

/* ===== 底部控制区 ===== */
.capture-bottom {
  position: relative;
  z-index: 50;
  background: rgba(24, 22, 20, 0.85);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  padding: 24rpx 40rpx;
  padding-bottom: calc(env(safe-area-inset-bottom) + 24rpx);
}

.shutter-row {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 56rpx;
}

.last-photo {
  width: 96rpx;
  height: 96rpx;
  border-radius: 20rpx;
  overflow: hidden;
  border: 3rpx solid rgba(255, 255, 255, 0.15);
  flex-shrink: 0;
}

.last-photo-img {
  width: 100%;
  height: 100%;
}

.last-photo-empty {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.3);
  font-size: 36rpx;
}

.shutter-btn {
  width: 140rpx;
  height: 140rpx;
  border-radius: 50%;
  border: 6rpx solid var(--color-brand);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: transform 100ms ease-out;
}

.shutter-btn.capturing {
  transform: scale(0.92);
}

.shutter-inner {
  width: 108rpx;
  height: 108rpx;
  border-radius: 50%;
  background: #fff;
}

.flip-btn {
  width: 80rpx;
  height: 80rpx;
  border-radius: 50%;
  border: 3rpx solid rgba(255, 255, 255, 0.25);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  flex-shrink: 0;
}

.template-strip {
  margin-top: 24rpx;
  white-space: nowrap;
}

.strip-list {
  display: inline-flex;
  gap: 16rpx;
}

.strip-item {
  width: 96rpx;
  height: 96rpx;
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

/* ===== 横屏自适应 ===== */
.capture-page.is-landscape .viewfinder {
  flex: 1;
}

.capture-page.is-landscape .capture-bottom {
  position: fixed;
  right: 0;
  top: 0;
  bottom: 0;
  z-index: 60;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 24rpx 20rpx;
  padding-top: calc(env(safe-area-inset-top) + 24rpx);
  padding-bottom: calc(env(safe-area-inset-bottom) + 24rpx);
  width: 520rpx;
}

.capture-page.is-landscape .shutter-row {
  flex-direction: column;
  gap: 24rpx;
}

.capture-page.is-landscape .template-strip {
  margin-top: 24rpx;
  height: 300rpx;
  white-space: normal;
}

.capture-page.is-landscape .strip-list {
  flex-direction: column;
  align-items: center;
}

.capture-page.is-landscape .param-pill-bar {
  top: auto;
  bottom: 60rpx;
  left: 40rpx;
  transform: none;
}

.capture-page.is-landscape .level-indicator {
  bottom: 40rpx;
  left: 40rpx;
  transform: none;
}
</style>
