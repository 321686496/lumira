/**
 * 主题 + 风格管理 composable
 * 管理当前主题（颜色）和风格（效果）状态、持久化、跟随系统
 */
import { ref } from 'vue'
import type { ThemeId, StyleId } from '@/theme/theme-configs'
import { THEME_IDS, STYLE_IDS } from '@/theme/theme-configs'

const currentTheme = ref<ThemeId>('warm')
const currentStyle = ref<StyleId>('neumorphism')
const followSystem = ref(false)
let initialized = false

function applyTheme(id: ThemeId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', id)
  }
  // #endif
}

function applyStyle(id: StyleId) {
  // #ifdef H5
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-style', id)
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

function setStyle(id: StyleId) {
  currentStyle.value = id
  applyStyle(id)
  try {
    uni.setStorageSync('uiStyle', id)
  } catch (e) {
    console.warn('Failed to persist style', e)
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

function loadStyle() {
  try {
    const saved = uni.getStorageSync('uiStyle') as StyleId
    if (saved && STYLE_IDS.includes(saved)) {
      currentStyle.value = saved
    }
  } catch (e) {
    console.warn('Failed to load style', e)
  }
  applyStyle(currentStyle.value)
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
    currentStyle,
    followSystem,
    setTheme,
    setStyle,
    loadTheme,
    loadStyle,
    setFollowSystem
  }
}
