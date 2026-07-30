<template>
  <view class="lumira-container no-tabbar">
    <!-- 顶部导航 -->
    <view class="lumira-nav">
      <view class="lumira-nav-left" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="lumira-nav-title">碎片收集</text>
      <view class="lumira-nav-right"></view>
    </view>

    <view class="page-body">
      <!-- 总进度卡 -->
      <view class="lumira-card summary-card fade-up">
        <view class="summary-deco"></view>
        <text class="summary-title">我的拍摄碎片</text>
        <text class="summary-desc">在不同场景类别下拍摄 {{ fragmentTarget }} 张照片即可集齐该碎片</text>
        <view class="summary-num-row">
          <text class="summary-num">{{ collectedCount }}</text>
          <text class="summary-num-mid">/</text>
          <text class="summary-num-total">{{ totalCount }}</text>
        </view>
        <view class="lumira-progress summary-progress">
          <view class="lumira-progress-fill" :style="{ width: summaryPercent + '%' }"></view>
        </view>
        <text class="summary-tip">{{ summaryTip }}</text>
      </view>

      <!-- 碎片列表 -->
      <view
        class="lumira-card frag-card fade-up"
        :class="'fade-up-d' + (i + 1)"
        v-for="(f, i) in fragments"
        :key="f.category"
      >
        <view class="frag-head">
          <view class="frag-icon-wrap" :class="{ 'frag-icon-done': f.cur >= f.target }">
            <text class="ph frag-icon" :class="f.icon"></text>
          </view>
          <view class="frag-head-body">
            <text class="frag-name">{{ f.name }}</text>
            <text class="frag-desc">{{ f.desc }}</text>
          </view>
          <view class="frag-status" :class="{ 'frag-done': f.cur >= f.target }">
            <text v-if="f.cur >= f.target" class="ph ph-check frag-status-icon"></text>
            <text class="frag-status-text">{{ f.cur >= f.target ? '已集齐' : `${f.cur}/${f.target}` }}</text>
          </view>
        </view>
        <view class="lumira-progress frag-progress">
          <view class="lumira-progress-fill" :style="{ width: f.percent + '%' }"></view>
        </view>
        <view class="frag-steps">
          <view
            class="frag-step"
            :class="{ 'frag-step-done': n < f.cur, 'frag-step-next': n === f.cur }"
            v-for="n in f.target"
            :key="n"
          >
            <text v-if="n < f.cur" class="ph ph-check frag-step-check"></text>
            <text v-else class="frag-step-num">{{ n }}</text>
          </view>
        </view>
      </view>

      <!-- 海报导出区 -->
      <view class="lumira-card export-card fade-up fade-up-d5">
        <view class="lumira-section-title section-title-row">
          <text class="section-title-text">导出海报</text>
        </view>
        <text class="export-desc">将你的碎片收集进度生成精美海报，分享给好友</text>
        <view class="export-btns">
          <view class="lumira-btn-brand export-btn" @click="generatePoster" :class="{ 'btn-loading': generating }">
            <text class="ph" :class="generating ? 'ph-spinner-gap' : 'ph-paint-brush'"></text>
            <text>{{ generating ? '生成中...' : '生成海报' }}</text>
          </view>
          <view class="lumira-btn-outline export-btn" @click="exportPoster" :class="{ 'btn-disabled': !posterReady }">
            <text class="ph ph-download-simple"></text>
            <text>导出海报</text>
          </view>
          <view class="lumira-btn-outline export-btn" @click="sharePoster" :class="{ 'btn-disabled': !posterReady }">
            <text class="ph ph-share-network"></text>
            <text>分享海报</text>
          </view>
        </view>
      </view>

      <view class="bottom-spacer"></view>
    </view>

    <!-- 隐藏的 canvas 用于绘制海报（移出视口，不占位） -->
    <canvas
      canvas-id="posterCanvas"
      id="posterCanvas"
      class="poster-canvas"
      :style="{ width: canvasWidth + 'px', height: canvasHeight + 'px' }"
    ></canvas>

    <!-- 海报预览 -->
    <view v-if="posterUrl && showPreview" class="poster-preview-mask" @click="closePreview">
      <view class="poster-preview-wrap" @click.stop>
        <image class="poster-preview-img" :src="posterUrl" mode="widthFix" />
        <view class="poster-preview-actions">
          <view class="lumira-btn-brand preview-action-btn" @click="saveToAlbum">
            <text class="ph ph-download-simple"></text>
            <text>保存到相册</text>
          </view>
          <view class="lumira-btn-outline preview-action-btn" @click="closePreview">
            <text>关闭</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import { useGrowth } from '@/composables/useGrowth'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type { SceneCategory } from '@/types/template'

