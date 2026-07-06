<template>
  <view class="templates-page">
    <!-- Header -->
    <view class="page-header">
      <text class="page-title">模板</text>
      <text class="page-subtitle">{{ templateCount }} 个模板</text>
    </view>

    <!-- Category tabs -->
    <scroll-view class="category-bar" scroll-x>
      <view class="category-list">
        <view
          v-for="cat in categories"
          :key="cat"
          class="category-pill"
          :class="{ active: cat === currentCategory }"
          @tap="onCategoryTap(cat)"
        >
          <text class="category-text" :class="{ active: cat === currentCategory }">{{ cat }}</text>
        </view>
      </view>
    </scroll-view>

    <!-- Template grid -->
    <scroll-view class="template-scroll" scroll-y>
      <view class="template-grid">
        <view
          v-for="tpl in filteredTemplates"
          :key="tpl.id"
          class="grid-item"
          @tap="onTemplateTap(tpl.id)"
        >
          <TemplateCard :template="tpl" />
        </view>
      </view>
      <view v-if="filteredTemplates.length === 0" class="empty-wrap">
        <text class="empty-text">该分类下暂无模板</text>
      </view>
      <view class="bottom-pad"></view>
    </scroll-view>
  </view>
</template>

<script setup lang="ts">
import { onLoad } from '@dcloudio/uni-app'
import TemplateCard from '@/components/TemplateCard.vue'
import { useTemplatesStore } from '@/stores/templates'

const templatesStore = useTemplatesStore()

const categories = templatesStore.categories
const currentCategory = templatesStore.currentCategory
const filteredTemplates = templatesStore.filteredTemplates
const templateCount = templatesStore.templateCount

onLoad(() => {
  templatesStore.loadTemplates()
})

const onCategoryTap = (cat: string) => {
  templatesStore.setCategory(cat)
}

const onTemplateTap = (id: string | number) => {
  uni.navigateTo({ url: `/pages/templates/detail?id=${id}` })
}
</script>

<style lang="scss" scoped>
.templates-page {
  position: relative;
  width: 100%;
  height: 100vh;
  background: var(--color-bg-canvas);
  display: flex;
  flex-direction: column;
}

.page-header {
  padding: var(--space-6) var(--space-5) var(--space-3);
  display: flex;
  flex-direction: column;
}

.page-title {
  font-size: var(--font-size-display);
  color: var(--color-text-primary);
  font-family: 'Source Han Serif SC', 'Noto Serif SC', serif;
}

.page-subtitle {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  margin-top: var(--space-1);
}

.category-bar {
  flex-shrink: 0;
  padding: var(--space-2) var(--space-5);
  margin-bottom: var(--space-2);
}

.category-list {
  display: inline-flex;
  gap: var(--space-2);
}

.category-pill {
  padding: var(--space-2) var(--space-4);
  border-radius: 999px;
  background: var(--color-bg-card);
  border: 1px solid var(--color-border);
}

.category-pill.active {
  background: var(--color-brand-primary);
  border-color: var(--color-brand-primary);
}

.category-text {
  font-size: var(--font-size-tag);
  color: var(--color-text-secondary);
}

.category-text.active {
  color: var(--color-text-primary);
}

.template-scroll {
  flex: 1;
}

.template-grid {
  display: flex;
  flex-wrap: wrap;
  padding: 0 var(--space-5);
  gap: var(--space-3);
}

.grid-item {
  width: calc((100% - var(--space-3)) / 2);
}

.empty-wrap {
  padding: var(--space-9) var(--space-5);
  display: flex;
  align-items: center;
  justify-content: center;
}

.empty-text {
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
}

.bottom-pad {
  height: var(--space-9);
}
</style>
