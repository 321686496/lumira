/**
 * 拍摄组合组合式函数
 *
 * 提供拍摄组合（场景 + 模板 + overrides）的 CRUD + 使用记录。
 * 内部调用 useSceneManager.getSceneById 获取场景（useSceneManager 不依赖 useShootKit，无循环依赖）。
 * getKitDetail 接收 templates 数组参数，避免依赖 useTemplate。
 * localStorage 持久化，module-level 单例状态（与 useSceneManager 一致）。
 */

import { computed, ref } from 'vue'
import type { ShootKit, AnyScene, PhotoTemplate } from '@/types/template'
import { useSceneManager } from './useSceneManager'

const STORAGE_KEY = 'lumira_shoot_kits'

interface PersistedState {
  version: number
  kits: ShootKit[]
}

const DEFAULT_STATE: PersistedState = {
  version: 1,
  kits: [],
}

/** 从 localStorage 读取状态 */
function loadState(): PersistedState {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (!raw) return { ...DEFAULT_STATE }
    if (raw && typeof raw === 'object') {
      return {
        version: typeof raw.version === 'number' ? raw.version : 1,
        kits: Array.isArray(raw.kits) ? raw.kits : [],
      }
    }
    return { ...DEFAULT_STATE }
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

/** 生成唯一组合 ID */
function generateKitId(): string {
  return `kit_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

/** module-level 单例状态（跨组件共享） */
const state = ref<PersistedState>(loadState())

/** 持久化写入 */
function persist() {
  saveState(state.value)
}

export function useShootKit() {
  const kits = computed<ShootKit[]>(() => state.value.kits)

  function createKit(data: Omit<ShootKit, 'id' | 'createdAt' | 'updatedAt' | 'useCount'>): string {
    const id = generateKitId()
    const now = Date.now()
    const kit: ShootKit = {
      ...data,
      id,
      createdAt: now,
      updatedAt: now,
      useCount: 0,
    }
    // 最新创建的组合在前
    state.value = {
      ...state.value,
      kits: [kit, ...state.value.kits],
    }
    persist()
    return id
  }

  function updateKit(id: string, data: Partial<ShootKit>): void {
    state.value = {
      ...state.value,
      kits: state.value.kits.map(k =>
        k.id === id ? { ...k, ...data, updatedAt: Date.now() } : k
      ),
    }
    persist()
  }

  function deleteKit(id: string): void {
    state.value = {
      ...state.value,
      kits: state.value.kits.filter(k => k.id !== id),
    }
    persist()
  }

  function getKitDetail(
    id: string,
    templates: PhotoTemplate[]
  ): { kit: ShootKit; scene: AnyScene; template: PhotoTemplate } | null {
    const kit = state.value.kits.find(k => k.id === id)
    if (!kit) return null
    const { getSceneById } = useSceneManager()
    const scene = getSceneById(kit.sceneId)
    const template = templates.find(t => t.meta.id === kit.templateId)
    if (!scene || !template) return null
    return { kit, scene, template }
  }

  function recordUsage(id: string): void {
    state.value = {
      ...state.value,
      kits: state.value.kits.map(k =>
        k.id === id
          ? { ...k, useCount: k.useCount + 1, lastUsedAt: Date.now() }
          : k
      ),
    }
    persist()
  }

  /** 最近使用的组合：按 lastUsedAt（优先）或 createdAt 降序 */
  const recentKits = computed<ShootKit[]>(() => {
    return [...state.value.kits].sort((a, b) => {
      const aTime = a.lastUsedAt || a.createdAt
      const bTime = b.lastUsedAt || b.createdAt
      return bTime - aTime
    })
  })

  return {
    kits,
    createKit,
    updateKit,
    deleteKit,
    getKitDetail,
    recordUsage,
    recentKits,
  }
}
