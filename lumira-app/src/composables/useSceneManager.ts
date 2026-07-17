/**
 * 场景管理组合式函数
 *
 * 提供自定义场景 CRUD、预设收藏、照片统计、成就、排行榜，localStorage 持久化。
 * 使用 module-level ref 实现跨组件共享的单例状态。
 */

import { computed, ref } from 'vue'
import { SCENE_PRESETS, SCENE_CATEGORIES } from '@/data/scenePresets'
import { SCENE_LEVELS } from '@/types/template'
import type {
  ScenePreset,
  ScenePresetId,
  CustomScenePreset,
  CustomSceneId,
  AnyScene,
  SceneCategory,
  SceneCategoryGroup,
  LocalPhoto,
  SceneAchievement,
  LutPreset
} from '@/types/template'

const STORAGE_KEY = 'lumira_scene_manager'

interface PersistedState {
  version: number
  customScenes: CustomScenePreset[]
  favoritePresetIds: string[]
  photos: LocalPhoto[]
}

const DEFAULT_STATE: PersistedState = {
  version: 2,
  customScenes: [],
  favoritePresetIds: [],
  photos: []
}

/**
 * v1 → v2 迁移：删除 customScenes 中已废弃的 cameraSuggestion/postSuggestion，
 * 补默认 filter/vibe/description/exampleImages/tips/whereToShoot/bestTime/category/style/recommendedTagIds/tagIds。
 */
function migrateState(raw: any): PersistedState {
  if (raw && raw.version === 1) {
    const migratedCustomScenes = (Array.isArray(raw.customScenes) ? raw.customScenes : []).map((s: any) => ({
      ...s,
      // 删除旧字段（设置 undefined，JSON 序列化时会被剔除）
      cameraSuggestion: undefined,
      postSuggestion: undefined,
      // 补新字段默认值
      filter: s.filter || { lut: 'none' as LutPreset, reason: '自定义场景滤镜' },
      vibe: s.vibe || s.description || '自定义场景',
      description: s.description || '',
      exampleImages: s.exampleImages || [],
      tips: s.tips || s.sceneGuide?.tips || [],
      whereToShoot: s.whereToShoot || '',
      bestTime: s.bestTime || s.sceneGuide?.bestTime || '',
      category: s.category || ('indoor' as SceneCategory),
      style: s.style || 'cafe',
      recommendedTagIds: s.recommendedTagIds || [],
      tagIds: s.tagIds || [],
    }))
    return {
      version: 2,
      customScenes: migratedCustomScenes,
      favoritePresetIds: Array.isArray(raw.favoritePresetIds) ? raw.favoritePresetIds : [],
      photos: [],
    }
  }
  if (raw && raw.version === 2) {
    return {
      version: 2,
      customScenes: Array.isArray(raw.customScenes) ? raw.customScenes : [],
      favoritePresetIds: Array.isArray(raw.favoritePresetIds) ? raw.favoritePresetIds : [],
      photos: Array.isArray(raw.photos) ? raw.photos : [],
    }
  }
  return { ...DEFAULT_STATE }
}

