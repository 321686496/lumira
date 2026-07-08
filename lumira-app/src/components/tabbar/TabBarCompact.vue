<script setup lang="ts">
/**
 * 紧凑横条 TabBar（retro 主题）
 * 无悬浮、无快门突出、方正扁平设计
 * 与 TabBarFloating 共享相同的 props/emits 契约
 */
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface TabBarCompactProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<TabBarCompactProps>(), {
  theme: 'light',
})

const emit = defineEmits<{
  (e: 'on-switch', key: string): void
}>()

const tabs: TabItem[] = [
  { key: 'home', label: '首页', iconChar: '⌂' },
  { key: 'capture', label: '拍摄', iconChar: '◉', center: true },
  { key: 'profile', label: '我的', iconChar: '◍' },
]

const handleSwitch = (key: string) => {
  const tab = tabs.find((t) => t.key === key)
  if (key === props.current && !tab?.center) return
  emit('on-switch', key)
}
</script>

<template>
  <view class="tab-bar-compact" :class="`theme-${theme}`">
    <view
      v-for="tab in tabs"
      :key="tab.key"
      class="compact-tab"
      :class="{ active: current === tab.key, 'is-center': tab.center }"
      @click="handleSwitch(tab.key)"
    >
      <view class="compact-icon-wrap">
        <text class="compact-icon">{{ tab.iconChar }}</text>
      </view>
      <text class="compact-label">{{ tab.label }}</text>
      <view v-if="current === tab.key" class="compact-indicator" />
    </view>
  </view>
</template>

<style lang="scss" scoped>
.tab-bar-compact {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 0;
  bottom: env(safe-area-inset-bottom);
  z-index: 900;
  display: flex;
  height: calc(var(--tabbar-height) + env(safe-area-inset-bottom));
  padding-bottom: env(safe-area-inset-bottom);

  .theme-light & {
    background: var(--color-bg-card);
    border-top: 1px solid var(--color-border);
  }

  .theme-dark & {
    background: var(--color-bg-card-dark);
    border-top: 1px solid rgba(255, 255, 255, 0.08);
  }
}

.compact-tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  padding: var(--space-1) 0;
  position: relative;

  .theme-light & {
    color: var(--color-text-tertiary);
  }

  .theme-dark & {
    color: rgba(255, 255, 255, 0.4);
  }

  &.active {
    color: var(--color-brand-primary);
  }

  &:active {
    opacity: 0.7;
  }
}

.compact-icon-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
}

.compact-icon {
  font-size: 20px;
  line-height: 1;
}

.compact-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  line-height: 1;
}

.compact-indicator {
  position: absolute;
  bottom: var(--space-1);
  width: 20px;
  height: 2px;
  border-radius: 1px;
  background: var(--color-brand-primary);
}

.is-center {
  .compact-icon-wrap {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 1.5px solid var(--color-brand-primary);
  }

  .compact-icon {
    font-size: 18px;
    color: var(--color-brand-primary);
  }
}
</style>
