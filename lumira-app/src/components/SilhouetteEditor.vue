<template>
  <view v-if="visible" class="silhouette-editor-mask" @click="$emit('close')">
    <view class="silhouette-editor-sheet" @click.stop>
      <!-- 顶部工具栏 -->
      <view class="editor-header">
        <text class="ph ph-x close-btn" @click="$emit('close')" />
        <text class="editor-title">绘制剪影</text>
        <text class="ph ph-check save-btn" @click="onComplete" />
      </view>

      <!-- 工具切换栏 -->
      <view class="tool-bar">
        <view class="tool-item" :class="{ active: tool === 'brush' }" @click="tool = 'brush'">
          <text class="ph ph-paint-brush" />
          <text class="tool-label">画笔</text>
        </view>
        <view class="tool-item" :class="{ active: tool === 'eraser' }" @click="tool = 'eraser'">
          <text class="ph ph-eraser" />
          <text class="tool-label">橡皮</text>
        </view>
        <view class="tool-divider" />
        <view class="tool-item" @click="undo">
          <text class="ph ph-arrow-counter-clockwise" />
          <text class="tool-label">撤销</text>
        </view>
        <view class="tool-item" @click="redo">
          <text class="ph ph-arrow-clockwise" />
          <text class="tool-label">重做</text>
        </view>
        <view class="tool-item danger" @click="clear">
          <text class="ph ph-trash" />
          <text class="tool-label">清空</text>
        </view>
      </view>

      <!-- 画笔粗细 -->
      <view class="brush-size-row">
        <text class="size-label">粗细</text>
        <slider
          :value="brushSize"
          :min="2"
          :max="30"
          :step="1"
          activeColor="var(--color-brand)"
          backgroundColor="var(--color-divider)"
          block-color="var(--color-brand)"
          class="size-slider"
          @change="onSliderChange"
        />
        <view class="size-preview" :style="{ width: brushSize + 'px', height: brushSize + 'px' }" />
      </view>

      <!-- 画布区域 -->
      <view class="canvas-wrap">
        <!-- 参考图（半透明，便于临摹） -->
        <image v-if="referenceImage" :src="referenceImage" class="reference-img" mode="aspectFit" />
        <!-- SVG 绘图画布 -->
        <view
          class="draw-canvas"
          ref="canvasRef"
          @touchstart="onTouchStart"
          @touchmove.prevent="onTouchMove"
          @touchend="onTouchEnd"
        >
          <svg viewBox="0 0 300 480" class="draw-svg" xmlns="http://www.w3.org/2000/svg">
            <path
              v-for="(path, i) in paths"
              :key="i"
              :d="path.d"
              :stroke="path.eraser ? 'rgba(0,0,0,0)' : '#000000'"
              :stroke-width="path.width"
              stroke-linecap="round"
              stroke-linejoin="round"
              fill="none"
            />
          </svg>
        </view>
        <!-- 人体比例参考线 -->
        <view class="guide-lines">
          <view class="guide-h" style="top: 12.5%" />
          <text class="guide-label" style="top: 12.5%">头</text>
          <view class="guide-h" style="top: 37.5%" />
          <text class="guide-label" style="top: 37.5%">腰</text>
          <view class="guide-h" style="top: 62.5%" />
          <text class="guide-label" style="top: 62.5%">膝</text>
        </view>
      </view>

      <!-- 底部说明 -->
      <view class="editor-tip">
        <text class="ph ph-info" />
        <text>在画布上绘制人物轮廓，完成后将自动保存为 SVG 矢量剪影</text>
      </view>

      <!-- 参考图上传 -->
      <view class="ref-upload">
        <view class="ref-btn" @click="onUploadReference">
          <text class="ph ph-image" />
          <text>{{ referenceImage ? '更换参考图' : '上传参考图（临摹用）' }}</text>
        </view>
        <view v-if="referenceImage" class="ref-clear" @click="referenceImage = ''">
          <text class="ph ph-x" />
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from 'vue'

interface DrawPath {
  d: string
  color: string
  width: number
  eraser: boolean
}

defineProps<{
  visible: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'complete', svg: string): void
}>()

