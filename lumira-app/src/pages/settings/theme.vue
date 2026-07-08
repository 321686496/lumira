<script setup lang="ts">
/**
 * 主题选择页
 * 4 张主题预览卡（2×2 网格）+ 跟随系统开关
 */
import { computed } from 'vue'
import { useThemeStore } from '@/stores/theme'
import type { ThemeId } from '@/theme/theme-configs'

interface ThemePreview {
  id: ThemeId
  label: string
  description: string
  layoutDesc: string
  tabBarStyle: 'floating' | 'compact' | 'minimal'
  colors: {
    bgCanvas: string
    bgCard: string
    brandPrimary: string
    textPrimary: string
    textSecondary: string
    textTertiary: string
  }
}

const themeStore = useThemeStore()

const themePreviews: ThemePreview[] = [
  {
    id: 'warm',
    label: '暖米白',
    description: '温暖留白，编辑式质感',
    layoutDesc: '悬浮 TabBar · 2 列网格',
    tabBarStyle: 'floating',
    colors: {
      bgCanvas: '#FAF7F2',
      bgCard: '#FFFFFF',
      brandPrimary: '#C9A96E',
      textPrimary: '#1A1A1A',
      textSecondary: '#5C5852',
      textTertiary: '#9C9690',
    },
  },
  {
    id: 'ink',
    label: '浓墨',
    description: '深色沉浸，夜拍伴侣',
    layoutDesc: '悬浮 TabBar · 2 列网格',
    tabBarStyle: 'floating',
    colors: {
      bgCanvas: '#1C1A17',
      bgCard: '#262320',
      brandPrimary: '#D4B57A',
      textPrimary: '#F2EEE6',
      textSecondary: '#9C9690',
      textTertiary: '#6B6660',
    },
  },
  {
    id: 'retro',
    label: '胶片复古',
    description: '暖橘深棕，胶片方格',
    layoutDesc: '紧凑 TabBar · 方形构图',
    tabBarStyle: 'compact',
    colors: {
      bgCanvas: '#F5E6D3',
      bgCard: '#FAF0E0',
      brandPrimary: '#D4865C',
      textPrimary: '#3D2817',
      textSecondary: '#6B4C2F',
      textTertiary: '#9C8060',
    },
  },
  {
    id: 'fresh',
    label: '日系清新',
    description: '淡粉米白，杂志呼吸',
    layoutDesc: '极简 TabBar · 单列大卡',
    tabBarStyle: 'minimal',
    colors: {
      bgCanvas: '#FAF7F2',
      bgCard: '#FFFFFF',
      brandPrimary: '#E8B4A0',
      textPrimary: '#4A3F35',
      textSecondary: '#8C7F70',
      textTertiary: '#B8AEA0',
    },
  },
]

const currentTheme = computed(() => themeStore.currentTheme)
const followSystem = computed(() => themeStore.followSystem)

const isStylizedTheme = (id: ThemeId): boolean => id === 'retro' || id === 'fresh'

const selectTheme = async (id: ThemeId) => {
  // 选择 retro/fresh 时，若跟随系统已开启则关闭
  if (isStylizedTheme(id) && themeStore.followSystem) {
    await themeStore.setFollowSystem(false)
  }
  await themeStore.setTheme(id)
}

const toggleFollowSystem = async () => {
  // switch @change 不传参：依据 store 当前值取反（与 profile/settings.vue 一致）
  const enabled = !themeStore.followSystem
  if (enabled) {
    // 开启跟随系统时，若当前为 retro/fresh 则切换到 warm/ink
    const current = themeStore.currentTheme
    if (isStylizedTheme(current)) {
      // #ifdef H5
      const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches
      await themeStore.setTheme(isDark ? 'ink' : 'warm')
      // #endif
      // #ifndef H5
      await themeStore.setTheme('warm')
      // #endif
    }
  }
  await themeStore.setFollowSystem(enabled)
}

const goBack = () => {
  uni.navigateBack()
}
</script>

