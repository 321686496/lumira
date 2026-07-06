/**
 * 设置状态仓库
 */
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { storageService } from '@/services/storage'

export const useSettingsStore = defineStore('settings', () => {
  // === State ===
  const saveQuality = ref<'standard' | 'high' | 'original'>('high')
  const defaultGridDisplay = ref(true)
  const defaultOverlayOpacity = ref(0.5)
  const defaultCamera = ref<'front' | 'back'>('back')
  const waterMarkEnabled = ref(false)
  const loaded = ref(false)

  // === Actions ===
  async function loadSettings(): Promise<void> {
    const sq = await storageService.getSetting('saveQuality')
    if (sq) saveQuality.value = sq as 'standard' | 'high' | 'original'

    const gd = await storageService.getSetting('defaultGridDisplay')
    defaultGridDisplay.value = gd !== 'false'

    const oo = await storageService.getSetting('defaultOverlayOpacity')
    if (oo) defaultOverlayOpacity.value = parseFloat(oo)

    const dc = await storageService.getSetting('defaultCamera')
    if (dc === 'front' || dc === 'back') defaultCamera.value = dc

    const wm = await storageService.getSetting('waterMarkEnabled')
    waterMarkEnabled.value = wm === 'true'

    loaded.value = true
  }

  async function setSaveQuality(quality: 'standard' | 'high' | 'original'): Promise<void> {
    saveQuality.value = quality
    await storageService.setSetting('saveQuality', quality)
  }

  async function setDefaultGridDisplay(enabled: boolean): Promise<void> {
    defaultGridDisplay.value = enabled
    await storageService.setSetting('defaultGridDisplay', String(enabled))
  }

  async function setDefaultOverlayOpacity(opacity: number): Promise<void> {
    defaultOverlayOpacity.value = opacity
    await storageService.setSetting('defaultOverlayOpacity', String(opacity))
  }

  async function setDefaultCamera(camera: 'front' | 'back'): Promise<void> {
    defaultCamera.value = camera
    await storageService.setSetting('defaultCamera', camera)
  }

  async function setWaterMarkEnabled(enabled: boolean): Promise<void> {
    waterMarkEnabled.value = enabled
    await storageService.setSetting('waterMarkEnabled', String(enabled))
  }

  async function clearCache(): Promise<void> {
    // Mock：实际应清理临时文件
    console.log('缓存已清理')
  }

  return {
    // state
    saveQuality,
    defaultGridDisplay,
    defaultOverlayOpacity,
    defaultCamera,
    waterMarkEnabled,
    loaded,
    // actions
    loadSettings,
    setSaveQuality,
    setDefaultGridDisplay,
    setDefaultOverlayOpacity,
    setDefaultCamera,
    setWaterMarkEnabled,
    clearCache,
  }
})