const tool = ref<'brush' | 'eraser'>('brush')
const brushSize = ref(8)
const paths = ref<DrawPath[]>([])
const redoStack = ref<DrawPath[]>([])
const referenceImage = ref('')
const isDrawing = ref(false)
const canvasRef = ref<any>(null)

// 触摸事件处理
const onTouchStart = (e: TouchEvent) => {
  isDrawing.value = true
  const pt = getPoint(e)
  paths.value.push({
    d: `M ${pt.x} ${pt.y}`,
    color: '#000000',
    width: brushSize.value,
    eraser: tool.value === 'eraser'
  })
  redoStack.value = []
}

const onTouchMove = (e: TouchEvent) => {
  if (!isDrawing.value) return
  const pt = getPoint(e)
  const last = paths.value[paths.value.length - 1]
  if (!last) return
  last.d += ` L ${pt.x} ${pt.y}`
  paths.value = [...paths.value]
}

const onTouchEnd = () => {
  isDrawing.value = false
}

// 坐标转换：触摸坐标 -> SVG viewBox 坐标
// 使用 e.currentTarget 获取原生 DOM 元素，而非 canvasRef（uni-app ref 不指向原生 HTMLElement）
const getPoint = (e: TouchEvent) => {
  const touch = e.touches[0] || e.changedTouches[0]
  const target = (e.currentTarget || canvasRef.value?.$el || canvasRef.value) as HTMLElement | null
  if (!target || !touch) return { x: 0, y: 0 }
  const rect = target.getBoundingClientRect?.()
  if (!rect) return { x: 0, y: 0 }
  const x = ((touch.clientX - rect.left) / rect.width) * 300
  const y = ((touch.clientY - rect.top) / rect.height) * 480
  return { x: Math.round(x), y: Math.round(y) }
}

// 滑块变化
const onSliderChange = (e: { detail: { value: number } }) => {
  brushSize.value = e.detail.value
}

// 撤销/重做/清空
const undo = () => {
  if (paths.value.length === 0) return
  redoStack.value.push(paths.value.pop()!)
  paths.value = [...paths.value]
}

const redo = () => {
  if (redoStack.value.length === 0) return
  paths.value.push(redoStack.value.pop()!)
  paths.value = [...paths.value]
}

const clear = () => {
  paths.value = []
  redoStack.value = []
}

