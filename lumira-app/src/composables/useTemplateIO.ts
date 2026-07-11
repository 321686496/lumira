/**
 * 模板导入导出组合式函数
 *
 * 提供模板的 .pptpl JSON 文件导入导出能力。
 * - H5 端使用浏览器 File API
 * - 非 H5 端暂不支持，后续适配 App 原生
 *
 * 导出的 .pptpl 文件是完全自包含的 JSON：
 * - builtin 剪影：仅含 key 字符串
 * - image 剪影：含完整 base64 data URL
 * - svg 剪影：含完整 SVG 字符串
 */

import { useTemplate } from './useTemplate'
import { BUILTIN_SILHOUETTES } from '@/data/silhouettes'
import type { PhotoTemplate } from '@/types/template'

export function useTemplateIO() {
  const { saveCustomTemplate, getCustomTemplates } = useTemplate()

  /**
   * 导出模板为 .pptpl JSON 文件
   * @param tpl 模板对象
   */
  async function exportTemplate(tpl: PhotoTemplate): Promise<void> {
    const json = JSON.stringify(tpl, null, 2)

    // #ifdef H5
    const blob = new Blob([json], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${tpl.meta.id}.pptpl`
    a.click()
    URL.revokeObjectURL(url)
    uni.showToast({ title: '已导出 .pptpl 文件', icon: 'none' })
    // #endif

    // #ifndef H5
    uni.showToast({ title: '当前环境暂不支持导出', icon: 'none' })
    // #endif
  }

  /**
   * 导入 .pptpl 文件并解析
   * @returns 导入成功的模板对象，失败返回 null
   */
  async function importTemplate(): Promise<PhotoTemplate | null> {
    return new Promise((resolve) => {
      // #ifdef H5
      const input = document.createElement('input')
      input.type = 'file'
      input.accept = '.pptpl,.json'
      input.onchange = async (e: Event) => {
        const target = e.target as HTMLInputElement
        const file = target.files?.[0]
        if (!file) {
          resolve(null)
          return
        }
        try {
          const text = await file.text()
          const tpl = parseTemplate(text)
          // 若 ID 与已有模板冲突，自动追加后缀
          const existing = getCustomTemplates()
          const allBuiltinIds = new Set<string>()
          // 内置模板 id 也不可冲突
          BUILTIN_SILHOUETTES // 触发导入（避免 tree-shaking 移除）
          if (existing.some(t => t.meta.id === tpl.meta.id) || allBuiltinIds.has(tpl.meta.id)) {
            tpl.meta.id = `${tpl.meta.id}_imported_${Date.now()}`
            tpl.meta.name = `${tpl.meta.name}（导入）`
          }
          saveCustomTemplate(tpl)
          uni.showToast({ title: '模板导入成功', icon: 'success' })
          resolve(tpl)
        } catch (err) {
          uni.showToast({
            title: err instanceof Error ? err.message : '模板文件格式错误',
            icon: 'none'
          })
          resolve(null)
        }
      }
      input.click()
      // #endif

      // #ifndef H5
      uni.showToast({ title: '当前环境暂不支持导入', icon: 'none' })
      resolve(null)
      // #endif
    })
  }

  /**
   * 解析模板 JSON（含校验与降级）
   * @param json JSON 字符串
   * @returns 解析后的 PhotoTemplate
   * @throws 字段缺失或格式错误时抛出异常
   */
  function parseTemplate(json: string): PhotoTemplate {
    const tpl = JSON.parse(json) as PhotoTemplate

    // 校验必要字段
    if (!tpl.meta?.id || !tpl.meta?.name) {
      throw new Error('模板缺少必要字段（meta.id 或 meta.name）')
    }
    if (!tpl.composition || !tpl.camera || !tpl.postProcess) {
      throw new Error('模板缺少核心模块（composition/camera/postProcess）')
    }

    // 补全可选模块
    if (!tpl.pose) {
      tpl.pose = {
        silhouette: { type: 'builtin', data: 'none' },
        position: { x: 0.5, y: 0.5 },
        scale: 1.0,
        rotation: 0,
        description: ''
      }
    }
    if (!tpl.sceneGuide) {
      tpl.sceneGuide = {
        lightDirection: '',
        shootingDistance: '',
        background: '',
        props: [],
        bestTime: '',
        tips: []
      }
    }

    // 校验内置剪影是否存在，不存在则降级为 none
    if (tpl.pose.silhouette?.type === 'builtin') {
      if (!BUILTIN_SILHOUETTES[tpl.pose.silhouette.data]) {
        tpl.pose.silhouette.data = 'none'
      }
    }

    return tpl
  }

  return {
    exportTemplate,
    importTemplate,
    parseTemplate
  }
}
