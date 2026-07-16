/**
 * 标签管理组合式函数
 *
 * 提供用户自定义标签 CRUD + 场景/模板多标签筛选（OR 逻辑）。
 * 内部调用 useSceneManager 获取场景列表（useSceneManager 不依赖 useTagManager，无循环依赖）。
 * 模板筛选接收 templates 数组参数，避免依赖 useTemplate。
 * localStorage 持久化，module-level 单例状态（与 useSceneManager 一致）。
 */

import { computed, ref } from 'vue'
import type { UserTag, AnyScene, PhotoTemplate } from '@/types/template'
import { useSceneManager } from './useSceneManager'

const STORAGE_KEY = 'lumira_user_tags'

interface PersistedState {
  version: number
  tags: UserTag[]
}

const DEFAULT_STATE: PersistedState = {
  version: 1,
  tags: [],
}

/** 从 localStorage 读取状态 */
function loadState(): PersistedState {
  try {
    const raw = uni.getStorageSync(STORAGE_KEY)
    if (!raw) return { ...DEFAULT_STATE }
    if (raw && typeof raw === 'object') {
      return {
        version: typeof raw.version === 'number' ? raw.version : 1,
        tags: Array.isArray(raw.tags) ? raw.tags : [],
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

/** 生成唯一标签 ID */
function generateTagId(): string {
  return `tag_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

/** module-level 单例状态（跨组件共享） */
const state = ref<PersistedState>(loadState())

/** 持久化写入 */
function persist() {
  saveState(state.value)
}

export function useTagManager() {
  const tags = computed<UserTag[]>(() => state.value.tags)

  function getTagsByType(type: UserTag['type']): UserTag[] {
    if (type === 'both') return state.value.tags
    return state.value.tags.filter(t => t.type === type || t.type === 'both')
  }

  function createTag(name: string, type: UserTag['type']): string {
    const id = generateTagId()
    const tag: UserTag = { id, name, type, createdAt: Date.now() }
    state.value = {
      ...state.value,
      tags: [...state.value.tags, tag],
    }
    persist()
    return id
  }

  function updateTag(id: string, data: Partial<UserTag>): void {
    state.value = {
      ...state.value,
      tags: state.value.tags.map(t => (t.id === id ? { ...t, ...data } : t)),
    }
    persist()
  }

  function deleteTag(id: string): void {
    state.value = {
      ...state.value,
      tags: state.value.tags.filter(t => t.id !== id),
    }
    persist()
  }

  function getScenesByTag(tagId: string): AnyScene[] {
    const { allScenes } = useSceneManager()
    return allScenes.value.filter(s => {
      const ids = 'tagIds' in s ? s.tagIds : s.recommendedTagIds
      return ids.includes(tagId)
    })
  }

  function getTemplatesByTag(tagId: string, templates: PhotoTemplate[]): PhotoTemplate[] {
    return templates.filter(t => t.meta.tagIds.includes(tagId))
  }

  function filterScenesByTags(tagIds: string[]): AnyScene[] {
    const { allScenes } = useSceneManager()
    if (tagIds.length === 0) return allScenes.value
    return allScenes.value.filter(s => {
      const ids = 'tagIds' in s ? s.tagIds : s.recommendedTagIds
      return tagIds.some(id => ids.includes(id))
    })
  }

  function filterTemplatesByTags(tagIds: string[], templates: PhotoTemplate[]): PhotoTemplate[] {
    if (tagIds.length === 0) return templates
    return templates.filter(t => tagIds.some(id => t.meta.tagIds.includes(id)))
  }

  return {
    tags,
    getTagsByType,
    createTag,
    updateTag,
    deleteTag,
    getScenesByTag,
    getTemplatesByTag,
    filterScenesByTags,
    filterTemplatesByTags,
  }
}