const goBack = () => uni.navigateBack()

const { photos } = useSceneManager()
const { growthData, totalPhotos } = useGrowth()

// 重新加载数据（onShow 时同步跨页修改）
onShow(() => {
  // photos 是 computed，自动响应
})

/** 碎片定义：4 个场景分类 */
interface FragmentDef {
  category: SceneCategory
  name: string
  desc: string
  icon: string
}

const FRAGMENT_DEFS: FragmentDef[] = [
  { category: 'light', name: '光线碎片', desc: '在光线氛围类场景中拍摄', icon: 'ph-sun' },
  { category: 'outdoor', name: '室外碎片', desc: '在室外环境类场景中拍摄', icon: 'ph-mountains' },
  { category: 'indoor', name: '室内碎片', desc: '在室内空间类场景中拍摄', icon: 'ph-house' },
  { category: 'mood', name: '情绪碎片', desc: '在情绪氛围类场景中拍摄', icon: 'ph-heart' },
]

/** 每个分类需要拍 5 张才能集齐 */
const fragmentTarget = 5

/** 计算各分类碎片进度 */
const fragments = computed(() => {
  const sceneCategoryMap = new Map<string, SceneCategory>()
  SCENE_PRESETS.forEach(s => {
    sceneCategoryMap.set(s.id, s.category)
  })

  const counts: Record<string, number> = {}
  photos.value.forEach(p => {
    if (p.sceneId) {
      const cat = sceneCategoryMap.get(p.sceneId)
      if (cat) {
        counts[cat] = (counts[cat] || 0) + 1
      }
    }
  })

  return FRAGMENT_DEFS.map(def => {
    const cur = Math.min(counts[def.category] || 0, fragmentTarget)
    return {
      category: def.category,
      name: def.name,
      desc: def.desc,
      icon: def.icon,
      cur,
      target: fragmentTarget,
      percent: Math.round((cur / fragmentTarget) * 100),
    }
  })
})

/** 已集齐的碎片数 */
const collectedCount = computed(() => fragments.value.filter(f => f.cur >= f.target).length)

/** 总碎片数 */
const totalCount = FRAGMENT_DEFS.length

/** 总进度百分比 */
const summaryPercent = computed(() => {
  const totalCur = fragments.value.reduce((sum, f) => sum + f.cur, 0)
  const totalGoal = fragments.value.reduce((sum, f) => sum + f.target, 0)
  return Math.round((totalCur / totalGoal) * 100)
})

/** 进度提示文案 */
const summaryTip = computed(() => {
  if (collectedCount.value === totalCount) return '恭喜！你已集齐所有碎片'
  if (collectedCount.value > 0) return `已集齐 ${collectedCount.value} 个碎片，继续努力`
  return '开始拍摄，收集你的第一块碎片'
})

// ── 海报生成 ──

const canvasWidth = 600
const canvasHeight = 900
const generating = ref(false)
const posterUrl = ref('')
const showPreview = ref(false)

const posterReady = computed(() => !!posterUrl.value)

