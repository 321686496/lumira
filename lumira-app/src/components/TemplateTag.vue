<script setup lang="ts">
interface Props {
  type?: 'gold' | 'red' | 'green'
  text: string
}

withDefaults(defineProps<Props>(), {
  type: 'gold'
})
</script>

<template>
  <view class="template-tag" :class="`type-${type}`">
    <text class="tag-text">{{ text }}</text>
  </view>
</template>

<style lang="scss" scoped>
.template-tag {
  display: inline-flex;
  align-items: center;
  border-radius: var(--radius-pill);
  padding: 2px var(--space-2);
}

.tag-text {
  font-size: var(--font-size-tag);
  line-height: 1.4;
}

.type-gold {
  background: var(--color-tag-gold-bg);
  .tag-text {
    color: var(--color-tag-gold-text);
  }
}

.type-red {
  background: var(--color-tag-red-bg);
  .tag-text {
    color: var(--color-tag-red-text);
  }
}

.type-green {
  background: var(--color-tag-green-bg);
  .tag-text {
    color: var(--color-tag-green-text);
  }
}
</style>
