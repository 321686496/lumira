/**
 * 模板引擎组合式逻辑
 */
import { ref } from 'vue'
import { templateEngine, type TemplateEngine } from '@/services/templateEngine'
import type { ResolvedTemplate, PhotoTemplate, RawTemplate, ValidationResult } from '@/types/template'
import { useTemplatesStore } from '@/stores/templates'
import { useCaptureStore } from '@/stores/capture'

export function useTemplateEngine(engine: TemplateEngine = templateEngine) {
  const templatesStore = useTemplatesStore()
  const captureStore = useCaptureStore()

  const currentTemplate = ref<ResolvedTemplate | null>(null)
  const parseError = ref<string | null>(null)

  async function loadTemplate(templateId: string): Promise<ResolvedTemplate> {
    const resolved = await templatesStore.getResolvedTemplate(templateId)
    if (!resolved) {
      throw new Error(`模板 ${templateId} 不存在`)
    }
    currentTemplate.value = resolved
    captureStore.setActiveTemplate(templateId)
    return resolved
  }

  async function parse(json: string): Promise<ResolvedTemplate> {
    parseError.value = null
    try {
      const resolved = await engine.parse(json)
      currentTemplate.value = resolved
      return resolved
    } catch (e) {
      parseError.value = e instanceof Error ? e.message : '模板解析失败'
      throw e
    }
  }

  async function serialize(template: PhotoTemplate): Promise<string> {
    return engine.serialize(template)
  }

  function validate(template: RawTemplate): ValidationResult {
    return engine.validate(template)
  }

  function checkCompatibility(version: string) {
    return engine.checkCompatibility(version)
  }

  async function migrate(template: RawTemplate): Promise<ResolvedTemplate> {
    return engine.migrate(template)
  }

  function clearCurrent(): void {
    currentTemplate.value = null
    captureStore.setActiveTemplate(null)
  }

  return {
    currentTemplate,
    parseError,
    loadTemplate,
    parse,
    serialize,
    validate,
    checkCompatibility,
    migrate,
    clearCurrent,
  }
}