/** 生成海报：在 canvas 上绘制 */
function generatePoster() {
  if (generating.value) return
  generating.value = true

  const ctx = uni.createCanvasContext('posterCanvas')

  // 背景渐变
  const bgGradient = ctx.createLinearGradient(0, 0, 0, canvasHeight)
  bgGradient.addColorStop(0, '#FFF8EE')
  bgGradient.addColorStop(0.5, '#FDF6EC')
  bgGradient.addColorStop(1, '#F5E6CC')
  ctx.setFillStyle(bgGradient)
  ctx.fillRect(0, 0, canvasWidth, canvasHeight)

  // 顶部装饰圆
  ctx.setFillStyle('rgba(201, 169, 110, 0.08)')
  ctx.beginPath()
  ctx.arc(canvasWidth - 60, 80, 120, 0, 2 * Math.PI)
  ctx.fill()

  // 标题
  ctx.setFillStyle('#3D2817')
  ctx.setFontSize(40)
  ctx.font = 'bold 40px "Noto Serif SC", serif'
  ctx.fillText('我的拍摄碎片', 48, 100)

  // 副标题：等级 + 作品数
  ctx.setFillStyle('#8C7340')
  ctx.setFontSize(20)
  ctx.font = '20px "Courier New", monospace'
  const subtitle = `Lv.${growthData.value.level} ${growthData.value.levelName} · ${totalPhotos.value} 张作品`
  ctx.fillText(subtitle, 48, 130)

  // 分割线
  ctx.setStrokeStyle('rgba(201, 169, 110, 0.2)')
  ctx.setLineWidth(1)
  ctx.beginPath()
  ctx.moveTo(48, 160)
  ctx.lineTo(canvasWidth - 48, 160)
  ctx.stroke()

  // 总进度
  ctx.setFillStyle('#3D2817')
  ctx.setFontSize(22)
  ctx.font = '22px "Noto Serif SC", serif'
  ctx.fillText('总进度', 48, 200)

  ctx.setFillStyle('#C9A96E')
  ctx.setFontSize(28)
  ctx.font = 'bold 28px "Courier New", monospace'
  ctx.fillText(`${collectedCount.value}/${totalCount}`, canvasWidth - 48 - 60, 200)

  // 总进度条背景
  ctx.setFillStyle('rgba(201, 169, 110, 0.15)')
  drawRoundRect(ctx, 48, 220, canvasWidth - 96, 12, 6)
  ctx.fill()
  // 总进度条填充
  const summaryWidth = (canvasWidth - 96) * (summaryPercent.value / 100)
  if (summaryWidth > 0) {
    ctx.setFillStyle('#C9A96E')
    drawRoundRect(ctx, 48, 220, summaryWidth, 12, 6)
    ctx.fill()
  }

  // 4 个碎片卡片
  const cardStartY = 270
  const cardHeight = 110
  const cardGap = 16
  fragments.value.forEach((f, i) => {
    const y = cardStartY + i * (cardHeight + cardGap)

    // 卡片背景
    ctx.setFillStyle('#FFFFFF')
    drawRoundRect(ctx, 48, y, canvasWidth - 96, cardHeight, 16)
    ctx.fill()

    // 图标圆形背景
    const iconX = 80
    const iconY = y + cardHeight / 2
    ctx.setFillStyle(f.cur >= f.target ? 'rgba(90, 122, 72, 0.12)' : 'rgba(201, 169, 110, 0.12)')
    ctx.beginPath()
    ctx.arc(iconX, iconY, 24, 0, 2 * Math.PI)
    ctx.fill()

    // 图标符号（用文字代替）
    ctx.setFillStyle(f.cur >= f.target ? '#5A7A48' : '#C9A96E')
    ctx.setFontSize(24)
    ctx.font = '24px serif'
    const iconSymbol = f.cur >= f.target ? '✓' : '◆'
    ctx.fillText(iconSymbol, iconX - 8, iconY + 8)

    // 碎片名称
    ctx.setFillStyle('#3D2817')
    ctx.setFontSize(22)
    ctx.font = '600 22px "Noto Serif SC", serif'
    ctx.fillText(f.name, 130, y + 40)

    // 碎片描述
    ctx.setFillStyle('#8C7340')
    ctx.setFontSize(16)
    ctx.font = '16px sans-serif'
    ctx.fillText(f.desc, 130, y + 65)

    // 进度文字
    ctx.setFillStyle(f.cur >= f.target ? '#5A7A48' : '#8C7340')
    ctx.setFontSize(18)
    ctx.font = 'bold 18px "Courier New", monospace'
    const progressText = `${f.cur}/${f.target}`
    ctx.fillText(progressText, canvasWidth - 48 - 50, y + 40)

    // 进度条背景
    const barX = 130
    const barY = y + 75
    const barW = canvasWidth - 130 - 48 - 50
    ctx.setFillStyle('rgba(201, 169, 110, 0.15)')
    drawRoundRect(ctx, barX, barY, barW, 8, 4)
    ctx.fill()
    // 进度条填充
    const fillW = barW * (f.percent / 100)
    if (fillW > 0) {
      ctx.setFillStyle(f.cur >= f.target ? '#5A7A48' : '#C9A96E')
      drawRoundRect(ctx, barX, barY, fillW, 8, 4)
      ctx.fill()
    }
  })

  // 底部信息
  const footerY = canvasHeight - 60
  ctx.setFillStyle('rgba(201, 169, 110, 0.4)')
  ctx.setFontSize(14)
  ctx.font = '14px sans-serif'
  const dateStr = new Date().toISOString().slice(0, 10)
  ctx.fillText(`如画 Lumira · ${dateStr}`, 48, footerY)

  ctx.setFillStyle('#C9A96E')
  ctx.setFontSize(16)
  ctx.font = '600 16px "Noto Serif SC", serif'
  ctx.fillText('记录每一束光', canvasWidth - 48 - 100, footerY)

  // 执行绘制
  ctx.draw(false, () => {
    setTimeout(() => {
      uni.canvasToTempFilePath({
        canvasId: 'posterCanvas',
        width: canvasWidth,
        height: canvasHeight,
        destWidth: canvasWidth * 2,
        destHeight: canvasHeight * 2,
        fileType: 'png',
        quality: 1,
        success: (res) => {
          posterUrl.value = res.tempFilePath
          generating.value = false
          showPreview.value = true
          uni.showToast({ title: '海报已生成', icon: 'success' })
        },
        fail: () => {
          generating.value = false
          uni.showToast({ title: '生成失败，请重试', icon: 'none' })
        },
      })
    }, 100)
  })
}

