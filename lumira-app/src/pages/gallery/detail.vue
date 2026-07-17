<template>
  <view class="lumira-container no-tabbar dark-container">
    <!-- Dark Top Bar -->
    <view class="lumira-nav dark-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-caret-left nav-icon-light"></text>
      </view>
      <text class="nav-title-light">照片详情</text>
      <view class="lumira-nav-right">
        <text class="nav-action-gold">对比</text>
        <text class="ph ph-dots-three nav-icon-dim"></text>
      </view>
    </view>

    <!-- Main Image Canvas Area -->
    <view v-if="photo" class="canvas-area">
      <image class="canvas-img" :src="photo.dataUrl" mode="aspectFit" />
    </view>
    <view v-else class="canvas-area empty-canvas">
      <text class="ph ph-image empty-canvas-icon"></text>
      <text class="empty-canvas-text">照片不存在或已被删除</text>
    </view>

    <!-- 场景信息行（仅当 photo 存在时显示） -->
    <view v-if="photo" class="info-row" @click="onChangeScene">
      <view class="info-label-wrap">
        <text class="ph ph-map-pin info-label-icon"></text>
        <text class="info-label">场景</text>
      </view>
      <view class="info-value-row">
        <text class="info-value">{{ currentSceneName || '未分类' }}</text>
        <text class="ph ph-caret-right change-arrow"></text>
      </view>
    </view>

    <!-- Tool Tab Row (Horizontal Scroll Pills) -->
    <scroll-view scroll-x class="tool-row" :show-scrollbar="false">
      <view class="tool-inner">
        <view
          v-for="(t, i) in tools"
          :key="i"
          class="tool-pill"
          :class="{ active: activeTool === i }"
          @click="activeTool = i"
        >
          <text class="tool-pill-text">{{ t }}</text>
        </view>
      </view>
    </scroll-view>

    <!-- Parameter Sliders -->
    <view class="slider-block">
      <view v-for="(s, i) in sliders" :key="i" class="slider-row">
        <text class="slider-label">{{ s.label }}</text>
        <slider
          class="slider"
          :value="s.value"
          :min="0"
          :max="100"
          :block-size="18"
          activeColor="#C9A96E"
          backgroundColor="rgba(255,255,255,0.15)"
          @changing="(e: any) => (s.value = e.detail.value)"
        />
        <text class="slider-value">{{ s.display }}</text>
      </view>
    </view>

    <!-- LUT Filter Thumbnails Row -->
    <view class="lut-block">
      <scroll-view scroll-x class="lut-row" :show-scrollbar="false">
        <view class="lut-inner">
          <view
            v-for="(l, i) in luts"
            :key="i"
            class="lut-cell"
            :class="{ active: activeLut === i }"
            @click="activeLut = i"
          >
            <image class="lut-img" :src="l.img" mode="aspectFill" />
            <view v-if="l.name" class="lut-name-wrap">
              <text class="lut-name">{{ l.name }}</text>
            </view>
          </view>
        </view>
      </scroll-view>
    </view>

    <!-- EXIF Card Quick Button -->
    <view class="exif-btn-wrap">
      <view class="exif-btn">
        <text class="ph ph-clipboard-text exif-btn-icon"></text>
        <text class="exif-btn-text">生成 EXIF 卡片</text>
      </view>
    </view>

    <!-- Bottom Action Bar -->
    <view class="action-bar">
      <view class="action-btn-outline" @click="reset">
        <text class="action-btn-outline-text">重置</text>
      </view>
      <view class="action-btn-primary" @click="exportPhoto">
        <text class="action-btn-primary-text">导出</text>
      </view>
    </view>

    <!-- 场景选择 sheet -->
    <view v-if="sceneSelectorVisible" class="scene-selector-mask" @click="sceneSelectorVisible = false">
      <view class="scene-selector-sheet" @click.stop>
        <text class="selector-title">归类到场景</text>
        <scroll-view scroll-y class="selector-list">
          <view
            class="selector-item"
            :class="{ active: !photo?.sceneId }"
            @click="onSelectScene(null)"
          >
            <text class="ph selector-icon ph-folder-dashed"></text>
            <text>不归类（未分类）</text>
          </view>
          <view
            v-for="s in allScenes"
            :key="s.id"
            class="selector-item"
            :class="{ active: photo?.sceneId === s.id }"
            @click="onSelectScene(s.id)"
          >
            <text class="ph selector-icon" :class="s.icon"></text>
            <text>{{ s.name }}</text>
          </view>
        </scroll-view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import type { ScenePresetId, CustomSceneId } from '@/types/template'

