/**
 * 模板库状态仓库
 * 对应前端文档 5.4 templates store
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { LocalTemplate, PhotoTemplate, ResolvedTemplate } from '@/types/template'
import { storageService } from '@/services/storage'
import { templateEngine, type TemplateEngine } from '@/services/templateEngine'
import { generateId } from '@/utils/math'

export const useTemplatesStore = defineStore('templates', () => {
  // === State ===
  const builtinTemplates = ref<LocalTemplate[]>([])
  const importedTemplates = ref<LocalTemplate[]>([])
  const createdTemplates = ref<LocalTemplate[]>([])
  const currentCategory = ref('全部')
  const searchQuery = ref('')
  const loading = ref(false)
  const currentTemplateId = ref<string | null>(null)

  // === Getters ===
  const allTemplates = computed(() => [
    ...builtinTemplates.value,
    ...importedTemplates.value,
    ...createdTemplates.value,
  ])
  const categories = computed(() => {
    const cats = new Set<string>()
    cats.add('全部')
    allTemplates.value.forEach((t) => {
      // 从 pptplJson 提取分类
      try {
        const parsed = JSON.parse(t.pptplJson) as { meta?: { category?: string } }
        if (parsed.meta?.category) cats.add(parsed.meta.category)
      } catch {
        // ignore
      }
    })
    return Array.from(cats)
  })
  const filteredTemplates = computed(() => {
    let result = allTemplates.value
    if (currentCategory.value !== '全部') {
      result = result.filter((t) => {
        try {
          const parsed = JSON.parse(t.pptplJson) as { meta?: { category?: string } }
          return parsed.meta?.category === currentCategory.value
        } catch {
          return false
        }
      })
    }
    if (searchQuery.value.trim()) {
      const q = searchQuery.value.toLowerCase()
      result = result.filter((t) => t.name.toLowerCase().includes(q))
    }
    return result
  })
  const currentTemplate = computed(() =>
    allTemplates.value.find((t) => t.id === currentTemplateId.value) ?? null,
  )
  const templateCount = computed(() => allTemplates.value.length)

  // === Actions ===
  async function loadTemplates(): Promise<void> {
    loading.value = true
    try {
      builtinTemplates.value = await storageService.getTemplatesBySource('builtin')
      importedTemplates.value = await storageService.getTemplatesBySource('imported')
      createdTemplates.value = await storageService.getTemplatesBySource('created')
    } finally {
      loading.value = false
    }
  }

  function setCategory(category: string): void {
    currentCategory.value = category
  }

  function setSearchQuery(query: string): void {
    searchQuery.value = query
  }

  function setCurrentTemplate(id: string | null): void {
    currentTemplateId.value = id
  }

  async function addTemplate(
    template: PhotoTemplate,
    source: 'builtin' | 'imported' | 'created',
  ): Promise<string> {
    const id = template.meta.id || generateId('tmpl')
    const pptplJson = await templateEngine.serialize(template)
    const localTemplate: LocalTemplate = {
      id,
      name: template.meta.name,
      source,
      pptplJson,
      coverPath: template.meta.cover,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    }
    await storageService.insertTemplate(localTemplate)
    switch (source) {
      case 'builtin':
        builtinTemplates.value.push(localTemplate)
        break
      case 'imported':
        importedTemplates.value.push(localTemplate)
        break
      case 'created':
        createdTemplates.value.push(localTemplate)
        break
    }
    return id
  }

  async function updateTemplate(template: LocalTemplate): Promise<void> {
    await storageService.updateTemplate(template)
    const updateInList = (list: LocalTemplate[]) => {
      const index = list.findIndex((t) => t.id === template.id)
      if (index >= 0) list[index] = template
    }
    updateInList(builtinTemplates.value)
    updateInList(importedTemplates.value)
    updateInList(createdTemplates.value)
  }

  async function deleteTemplate(id: string): Promise<void> {
    await storageService.deleteTemplate(id)
    builtinTemplates.value = builtinTemplates.value.filter((t) => t.id !== id)
    importedTemplates.value = importedTemplates.value.filter((t) => t.id !== id)
    createdTemplates.value = createdTemplates.value.filter((t) => t.id !== id)
    if (currentTemplateId.value === id) {
      currentTemplateId.value = null
    }
  }

  async function importFromJson(json: string): Promise<string> {
    const resolved: ResolvedTemplate = await templateEngine.parse(json)
    return addTemplate(resolved, 'imported')
  }

  async function getResolvedTemplate(id: string): Promise<ResolvedTemplate | null> {
    const local = allTemplates.value.find((t) => t.id === id)
    if (!local) return null
    return templateEngine.parse(local.pptplJson)
  }

  function resetState(): void {
    builtinTemplates.value = []
    importedTemplates.value = []
    createdTemplates.value = []
    currentCategory.value = '全部'
    searchQuery.value = ''
    loading.value = false
    currentTemplateId.value = null
  }

  return {
    // state
    builtinTemplates,
    importedTemplates,
    createdTemplates,
    currentCategory,
    searchQuery,
    loading,
    currentTemplateId,
    // getters
    allTemplates,
    categories,
    filteredTemplates,
    currentTemplate,
    templateCount,
    // actions
    loadTemplates,
    setCategory,
    setSearchQuery,
    setCurrentTemplate,
    addTemplate,
    updateTemplate,
    deleteTemplate,
    importFromJson,
    getResolvedTemplate,
    resetState,
  }
})

export type { TemplateEngine }