/** 绘制圆角矩形 */
function drawRoundRect(ctx: any, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.lineTo(x + w - r, y)
  ctx.arcTo(x + w, y, x + w, y + r, r)
  ctx.lineTo(x + w, y + h - r)
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
  ctx.lineTo(x + r, y + h)
  ctx.arcTo(x, y + h, x, y + h - r, r)
  ctx.lineTo(x, y + r)
  ctx.arcTo(x, y, x + r, y, r)
  ctx.closePath()
}

/** 导出海报：保存到相册 */
function exportPoster() {
  if (!posterReady.value) {
    uni.showToast({ title: '请先生成海报', icon: 'none' })
    return
  }
  saveToAlbum()
}

/** 保存到相册 */
function saveToAlbum() {
  if (!posterUrl.value) return
  uni.saveImageToPhotosAlbum({
    filePath: posterUrl.value,
    success: () => {
      uni.showToast({ title: '已保存到相册', icon: 'success' })
    },
    fail: (err) => {
      const errMsg = err?.errMsg || ''
      if (errMsg.includes('auth') || errMsg.includes('deny') || errMsg.includes('permission')) {
        uni.showModal({
          title: '权限提示',
          content: '需要相册权限才能保存海报，请前往设置开启',
          confirmText: '去设置',
          success: (res) => {
            if (res.confirm) uni.openSetting({})
          },
        })
      } else {
        uni.showToast({ title: '保存失败', icon: 'none' })
      }
    },
  })
}

