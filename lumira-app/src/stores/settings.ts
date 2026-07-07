/**
 * 设置状态仓库
 */
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { storageService } from '@/services/storage'

type SettingKey =
  | 'showGrid'
  | 'showLevelIndicator'
  | 'shutterSound'
  | 'saveQuality'
  | 'defaultOverlayOpacity'
  | 'defaultCamera'
  | 'waterMarkEnabled'

export const useSettingsStore = defineStore('settings', () => {
  // === State ===
  const saveQuality = ref<'standard' | 'high' | 'original'>('high')
  const defaultGridDisplay = ref(true)
  const defaultOverlayOpacity = ref(0.5)
  const defaultCamera = ref<'front' | 'back'>('back')
  const waterMarkEnabled = ref(false)
  const showLevelIndicator = ref(true)
  const shutterSound = ref(true)
  const loaded = ref(false)

  // === Aggregated settings (read-only view) ===
  const settings = computed(() => ({
    showGrid: defaultGridDisplay.value,
    showLevelIndicator: showLevelIndicator.value,
    shutterSound: shutterSound.value,
    saveQuality: saveQuality.value,
    defaultOverlayOpacity: defaultOverlayOpacity.value,
    defaultCamera: defaultCamera.value,
    waterMarkEnabled: waterMarkEnabled.value,
  }))

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

    const li = await storageService.getSetting('showLevelIndicator')
    showLevelIndicator.value = li !== 'false'

    const ss = await storageService.getSetting('shutterSound')
    shutterSound.value = ss !== 'false'

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

  async function setShowLevelIndicator(enabled: boolean): Promise<void> {
    showLevelIndicator.value = enabled
    await storageService.setSetting('showLevelIndicator', String(enabled))
  }

  async function setShutterSound(enabled: boolean): Promise<void> {
    shutterSound.value = enabled
    await storageService.setSetting('shutterSound', String(enabled))
  }

  async function updateSetting(
    key: SettingKey,
    value: boolean | string | number,
  ): Promise<void> {
    switch (key) {
      case 'showGrid':
        await setDefaultGridDisplay(value as boolean)
        break
      case 'showLevelIndicator':
        await setShowLevelIndicator(value as boolean)
        break
      case 'shutterSound':
        await setShutterSound(value as boolean)
        break
      case 'saveQuality':
        await setSaveQuality(value as 'standard' | 'high' | 'original')
        break
      case 'defaultOverlayOpacity':
        await setDefaultOverlayOpacity(value as number)
        break
      case 'defaultCamera':
        await setDefaultCamera(value as 'front' | 'back')
        break
      case 'waterMarkEnabled':
        await setWaterMarkEnabled(value as boolean)
        break
    }
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
    showLevelIndicator,
    shutterSound,
    loaded,
    // aggregated view
    settings,
    // actions
    loadSettings,
    setSaveQuality,
    setDefaultGridDisplay,
    setDefaultOverlayOpacity,
    setDefaultCamera,
    setWaterMarkEnabled,
    setShowLevelIndicator,
    setShutterSound,
    updateSetting,
    clearCache,
  }
})
