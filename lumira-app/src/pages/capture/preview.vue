<template>
  <view class="preview-container">
    <!-- 深色导航栏 -->
    <view class="preview-nav">
      <view class="lumira-nav-left" @click="back">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">照片预览</text>
      <view class="lumira-nav-right">
        <text class="nav-compare" @click="onCompare">对比 ›</text>
      </view>
    </view>

    <!-- 拍摄照片 -->
    <view class="photo-frame fade-in">
      <image v-if="photoUrl" class="photo-img" :src="photoUrl" mode="aspectFill" />
      <view v-else class="photo-empty">
        <text class="ph ph-image photo-empty-icon"></text>
        <text class="photo-empty-text">无照片数据</text>
      </view>
    </view>

    <!-- 底部白色 Sheet -->
    <view class="bottom-sheet">
      <!-- 拖拽手柄 -->
      <view class="sheet-handle"></view>

      <!-- 心情标签 -->
      <view class="sheet-section">
        <view class="section-title-row">
          <text class="section-title">今天的心情是？</text>
          <text class="section-link" @click="onSkip">跳过</text>
        </view>
        <scroll-view class="pill-scroll" scroll-x>
          <view class="pill-list">
            <view
              class="pill"
              :class="{ active: m.active }"
              v-for="m in moods"
              :key="m.name"
              @click="selectMood(m)"
            >
              <text class="ph pill-icon" :class="m.icon"></text>
              <text class="pill-text">{{ m.name }}</text>
            </view>
          </view>
        </scroll-view>
      </view>

      <!-- 场景标签 -->
      <view class="sheet-section sheet-section-scene">
        <view class="section-title-row">
          <text class="section-title">拍摄场景</text>
        </view>
        <scroll-view class="pill-scroll" scroll-x>
          <view class="pill-list">
            <view
              class="pill"
              :class="{ active: selectedSceneId === s.id }"
              v-for="s in sceneOptions"
              :key="s.id"
              @click="selectedSceneId = s.id"
            >
              <text class="ph pill-icon" :class="s.icon"></text>
              <text class="pill-text">{{ s.name }}</text>
            </view>
            <view
              class="pill"
              :class="{ active: selectedSceneId === null }"
              @click="selectedSceneId = null"
            >
              <text class="pill-text">不标记</text>
            </view>
          </view>
        </scroll-view>
      </view>

      <!-- 操作按钮行 -->
      <view class="action-row">
        <view class="action-btn" @click="onCompareCard">
          <text class="ph ph-chart-bar action-icon"></text>
          <text class="action-text">生成对比图</text>
        </view>
        <view class="action-btn" @click="onExifCard">
          <text class="ph ph-clipboard-text action-icon"></text>
          <text class="action-text">生成EXIF卡片</text>
        </view>
      </view>

      <!-- 主操作按钮 -->
      <view class="lumira-btn-primary save-btn" @click="onSave">
        <text class="ph ph-floppy-disk save-icon"></text>
        <text class="save-text">保存到相册</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import type { ScenePresetId, CustomSceneId } from '@/types/template'

const photoUrl = ref('')

onLoad(() => {
  // 从全局变量读取拍摄的照片数据
  const data = (uni as unknown as { _lastCaptureData?: string })._lastCaptureData
  if (data) {
    photoUrl.value = data
    // 读取后清除，避免残留
    delete (uni as unknown as { _lastCaptureData?: string })._lastCaptureData
  }
})

const moods = ref([
  { name: '开心', icon: 'ph-smiley', active: true },
  { name: '甜酷', icon: 'ph-sunglasses', active: false },
  { name: '温柔', icon: 'ph-flower', active: false },
  { name: '复古', icon: 'ph-film-strip', active: false },
  { name: '清新', icon: 'ph-leaf', active: false },
  { name: '文艺', icon: 'ph-palette', active: false },
  { name: '治愈', icon: 'ph-plant', active: false }
])

// 场景选择器：使用真实数据（预设场景 + 用户自定义场景）
const { allScenes, addPhoto } = useSceneManager()
const selectedSceneId = ref<string | null>(null)
const sceneOptions = computed(() => allScenes.value.map(s => ({
  id: s.id,
  name: s.name,
  icon: s.icon,
})))

const selectMood = (m: { name: string; active: boolean }) => {
  moods.value.forEach((item) => (item.active = item.name === m.name))
}

const back = () => uni.navigateBack()

const onCompare = () => {
  uni.showToast({ title: '查看对比', icon: 'none' })
}

const onSkip = () => {
  uni.showToast({ title: '已跳过', icon: 'none' })
}

const onCompareCard = () => {
  uni.showToast({ title: '生成对比图中', icon: 'none' })
}

const onExifCard = () => {
  uni.showToast({ title: '生成EXIF卡片', icon: 'none' })
}