const { photos, updatePhotoScene, allScenes, reloadFromStorage } = useSceneManager()

const photoId = ref('')
const photo = computed(() => photos.value.find(p => p.id === photoId.value))

const currentSceneName = computed(() => {
  const sid = photo.value?.sceneId
  if (!sid) return ''
  const scene = allScenes.value.find(s => s.id === sid)
  return scene?.name || ''
})

const sceneSelectorVisible = ref(false)

const activeTool = ref(0)
const tools = ['调色', 'LUT', '裁剪', '磨皮', '锐化']

const activeLut = ref(0)
const luts = ref([
  { img: 'https://picsum.photos/seed/733872/400/400', name: '暖调' },
  { img: 'https://picsum.photos/seed/1239291/400/400', name: '冷调' },
  { img: 'https://picsum.photos/seed/1926769/400/400', name: '' },
  { img: 'https://picsum.photos/seed/774909/400/400', name: '' },
  { img: 'https://picsum.photos/seed/1038002/400/400', name: '' },
  { img: 'https://picsum.photos/seed/51383/400/400', name: '' }
])

const sliders = ref([
  { label: '亮度', value: 62, display: '+12' },
  { label: '对比度', value: 44, display: '-4' },
  { label: '饱和度', value: 50, display: '0' },
  { label: '色温', value: 58, display: '+8' }
])

onLoad((options) => {
  const id = options?.id
  if (typeof id === 'string' && id) photoId.value = id
})

onShow(() => {
  reloadFromStorage()
})

function onChangeScene() {
  sceneSelectorVisible.value = true
}

function onSelectScene(sceneId: ScenePresetId | CustomSceneId | null) {
  if (photo.value) {
    updatePhotoScene(photo.value.id, sceneId)
    sceneSelectorVisible.value = false
    uni.showToast({ title: '已更新', icon: 'success' })
  }
}

const back = () => uni.navigateBack()
const reset = () => {
  sliders.value.forEach((s) => (s.value = 50))
}
const exportPhoto = () => {
  uni.showToast({ title: '已导出', icon: 'success' })
}
</script>

<style lang="scss" scoped>
.dark-container {
  background-color: #1C1A17;
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

/* 顶部导航 */
.dark-nav {
  background-color: rgba(28, 26, 23, 0.92);
  border-bottom: 2rpx solid rgba(255, 255, 255, 0.06);
}

.nav-icon-light {
  font-size: 40rpx;
  color: #fff;
}

.nav-title-light {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: #fff;
  flex: 1;
  text-align: left;
  padding-left: 16rpx;
  letter-spacing: -0.01em;
}

.nav-action-gold {
  font-size: 26rpx;
  font-weight: 500;
  color: #C9A96E;
}

.nav-icon-dim {
  font-size: 40rpx;
  color: rgba(255, 255, 255, 0.6);
}

/* 画布区 */
.canvas-area {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32rpx;
  min-height: 0;
}

.canvas-img {
  max-width: 100%;
  max-height: 100%;
  border-radius: 24rpx;
}

/* 工具 Pills */
.tool-row {
  padding: 0 48rpx 24rpx;
  white-space: nowrap;
}

.tool-inner {
  display: flex;
  gap: 20rpx;
}

.tool-pill {
  flex-shrink: 0;
  padding: 14rpx 32rpx;
  border-radius: 9999rpx;
  border: 3rpx solid rgba(255, 255, 255, 0.2);
  background: transparent;
}

.tool-pill.active {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  border-color: transparent;
}

.tool-pill-text {
  font-size: 26rpx;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.7);
}

.tool-pill.active .tool-pill-text {
  color: #1C1A17;
}

/* 滑块 */
.slider-block {
  padding: 0 48rpx 24rpx;
}

.slider-row {
  display: flex;
  align-items: center;
  gap: 24rpx;
  padding: 12rpx 0;
}

