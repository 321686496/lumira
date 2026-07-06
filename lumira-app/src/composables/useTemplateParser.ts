/**
 * PPTPL 解析器组合式逻辑
 * 专门处理 .pptpl 文件的解析与导入
 */
import { ref } from 'vue'
import { templateEngine } from '@/services/templateEngine'
import type { ResolvedTemplate, ValidationResult } from '@/types/template'

export function useTemplateParser() {
  const parsedTemplate = ref<ResolvedTemplate | null>(null)
  const validation = ref<ValidationResult | null>(null)
  const error = ref<string | null>(null)

  async function parseFile(jsonString: string): Promise<boolean> {
    error.value = null
    try {
      const raw = JSON.parse(jsonString)
      validation.value = templateEngine.validate(raw)
      if (!validation.value.valid) {
        return false
      }
      parsedTemplate.value = await templateEngine.parse(jsonString)
      return true
    } catch (e) {
      if (e instanceof SyntaxError) {
        error.value = '模板文件无效：JSON 解析失败'
      } else {
        error.value = e instanceof Error ? e.message : '模板解析失败'
      }
      return false
    }
  }

  function validateRaw(raw: unknown): ValidationResult {
    const result = templateEngine.validate(raw as Record<string, unknown>)
    validation.value = result
    return result
  }

  function checkVersion(version: string) {
    return templateEngine.checkCompatibility(version)
  }

  function reset(): void {
    parsedTemplate.value = null
    validation.value = null
    error.value = null
  }

  return {
    parsedTemplate,
    validation,
    error,
    parseFile,
    validateRaw,
    checkVersion,
    reset,
  }
}
