<script setup lang="ts">
interface CategoryTabsProps {
  categories: string[]
  current: string
}

defineProps<CategoryTabsProps>()

const emit = defineEmits<{
  (e: 'on-change', category: string): void
}>()
</script>

<template>
  <scroll-view scroll-x class="category-tabs" :show-scrollbar="false">
    <view class="tabs-row">
      <view
        v-for="cat in categories"
        :key="cat"
        class="tab-pill"
        :class="{ active: cat === current }"
        @click="emit('on-change', cat)"
      >
        <text class="tab-text">{{ cat }}</text>
      </view>
    </view>
  </scroll-view>
</template>

<style lang="scss" scoped>
.category-tabs {
  width: 100%;
  white-space: nowrap;
  margin-bottom: var(--space-4);
}

.tabs-row {
  display: inline-flex;
  gap: var(--space-2);
  padding: 0 var(--space-5);
}

.tab-pill {
  display: inline-flex;
  align-items: center;
  padding: var(--space-2) var(--space-4);
  border-radius: var(--radius-pill);
  background: var(--color-bg-surface);
  border: 1px solid var(--color-border);
  transition: all var(--duration-normal) ease;
  flex-shrink: 0;

  &:active { transform: scale(0.96); }

  &.active {
    background: var(--color-tag-gold-bg);
    border-color: var(--color-brand-primary);
  }
}

.tab-text {
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  font-weight: var(--weight-medium);
  color: var(--color-text-secondary);
  letter-spacing: var(--letter-spacing-tag);

  .active & {
    color: var(--color-tag-gold-text);
  }
}
</style>
