/**
 * 模板引擎服务测试
 * 对应测试文档：
 * - LM-TPL-DATA-020: parse 往返一致
 * - LM-TPL-DATA-021: validate 缺字段
 * - LM-TPL-DATA-022: 兼容性检查
 * - LM-TPL-ERR-017: 导入损坏文件
 * - LM-TPL-DATA-018: 旧版本迁移
 * - LM-TPL-DATA-014: 保存模板（serialize）
 * - LM-TPL-DATA-016: 导入有效模板
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { TemplateEngineImpl } from '@/services/templateEngine'
import {
  VALID_TEMPLATE_JSON,
  TEMPLATE_MISSING_META,
  TEMPLATE_MISSING_ID,
  TEMPLATE_OLD_VERSION,
  TEMPLATE_FUTURE_VERSION,
  INVALID_JSON,
  TEMPLATE_NO_POSTPROCESS,
} from './fixtures/templates'
import type { RawTemplate } from '@/types/template'

describe('TemplateEngine', () => {
  let engine: TemplateEngineImpl

  beforeEach(() => {
    engine = new TemplateEngineImpl()
  })

  // === LM-TPL-DATA-020: parse 往返一致 ===
  describe('parse & serialize 往返一致性 (LM-TPL-DATA-020)', () => {
    it('应成功解析合法模板 JSON', async () => {
      const resolved = await engine.parse(VALID_TEMPLATE_JSON)
      expect(resolved.meta.id).toBe('tmpl_test_001')
      expect(resolved.meta.name).toBe('日落逆光剪影')
      expect(resolved.meta.version).toBe('1.0.0')
      expect(resolved.composition.overlayType).toBe('rule_of_thirds')
      expect(resolved.camera.iso).toBe(100)
      expect(resolved.postProcess.lut).toBe('warm_sunset.cube')
      expect(resolved.resolvedAt).toBeGreaterThan(0)
    })

    it('serialize 后再 parse 应数据无损', async () => {
      const resolved = await engine.parse(VALID_TEMPLATE_JSON)
      const serialized = await engine.serialize(resolved)
      const reparsed = await engine.parse(serialized)

      expect(reparsed.meta.id).toBe(resolved.meta.id)
      expect(reparsed.meta.name).toBe(resolved.meta.name)
      expect(reparsed.meta.version).toBe(resolved.meta.version)
      expect(reparsed.composition.overlayType).toBe(resolved.composition.overlayType)
      expect(reparsed.camera.iso).toBe(resolved.camera.iso)
      expect(reparsed.postProcess.lut).toBe(resolved.postProcess.lut)
    })
  })

  // === LM-TPL-ERR-017: 导入损坏文件 ===
  describe('损坏文件处理 (LM-TPL-ERR-017)', () => {
    it('无效 JSON 应抛出 SyntaxError', async () => {
      await expect(engine.parse(INVALID_JSON)).rejects.toThrow(SyntaxError)
    })

    it('验证失败应抛出 Error', async () => {
      await expect(engine.parse(TEMPLATE_MISSING_META)).rejects.toThrow('模板验证失败')
    })
  })

  // === LM-TPL-DATA-021: validate 缺字段 ===
  describe('validate 验证完整性 (LM-TPL-DATA-021)', () => {
    it('缺少 meta 应返回验证失败', () => {
      const raw: RawTemplate = { composition: {}, camera: {}, postProcess: {} }
      const result = engine.validate(raw)
      expect(result.valid).toBe(false)
      expect(result.errors.some((e) => e.field === 'meta')).toBe(true)
    })

    it('缺少 meta.id 应返回验证失败', () => {
      const raw: RawTemplate = JSON.parse(TEMPLATE_MISSING_ID)
      const result = engine.validate(raw)
      expect(result.valid).toBe(false)
      expect(result.errors.some((e) => e.field === 'meta.id')).toBe(true)
    })

    it('缺少 postProcess 应返回验证失败', () => {
      const raw: RawTemplate = JSON.parse(TEMPLATE_NO_POSTPROCESS)
      const result = engine.validate(raw)
      expect(result.valid).toBe(false)
      expect(result.errors.some((e) => e.field === 'postProcess')).toBe(true)
    })

    it('完整模板应返回验证通过', () => {
      const raw: RawTemplate = JSON.parse(VALID_TEMPLATE_JSON)
      const result = engine.validate(raw)
      expect(result.valid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })
  })

  // === LM-TPL-DATA-022: 兼容性检查 ===
  describe('checkCompatibility 兼容性检查 (LM-TPL-DATA-022)', () => {
    it('当前版本应兼容', () => {
      const result = engine.checkCompatibility('1.0.0')
      expect(result.compatible).toBe(true)
    })

    it('未来版本应不兼容', () => {
      const result = engine.checkCompatibility('2.0.0')
      expect(result.compatible).toBe(false)
      expect(result.message).toContain('2.0.0')
    })

    it('旧版本应兼容但需迁移', () => {
      const result = engine.checkCompatibility('0.9.0')
      expect(result.compatible).toBe(true)
      expect(result.message).toContain('迁移')
    })
  })

  // === LM-TPL-DATA-018: 旧版本迁移 ===
  describe('migrate 旧版本迁移 (LM-TPL-DATA-018)', () => {
    it('应将旧版本号升级到当前版本', async () => {
      const raw: RawTemplate = JSON.parse(TEMPLATE_OLD_VERSION)
      const compat = engine.checkCompatibility((raw.meta as { version: string }).version)
      expect(compat.compatible).toBe(true)

      const migrated = await engine.migrate(raw)
      expect(migrated.meta.version).toBe('1.0.0')
    })

    it('parse 旧版本模板应自动迁移', async () => {
      const resolved = await engine.parse(TEMPLATE_OLD_VERSION)
      expect(resolved.meta.version).toBe('1.0.0')
    })

    it('parse 未来版本应抛出不兼容错误', async () => {
      await expect(engine.parse(TEMPLATE_FUTURE_VERSION)).rejects.toThrow('不兼容')
    })
  })

  // === LM-TPL-DATA-014: 保存模板 (serialize) ===
  describe('serialize 序列化 (LM-TPL-DATA-014)', () => {
    it('应将模板序列化为有效 JSON 字符串', async () => {
      const resolved = await engine.parse(VALID_TEMPLATE_JSON)
      const json = await engine.serialize(resolved)
      expect(typeof json).toBe('string')

      const parsed = JSON.parse(json)
      expect(parsed.meta.id).toBe('tmpl_test_001')
    })
  })

  // === LM-TPL-DATA-016: 导入有效模板 ===
  describe('parse 导入有效模板 (LM-TPL-DATA-016)', () => {
    it('合法模板应成功解析', async () => {
      const resolved = await engine.parse(VALID_TEMPLATE_JSON)
      expect(resolved.meta.id).toBeTruthy()
      expect(resolved.composition).toBeDefined()
      expect(resolved.camera).toBeDefined()
      expect(resolved.postProcess).toBeDefined()
    })
  })

  // === toSummary ===
  describe('toSummary 生成摘要', () => {
    it('应正确生成模板摘要', async () => {
      const resolved = await engine.parse(VALID_TEMPLATE_JSON)
      const summary = engine.toSummary(resolved)
      expect(summary.id).toBe('tmpl_test_001')
      expect(summary.name).toBe('日落逆光剪影')
      expect(summary.category).toBe('人像')
      expect(summary.hasComposition).toBe(true)
      expect(summary.hasPose).toBe(true)
      expect(summary.hasCameraParams).toBe(true)
      expect(summary.hasPostProcess).toBe(true)
    })
  })
})
