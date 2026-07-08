<script setup lang="ts">
import { computed } from 'vue'
import { onLoad, onShow } from '@dcloudio/uni-app'
import CategoryTabs from '@/components/template/CategoryTabs.vue'
import { useTabBarVariant } from '@/composables/useThemeComponent'
import AppEmpty from '@/components/AppEmpty.vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()

const categories = computed(() => templatesStore.categories)
const currentCategory = computed(() => templatesStore.currentCategory)
const filteredTemplates = computed(() => templatesStore.filteredTemplates)

const tabBarVariant = useTabBarVariant()

let urlCategory = ''

onLoad((query) => {
  if (query?.category) {
    urlCategory = decodeURIComponent(query.category)
    templatesStore.setCategory(urlCategory)
  }
})

onShow(() => {
  templatesStore.loadTemplates()
})

const handleCategoryChange = (category: string) => {
  templatesStore.setCategory(category)
}

const goDetail = (id: string) => {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}

const goImport = () => {
  uni.navigateTo({ url: '/pages/templates/import' })
}

const handleTabSwitch = (key: string) => {
  if (key === 'capture') {
    uni.navigateTo({ url: '/pages/capture/index' })
  } else if (key === 'home') {
    uni.redirectTo({ url: '/pages/home/index' })
  } else if (key === 'profile') {
    uni.redirectTo({ url: '/pages/profile/index' })
  }
}
</script>

<template>
  <view class="templates-page">
    <view class="page-header">
      <text class="page-title">模板</text>
      <text class="page-sub">{{ templatesStore.templateCount }} 个模板</text>
    </view>

    <CategoryTabs
      :categories="categories"
      :current="currentCategory"
      @on-change="handleCategoryChange"
    />

    <scroll-view scroll-y class="templates-scroll" :show-scrollbar="false">
      <view v-if="filteredTemplates.length > 0" class="templates-grid">
        <view
          v-for="tmpl in filteredTemplates"
          :key="tmpl.id"
          class="template-card"
          @click="goDetail(tmpl.id)"
        >
          <view class="card-cover">
            <image v-if="tmpl.coverPath" :src="tmpl.coverPath" mode="aspectFill" class="cover-img" />
            <view v-else class="cover-placeholder">
              <text class="placeholder-char">▦</text>
            </view>
          </view>
          <view class="card-info">
            <text class="card-name">{{ tmpl.name }}</text>
            <text class="card-source">{{ tmpl.source === 'builtin' ? '内置' : tmpl.source === 'imported' ? '导入' : '自建' }}</text>
          </view>
        </view>
      </view>

      <AppEmpty
        v-else
        title="暂无模板"
        description="导入 .pptpl 模板文件"
        @on-action="goImport"
      />

      <view class="bottom-spacer" />
    </scroll-view>

    <component :is="tabBarVariant" current="home" theme="light" @on-switch="handleTabSwitch" />
  </view>
</template>

<style lang="scss" scoped>
.templates-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.page-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.page-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-display);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-display);
  line-height: var(--line-height-display);
}

.page-sub {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}

.templates-scroll {
  flex: 1;
  width: 100%;
}

.templates-grid {
  display: grid;
  grid-template-columns: repeat(var(--layout-grid-columns, 2), 1fr);
  gap: var(--space-4);
  padding: 0 var(--space-5);
}

.template-card {
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  overflow: hidden;

  &:active { opacity: 0.85; }
}

.card-cover {
  width: 100%;
  aspect-ratio: var(--layout-card-aspect, 3 / 4);
  background: var(--color-bg-surface);
  overflow: hidden;
}

.cover-img {
  width: 100%;
  height: 100%;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.placeholder-char {
  font-size: 32px;
  color: var(--color-text-tertiary);
  opacity: 0.3;
}

.card-info {
  padding: var(--space-3);
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.card-name {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-source {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}

.bottom-spacer {
  height: 120px;
}
</style>
