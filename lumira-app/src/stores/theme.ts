/**
 * 主题状态仓库
 * 管理当前主题、跟随系统、布局参数
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { storageService } from '@/services/storage'
import {
  THEME_METAS,
  THEME_IDS,
  type ThemeId,
  type ThemeMeta,
  type ThemeLayout,
} from '@/theme/theme-configs'

export const useThemeStore = defineStore('theme', () => {
  // === State ===
  const currentTheme = ref<ThemeId>('warm')
  const followSystem = ref(false)
  const loaded = ref(false)

  // === Computed ===
  const themeMeta = computed<ThemeMeta>(() => THEME_METAS[currentTheme.value])
  const layout = computed<ThemeLayout>(() => themeMeta.value.layout)
  const componentVariant = computed(() => themeMeta.value.componentVariant)
  const iconStyle = computed(() => themeMeta.value.iconStyle)

  // === Actions ===
  async function setTheme(id: ThemeId): Promise<void> {
    currentTheme.value = id
    applyTheme(id)
    await storageService.setSetting('theme', id)
  }

  async function setFollowSystem(enabled: boolean): Promise<void> {
    followSystem.value = enabled
    await storageService.setSetting('followSystemTheme', String(enabled))
    if (enabled) syncWithSystem()
  }

  async function loadTheme(): Promise<void> {
    const saved = await storageService.getSetting('theme')
    if (saved && THEME_IDS.includes(saved as ThemeId)) {
      currentTheme.value = saved as ThemeId
    }
    const fs = await storageService.getSetting('followSystemTheme')
    followSystem.value = fs === 'true'
    applyTheme(currentTheme.value)
    if (followSystem.value) syncWithSystem()
    loaded.value = true
  }

  function applyTheme(id: ThemeId): void {
    const meta = THEME_METAS[id]
    // #ifdef H5
    document.documentElement.setAttribute('data-theme', id)
    document.documentElement.style.setProperty(
      '--layout-grid-columns',
      String(meta.layout.templateGridColumns),
    )
    document.documentElement.style.setProperty(
      '--layout-gallery-columns',
      String(meta.layout.galleryGridColumns),
    )
    document.documentElement.style.setProperty(
      '--layout-card-aspect',
      meta.layout.cardAspectRatio,
    )
    // #endif
    // #ifndef H5
    uni.$emit('theme-change', id)
    // #endif
  }

  function syncWithSystem(): void {
    // #ifdef H5
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const handler = (e: MediaQueryListEvent) => {
      if (followSystem.value) {
        setTheme(e.matches ? 'ink' : 'warm')
      }
    }
    mq.addEventListener('change', handler)
    // #endif
  }

  return {
    // state
    currentTheme,
    followSystem,
    loaded,
    // computed
    themeMeta,
    layout,
    componentVariant,
    iconStyle,
    // actions
    setTheme,
    setFollowSystem,
    loadTheme,
    applyTheme,
    syncWithSystem,
  }
})
