<template>
  <view class="scene-guide-page">
    <!-- 导航栏 -->
    <view class="guide-nav">
      <view class="nav-back" @click="goBack">
        <text class="ph ph-arrow-left nav-back-icon"></text>
      </view>
      <text class="nav-title">场景灵感</text>
      <view class="nav-manage" @click="goSceneManage">
        <text class="ph ph-gear-six nav-manage-icon"></text>
      </view>
    </view>

    <scroll-view scroll-y class="guide-scroll">
      <!-- 分类导航 -->
      <view class="guide-section">
        <CategoryNav :layers="categoryLayers" @select="onLayerSelect" />
      </view>

      <!-- 标签筛选 -->
      <view class="guide-tags">
        <TagSelector
          :selected-tag-ids="selectedTagIds"
          type="scene"
          @update:selected-tag-ids="selectedTagIds = $event"
        />
      </view>

      <!-- 场景卡片列表 -->
      <view class="guide-list">
        <view
          v-for="scene in filteredScenes"
          :key="scene.id"
          class="guide-card"
          @click="goSceneDetail(scene.id)"
        >
          <image
            v-if="scene.exampleImages[0]"
            class="guide-card-img"
            :src="scene.exampleImages[0]"
            mode="aspectFill"
          />
          <view v-else class="guide-card-img guide-card-img-placeholder">
            <text class="ph ph-image guide-card-img-placeholder-icon"></text>
          </view>
          <view class="guide-card-info">
            <text class="guide-card-name">{{ scene.name }}</text>
            <text class="guide-card-vibe">{{ scene.vibe }}</text>
            <view class="guide-card-stats">
              <text class="stat-item"><text class="ph ph-images-square"></text> {{ getPhotoCountByScene(scene.id) }}</text>
              <text v-if="getSceneAchievement(scene.id).level > 0" class="stat-item">
                <text class="ph ph-trophy"></text> Lv.{{ getSceneAchievement(scene.id).level }}
              </text>
            </view>
          </view>
        </view>
      </view>

      <view v-if="filteredScenes.length === 0" class="guide-empty">
        <text class="guide-empty-text">暂无匹配场景</text>
      </view>

      <view class="guide-bottom-space"></view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import { useSceneManager } from '@/composables/useSceneManager'
import { SCENE_CATEGORIES } from '@/data/scenePresets'
import CategoryNav from '@/components/CategoryNav.vue'
import TagSelector from '@/components/TagSelector.vue'
import type { SceneCategory, AnyScene } from '@/types/template'

const { allScenes, reloadFromStorage, getPhotoCountByScene, getSceneAchievement } = useSceneManager()

onLoad(() => {})
onShow(() => { reloadFromStorage() })

// 分类导航：第一层大类，第二层风格
const selectedCategory = ref<SceneCategory | null>(null)
const selectedStyle = ref<string | null>(null)
const selectedTagIds = ref<string[]>([])

const categoryLayers = computed(() => {
  const layers = []
  // 第一层：大类
  layers.push({
    label: '大类',
    selected: selectedCategory.value,
    options: SCENE_CATEGORIES.map(c => ({ value: c.category, label: c.name })),
  })
  // 第二层：风格（仅当大类选中时显示）
  if (selectedCategory.value) {
    const group = SCENE_CATEGORIES.find(c => c.category === selectedCategory.value)
    if (group) {
      layers.push({
        label: '风格',
        selected: selectedStyle.value,
        options: group.styles.map(s => ({ value: s.id, label: s.name })),
      })
    }
  }
  return layers
})

function onLayerSelect(idx: number, value: string | null) {
  if (idx === 0) {
    selectedCategory.value = value as SceneCategory | null
    selectedStyle.value = null  // 重置子分类
  } else if (idx === 1) {
    selectedStyle.value = value
  }
}

// 筛选后的场景列表
// 注意：偏离 brief —— brief 中调用 filterScenesByTags(selectedTagIds.value) 会从 allScenes 重新过滤，
// 导致已应用的 category/style 筛选被覆盖。此处改为在已筛选的 list 上直接做标签匹配，
// 保留 category + style + tag 的组合筛选结果。
const filteredScenes = computed<AnyScene[]>(() => {
  let list: AnyScene[] = allScenes.value
  if (selectedCategory.value) {
    list = list.filter(s => s.category === selectedCategory.value)
  }
  if (selectedStyle.value) {
    list = list.filter(s => s.style === selectedStyle.value)
  }
  if (selectedTagIds.value.length > 0) {
    list = list.filter(s => {
      const ids = 'tagIds' in s ? s.tagIds : s.recommendedTagIds
      return selectedTagIds.value.some(id => ids.includes(id))
    })
  }
  return list
})

function goBack() {
  uni.navigateBack()
}

function goSceneDetail(id: string) {
  uni.navigateTo({ url: `/pages/capture/scene-detail?sceneId=${id}` })
}

function goSceneManage() {
  uni.navigateTo({ url: '/pages/capture/scene-manage' })
}
</script>

<style lang="scss" scoped>
.scene-guide-page {
  min-height: 100vh;
  background: #FAF7F2;
  display: flex;
  flex-direction: column;
}

/* ===== 导航栏 ===== */
.guide-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24rpx;
  height: 88rpx;
  padding-top: env(safe-area-inset-top);
}

.nav-back {
  width: 64rpx;
  height: 64rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.nav-back-icon {
  font-size: 36rpx;
  color: #2A2520;
}

.nav-title {
  font-size: 32rpx;
  font-weight: 600;
  color: #2A2520;
}

.nav-manage {
  width: 64rpx;
  height: 64rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.nav-manage-icon {
  font-size: 36rpx;
  color: #2A2520;
}

/* ===== 滚动区 ===== */
.guide-scroll {
  flex: 1;
}

/* ===== 分类导航区 ===== */
.guide-section {
  padding: 24rpx 0 8rpx;
}

/* ===== 标签筛选区 ===== */
.guide-tags {
  padding: 16rpx 0 24rpx;
}

/* ===== 场景卡片列表 ===== */
.guide-list {
  padding: 0 24rpx;
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.guide-card {
  display: flex;
  flex-direction: row;
  align-items: stretch;
  background: rgba(0, 0, 0, 0.04);
  border-radius: 24rpx;
  overflow: hidden;
}

.guide-card-img {
  width: 200rpx;
  height: 200rpx;
  flex-shrink: 0;
}

.guide-card-img-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(201, 168, 118, 0.12);
}

.guide-card-img-placeholder-icon {
  font-size: 56rpx;
  color: #C9A876;
}

.guide-card-info {
  flex: 1;
  min-width: 0;
  padding: 24rpx;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 8rpx;
}

.guide-card-name {
  font-size: 30rpx;
  font-weight: 600;
  color: #2A2520;
  line-height: 1.3;
}

.guide-card-vibe {
  font-size: 24rpx;
  color: #6B635A;
  font-style: italic;
  line-height: 1.4;
}

.guide-card-stats {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 20rpx;
  margin-top: 4rpx;
}

.stat-item {
  font-size: 22rpx;
  color: #6B635A;
  line-height: 1.2;
}

/* ===== 空状态 ===== */
.guide-empty {
  padding: 80rpx 24rpx;
  display: flex;
  align-items: center;
  justify-content: center;
}

.guide-empty-text {
  font-size: 26rpx;
  color: #6B635A;
}

.guide-bottom-space {
  height: 48rpx;
}
</style>
