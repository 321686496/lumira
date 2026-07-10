/**
 * 主题管理 composable
 * 管理当前主题状态、持久化、跟随系统
 */
import { ref } from 'vue'
import type { ThemeId } from '@/theme/theme-configs'
import { THEME_IDS } from '@/theme/theme-configs'

const currentTheme = ref<ThemeId>('warm')
const followSystem = ref(false)
let initialized = false

function applyTheme(id: ThemeId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', id)
  }
  // #endif
}

let listenerRegistered = false

function setupSystemListener() {
  // #ifdef H5
  if (typeof window !== 'undefined' && window.matchMedia) {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    if (followSystem.value) {
      setTheme(mq.matches ? 'ink' : 'warm')
    }
    if (!listenerRegistered) {
      listenerRegistered = true
      mq.addEventListener('change', (e) => {
        if (followSystem.value) {
          setTheme(e.matches ? 'ink' : 'warm')
        }
      })
    }
  }
  // #endif
}

function setTheme(id: ThemeId) {
  currentTheme.value = id
  applyTheme(id)
  try {
    uni.setStorageSync('theme', id)
  } catch (e) {
    console.warn('Failed to persist theme', e)
  }
}

function loadTheme() {
  if (initialized) return
  initialized = true
  try {
    const saved = uni.getStorageSync('theme') as ThemeId
    if (saved && THEME_IDS.includes(saved)) {
      currentTheme.value = saved
    }
    const fs = uni.getStorageSync('followSystem')
    followSystem.value = fs === true || fs === 'true'
  } catch (e) {
    console.warn('Failed to load theme', e)
  }
  applyTheme(currentTheme.value)
  if (followSystem.value) {
    setupSystemListener()
  }
}

function setFollowSystem(enabled: boolean) {
  followSystem.value = enabled
  try {
    uni.setStorageSync('followSystem', enabled)
  } catch (e) {
    console.warn('Failed to persist followSystem', e)
  }
  if (enabled) {
    setupSystemListener()
  }
}

export function useTheme() {
  return {
    currentTheme,
    followSystem,
    setTheme,
    loadTheme,
    setFollowSystem
  }
}
