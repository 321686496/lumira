<template>
  <view class="lumira-container">
    <!-- NAVBAR (Tab页，无返回按钮) -->
    <view class="lumira-nav">
      <view class="lumira-nav-left"></view>
      <text class="lumira-nav-title">模板库</text>
      <view class="lumira-nav-right">
        <text class="ph ph-magnifying-glass nav-icon"></text>
      </view>
    </view>

    <!-- HERO -->
    <view class="hero-wrap fade-up">
      <view class="hero-card">
        <view class="hero-deco"></view>
        <view class="hero-deco-2"></view>
        <view class="hero-body">
          <text class="hero-title">模板库</text>
          <text class="hero-desc">{{ allTemplatesCount }} 个模板等你探索</text>
          <view class="hero-pill">
            <text class="ph ph-lock-simple-open hero-pill-icon"></text>
            <text class="hero-pill-text">已解锁 {{ unlockedCount }} 个</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 三层分类导航 + 标签筛选 -->
    <view class="template-filter fade-up fade-up-d1">
      <CategoryNav :layers="categoryLayers" @select="onLayerSelect" />
      <view class="template-tags">
        <TagSelector
          :selected-tag-ids="selectedTagIds"
          type="template"
          @update:selected-tag-ids="selectedTagIds = $event"
        />
      </view>
      <!-- "我的"自定义模板切换 -->
      <view class="custom-toggle-row">
        <view
          class="custom-toggle-pill"
          :class="{ 'custom-toggle-pill-active': showCustom }"
          @click="showCustom = !showCustom"
        >
          <text class="custom-toggle-text">我的</text>
        </view>
      </view>
    </view>

    <!-- "我的"分类操作入口按钮行 -->
    <view v-if="showCustom" class="action-row fade-up fade-up-d2">
      <view class="action-btn lumira-btn-ghost" @click="handleImport">
        <text class="ph ph-download-simple action-btn-icon"></text>
        <text class="action-btn-text">导入模板</text>
      </view>
      <view class="action-btn lumira-btn-ghost" @click="goEditor">
        <text class="ph ph-plus action-btn-icon"></text>
        <text class="action-btn-text">新建模板</text>
      </view>
    </view>

    <!-- 模板网格 -->
    <view v-if="filteredTemplates.length" class="tpl-grid section-pad fade-up fade-up-d2">
      <view
        class="tpl-card lumira-card-hover"
        v-for="t in filteredTemplates"
        :key="t.meta.id"
        @click="goDetail(t.meta.id)"
      >
        <view class="tpl-img-wrap">
          <image class="tpl-img" :src="coverUrl(t)" mode="aspectFill" />
          <view v-if="t.meta.price === 0" class="tpl-badge-free">
            <text class="tpl-badge-free-text">免费</text>
          </view>
          <view v-else class="tpl-badge-premium">
            <text class="ph ph-star tpl-badge-icon"></text>
            <text class="tpl-badge-text">精选 ¥{{ t.meta.price }}</text>
          </view>
        </view>
        <view class="tpl-info">
          <text class="tpl-name">{{ t.meta.name }}</text>
          <view class="tpl-meta">
            <text class="tpl-cat">{{ categoryLabel(t.meta.category) }}</text>
            <text v-if="showCustom" class="tpl-custom-tag">自定义</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 空状态 -->
    <view v-else class="empty-state-wrap fade-up fade-up-d2">
      <text class="ph ph-folder-open empty-icon"></text>
      <text class="empty-text">{{
        showCustom ? '还没有自定义模板' : '该分类暂无模板'
      }}</text>
      <view v-if="showCustom" class="empty-btn" @click="goEditor">
        去创建
      </view>
    </view>

    <FloatingTabBar active="templates" />
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { onShow, onLoad } from '@dcloudio/uni-app'
import FloatingTabBar from '@/components/FloatingTabBar.vue'
import CategoryNav from '@/components/CategoryNav.vue'
import TagSelector from '@/components/TagSelector.vue'
import { useTemplate } from '@/composables/useTemplate'
import { useTemplateIO } from '@/composables/useTemplateIO'
import { useTagManager } from '@/composables/useTagManager'
import { SCENE_TO_CATEGORY } from '@/data/scenePresets'
import type { PhotoTemplate, Target, ScenePresetId } from '@/types/template'

