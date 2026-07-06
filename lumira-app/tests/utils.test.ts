/**
 * 工具函数测试
 */
import { describe, it, expect } from 'vitest'
import { parseExif, serializeExif, summarizeExif } from '@/utils/exif'
import { rgbToHsl, hslToRgb, kelvinToRgb, clampColor } from '@/utils/color'
import { clamp, lerp, distance, isPointInRect, rectIntersection, IoU, degToRad, radToDeg, generateId } from '@/utils/math'

describe('EXIF 工具', () => {
  it('parseExif 应正确解析 JSON', () => {
    const json = JSON.stringify({ iso: 100, fNumber: 2.8 })
    const exif = parseExif(json)
    expect(exif.iso).toBe(100)
    expect(exif.fNumber).toBe(2.8)
  })

  it('parseExif 空 JSON 应返回空对象', () => {
    expect(parseExif('')).toEqual({})
    expect(parseExif('invalid')).toEqual({})
  })

  it('serializeExif 应序列化为 JSON', () => {
    const exif = { iso: 200, exposureTime: '1/100' }
    const json = serializeExif(exif)
    expect(JSON.parse(json).iso).toBe(200)
  })

  it('summarizeExif 应生成摘要', () => {
    const exif = { exposureTime: '1/200', fNumber: 2.8, iso: 100, focalLength: 50 }
    const summary = summarizeExif(exif)
    expect(summary).toContain('1/200')
    expect(summary).toContain('2.8')
    expect(summary).toContain('ISO 100')
    expect(summary).toContain('50mm')
  })
})

describe('颜色工具', () => {
  it('rgbToHsl 应正确转换', () => {
    const hsl = rgbToHsl({ r: 255, g: 255, b: 255 })
    expect(hsl.l).toBe(1) // 白色亮度=1
  })

  it('hslToRgb 应正确转换', () => {
    const rgb = hslToRgb({ h: 0, s: 1, l: 0.5 })
    expect(rgb.r).toBe(255)
    expect(rgb.g).toBe(0)
    expect(rgb.b).toBe(0)
  })

  it('rgbToHsl → hslToRgb 应往返一致', () => {
    const original = { r: 128, g: 64, b: 200 }
    const hsl = rgbToHsl(original)
    const rgb = hslToRgb(hsl)
    expect(Math.abs(rgb.r - original.r)).toBeLessThanOrEqual(1)
    expect(Math.abs(rgb.g - original.g)).toBeLessThanOrEqual(1)
    expect(Math.abs(rgb.b - original.b)).toBeLessThanOrEqual(1)
  })

  it('kelvinToRgb 应返回有效 RGB', () => {
    const rgb = kelvinToRgb(5500)
    expect(rgb.r).toBeGreaterThanOrEqual(0)
    expect(rgb.r).toBeLessThanOrEqual(255)
  })

  it('clampColor 应限制在 0~255', () => {
    expect(clampColor(-10)).toBe(0)
    expect(clampColor(300)).toBe(255)
    expect(clampColor(128)).toBe(128)
  })
})

describe('数学工具', () => {
  it('clamp 应限制范围', () => {
    expect(clamp(5, 0, 10)).toBe(5)
    expect(clamp(-5, 0, 10)).toBe(0)
    expect(clamp(15, 0, 10)).toBe(10)
  })

  it('lerp 应线性插值', () => {
    expect(lerp(0, 10, 0.5)).toBe(5)
    expect(lerp(0, 10, 0)).toBe(0)
    expect(lerp(0, 10, 1)).toBe(10)
  })

  it('distance 应计算两点距离', () => {
    expect(distance({ x: 0, y: 0 }, { x: 3, y: 4 })).toBe(5)
  })

  it('isPointInRect 应判断点在矩形内', () => {
    const rect = { x: 0, y: 0, w: 10, h: 10 }
    expect(isPointInRect({ x: 5, y: 5 }, rect)).toBe(true)
    expect(isPointInRect({ x: 15, y: 5 }, rect)).toBe(false)
  })

  it('rectIntersection 应计算交集面积', () => {
    const a = { x: 0, y: 0, w: 10, h: 10 }
    const b = { x: 5, y: 5, w: 10, h: 10 }
    expect(rectIntersection(a, b)).toBe(25) // 5x5 交集
  })

  it('rectIntersection 无交集应返回 0', () => {
    const a = { x: 0, y: 0, w: 5, h: 5 }
    const b = { x: 10, y: 10, w: 5, h: 5 }
    expect(rectIntersection(a, b)).toBe(0)
  })

  it('IoU 应计算交并比', () => {
    const a = { x: 0, y: 0, w: 10, h: 10 }
    const b = { x: 0, y: 0, w: 10, h: 10 }
    expect(IoU(a, b)).toBe(1) // 完全重叠
  })

  it('degToRad / radToDeg 应互逆', () => {
    expect(degToRad(180)).toBeCloseTo(Math.PI)
    expect(radToDeg(Math.PI)).toBeCloseTo(180)
  })

  it('generateId 应生成唯一 ID', () => {
    const id1 = generateId('test')
    const id2 = generateId('test')
    expect(id1).not.toBe(id2)
    expect(id1).toContain('test_')
  })
})
