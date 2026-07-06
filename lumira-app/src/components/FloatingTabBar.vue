<script setup lang="ts">
interface Props {
  current: string
  theme?: 'light' | 'dark'
}

const props = withDefaults(defineProps<Props>(), {
  theme: 'light'
})

const emit = defineEmits<{
  (e: 'on-switch', key: string): void
}>()

interface TabItem {
  key: string
  label: string
  icon: string
  center?: boolean
}

// 首页 / 拍摄(中间突出) / 我的
const tabs: TabItem[] = [
  { key: 'home', label: '首页', icon: '⌂' },
  { key: 'capture', label: '拍摄', icon: '◉', center: true },
  { key: 'mine', label: '我的', icon: '◍' }
]

const handleSwitch = (key: string) => {
  // 中间项始终允许触发（即使当前在拍摄页，也可重新进入）
  if (key === props.current && !tabs.find((t) => t.key === key)?.center) return
  emit('on-switch', key)
}
</script>

<template>
  <view class="floating-tab-bar" :class="`theme-${theme}`">
    <view class="tab-bar-inner">
      <!-- 左侧：首页 -->
      <view
        class="tab-item tab-side"
        :class="{ active: current === 'home' }"
        @click="handleSwitch('home')"
      >
        <text class="tab-icon">{{ tabs[0].icon }}</text>
        <text v-if="current === 'home'" class="tab-label">{{ tabs[0].label }}</text>
      </view>

      <!-- 中间：拍摄快门按钮 -->
      <view class="tab-center" @click="handleSwitch('capture')">
        <view class="shutter-btn" :class="{ active: current === 'capture' }">
          <view class="shutter-ring"></view>
          <text class="shutter-icon">{{ tabs[1].icon }}</text>
        </view>
      </view>

      <!-- 右侧：我的 -->
      <view
        class="tab-item tab-side"
        :class="{ active: current === 'mine' }"
        @click="handleSwitch('mine')"
      >
        <text class="tab-icon">{{ tabs[2].icon }}</text>
        <text v-if="current === 'mine'" class="tab-label">{{ tabs[2].label }}</text>
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.floating-tab-bar {
  position: fixed;
  left: 50%;
  transform: translateX(-50%);
  bottom: calc(var(--space-3) + env(safe-area-inset-bottom));
  z-index: 100;
  width: auto;
}

.tab-bar-inner {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  height: 56px;
  padding: 0 var(--space-3);
  border-radius: var(--radius-pill);
  gap: var(--space-6);
  position: relative;

  .theme-light & {
    background: rgba(255, 255, 255, 0.92);
    backdrop-filter: blur(24px);
    -webkit-backdrop-filter: blur(24px);
    border: 1px solid var(--color-border);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
  }

  .theme-dark & {
    background: rgba(28, 26, 23, 0.7);
    backdrop-filter: blur(24px);
    -webkit-backdrop-filter: blur(24px);
    border: 1px solid rgba(255, 255, 255, 0.1);
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
  transition: all 0.25s ease;
  min-width: 44px;

  .theme-light & {
    color: var(--color-text-tertiary);
  }
  .theme-dark & {
    color: rgba(255, 255, 255, 0.5);
  }

  &.active {
    transform: scale(1.05);
    color: var(--color-brand-primary);
  }

  &:active {
    opacity: 0.6;
  }
}

.tab-icon {
  font-size: 20px;
  line-height: 1;
}

.tab-label {
  font-size: var(--font-size-caption);
  font-weight: 500;
  line-height: 1;
}

/* 中间拍摄按钮 */
.tab-center {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 60px;
  height: 56px;
  flex-shrink: 0;
}

.shutter-btn {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  margin-top: -20px;
  border-radius: 50%;
  background: linear-gradient(135deg, #D4B57A 0%, #C9A96E 50%, #A88550 100%);
  box-shadow:
    0 4px 16px rgba(201, 169, 110, 0.45),
    0 1px 4px rgba(168, 133, 80, 0.3),
    inset 0 1px 2px rgba(255, 255, 255, 0.3);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  border: 3px solid var(--color-bg-canvas);

  .theme-dark & {
    border-color: #1C1A17;
  }

  &.active {
    transform: scale(0.95);
    box-shadow:
      0 2px 8px rgba(201, 169, 110, 0.4),
      inset 0 2px 4px rgba(0, 0, 0, 0.15);
  }

  &:active {
    transform: scale(0.9);
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
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}
</style>