const { getAllTemplates, getCustomTemplates } = useTemplate()
const { filterTemplatesByTags } = useTagManager()
const { importTemplate } = useTemplateIO()

// ===== 三层分类 + 标签筛选 =====
const selectedType = ref<Target | null>(null)
const selectedStyle = ref<string | null>(null)
const selectedMethod = ref<string | null>(null)
const selectedTagIds = ref<string[]>([])
const showCustom = ref(false)

// 自定义模板刷新触发器：onShow / 导入后自增，触发 computed 重算
// （getAllTemplates / getCustomTemplates 内部读 storage，本身非响应式）
const refreshTick = ref(0)

// 接收场景推荐页传入的 scene 参数，自动切换到对应分类
onLoad((options) => {
  if (options?.scene) {
    const cat = SCENE_TO_CATEGORY[options.scene as ScenePresetId]
    if (cat) selectedType.value = cat
  }
})

onShow(() => {
  refreshTick.value++
})

// 三层分类选项
const STYLE_MAP: Record<Target, { value: string; label: string }[]> = {
  portrait: [
    { value: 'japanese', label: '日系' },
    { value: 'emotional', label: '情绪' },
    { value: 'film', label: '胶片' },
    { value: 'western', label: '欧美' },
  ],
  landscape: [
    { value: 'fresh', label: '清新' },
    { value: 'epic', label: '大气' },
  ],
  food: [
    { value: 'overhead', label: '俯拍' },
    { value: 'closeup', label: '特写' },
  ],
  street: [
    { value: 'casual', label: '随性' },
    { value: 'geometric', label: '几何' },
  ],
  night: [
    { value: 'neon', label: '霓虹' },
    { value: 'starry', label: '星空' },
  ],
  macro: [
    { value: 'nature', label: '自然' },
    { value: 'object', label: '物品' },
  ],
  'still-life': [
    { value: 'minimal', label: '极简' },
    { value: 'flat', label: '扁平' },
  ],
}

const METHOD_MAP: Record<string, { value: string; label: string }[]> = {
  japanese: [
    { value: 'selfie', label: '自拍' },
    { value: 'normal', label: '他拍' },
    { value: 'overhead', label: '俯拍' },
  ],
  emotional: [
    { value: 'selfie', label: '自拍' },
    { value: 'wide', label: '远景' },
  ],
  film: [
    { value: 'selfie', label: '自拍' },
    { value: 'normal', label: '他拍' },
  ],
  western: [
    { value: 'normal', label: '他拍' },
    { value: 'wide', label: '远景' },
  ],
  fresh: [
    { value: 'wide', label: '远景' },
    { value: 'flat', label: '平拍' },
  ],
  epic: [
    { value: 'wide', label: '远景' },
    { value: 'overhead', label: '俯拍' },
  ],
  overhead: [
    { value: 'flat', label: '平拍' },
    { value: 'overhead', label: '俯拍' },
  ],
  closeup: [
    { value: 'macro', label: '微距' },
    { value: 'detail', label: '细节' },
  ],
  casual: [
    { value: 'normal', label: '随拍' },
    { value: 'wide', label: '远景' },
  ],
  geometric: [
    { value: 'wide', label: '远景' },
    { value: 'overhead', label: '俯拍' },
  ],
  neon: [
    { value: 'normal', label: '他拍' },
    { value: 'wide', label: '远景' },
  ],
  starry: [
    { value: 'wide', label: '远景' },
    { value: 'long', label: '长曝' },
  ],
  nature: [
    { value: 'macro', label: '微距' },
    { value: 'detail', label: '细节' },
  ],
  object: [
    { value: 'macro', label: '微距' },
    { value: 'flat', label: '平拍' },
  ],
  minimal: [
    { value: 'flat', label: '平拍' },
    { value: 'detail', label: '细节' },
  ],
  flat: [
    { value: 'flat', label: '平拍' },
    { value: 'overhead', label: '俯拍' },
  ],
}

interface CategoryLayer {
  label: string
  selected: string | null
  options: { value: string; label: string }[]
}