const onSave = () => {
  if (!photoUrl.value) {
    uni.showToast({ title: '无照片数据', icon: 'none' })
    return
  }

  // 写入 LocalPhoto（应用内部记录，与保存到相册相互独立）
  const selectedMoodName = moods.value.find(m => m.active)?.name
  addPhoto({
    dataUrl: photoUrl.value,
    sceneId: selectedSceneId.value as ScenePresetId | CustomSceneId | null,
    mood: selectedMoodName || undefined,
  })

  // H5 端：通过创建 <a> 标签下载图片
  // #ifdef H5
  try {
    const link = document.createElement('a')
    link.download = `lumira_${Date.now()}.jpg`
    link.href = photoUrl.value
    link.click()
    uni.showToast({ title: '已保存', icon: 'success' })
  } catch (err) {
    uni.showToast({ title: '保存失败', icon: 'none' })
  }
  // #endif
  // #ifdef APP-PLUS || MP
  // App-Plus / 小程序：保存到系统相册
  // 注意：camera 模块返回的是临时文件路径（tempImagePath），可直接保存
  uni.saveImageToPhotosAlbum({
    filePath: photoUrl.value,
    success: () => {
      uni.showToast({ title: '已保存到相册', icon: 'success' })
    },
    fail: (err) => {
      const errMsg = err?.errMsg || ''
      // 权限被拒绝（用户拒绝授权保存到相册）
      if (errMsg.includes('auth') || errMsg.includes('deny') || errMsg.includes('permission')) {
        uni.showModal({
          title: '权限提示',
          content: '保存到相册需要相册访问权限，请在系统设置中允许',
          confirmText: '去设置',
          success: (modalRes) => {
            if (modalRes.confirm) {
              // 跳转到应用权限设置页
              if (uni.openAppAuthorizeSetting) {
                uni.openAppAuthorizeSetting()
              }
            }
          }
        })
      } else {
        uni.showToast({ title: '保存失败', icon: 'none' })
      }
    }
  })
  // #endif
  setTimeout(() => uni.navigateTo({ url: '/pages/gallery/index' }), 800)
}
</script>

<style lang="scss" scoped>
.preview-container {
  min-height: 100vh;
  background-color: #1C1A17;
  display: flex;
  flex-direction: column;
}

/* ===== 深色导航栏 ===== */
.preview-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 28rpx 40rpx;
  padding-top: calc(env(safe-area-inset-top) + 28rpx);
  background-color: rgba(28, 26, 23, 0.9);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.nav-back-icon {
  font-size: 40rpx;
  color: #ffffff;
}

.nav-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 34rpx;
  font-weight: 600;
  color: #ffffff;
  text-align: left;
  flex: 1;
  padding-left: 16rpx;
}

.nav-compare {
  color: #C9A96E;
  font-size: 28rpx;
  font-weight: 500;
}

/* ===== 拍摄照片 ===== */
.photo-frame {
  margin: 16rpx;
  border-radius: 28rpx;
  overflow: hidden;
  position: relative;
  padding-bottom: 133.33%;
}

.photo-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.photo-empty {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  background: rgba(255, 255, 255, 0.04);
}

.photo-empty-icon {
  font-size: 80rpx;
  color: rgba(255, 255, 255, 0.3);
}

.photo-empty-text {
  font-size: 26rpx;
  color: rgba(255, 255, 255, 0.4);
}

/* ===== 底部白色 Sheet ===== */
.bottom-sheet {
  background-color: #FFFFFF;
  border-radius: 40rpx 40rpx 0 0;
  padding: 48rpx 48rpx 0;
  padding-bottom: calc(env(safe-area-inset-bottom) + 32rpx);
  flex-shrink: 0;
}

.sheet-handle {
  width: 72rpx;
  height: 8rpx;
  border-radius: 4rpx;
  background-color: #E5E0D8;
  margin: 0 auto 32rpx;
}

/* ===== 区块标题 ===== */
.sheet-section {
  margin-bottom: 40rpx;
}

.sheet-section-scene {
  margin-bottom: 48rpx;
}

.section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24rpx;
}

.section-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 30rpx;
  font-weight: 600;
  color: $color-text-primary;
}

.section-link {
  font-size: 26rpx;
  color: $color-text-tertiary;
}

/* ===== 标签滚动行 ===== */
.pill-scroll {
  width: 100%;
  white-space: nowrap;
}

.pill-list {
  display: inline-flex;
  gap: 16rpx;
  padding-bottom: 8rpx;
}

.pill {
  flex-shrink: 0;
  padding: 14rpx 32rpx;
  border-radius: 9999rpx;
  font-size: 26rpx;
  font-weight: 500;
  border: 3rpx solid $color-border;
  background-color: $color-bg-card;
  color: $color-text-secondary;
  display: inline-flex;
  align-items: center;
  gap: 12rpx;
  white-space: nowrap;
}

.pill.active {
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  color: #ffffff;
  border-color: transparent;
}

.pill-icon {
  font-size: 28rpx;
}

.pill-text {
  font-size: 26rpx;
}

/* ===== 操作按钮行 ===== */
.action-row {
  display: flex;
  gap: 20rpx;
  margin-bottom: 32rpx;
}

.action-btn {
  flex: 1;
  background: transparent;
  color: $color-text-primary;
  border-radius: 16rpx;
  padding: 24rpx 16rpx;
  font-size: 26rpx;
  font-weight: 500;
  border: 3rpx solid $color-border;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
}

.action-btn:active {
  transform: scale(0.97);
}

.action-icon {
  font-size: 32rpx;
  color: $color-text-secondary;
}

.action-text {
  font-size: 26rpx;
  color: $color-text-primary;
}

/* ===== 保存按钮 ===== */
.save-btn {
  background-color: #1A1A1A;
  color: #FAF7F2;
  border-radius: 16rpx;
  padding: 28rpx 48rpx;
  font-size: 30rpx;
  font-weight: 500;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16rpx;
  width: 100%;
}

.save-btn:active {
  transform: scale(0.97);
}

.save-icon {
  font-size: 32rpx;
  color: #FAF7F2;
}

.save-text {
  font-size: 30rpx;
  color: #FAF7F2;
}
</style>