// 完成：导出 SVG 字符串（仅保留非橡皮路径，使用白色描边便于叠在照片上）
const onComplete = () => {
  const visiblePaths = paths.value.filter(p => !p.eraser)
  const svgContent = `<svg viewBox="0 0 300 480" xmlns="http://www.w3.org/2000/svg">${visiblePaths
    .map(
      p =>
        `<path d="${p.d}" stroke="#fff" stroke-width="${p.width}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`
    )
    .join('')}</svg>`
  emit('complete', svgContent)
}

// 参考图上传
const onUploadReference = () => {
  uni.chooseImage({
    count: 1,
    success: (res) => {
      const path = res.tempFilePaths[0]
      // #ifdef H5
      const xhr = new XMLHttpRequest()
      xhr.onload = () => {
        const reader = new FileReader()
        reader.onload = () => {
          referenceImage.value = reader.result as string
        }
        reader.readAsDataURL(xhr.response)
      }
      xhr.open('GET', path)
      xhr.responseType = 'blob'
      xhr.send()
      // #endif
      // #ifndef H5
      referenceImage.value = path
      // #endif
    }
  })
}
</script>

<style lang="scss" scoped>
.silhouette-editor-mask {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 1000;
  display: flex;
  align-items: flex-end;
  animation: fadeIn 0.25s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.silhouette-editor-sheet {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: var(--color-surface);
  border-radius: 32rpx 32rpx 0 0;
  box-shadow: 0 -8rpx 32rpx rgba(0, 0, 0, 0.12);
  padding: 24rpx 32rpx;
  padding-bottom: calc(24rpx + env(safe-area-inset-bottom, 0));
  display: flex;
  flex-direction: column;
  animation: slideUp 0.35s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}

/* 顶部工具栏 */
.editor-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8rpx 0 20rpx;
  flex-shrink: 0;
}

.editor-title {
  font-family: var(--font-cn-title);
  font-size: 34rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  letter-spacing: 0.04em;
}

.close-btn,
.save-btn {
  font-size: 40rpx;
  color: var(--color-text-secondary);
  width: 72rpx;
  height: 72rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  transition: color 0.2s ease, background-color 0.2s ease;
}

.close-btn:active {
  color: var(--color-danger);
  background-color: var(--color-danger-subtle);
}

.save-btn {
  color: var(--color-brand);
}

.save-btn:active {
  background-color: var(--color-brand-subtle);
}

/* 工具切换栏 */
.tool-bar {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 16rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
  flex-shrink: 0;
}

.tool-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6rpx;
  padding: 12rpx 0;
  color: var(--color-text-secondary);
  border-radius: 16rpx;
  transition: color 0.2s ease, background-color 0.2s ease;

  .ph {
    font-size: 36rpx;
    line-height: 1;
  }

  .tool-label {
    font-size: 20rpx;
    letter-spacing: 0.04em;
  }

  &:active {
    background-color: var(--color-canvas-deep);
  }

  &.active {
    color: var(--color-brand);
    background-color: var(--color-brand-subtle);
  }

  &.danger {
    color: var(--color-danger);

    &:active {
      background-color: var(--color-danger-subtle);
    }
  }
}

.tool-divider {
  width: 1rpx;
  height: 56rpx;
  background-color: var(--color-divider);
  flex-shrink: 0;
}

/* 画笔粗细 */
.brush-size-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
  padding: 20rpx 0;
  border-bottom: 1rpx solid var(--color-divider);
  flex-shrink: 0;
}

.size-label {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

.size-slider {
  flex: 1;
  margin: 0;
}

.size-preview {
  background-color: var(--color-text-primary);
  border-radius: 50%;
  flex-shrink: 0;
  min-width: 8rpx;
  min-height: 8rpx;
  transition: width 0.15s ease, height 0.15s ease;
}

/* 画布区域 */
.canvas-wrap {
  position: relative;
  height: 50vh;
  background-color: #ffffff;
  border-radius: 20rpx;
  overflow: hidden;
  margin: 20rpx 0;
  border: 1rpx solid var(--color-divider);
  flex-shrink: 0;
}

.reference-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0.3;
  pointer-events: none;
  z-index: 1;
}

.draw-canvas {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  z-index: 2;
  touch-action: none;
}

.draw-svg {
  width: 100%;
  height: 100%;
  display: block;
}

/* 人体比例参考线 */
.guide-lines {
  position: absolute;
  inset: 0;
  pointer-events: none;
  z-index: 3;
}

.guide-h {
  position: absolute;
  left: 0;
  right: 0;
  height: 1rpx;
  background: rgba(200, 200, 200, 0.5);
  border-top: 1px dashed #ccc;
  transform: translateY(-50%);
}

.guide-label {
  position: absolute;
  right: 8rpx;
  font-size: 20rpx;
  color: #999;
  transform: translateY(-50%);
  background: rgba(255, 255, 255, 0.8);
  padding: 0 8rpx;
  border-radius: 4rpx;
  line-height: 1.6;
}

/* 底部说明 */
.editor-tip {
  display: flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 0;
  font-size: 22rpx;
  color: var(--color-text-tertiary);
  line-height: 1.5;
  flex-shrink: 0;

  .ph {
    font-size: 26rpx;
    flex-shrink: 0;
  }
}

/* 参考图上传 */
.ref-upload {
  display: flex;
  align-items: center;
  gap: 16rpx;
  padding: 12rpx 0 0;
  flex-shrink: 0;
}

.ref-btn {
  flex: 1;
  height: 80rpx;
  border-radius: 16rpx;
  background-color: var(--color-canvas-deep);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  transition: background-color 0.2s ease;

  .ph {
    font-size: 30rpx;
  }

  &:active {
    background-color: var(--color-divider);
  }
}

.ref-clear {
  width: 80rpx;
  height: 80rpx;
  border-radius: 16rpx;
  background-color: var(--color-danger-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-danger);
  flex-shrink: 0;

  .ph {
    font-size: 30rpx;
  }

  &:active {
    opacity: 0.7;
  }
}
</style>