const categoryLayers = computed<CategoryLayer[]>(() => {
  const layers: CategoryLayer[] = [{
    label: '类型',
    selected: selectedType.value,
    options: [
      { value: 'portrait', label: '人像' },
      { value: 'landscape', label: '风景' },
      { value: 'food', label: '美食' },
      { value: 'street', label: '街拍' },
      { value: 'night', label: '夜景' },
      { value: 'macro', label: '微距' },
      { value: 'still-life', label: '静物' },
    ],
  }]
  if (selectedType.value && STYLE_MAP[selectedType.value]) {
    layers.push({
      label: '风格',
      selected: selectedStyle.value,
      options: STYLE_MAP[selectedType.value],
    })
  }
  if (selectedStyle.value && METHOD_MAP[selectedStyle.value]) {
    layers.push({
      label: '方式',
      selected: selectedMethod.value,
      options: METHOD_MAP[selectedStyle.value],
    })
  }
  return layers
})

function onLayerSelect(idx: number, value: string | null) {
  if (idx === 0) {
    selectedType.value = value as Target | null
    selectedStyle.value = null
    selectedMethod.value = null
  } else if (idx === 1) {
    selectedStyle.value = value
    selectedMethod.value = null
  } else if (idx === 2) {
    selectedMethod.value = value
  }
}

// 所有模板（builtin + 自定义）。访问 refreshTick 触发 onShow 刷新
const allTemplates = computed<PhotoTemplate[]>(() => {
  void refreshTick.value
  return getAllTemplates()
})

const customOnly = computed<PhotoTemplate[]>(() => {
  void refreshTick.value
  return getCustomTemplates()
})

const allTemplatesCount = computed(() => allTemplates.value.length)
const unlockedCount = computed(() => allTemplates.value.filter(t => t.meta.price === 0).length)

const filteredTemplates = computed<PhotoTemplate[]>(() => {
  let list = showCustom.value ? customOnly.value : allTemplates.value
  if (selectedType.value) {
    list = list.filter(t => t.meta.classification.type === selectedType.value)
  }
  if (selectedStyle.value) {
    list = list.filter(t => t.meta.classification.style === selectedStyle.value)
  }
  if (selectedMethod.value) {
    list = list.filter(t => t.meta.classification.method === selectedMethod.value)
  }
  if (selectedTagIds.value.length > 0) {
    list = filterTemplatesByTags(selectedTagIds.value, list)
  }
  return list
})

const categoryLabelMap: Record<Target, string> = {
  portrait: '人像',
  landscape: '风光',
  food: '美食',
  night: '夜景',
  street: '街拍',
  macro: '微距',
  'still-life': '静物'
}

function categoryLabel(cat: Target): string {
  return categoryLabelMap[cat] || cat
}

function coverUrl(t: PhotoTemplate): string {
  return t.meta.cover || `https://picsum.photos/seed/${t.meta.id}/400/600`
}

function goDetail(id: string) {
  uni.navigateTo({ url: `/pages/templates/detail?templateId=${id}` })
}

function goEditor() {
  uni.navigateTo({ url: '/pages/templates/editor' })
}

async function handleImport() {
  const tpl = await importTemplate()
  if (tpl) {
    refreshTick.value++
  }
}
</script>

<style lang="scss" scoped>
.nav-icon {
  font-size: 40rpx;
  color: var(--color-text-primary);
}

.section-pad {
  padding: 0 40rpx;
}

/* Hero */
.hero-wrap {
  padding: 0 40rpx 32rpx;
}

.hero-card {
  position: relative;
  background: linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%);
  border-radius: 40rpx;
  padding: 56rpx 48rpx;
  overflow: hidden;
}

.hero-deco {
  position: absolute;
  top: -60rpx;
  right: -60rpx;
  width: 280rpx;
  height: 280rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.10);
}

.hero-deco-2 {
  position: absolute;
  bottom: -40rpx;
  left: -40rpx;
  width: 200rpx;
  height: 200rpx;
  border-radius: 50%;
  background: rgba(201, 169, 110, 0.06);
}

.hero-body {
  position: relative;
  z-index: 1;
}