/** 分享海报 */
function sharePoster() {
  if (!posterReady.value) {
    uni.showToast({ title: '请先生成海报', icon: 'none' })
    return
  }

  // #ifdef APP-PLUS
  uni.share({
    provider: 'weixin',
    scene: 'WXSceneSession',
    type: 2,
    imageUrl: posterUrl.value,
    success: () => uni.showToast({ title: '分享成功', icon: 'success' }),
    fail: () => uni.showToast({ title: '分享取消', icon: 'none' }),
  })
  // #endif

  // #ifdef H5
  // H5：尝试 Web Share API，否则复制图片链接
  if (navigator.share) {
    fetch(posterUrl.value)
      .then(res => res.blob())
      .then(blob => {
        const file = new File([blob], 'lumira-fragments.png', { type: 'image/png' })
        navigator.share({
          title: '我的拍摄碎片',
          text: '来如画 Lumira，一起记录每一束光',
          files: [file],
        }).catch(() => {})
      })
      .catch(() => {
        copyPosterLink()
      })
  } else {
    copyPosterLink()
  }
  // #endif

  // #ifdef MP
  uni.showToast({ title: '请长按海报图片保存或分享', icon: 'none', duration: 2000 })
  showPreview.value = true
  // #endif
}

/** H5 复制图片链接兜底 */
function copyPosterLink() {
  uni.setClipboardData({
    data: posterUrl.value,
    success: () => uni.showToast({ title: '图片链接已复制', icon: 'success' }),
  })
}

function closePreview() {
  showPreview.value = false
}
</script>

<style lang="scss" scoped>
.nav-back-icon {
  font-size: 40rpx;
  color: $color-text-primary;
}

.page-body {
  padding: 48rpx 40rpx 0;
}

/* 总进度卡 */
.summary-card {
  position: relative;
  overflow: hidden;
  padding: 56rpx 48rpx;
  margin-bottom: 32rpx;
  background: linear-gradient(145deg, #FFF8EE 0%, #F5EDDB 40%, #EDE3D0 100%);
  border: 2rpx solid rgba(201, 169, 110, 0.12);
  text-align: center;
}

.summary-deco {
  position: absolute;
  top: -80rpx;
  right: -80rpx;
  width: 240rpx;
  height: 240rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.06);
  pointer-events: none;
}

.summary-title {
  display: block;
  position: relative;
  font-family: 'Noto Serif SC', serif;
  font-size: 40rpx;
  font-weight: 600;
  color: #3D2817;
  margin-bottom: 12rpx;
  letter-spacing: 0.02em;
}

.summary-desc {
  display: block;
  position: relative;
  font-size: 24rpx;
  color: #8C7340;
  line-height: 1.6;
  margin-bottom: 32rpx;
}

.summary-num-row {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 8rpx;
  position: relative;
  margin-bottom: 24rpx;
}

.summary-num {
  font-family: 'Noto Serif SC', serif;
  font-size: 96rpx;
  font-weight: 600;
  color: #C9A96E;
  line-height: 1;
}

.summary-num-mid {
  font-size: 56rpx;
  color: #C9A96E;
  opacity: 0.5;
}

.summary-num-total {
  font-family: 'Noto Serif SC', serif;
  font-size: 56rpx;
  font-weight: 600;
  color: #8C7340;
}

.summary-progress {
  height: 16rpx;
  position: relative;
}

.summary-tip {
  display: block;
  font-size: 22rpx;
  color: #B89860;
  margin-top: 16rpx;
  letter-spacing: 0.02em;
}

/* 碎片卡片 */
.frag-card {
  padding: 36rpx 32rpx;
  margin-bottom: 24rpx;
}

