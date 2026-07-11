/**
 * 模板组合式函数
 *
 * 提供模板加载、查询、自定义模板 CRUD、最近使用管理。
 * 内置模板从 data/templates 注册表加载，自定义模板存储于本地（uni.setStorageSync）。
 */

import { ref } from 'vue'
import {
  BUILTIN_TEMPLATES,
  getTemplateById as getBuiltinById
} from '@/data/templates'
import type { PhotoTemplate } from '@/types/template'

const CUSTOM_TEMPLATES_KEY = 'lumira_custom_templates'
const RECENT_TEMPLATES_KEY = 'lumira_recent_templates'
const DRAFTS_KEY = 'lumira_template_drafts'  // 多草稿列表
const ADJUSTMENT_KEY = 'lumira_template_adjustment'
const MAX_RECENT = 6

/** 草稿数据结构 */
export interface TemplateDraft {
  id: string          // 草稿唯一 ID
  template: PhotoTemplate  // 模板数据
  updatedAt: number    // 最后更新时间戳
  name: string         // 草稿显示名称（取模板名或"未命名草稿"）
}

/** 最近使用的模板列表（跨组件共享） */
const recentTemplates = ref<PhotoTemplate[]>([])

/** 创建空白模板（用于新建模板时初始化） */
function createBlankTemplate(): PhotoTemplate {
  const now = Date.now()
  return {
    meta: {
      id: `custom_${now}`,
      name: '',
      author: '自定义',
      version: '1.0.0',
      category: 'portrait',
      tags: [],
      price: 0,
      cover: '',
      description: '',
      referenceSource: '用户自定义'
    },
    composition: {
      overlayType: 'rule_of_thirds',
      subjectFrame: { x: 0.33, y: 0.33, w: 0.34, h: 0.34 },
      opacity: 0.5,
      aspectRatio: '3:4',
      description: ''
    },
    pose: {
      silhouette: { type: 'builtin', data: 'none' },
      position: { x: 0.5, y: 0.5 },
      scale: 1.0,
      rotation: 0,
      description: ''
    },
    camera: {
      exposureCompensation: 0,
      isoMode: 'auto',
      iso: 200,
      shutterSpeed: '1/125',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      filterPreset: 'none',
      lensSuggestion: 'main'
    },
    sceneGuide: {
      lightDirection: '',
      shootingDistance: '',
      background: '',
      props: [],
      bestTime: '',
      tips: []
    },
    postProcess: {
      cropRatio: '3:4',
      color: { brightness: 0, contrast: 0, saturation: 0, temperature: 0, tint: 0 },
      smoothStrength: 0,
      sharpen: 0,
      vignette: 0,
      grain: 0,
      lut: 'none'
    }
  }
}