.hero-title {
  display: block;
  font-family: 'Noto Serif SC', serif;
  font-size: 44rpx;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 16rpx;
  letter-spacing: -0.01em;
}

.hero-desc {
  display: block;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  line-height: 1.6;
  margin-bottom: 24rpx;
}

.hero-pill {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 10rpx 24rpx;
  border-radius: 9999rpx;
  background-color: rgba(255, 255, 255, 0.6);
}

.hero-pill-icon {
  font-size: 26rpx;
  color: var(--color-brand);
}

.hero-pill-text {
  font-size: 24rpx;
  color: var(--color-text-secondary);
  font-weight: 500;
}

/* 三层分类 + 标签筛选区 */
.template-filter {
  padding: 0 16rpx 24rpx;
}

.template-tags {
  margin-top: 16rpx;
}

.custom-toggle-row {
  display: flex;
  justify-content: flex-start;
  padding: 16rpx 24rpx 0;
}

.custom-toggle-pill {
  display: inline-flex;
  align-items: center;
  padding: 12rpx 32rpx;
  border-radius: 32rpx;
  background: rgba(0, 0, 0, 0.05);
}

.custom-toggle-pill-active {
  background: #2A2520;
}

.custom-toggle-text {
  font-size: 24rpx;
  color: #2A2520;
  line-height: 1.2;
}

.custom-toggle-pill-active .custom-toggle-text {
  color: #FFFFFF;
}

/* "我的"分类操作按钮行 */
.action-row {
  display: flex;
  gap: 20rpx;
  padding: 0 40rpx 24rpx;
}

.action-btn {
  flex: 1;
  justify-content: center;
  padding: 24rpx 0;
}

.action-btn-icon {
  font-size: 32rpx;
}

.action-btn-text {
  font-size: 28rpx;
  font-weight: 500;
}

/* 模板网格 */
.tpl-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24rpx;
  padding-bottom: 48rpx;
}

.tpl-card {
  border-radius: 28rpx;
  overflow: hidden;
  border: none;
  background-color: var(--color-canvas);
  box-shadow: var(--shadow-convex);
}

.tpl-img-wrap {
  width: 100%;
  padding-bottom: 133.33%;
  position: relative;
  overflow: hidden;
}

.tpl-img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.tpl-badge-free {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  background-color: rgba(90, 122, 72, 0.85);
}

.tpl-badge-free-text {
  font-size: 22rpx;
  font-weight: 600;
  color: #fff;
}

.tpl-badge-premium {
  position: absolute;
  top: 16rpx;
  left: 16rpx;
  padding: 6rpx 20rpx;
  border-radius: 9999rpx;
  background-color: rgba(201, 169, 110, 0.85);
  display: flex;
  align-items: center;
  gap: 6rpx;
}

.tpl-badge-icon {
  font-size: 22rpx;
  color: #fff;
}

.tpl-badge-text {
  font-size: 22rpx;
  font-weight: 600;
  color: #fff;
}

.tpl-info {
  padding: 24rpx 28rpx 28rpx;
}

.tpl-name {
  display: block;
  font-size: 28rpx;
  font-weight: 600;
  font-family: 'Noto Serif SC', serif;
  color: var(--color-text-primary);
}

.tpl-meta {
  display: flex;
  align-items: center;
  gap: 12rpx;
  margin-top: 12rpx;
}

.tpl-cat {
  font-size: 22rpx;
  color: var(--color-brand);
}

.tpl-custom-tag {
  font-size: 20rpx;
  color: var(--color-brand);
  background-color: rgba(201, 169, 110, 0.12);
  padding: 4rpx 14rpx;
  border-radius: 9999rpx;
}

/* 空状态 */
.empty-state-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 40rpx 48rpx;
  gap: 24rpx;
}

.empty-icon {
  font-size: 96rpx;
  color: var(--color-text-tertiary);
  opacity: 0.4;
}

.empty-text {
  font-size: 28rpx;
  color: var(--color-text-tertiary);
}

.empty-btn {
  padding: 16rpx 48rpx;
  border-radius: 9999rpx;
  background: linear-gradient(135deg, #C9A96E 0%, #A88550 100%);
  color: #fff;
  font-size: 26rpx;
  font-weight: 500;
}
</style>
