/**
 * 图像处理服务
 * 对应前端文档 7.2 ImageProcessingService
 * 负责 LUT/调色/磨皮/锐化/裁剪/暗角/颗粒等图像处理
 */
import type { ImageHandle, ColorParams } from '@/types/native'
import type { CropRect, ExportOptions } from '@/types/photo'
import type { PostProcessParams } from '@/types/template'

/** 图像处理服务接口 */
export interface ImageProcessingService {
  load(path: string): Promise<ImageHandle>
  adjustColor(handle: ImageHandle, params: ColorParams): Promise<ImageHandle>
  applyLut(handle: ImageHandle, lutPath: string): Promise<ImageHandle>
  smooth(handle: ImageHandle, strength: number): Promise<ImageHandle>
  sharpen(handle: ImageHandle, strength: number): Promise<ImageHandle>
  crop(handle: ImageHandle, rect: CropRect): Promise<ImageHandle>
  rotate(handle: ImageHandle, angle: number): Promise<ImageHandle>
  vignette(handle: ImageHandle, strength: number): Promise<ImageHandle>
  grain(handle: ImageHandle, strength: number): Promise<ImageHandle>
  applyPostProcess(handle: ImageHandle, params: PostProcessParams): Promise<ImageHandle>
  export(handle: ImageHandle, options: ExportOptions): Promise<string>
  release(handle: ImageHandle): void
}

let handleCounter = 0

function createHandle(path?: string, width = 1080, height = 1920): ImageHandle {
  handleCounter++
  return {
    id: `handle_${Date.now()}_${handleCounter}`,
    width,
    height,
    path,
  }
}

/**
 * Mock 图像处理服务实现
 * 用于测试和 H5 环境
 */
export class ImageProcessingServiceMockImpl implements ImageProcessingService {
  private handles = new Map<string, ImageHandle>()

  async load(path: string): Promise<ImageHandle> {
    const handle = createHandle(path)
    this.handles.set(handle.id, handle)
    return handle
  }

  async adjustColor(handle: ImageHandle, params: ColorParams): Promise<ImageHandle> {
    this.checkHandle(handle)
    // Mock：返回新句柄，附带调色参数
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    newHandle.data = new Uint8Array(Object.values(params))
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async applyLut(handle: ImageHandle, lutPath: string): Promise<ImageHandle> {
    this.checkHandle(handle)
    void lutPath
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async smooth(handle: ImageHandle, strength: number): Promise<ImageHandle> {
    this.checkHandle(handle)
    if (strength < 0 || strength > 1) {
      throw new Error('磨皮强度超出范围 [0, 1]')
    }
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async sharpen(handle: ImageHandle, strength: number): Promise<ImageHandle> {
    this.checkHandle(handle)
    if (strength < 0 || strength > 1) {
      throw new Error('锐化强度超出范围 [0, 1]')
    }
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async crop(handle: ImageHandle, rect: CropRect): Promise<ImageHandle> {
    this.checkHandle(handle)
    if (rect.w <= 0 || rect.h <= 0 || rect.w > 1 || rect.h > 1) {
      throw new Error('裁剪区域无效')
    }
    const newWidth = Math.round(handle.width * rect.w)
    const newHeight = Math.round(handle.height * rect.h)
    const newHandle = createHandle(handle.path, newWidth, newHeight)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async rotate(handle: ImageHandle, angle: number): Promise<ImageHandle> {
    this.checkHandle(handle)
    const normalized = ((angle % 360) + 360) % 360
    if (normalized === 90 || normalized === 270) {
      const newHandle = createHandle(handle.path, handle.height, handle.width)
      this.handles.set(newHandle.id, newHandle)
      return newHandle
    }
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async vignette(handle: ImageHandle, strength: number): Promise<ImageHandle> {
    this.checkHandle(handle)
    if (strength < 0 || strength > 1) {
      throw new Error('暗角强度超出范围 [0, 1]')
    }
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async grain(handle: ImageHandle, strength: number): Promise<ImageHandle> {
    this.checkHandle(handle)
    if (strength < 0 || strength > 1) {
      throw new Error('颗粒强度超出范围 [0, 1]')
    }
    const newHandle = createHandle(handle.path, handle.width, handle.height)
    this.handles.set(newHandle.id, newHandle)
    return newHandle
  }

  async applyPostProcess(handle: ImageHandle, params: PostProcessParams): Promise<ImageHandle> {
    this.checkHandle(handle)
    let result = handle
    if (params.color || params.colorParams) {
      result = await this.adjustColor(result, (params.color || params.colorParams) as ColorParams)
    }
    if (params.lut) {
      result = await this.applyLut(result, params.lut)
    }
    if (params.smoothStrength !== undefined || params.smoothing !== undefined) {
      const strength = params.smoothStrength ?? params.smoothing ?? 0
      result = await this.smooth(result, strength)
    }
    if (params.sharpen !== undefined || params.sharpness !== undefined) {
      const strength = params.sharpen ?? params.sharpness ?? 0
      result = await this.sharpen(result, strength)
    }
    if (params.vignette !== undefined) {
      result = await this.vignette(result, params.vignette)
    }
    if (params.grain !== undefined) {
      result = await this.grain(result, params.grain)
    }
    return result
  }

  async export(handle: ImageHandle, options: ExportOptions): Promise<string> {
    this.checkHandle(handle)
    const ext = options.format === 'png' ? 'png' : 'jpg'
    const path = `mock://export/${Date.now()}.${ext}`
    return path
  }

  release(handle: ImageHandle): void {
    this.handles.delete(handle.id)
  }

  private checkHandle(handle: ImageHandle): void {
    if (!this.handles.has(handle.id) && !handle.id.startsWith('handle_')) {
      throw new Error('无效的图像句柄')
    }
  }
}

/** 单例实例 */
export const imageProcessor = new ImageProcessingServiceMockImpl()
