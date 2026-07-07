<script setup lang="ts">
interface TabItem {
  key: string
  label: string
  iconChar: string
  center?: boolean
}

interface FloatingTabBarProps {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<FloatingTabBarProps>(), {
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
  <view class="floating-tab-bar" :class="`theme-${theme}`">
    <view class="tab-bar-inner">
      <view
        class="tab-item tab-side"
        :class="{ active: current === 'home' }"
        @click="handleSwitch('home')"
      >
        <text class="tab-icon">{{ tabs[0].iconChar }}</text>
        <text v-if="current === 'home'" class="tab-label">{{ tabs[0].label }}</text>
      </view>

      <view class="tab-center" @click="handleSwitch('capture')">
        <view class="shutter-btn" :class="{ active: current === 'capture' }">
          <view class="shutter-ring"></view>
          <text class="shutter-icon">{{ tabs[1].iconChar }}</text>
        </view>
      </view>

      <view
        class="tab-item tab-side"
        :class="{ active: current === 'profile' }"
        @click="handleSwitch('profile')"
      >
        <text class="tab-icon">{{ tabs[2].iconChar }}</text>
        <text v-if="current === 'profile'" class="tab-label">{{ tabs[2].label }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.floating-tab-bar {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  bottom: calc(var(--tabbar-bottom-offset) + env(safe-area-inset-bottom));
  z-index: 900;
  width: auto;
}

.tab-bar-inner {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  height: var(--tabbar-height);
  padding: 0 var(--space-3);
  border-radius: var(--radius-pill);
  gap: var(--space-6);
  position: relative;

  .theme-light & {
    background: rgba(255, 255, 255, 0.72);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid var(--color-border);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.06);
  }

  .theme-dark & {
    background: rgba(28, 26, 23, 0.6);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid rgba(255, 255, 255, 0.12);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.3);
  }
}

/* 侧边 Tab 项 */
.tab-item {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-1);
  padding: 0 var(--space-3);
  height: 44px;
  border-radius: var(--radius-pill);
  transition: transform var(--duration-normal) var(--ease-default);
  min-width: 44px;

  .theme-light & {
    color: var(--color-text-tertiary);
  }

  .theme-dark & {
    color: rgba(255, 255, 255, 0.5);
  }

  &.active {
    transform: scale(1.08);
    color: var(--color-brand-primary);
  }

  &:active {
    transform: scale(0.94);
  }
}

.tab-icon {
  font-size: 20px;
  line-height: 1;
}

.tab-label {
  font-size: var(--font-size-tag);
  font-weight: var(--weight-medium);
  line-height: 1;
  color: var(--color-brand-primary);
}

/* 中间拍摄按钮 */
.tab-center {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 60px;
  height: var(--tabbar-height);
  flex-shrink: 0;
}

.shutter-btn {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: var(--tabbar-shutter-size);
  height: var(--tabbar-shutter-size);
  margin-top: calc(var(--tabbar-shutter-protrusion) * -1);
  border-radius: 50%;
  background: var(--color-brand-primary);
  border: 2px solid var(--color-bg-canvas);
  transition: transform var(--duration-fast) ease, box-shadow var(--duration-fast) ease;

  .theme-dark & {
    border-color: var(--color-capture-bg);
  }

  &.active {
    transform: scale(0.92);
  }

  &:active {
    transform: scale(0.92);
  }
}

.shutter-ring {
  position: absolute;
  top: -5px;
  left: -5px;
  right: -5px;
  bottom: -5px;
  border-radius: 50%;
  border: 1px solid var(--color-brand-primary);
  opacity: 0.25;
}

.shutter-icon {
  font-size: 24px;
  line-height: 1;
  color: #FFFFFF;
}
</style>