.frag-head {
  display: flex;
  align-items: center;
  gap: 24rpx;
  margin-bottom: 24rpx;
}

.frag-icon-wrap {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  background-color: rgba(201, 169, 110, 0.12);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.frag-icon-done {
  background-color: rgba(90, 122, 72, 0.12);
}

.frag-icon {
  font-size: 40rpx;
  color: $color-brand;
}

.frag-icon-done .frag-icon {
  color: $color-success;
}

.frag-head-body {
  flex: 1;
  min-width: 0;
}

.frag-name {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
  margin-bottom: 6rpx;
}

.frag-desc {
  display: block;
  font-size: 22rpx;
  color: $color-text-tertiary;
  line-height: 1.5;
}

.frag-status {
  display: flex;
  align-items: center;
  gap: 6rpx;
  padding: 8rpx 20rpx;
  border-radius: 9999rpx;
  background-color: rgba(201, 169, 110, 0.12);
  flex-shrink: 0;
}

.frag-done {
  background-color: rgba(90, 122, 72, 0.12);
}

.frag-status-icon {
  font-size: 22rpx;
  color: $color-success;
}

.frag-status-text {
  font-size: 22rpx;
  font-weight: 600;
  color: $color-brand;
  font-family: 'Courier New', monospace;
}

.frag-done .frag-status-text {
  color: $color-success;
}

.frag-progress {
  height: 12rpx;
  margin-bottom: 20rpx;
}

.frag-steps {
  display: flex;
  gap: 16rpx;
}

.frag-step {
  flex: 1;
  height: 48rpx;
  border-radius: 12rpx;
  background-color: $color-surface-alt;
  display: flex;
  align-items: center;
  justify-content: center;
}

.frag-step-done {
  background-color: $color-brand;
}

.frag-step-next {
  background-color: rgba(201, 169, 110, 0.2);
  border: 2rpx dashed $color-brand;
  box-sizing: border-box;
}

.frag-step-check {
  font-size: 24rpx;
  color: #fff;
}

.frag-step-num {
  font-size: 22rpx;
  font-weight: 600;
  color: $color-text-tertiary;
  font-family: 'Courier New', monospace;
}

/* 导出卡 */
.export-card {
  padding: 36rpx 32rpx;
  margin-bottom: 32rpx;
}

.section-title-row {
  margin-bottom: 16rpx;
}

.section-title-text {
  font-family: 'Noto Serif SC', serif;
  font-size: 32rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.export-desc {
  display: block;
  font-size: 24rpx;
  color: $color-text-tertiary;
  margin-bottom: 28rpx;
  line-height: 1.5;
}

.export-btns {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.export-btn {
  width: 100%;
  justify-content: center;
  padding: 24rpx;
  font-size: 28rpx;
}

.export-btn .ph {
  font-size: 32rpx;
}

.btn-loading {
  opacity: 0.7;
}

.btn-disabled {
  opacity: 0.4;
  pointer-events: none;
}

/* 隐藏 canvas：移出视口但保持可绘制 */
.poster-canvas {
  position: fixed;
  left: -9999rpx;
  top: -9999rpx;
  pointer-events: none;
}

/* 海报预览蒙层 */
.poster-preview-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.85);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48rpx;
}

.poster-preview-wrap {
  width: 100%;
  max-width: 600rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24rpx;
}

.poster-preview-img {
  width: 100%;
  border-radius: 16rpx;
  box-shadow: 0 8rpx 48rpx rgba(0, 0, 0, 0.4);
}

.poster-preview-actions {
  display: flex;
  gap: 16rpx;
  width: 100%;
}

.preview-action-btn {
  flex: 1;
  justify-content: center;
  padding: 20rpx;
  font-size: 26rpx;
}

.preview-action-btn .ph {
  font-size: 28rpx;
}

.bottom-spacer {
  height: 48rpx;
}
</style>
