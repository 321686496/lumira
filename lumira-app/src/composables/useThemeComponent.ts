/**
 * 主题组件变体选择 composable
 * 根据当前主题的 tabBarStyle 返回对应的 TabBar 组件
 */
import { computed } from 'vue'
import { useThemeStore } from '@/stores/theme'
import TabBarFloating from '@/components/tabbar/TabBarFloating.vue'
import TabBarCompact from '@/components/tabbar/TabBarCompact.vue'
import TabBarMinimal from '@/components/tabbar/TabBarMinimal.vue'
import type { Component } from 'vue'

const TABBAR_VARIANTS: Record<string, Component> = {
  floating: TabBarFloating,
  compact: TabBarCompact,
  minimal: TabBarMinimal,
}

export function useTabBarVariant() {
  const themeStore = useThemeStore()
  return computed<Component>(() => TABBAR_VARIANTS[themeStore.layout.tabBarStyle])
}