export function useTemplate() {
  /**
   * 加载模板（内置 + 自定义）
   * @param id 模板 id
   * @returns 模板对象，未找到返回 null
   */
  function loadTemplate(id: string): PhotoTemplate | null {
    const builtin = getBuiltinById(id)
    if (builtin) return builtin
    const custom = getCustomTemplates().find(t => t.meta.id === id)
    return custom || null
  }

  /** 获取所有模板（内置 + 自定义） */
  function getAllTemplates(): PhotoTemplate[] {
    return [...BUILTIN_TEMPLATES, ...getCustomTemplates()]
  }

  /** 获取所有免费模板（内置免费） */
  function getFreeTemplates(): PhotoTemplate[] {
    return BUILTIN_TEMPLATES.filter(t => t.meta.price === 0)
  }

  /** 获取所有付费模板（内置付费） */
  function getPaidTemplates(): PhotoTemplate[] {
    return BUILTIN_TEMPLATES.filter(t => t.meta.price > 0)
  }

  /** 获取所有自定义模板（从本地存储） */
  function getCustomTemplates(): PhotoTemplate[] {
    const raw = uni.getStorageSync(CUSTOM_TEMPLATES_KEY)
    if (!raw) return []
    try {
      const list = JSON.parse(raw) as PhotoTemplate[]
      return Array.isArray(list) ? list : []
    } catch {
      return []
    }
  }

  /** 获取自定义模板数量 */
  function getCustomTemplateCount(): number {
    return getCustomTemplates().length
  }

  /**
   * 保存自定义模板（新建或更新）
   * @param tpl 模板对象
   */
  function saveCustomTemplate(tpl: PhotoTemplate): void {
    const list = getCustomTemplates()
    const idx = list.findIndex(t => t.meta.id === tpl.meta.id)
    if (idx >= 0) {
      list[idx] = tpl
    } else {
      list.push(tpl)
    }
    uni.setStorageSync(CUSTOM_TEMPLATES_KEY, JSON.stringify(list))
  }

  /**
   * 删除自定义模板
   * @param id 模板 id
   */
  function deleteCustomTemplate(id: string): void {
    const list = getCustomTemplates().filter(t => t.meta.id !== id)
    uni.setStorageSync(CUSTOM_TEMPLATES_KEY, JSON.stringify(list))
  }

  /**
   * 复制自定义模板
   * @param id 源模板 id
   * @returns 复制后的模板对象，未找到返回 null
   */
  function duplicateTemplate(id: string): PhotoTemplate | null {
    const tpl = getCustomTemplates().find(t => t.meta.id === id)
    if (!tpl) return null
    const copy: PhotoTemplate = JSON.parse(JSON.stringify(tpl))
    copy.meta.id = `${tpl.meta.id}_copy_${Date.now()}`
    copy.meta.name = `${tpl.meta.name}（副本）`
    saveCustomTemplate(copy)
    return copy
  }

  /**
   * 添加到最近使用
   * @param id 模板 id
   */
  function pushRecent(id: string): void {
    const tpl = loadTemplate(id)
    if (!tpl) return
    const filtered = recentTemplates.value.filter(t => t.meta.id !== id)
    recentTemplates.value = [tpl, ...filtered].slice(0, MAX_RECENT)
    uni.setStorageSync(
      RECENT_TEMPLATES_KEY,
      JSON.stringify(recentTemplates.value.map(t => t.meta.id))
    )
  }

  /** 从本地存储加载最近使用模板列表 */
  function loadRecent(): void {
    const ids = uni.getStorageSync(RECENT_TEMPLATES_KEY)
    if (!ids || !Array.isArray(ids)) return
    recentTemplates.value = ids
      .map((id: string) => loadTemplate(id))
      .filter((t): t is PhotoTemplate => t !== null)
      .slice(0, MAX_RECENT)
  }

  // ===== 草稿管理（多草稿版本） =====

  /** 读取所有草稿 */
  function getAllDrafts(): TemplateDraft[] {
    const raw = uni.getStorageSync(DRAFTS_KEY)
    if (!raw) return []
    try {
      const arr = JSON.parse(raw) as TemplateDraft[]
      return Array.isArray(arr) ? arr : []
    } catch {
      return []
    }
  }

  /** 写入所有草稿 */
  function writeAllDrafts(drafts: TemplateDraft[]): void {
    uni.setStorageSync(DRAFTS_KEY, JSON.stringify(drafts))
  }

  /**
   * 保存草稿（自动更新或新建）
   * - 若 draftId 存在则更新对应草稿
   * - 若不存在则新建草稿
   * 返回草稿 ID
   */
  function saveDraft(tpl: PhotoTemplate, draftId?: string): string {
    const id = draftId || `draft_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    const drafts = getAllDrafts()
    const idx = drafts.findIndex(d => d.id === id)
    const draft: TemplateDraft = {
      id,
      template: tpl,
      updatedAt: Date.now(),
      name: tpl.meta.name?.trim() || '未命名草稿'
    }
    if (idx >= 0) {
      drafts[idx] = draft
    } else {
      drafts.unshift(draft)
    }
    writeAllDrafts(drafts)
    return id
  }

  /** 加载指定草稿 */
  function loadDraft(draftId: string): PhotoTemplate | null {
    const drafts = getAllDrafts()
    const draft = drafts.find(d => d.id === draftId)
    return draft ? draft.template : null
  }

  /** 删除指定草稿 */
  function deleteDraft(draftId: string): void {
    const drafts = getAllDrafts().filter(d => d.id !== draftId)
    writeAllDrafts(drafts)
  }

  /** 清除所有草稿 */
  function clearAllDrafts(): void {
    uni.removeStorageSync(DRAFTS_KEY)
  }

  /** 是否有草稿 */
  function hasDraft(): boolean {
    return getAllDrafts().length > 0
  }

  /** 获取草稿数量 */
  function getDraftCount(): number {
    return getAllDrafts().length
  }

  // ===== 预览调参同步 =====

  /** 保存预览页调整后的模板（用于同步回编辑器） */
  function saveAdjustment(tpl: PhotoTemplate): void {
    uni.setStorageSync(ADJUSTMENT_KEY, JSON.stringify(tpl))
  }

  /** 加载预览页调整后的模板 */
  function loadAdjustment(): PhotoTemplate | null {
    const raw = uni.getStorageSync(ADJUSTMENT_KEY)
    if (!raw) return null
    try {
      return JSON.parse(raw) as PhotoTemplate
    } catch {
      return null
    }
  }

  /** 清除预览调整数据 */
  function clearAdjustment(): void {
    uni.removeStorageSync(ADJUSTMENT_KEY)
  }

  return {
    recentTemplates,
    loadTemplate,
    getAllTemplates,
    getFreeTemplates,
    getPaidTemplates,
    getCustomTemplates,
    getCustomTemplateCount,
    saveCustomTemplate,
    deleteCustomTemplate,
    duplicateTemplate,
    pushRecent,
    loadRecent,
    createBlankTemplate,
    // 草稿管理
    getAllDrafts,
    saveDraft,
    loadDraft,
    deleteDraft,
    clearAllDrafts,
    hasDraft,
    getDraftCount,
    // 预览调参同步
    saveAdjustment,
    loadAdjustment,
    clearAdjustment
  }
}
