/**
 * 场景管理组合式函数
 *
 * 提供自定义场景 CRUD、预设收藏、localStorage 持久化。
 * 使用 module-level ref 实现跨组件共享的单例状态。
 */

import { computed, ref } from 'vue'
import { SCENE_PRESETS } from '@/data/scenePresets'
import type {
  ScenePreset,
  ScenePresetId,
  CustomScenePreset,
  CustomSceneId,
  AnyScene
} from '@/types/template'

const STORAGE_KEY = 'lumira_scene_manager'

interface PersistedState {
  customScenes: CustomScenePreset[]
  favoritePresetIds: ScenePresetId[]
  customOrder: string[]
}

const DEFAULT_STATE: PersistedState = {
  customScenes: [],
  favoritePresetIds: [],
  customOrder: []
}

/** 从 localStorage 读取状态 */
function loadState(): PersistedState {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (!raw) return { ...DEFAULT_STATE }
    return {
      customScenes: Array.isArray(raw.customScenes) ? raw.customScenes : [],
      favoritePresetIds: Array.isArray(raw.favoritePresetIds) ? raw.favoritePresetIds : [],
      customOrder: Array.isArray(raw.customOrder) ? raw.customOrder : []
    }
  } catch {
    return { ...DEFAULT_STATE }
  }
}

/** 写入 localStorage */
function saveState(state: PersistedState): void {
  try {
    uni.setStorageSync(STORAGE_KEY, state)
  } catch {
    // 忽略写入异常
  }
}

/** 生成唯一自定义场景 ID */
function generateCustomId(): CustomSceneId {
  return `custom_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`
}

/** 判断是否为自定义场景 */
function isCustomScene(scene: AnyScene): scene is CustomScenePreset {
  return scene.id.startsWith('custom_')
}

/** module-level 单例状态（跨组件共享） */
const state = ref<PersistedState>(loadState())

/** 持久化写入 */
function persist() {
  saveState(state.value)
}

export function useSceneManager() {
  const customScenes = computed(() => state.value.customScenes)
  const favoritePresetIds = computed(() => state.value.favoritePresetIds)

  const allScenes = computed<AnyScene[]>(() => {
    return [...state.value.customScenes, ...SCENE_PRESETS]
  })

  const favoriteScenes = computed<ScenePreset[]>(() => {
    return state.value.favoritePresetIds
      .map(id => SCENE_PRESETS.find(p => p.id === id))
      .filter((p): p is ScenePreset => p !== undefined)
  })

  const addCustomScene = (
    scene: Omit<CustomScenePreset, 'id' | 'creator' | 'createdAt' | 'updatedAt'>
  ): CustomScenePreset => {
    const now = Date.now()
    const newScene: CustomScenePreset = {
      ...scene,
      id: generateCustomId(),
      creator: 'user',
      createdAt: now,
      updatedAt: now
    }
    state.value = {
      ...state.value,
      customScenes: [...state.value.customScenes, newScene],
      customOrder: [...state.value.customOrder, newScene.id]
    }
    persist()
    return newScene
  }

  const updateCustomScene = (id: string, patch: Partial<CustomScenePreset>): void => {
    state.value = {
      ...state.value,
      customScenes: state.value.customScenes.map(s =>
        s.id === id ? { ...s, ...patch, updatedAt: Date.now() } : s
      )
    }
    persist()
  }

  const deleteCustomScene = (id: string): void => {
    state.value = {
      ...state.value,
      customScenes: state.value.customScenes.filter(s => s.id !== id),
      customOrder: state.value.customOrder.filter(oid => oid !== id)
    }
    persist()
  }

  const toggleFavorite = (presetId: ScenePresetId): void => {
    const current = state.value.favoritePresetIds
    if (current.includes(presetId)) {
      state.value = {
        ...state.value,
        favoritePresetIds: current.filter(id => id !== presetId)
      }
    } else {
      state.value = {
        ...state.value,
        favoritePresetIds: [...current, presetId]
      }
    }
    persist()
  }

  const isFavorite = (presetId: ScenePresetId): boolean => {
    return state.value.favoritePresetIds.includes(presetId)
  }

  const getSceneById = (id: string): AnyScene | undefined => {
    const custom = state.value.customScenes.find(s => s.id === id)
    if (custom) return custom
    return SCENE_PRESETS.find(p => p.id === id)
  }

  return {
    customScenes,
    favoritePresetIds,
    allScenes,
    favoriteScenes,
    addCustomScene,
    updateCustomScene,
    deleteCustomScene,
    toggleFavorite,
    isFavorite,
    getSceneById,
    isCustomScene
  }
}
