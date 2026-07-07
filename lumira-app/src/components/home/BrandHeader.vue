<script setup lang="ts">
</script>

<template>
  <view class="brand-header">
    <text class="brand-title">如画</text>
    <text class="brand-tagline">如你所见，皆成画卷</text>
  </view>
</template>

<style lang="scss" scoped>
.brand-header {
  padding: calc(var(--space-6) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.brand-title {
  display: block;
  font-family: var(--font-serif);
  font-size: var(--font-size-display);
  font-weight: var(--weight-semibold);
  color: var(--color-text-primary);
  letter-spacing: var(--letter-spacing-display);
  line-height: var(--line-height-display);
}

.brand-tagline {
  display: block;
  font-family: var(--font-sans);
  font-size: var(--font-size-caption);
  color: var(--color-text-tertiary);
  line-height: var(--line-height-caption);
  margin-top: var(--space-1);
}
</style>