/** 从 localStorage 读取状态 */
function loadState(): PersistedState {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (!raw) return { ...DEFAULT_STATE }
    return migrateState(raw)
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
  const photos = computed(() => state.value.photos)

  const allScenes = computed<AnyScene[]>(() => {
    return [...state.value.customScenes, ...SCENE_PRESETS]
  })

  const favoriteScenes = computed<ScenePreset[]>(() => {
    return state.value.favoritePresetIds
      .map(id => SCENE_PRESETS.find(p => p.id === id))
      .filter((p): p is ScenePreset => p !== undefined)
  })

  // ── 分类 computed ──

  const scenesByCategory = computed<Record<SceneCategory, AnyScene[]>>(() => {
    const result: Record<SceneCategory, AnyScene[]> = {
      light: [], outdoor: [], indoor: [], mood: []
    }
    for (const scene of allScenes.value) {
      result[scene.category].push(scene)
    }
    return result
  })

  const scenesByStyle = computed<Record<string, AnyScene[]>>(() => {
    const result: Record<string, AnyScene[]> = {}
    for (const scene of allScenes.value) {
      if (!result[scene.style]) result[scene.style] = []
      result[scene.style].push(scene)
    }
    return result
  })

  const sceneCategoryTree = computed<SceneCategoryGroup[]>(() => {
    return SCENE_CATEGORIES.map(group => ({
      ...group,
      styles: group.styles.map(style => ({ ...style })),
    }))
  })

  // ── 照片管理 ──

  function addPhoto(data: Omit<LocalPhoto, 'id' | 'createdAt'>): string {
    const id = `photo_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const photo: LocalPhoto = { ...data, id, createdAt: Date.now() }
    // 最新照片在前（按 createdAt 降序）
    state.value = {
      ...state.value,
      photos: [photo, ...state.value.photos],
    }
    persist()
    return id
  }

  function deletePhoto(id: string): void {
    state.value = {
      ...state.value,
      photos: state.value.photos.filter(p => p.id !== id),
    }
    persist()
  }

  function getPhotoCountByScene(sceneId: string): number {
    return state.value.photos.filter(p => p.sceneId === sceneId).length
  }

  function getPhotosByScene(sceneId: string): LocalPhoto[] {
    return state.value.photos.filter(p => p.sceneId === sceneId)
  }

  function updatePhotoScene(photoId: string, sceneId: ScenePresetId | CustomSceneId | null): void {
    const photo = state.value.photos.find(p => p.id === photoId)
    if (photo) {
      photo.sceneId = sceneId
      persist()
    }
  }

  function getPhotosGroupedByScene(): Record<string, LocalPhoto[]> {
    const groups: Record<string, LocalPhoto[]> = {}
    state.value.photos.forEach(p => {
      const key = p.sceneId || 'uncategorized'
      if (!groups[key]) groups[key] = []
      groups[key].push(p)
    })
    return groups
  }

  // ── 成就系统 ──

  function getSceneAchievement(sceneId: string): SceneAchievement {
    const count = getPhotoCountByScene(sceneId)
    let currentLevel = 0
    for (const lv of SCENE_LEVELS) {
      if (count >= lv.threshold) currentLevel = lv.level
    }
    if (currentLevel === 0) {
      return { sceneId, level: 0, levelName: '未开始', photoCount: count, nextLevelCount: 1 }
    }
    const currentLevelDef = SCENE_LEVELS.find(l => l.level === currentLevel)!
    const nextLevelDef = SCENE_LEVELS.find(l => l.level === currentLevel + 1)
    return {
      sceneId,
      level: currentLevel,
      levelName: currentLevelDef.name,
      photoCount: count,
      nextLevelCount: nextLevelDef ? nextLevelDef.threshold : currentLevelDef.threshold,
    }
  }

  const sceneAchievements = computed<SceneAchievement[]>(() => {
    return allScenes.value.map(s => getSceneAchievement(s.id))
  })

  // ── 排行榜 ──

  const allTimeRanking = computed<{ scene: AnyScene; photoCount: number; rank: number }[]>(() => {
    return allScenes.value
      .map(scene => ({ scene, photoCount: getPhotoCountByScene(scene.id) }))
      .filter(item => item.photoCount > 0)
      .sort((a, b) => b.photoCount - a.photoCount)
      .map((item, idx) => ({ ...item, rank: idx + 1 }))
  })

  const weeklyRanking = computed<{ scene: AnyScene; photoCount: number; rank: number }[]>(() => {
    const oneWeekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000
    return allScenes.value
      .map(scene => ({
        scene,
        photoCount: state.value.photos.filter(p => p.sceneId === scene.id && p.createdAt >= oneWeekAgo).length,
      }))
      .filter(item => item.photoCount > 0)
      .sort((a, b) => b.photoCount - a.photoCount)
      .map((item, idx) => ({ ...item, rank: idx + 1 }))
  })

  // ── 自定义场景 CRUD ──

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
      customScenes: [...state.value.customScenes, newScene]
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
      customScenes: state.value.customScenes.filter(s => s.id !== id)
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

  /** 从 localStorage 重新加载状态（用于 onShow 同步跨页修改） */
  const reloadFromStorage = (): void => {
    state.value = loadState()
  }

  return {
    // 原 API
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
    isCustomScene,
    reloadFromStorage,
    // 新增：分类
    scenesByCategory,
    scenesByStyle,
    sceneCategoryTree,
    // 新增：照片管理
    photos,
    addPhoto,
    deletePhoto,
    getPhotoCountByScene,
    getPhotosByScene,
    updatePhotoScene,
    getPhotosGroupedByScene,
    // 新增：成就
    getSceneAchievement,
    sceneAchievements,
    // 新增：排行榜
    weeklyRanking,
    allTimeRanking,
  }
}
