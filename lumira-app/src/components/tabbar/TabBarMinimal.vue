<script setup lang="ts">
/**
 * 极简线条 TabBar（fresh 主题）
 * 仅图标 + 细线下划线指示器，无快门突出
 * 与 TabBarFloating 共享相同的 props/emits 契约
 */
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface TabBarMinimalProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<TabBarMinimalProps>(), {
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
  <view class="tab-bar-minimal" :class="`theme-${theme}`">
    <view class="minimal-inner">
      <view
        v-for="tab in tabs"
        :key="tab.key"
        class="minimal-tab"
        :class="{ active: current === tab.key, 'is-center': tab.center }"
        @click="handleSwitch(tab.key)"
      >
        <text class="minimal-icon">{{ tab.iconChar }}</text>
        <view v-if="current === tab.key" class="minimal-underline" />
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.tab-bar-minimal {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  bottom: calc(var(--tabbar-bottom-offset) + env(safe-area-inset-bottom));
  z-index: 900;
}

.minimal-inner {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: var(--space-7);
  height: var(--tabbar-height);
  padding: 0 var(--space-5);

  .theme-light & {
    background: transparent;
  }

  .theme-dark & {
    background: transparent;
  }
}

.minimal-tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  width: 44px;
  height: 44px;
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
    opacity: 0.6;
  }
}

.minimal-icon {
  font-size: 22px;
  line-height: 1;
}

.minimal-underline {
  position: absolute;
  bottom: 2px;
  width: 16px;
  height: 1.5px;
  border-radius: 1px;
  background: var(--color-brand-primary);
}

.is-center {
  .minimal-icon {
    font-size: 26px;
  }
}
</style>