<template>
  <view class="theme-page">
    <view class="page-nav">
      <view class="nav-btn" @click="goBack">
        <text class="nav-icon">←</text>
      </view>
      <text class="nav-title">主题选择</text>
    </view>

    <view class="theme-grid">
      <view
        v-for="preview in themePreviews"
        :key="preview.id"
        class="preview-card"
        :class="{ active: preview.id === currentTheme }"
        :style="{ background: preview.colors.bgCanvas }"
        @click="selectTheme(preview.id)"
      >
        <view class="card-top-bar" :style="{ background: preview.colors.brandPrimary }" />

        <view class="card-body" :style="{ background: preview.colors.bgCard }">
          <text class="card-label" :style="{ color: preview.colors.textPrimary }">
            {{ preview.label }}
          </text>
          <text class="card-desc" :style="{ color: preview.colors.textSecondary }">
            {{ preview.description }}
          </text>
          <text class="card-desc" :style="{ color: preview.colors.textTertiary }">
            {{ preview.layoutDesc }}
          </text>
        </view>

        <view class="card-tabbar-preview">
          <view class="mini-tabbar" :class="`style-${preview.tabBarStyle}`">
            <view class="mini-tab-icon" :style="{ background: preview.colors.textTertiary }" />
            <view
              class="mini-shutter"
              :style="{
                background: preview.colors.brandPrimary,
                borderColor: preview.colors.bgCard,
              }"
            />
            <view class="mini-tab-icon" :style="{ background: preview.colors.textTertiary }" />
          </view>
        </view>

        <view v-if="preview.id === currentTheme" class="check-mark">
          <text class="check-icon">✓</text>
        </view>
      </view>
    </view>

    <view class="follow-system-section">
      <view class="setting-row">
        <view class="setting-text">
          <text class="setting-label">跟随系统</text>
          <text class="setting-hint">仅浅色/深色自动切换</text>
        </view>
        <switch
          :checked="followSystem"
          color="var(--color-brand-primary)"
          @change="toggleFollowSystem"
        />
      </view>
    </view>
  </view>
</template>

<style lang="scss" scoped>
.theme-page {
  min-height: 100vh;
  background: var(--color-bg-canvas);
}

.page-nav {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: calc(var(--space-4) + env(safe-area-inset-top)) var(--space-5) var(--space-3);
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;

  &:active {
    opacity: 0.6;
  }
}

.nav-icon {
  font-size: 22px;
  color: var(--color-text-primary);
}

.nav-title {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  font-weight: var(--weight-medium);
  color: var(--color-text-primary);
}

.theme-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--space-4);
  padding: var(--space-3) var(--space-5);
}

.preview-card {
  position: relative;
  border-radius: var(--radius-card);
  overflow: hidden;
  border: 2px solid transparent;
  transition: border-color var(--duration-normal) var(--ease-default);

  &.active {
    border-color: var(--color-brand-primary);
  }

  &:active {
    opacity: 0.9;
  }
}

.card-top-bar {
  height: 4px;
  width: 100%;
}

.card-body {
  padding: var(--space-3);
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

.card-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-heading);
  font-weight: var(--weight-semibold);
  line-height: 1.2;
}

.card-desc {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  line-height: 1.3;
}

.card-tabbar-preview {
  padding: var(--space-2) var(--space-3) var(--space-3);
}

.mini-tabbar {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  height: 24px;

  &.style-floating {
    background: rgba(255, 255, 255, 0.5);
    border-radius: var(--radius-pill);
    padding: 0 var(--space-2);
  }

  &.style-compact {
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    padding-top: var(--space-1);
  }

  &.style-minimal {
    background: transparent;
  }
}

.mini-tab-icon {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  opacity: 0.5;
}

.mini-shutter {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 1.5px solid transparent;
}

.style-floating {
  .mini-shutter {
    margin-top: -4px;
  }
}

.style-compact {
  .mini-shutter {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    border-width: 1px;
  }
}

.style-minimal {
  .mini-shutter {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: transparent !important;
    border-width: 1px;
  }
}

.check-mark {
  position: absolute;
  top: var(--space-2);
  right: var(--space-2);
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: var(--color-brand-primary);
  display: flex;
  align-items: center;
  justify-content: center;
}

.check-icon {
  font-size: 14px;
  color: #FFFFFF;
  font-weight: bold;
  line-height: 1;
}

.follow-system-section {
  padding: var(--space-5) var(--space-5) 0;
  margin-top: var(--space-3);
  border-top: 1px solid var(--color-border);
}

.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) 0;
}

.setting-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.setting-label {
  font-family: var(--font-sans);
  font-size: var(--font-size-body);
  color: var(--color-text-primary);
}

.setting-hint {
  font-family: var(--font-sans);
  font-size: var(--font-size-tag);
  color: var(--color-text-tertiary);
}
</style>
