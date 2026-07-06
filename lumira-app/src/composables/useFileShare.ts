/**
 * 文件分享/导入组合式逻辑
 * 处理 .pptpl 文件的导入和导出
 */
import { ref } from 'vue'
import { templateEngine } from '@/services/templateEngine'
import { useTemplatesStore } from '@/stores/templates'
import type { PhotoTemplate, LocalTemplate } from '@/types/template'

export function useFileShare() {
  const templatesStore = useTemplatesStore()
  const isExporting = ref(false)
  const isImporting = ref(false)
  const error = ref<string | null>(null)

  async function exportTemplate(template: PhotoTemplate | LocalTemplate): Promise<string> {
    isExporting.value = true
    error.value = null
    try {
      const json = await templateEngine.serialize(template)
      // 在真实环境中这里会调用系统分享
      return json
    } catch (e) {
      error.value = e instanceof Error ? e.message : '导出失败'
      throw e
    } finally {
      isExporting.value = false
    }
  }

  async function importFromJson(json: string): Promise<string> {
    isImporting.value = true
    error.value = null
    try {
      const id = await templatesStore.importFromJson(json)
      return id
    } catch (e) {
      error.value = e instanceof Error ? e.message : '导入失败'
      throw e
    } finally {
      isImporting.value = false
    }
  }

  async function importFromPath(filePath: string): Promise<string> {
    isImporting.value = true
    error.value = null
    try {
      // 在真实环境中读取文件内容
      // H5/App 环境使用 uni.getFileSystemManager().readFile
      const json = filePath // Mock：直接使用路径作为 JSON
      return importFromJson(json)
    } catch (e) {
      error.value = e instanceof Error ? e.message : '文件读取失败'
      throw e
    } finally {
      isImporting.value = false
    }
  }

  return {
    isExporting,
    isImporting,
    error,
    exportTemplate,
    importFromJson,
    importFromPath,
  }
}
