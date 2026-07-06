/**
 * 图像处理服务测试
 * 对应测试文档：
 * - LM-GAL-DATA-006: 加载图像
 * - LM-GAL-UI-007: 调色滑块
 * - LM-GAL-UI-008: LUT 滤镜
 * - LM-GAL-UI-009: 磨皮/锐化
 * - LM-GAL-UI-010: 裁剪
 * - LM-GAL-DATA-013: 导出照片
 * - LM-GAL-DATA-015: 句柄释放
 * - LM-GAL-ERR-016: 导出失败处理
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { ImageProcessingServiceMockImpl } from '@/services/imageProcessor'
import type { ColorParams } from '@/types/native'
import type { CropRect, ExportOptions } from '@/types/photo'
import type { PostProcessParams } from '@/types/template'

describe('ImageProcessingService (Mock)', () => {
  let processor: ImageProcessingServiceMockImpl

  beforeEach(() => {
    processor = new ImageProcessingServiceMockImpl()
  })

  // === LM-GAL-DATA-006: 加载图像 ===
  describe('加载图像 (LM-GAL-DATA-006)', () => {
    it('load 应返回有效图像句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      expect(handle.id).toBeTruthy()
      expect(handle.width).toBeGreaterThan(0)
      expect(handle.height).toBeGreaterThan(0)
      expect(handle.path).toBe('mock://photo.jpg')
    })
  })

  // === LM-GAL-UI-007: 调色滑块 ===
  describe('调色 (LM-GAL-UI-007)', () => {
    it('adjustColor 应返回新句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const params: ColorParams = {
        brightness: 0.1,
        contrast: 0.15,
        saturation: -0.1,
        temperature: 0.2,
        tint: 0.0,
      }
      const newHandle = await processor.adjustColor(handle, params)
      expect(newHandle.id).not.toBe(handle.id)
      expect(newHandle.width).toBe(handle.width)
    })
  })

  // === LM-GAL-UI-008: LUT 滤镜 ===
  describe('LUT 滤镜 (LM-GAL-UI-008)', () => {
    it('applyLut 应返回新句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.applyLut(handle, 'warm_sunset.cube')
      expect(newHandle.id).not.toBe(handle.id)
    })
  })

  // === LM-GAL-UI-009: 磨皮/锐化 ===
  describe('磨皮与锐化 (LM-GAL-UI-009)', () => {
    it('smooth 应返回新句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.smooth(handle, 0.3)
      expect(newHandle.id).not.toBe(handle.id)
    })

    it('smooth 强度超出范围应抛出错误', async () => {
      const handle = await processor.load('mock://photo.jpg')
      await expect(processor.smooth(handle, 1.5)).rejects.toThrow('超出范围')
      await expect(processor.smooth(handle, -0.5)).rejects.toThrow('超出范围')
    })

    it('sharpen 应返回新句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.sharpen(handle, 0.2)
      expect(newHandle.id).not.toBe(handle.id)
    })

    it('sharpen 强度超出范围应抛出错误', async () => {
      const handle = await processor.load('mock://photo.jpg')
      await expect(processor.sharpen(handle, 2)).rejects.toThrow('超出范围')
    })
  })

  // === LM-GAL-UI-010: 裁剪 ===
  describe('裁剪 (LM-GAL-UI-010)', () => {
    it('crop 应返回裁剪后尺寸的句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const rect: CropRect = { x: 0.1, y: 0.1, w: 0.5, h: 0.5 }
      const newHandle = await processor.crop(handle, rect)
      expect(newHandle.width).toBe(Math.round(1080 * 0.5))
      expect(newHandle.height).toBe(Math.round(1920 * 0.5))
    })

    it('无效裁剪区域应抛出错误', async () => {
      const handle = await processor.load('mock://photo.jpg')
      await expect(
        processor.crop(handle, { x: 0, y: 0, w: 0, h: 0.5 }),
      ).rejects.toThrow('裁剪区域无效')
      await expect(
        processor.crop(handle, { x: 0, y: 0, w: 1.5, h: 0.5 }),
      ).rejects.toThrow('裁剪区域无效')
    })
  })

  // === 旋转 ===
  describe('旋转', () => {
    it('90度旋转应交换宽高', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.rotate(handle, 90)
      expect(newHandle.width).toBe(handle.height)
      expect(newHandle.height).toBe(handle.width)
    })

    it('180度旋转应保持宽高', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.rotate(handle, 180)
      expect(newHandle.width).toBe(handle.width)
      expect(newHandle.height).toBe(handle.height)
    })
  })

  // === 暗角/颗粒 ===
  describe('暗角与颗粒', () => {
    it('vignette 应返回新句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.vignette(handle, 0.3)
      expect(newHandle.id).not.toBe(handle.id)
    })

    it('grain 应返回新句柄', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const newHandle = await processor.grain(handle, 0.1)
      expect(newHandle.id).not.toBe(handle.id)
    })
  })

  // === applyPostProcess ===
  describe('applyPostProcess 一键后期', () => {
    it('应依次应用所有后期参数', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const params: PostProcessParams = {
        color: {
          brightness: 0.1,
          contrast: 0.15,
          saturation: 0,
          temperature: 0.1,
          tint: 0,
        },
        lut: 'warm.cube',
        smoothStrength: 0.3,
        sharpen: 0.2,
        vignette: 0.2,
        grain: 0.1,
      }
      const result = await processor.applyPostProcess(handle, params)
      expect(result.id).not.toBe(handle.id)
    })
  })

  // === LM-GAL-DATA-013: 导出照片 ===
  describe('导出照片 (LM-GAL-DATA-013)', () => {
    it('export 应返回导出文件路径', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const options: ExportOptions = {
        format: 'jpeg',
        quality: 0.9,
      }
      const path = await processor.export(handle, options)
      expect(path).toBeTruthy()
      expect(path).toContain('.jpg')
    })

    it('PNG 格式应返回 .png 扩展名', async () => {
      const handle = await processor.load('mock://photo.jpg')
      const path = await processor.export(handle, {
        format: 'png',
        quality: 1,
      })
      expect(path).toContain('.png')
    })
  })

  // === LM-GAL-DATA-015: 句柄释放 ===
  describe('句柄释放 (LM-GAL-DATA-015)', () => {
    it('release 应无错误完成', async () => {
      const handle = await processor.load('mock://photo.jpg')
      expect(() => processor.release(handle)).not.toThrow()
    })
  })

  // === LM-GAL-ERR-016: 导出失败处理 ===
  describe('异常处理 (LM-GAL-ERR-016)', () => {
    it('未加载图像时操作应抛出错误', async () => {
      const fakeHandle = { id: 'fake', width: 0, height: 0 }
      await expect(
        processor.adjustColor(fakeHandle, {
          brightness: 0,
          contrast: 0,
          saturation: 0,
          temperature: 0,
          tint: 0,
        }),
      ).rejects.toThrow()
    })
  })
})
