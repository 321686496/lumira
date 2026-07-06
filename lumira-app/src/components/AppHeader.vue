<script setup lang="ts">
interface Props {
  title?: string
  showBack?: boolean
  transparent?: boolean
  theme?: 'light' | 'dark'
}

withDefaults(defineProps<Props>(), {
  title: '',
  showBack: false,
  transparent: false,
  theme: 'light'
})

const emit = defineEmits<{
  (e: 'on-back'): void
}>()

const handleBack = () => {
  emit('on-back')
}
</script>

<template>
  <view class="app-header" :class="[`theme-${theme}`, { transparent }]">
    <view class="header-inner">
      <view v-if="showBack" class="back-btn" @click="handleBack">
        <text class="back-icon">‹</text>
      </view>
      <text v-if="title" class="header-title">{{ title }}</text>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.app-header {
  width: 100%;
  padding-top: calc(var(--space-2) + env(safe-area-inset-top));

  &.theme-light {
    background: var(--color-bg-canvas);
    .back-icon,
    .header-title {
      color: var(--color-text-primary);
    }
  }

  &.theme-dark {
    background: transparent;
    .back-icon,
    .header-title {
      color: var(--color-bg-card);
    }
  }

  &.transparent {
    background: transparent;
  }
}

.header-inner {
  display: flex;
  align-items: center;
  height: 44px;
  padding: 0 var(--space-4);
  gap: var(--space-2);
}

.back-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;

  &:active {
    opacity: 0.6;
  }
}

.back-icon {
  font-size: var(--font-size-title);
  line-height: 1;
}

.header-title {
  font-family: 'Source Han Serif', 'Songti SC', serif;
  font-size: var(--font-size-heading);
  font-weight: 600;
  line-height: 1.2;
}
</style>