.slider-label {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.6);
  min-width: 100rpx;
}

.slider {
  flex: 1;
}

.slider-value {
  font-size: 24rpx;
  color: #C9A96E;
  min-width: 76rpx;
  text-align: right;
  font-family: 'Courier New', monospace;
}

/* LUT 滤镜缩略图 */
.lut-block {
  padding: 0 48rpx 32rpx;
}

.lut-row {
  white-space: nowrap;
}

.lut-inner {
  display: flex;
  gap: 20rpx;
}

.lut-cell {
  position: relative;
  flex-shrink: 0;
  width: 104rpx;
  height: 104rpx;
  border-radius: 16rpx;
  overflow: hidden;
  border: 3rpx solid rgba(255, 255, 255, 0.2);
}

.lut-cell.active {
  border: 4rpx solid #C9A96E;
}

.lut-img {
  width: 100%;
  height: 100%;
}

.lut-name-wrap {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: rgba(0, 0, 0, 0.6);
  text-align: center;
  padding: 2rpx 0;
}

.lut-name {
  font-size: 16rpx;
  color: #fff;
}

/* EXIF 按钮 */
.exif-btn-wrap {
  padding: 0 48rpx 24rpx;
  text-align: center;
}

.exif-btn {
  display: inline-flex;
  align-items: center;
  gap: 12rpx;
  background-color: rgba(255, 255, 255, 0.06);
  border: 2rpx solid rgba(255, 255, 255, 0.12);
  border-radius: 16rpx;
  padding: 20rpx 32rpx;
}

.exif-btn-icon {
  font-size: 32rpx;
  color: rgba(255, 255, 255, 0.7);
}

.exif-btn-text {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.7);
}

/* 底部操作栏 */
.action-bar {
  padding: 32rpx 48rpx calc(env(safe-area-inset-bottom) + 32rpx);
  display: flex;
  gap: 24rpx;
}

.action-btn-outline {
  flex: 1;
  padding: 28rpx 32rpx;
  border-radius: 16rpx;
  border: 3rpx solid rgba(255, 255, 255, 0.2);
  background: transparent;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn-outline-text {
  font-size: 30rpx;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.7);
}

.action-btn-primary {
  flex: 1;
  padding: 28rpx 32rpx;
  border-radius: 16rpx;
  background-color: #1A1A1A;
  border: 2rpx solid rgba(255, 255, 255, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn-primary-text {
  font-size: 30rpx;
  font-weight: 500;
  color: #FAF7F2;
}

/* 场景信息行（深色主题） */
.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 24rpx 48rpx;
  background: rgba(255, 255, 255, 0.04);
  border-bottom: 2rpx solid rgba(255, 255, 255, 0.08);
}

.info-label-wrap {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.info-label-icon {
  font-size: 28rpx;
  color: rgba(255, 255, 255, 0.6);
}

.info-label {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.6);
}

.info-value-row {
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.info-value {
  font-size: 26rpx;
  color: #ffffff;
}

.change-arrow {
  font-size: 24rpx;
  color: rgba(255, 255, 255, 0.4);
}

/* 空照片状态 */
.empty-canvas {
  flex-direction: column;
  gap: 16rpx;
}

.empty-canvas-icon {
  font-size: 96rpx;
  color: rgba(255, 255, 255, 0.3);
}

.empty-canvas-text {
  font-size: 28rpx;
  color: rgba(255, 255, 255, 0.4);
}

/* 场景选择 sheet（modal，浅色） */
.scene-selector-mask {
  position: fixed;
  inset: 0;
  z-index: 999;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: flex-end;
}

.scene-selector-sheet {
  width: 100%;
  max-height: 70vh;
  background: #ffffff;
  border-radius: 32rpx 32rpx 0 0;
  padding: 32rpx;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
}

.selector-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
  display: block;
  margin-bottom: 24rpx;
}

.selector-list {
  max-height: 50vh;
}

.selector-item {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 24rpx;
  border-radius: 12rpx;
  font-size: 28rpx;
  color: $color-text-primary;
}

.selector-item.active {
  background: $color-brand-light;
  color: $color-tag-gold-text;
}

.selector-icon {
  font-size: 32rpx;
}
</style>
