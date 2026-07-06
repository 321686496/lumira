/**
 * 模板引擎服务
 * 对应前端文档 7.3 TemplateEngine
 * 负责 .pptpl 的解析、序列化、验证、兼容性检查、迁移
 */
import type {
  RawTemplate,
  ResolvedTemplate,
  PhotoTemplate,
  LocalTemplate,
  ValidationResult,
  ValidationError,
  CompatibilityResult,
  TemplateSummary,
} from '@/types/template'

/** 当前引擎支持的模板版本 */
const CURRENT_VERSION = '1.0.0'

/** 版本号比较：返回 -1/0/1 */
function compareVersion(a: string, b: string): number {
  const partsA = a.split('.').map(Number)
  const partsB = b.split('.').map(Number)
  for (let i = 0; i < Math.max(partsA.length, partsB.length); i++) {
    const va = partsA[i] || 0
    const vb = partsB[i] || 0
    if (va < vb) return -1
    if (va > vb) return 1
  }
  return 0
}

/** 模板引擎接口 */
export interface TemplateEngine {
  parse(json: string): Promise<ResolvedTemplate>
  serialize(template: PhotoTemplate | LocalTemplate): Promise<string>
  validate(template: RawTemplate): ValidationResult
  checkCompatibility(version: string): CompatibilityResult
  migrate(template: RawTemplate): Promise<ResolvedTemplate>
  toSummary(template: PhotoTemplate): TemplateSummary
}

export class TemplateEngineImpl implements TemplateEngine {
  /**
   * 解析 .pptpl JSON 字符串为结构化模板
   * @throws SyntaxError JSON 格式错误时
   * @throws Error 必填字段缺失时
   */
  async parse(json: string): Promise<ResolvedTemplate> {
    let raw: RawTemplate
    try {
      raw = JSON.parse(json)
    } catch (e) {
      throw new SyntaxError('模板文件无效：JSON 解析失败')
    }

    const validation = this.validate(raw)
    if (!validation.valid) {
      const msg = validation.errors.map((e) => e.message).join('; ')
      throw new Error(`模板验证失败：${msg}`)
    }

    const compat = this.checkCompatibility((raw.meta as { version: string }).version)
    if (!compat.compatible) {
      throw new Error(`模板版本不兼容：${compat.message}`)
    }

    // 如果是旧版本，执行迁移
    const resolved = compareVersion(
      (raw.meta as { version: string }).version,
      CURRENT_VERSION,
    ) < 0
      ? await this.migrate(raw)
      : (raw as unknown as ResolvedTemplate)

    resolved.resolvedAt = Date.now()
    resolved.resolvedFrom = json
    return resolved
  }

  /** 序列化模板为 .pptpl JSON */
  async serialize(template: PhotoTemplate | LocalTemplate): Promise<string> {
    // 如果是 LocalTemplate（含 pptplJson），直接返回其 JSON
    if ('pptplJson' in template) {
      return template.pptplJson
    }
    // 否则序列化 PhotoTemplate
    const { resolvedAt, resolvedFrom, ...pure } = template as ResolvedTemplate
    void resolvedAt
    void resolvedFrom
    return JSON.stringify(pure, null, 2)
  }

  /** 验证模板完整性 */
  validate(template: RawTemplate): ValidationResult {
    const errors: ValidationError[] = []

    // meta 必须存在
    if (!template.meta || typeof template.meta !== 'object') {
      errors.push({ field: 'meta', message: '缺少 meta 字段' })
    } else {
      const meta = template.meta as Record<string, unknown>
      if (!meta.id || typeof meta.id !== 'string') {
        errors.push({ field: 'meta.id', message: '缺少 meta.id' })
      }
      if (!meta.name || typeof meta.name !== 'string') {
        errors.push({ field: 'meta.name', message: '缺少 meta.name' })
      }
      if (!meta.version || typeof meta.version !== 'string') {
        errors.push({ field: 'meta.version', message: '缺少 meta.version' })
      }
    }

    // composition 必须存在
    if (!template.composition || typeof template.composition !== 'object') {
      errors.push({ field: 'composition', message: '缺少 composition 字段' })
    }

    // camera 必须存在
    if (!template.camera || typeof template.camera !== 'object') {
      errors.push({ field: 'camera', message: '缺少 camera 字段' })
    }

    // postProcess 必须存在
    if (!template.postProcess || typeof template.postProcess !== 'object') {
      errors.push({ field: 'postProcess', message: '缺少 postProcess 字段' })
    }

    return { valid: errors.length === 0, errors }
  }

  /** 兼容性检查 */
  checkCompatibility(version: string): CompatibilityResult {
    // 当前引擎只支持 1.x.x 版本
    const major = version.split('.')[0]
    const currentMajor = CURRENT_VERSION.split('.')[0]

    if (major === currentMajor) {
      return {
        compatible: true,
        currentVersion: CURRENT_VERSION,
        templateVersion: version,
        message: '兼容',
      }
    }

    if (compareVersion(version, CURRENT_VERSION) < 0) {
      return {
        compatible: true,
        currentVersion: CURRENT_VERSION,
        templateVersion: version,
        message: '旧版本模板，需迁移',
      }
    }

    return {
      compatible: false,
      currentVersion: CURRENT_VERSION,
      templateVersion: version,
      message: `模板版本 ${version} 高于引擎支持版本 ${CURRENT_VERSION}`,
    }
  }

  /** 迁移旧版本模板 */
  async migrate(template: RawTemplate): Promise<ResolvedTemplate> {
    const meta = { ...((template.meta as object) || {}) } as Record<string, unknown>
    // 迁移版本号到当前版本
    meta.version = CURRENT_VERSION

    const migrated = {
      ...template,
      meta,
    } as unknown as ResolvedTemplate

    return migrated
  }

  /** 生成模板摘要 */
  toSummary(template: PhotoTemplate): TemplateSummary {
    return {
      id: template.meta.id,
      name: template.meta.name,
      category: template.meta.category,
      cover: template.meta.cover,
      tags: template.meta.tags,
      hasComposition: !!template.composition,
      hasPose: !!template.pose,
      hasCameraParams: !!template.camera,
      hasPostProcess: !!template.postProcess,
    }
  }
}

/** 单例实例 */
export const templateEngine = new TemplateEngineImpl()
