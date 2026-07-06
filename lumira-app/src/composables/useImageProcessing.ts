/**
 * 图像处理组合式逻辑
 */
import { ref } from 'vue'
import { imageProcessor, type ImageProcessingService } from '@/services/imageProcessor'
import type { ImageHandle, ColorParams } from '@/types/native'
import type { CropRect, ExportOptions, EditAction } from '@/types/photo'
import type { PostProcessParams } from '@/types/template'
import { useGalleryStore } from '@/stores/gallery'

export function useImageProcessing(service: ImageProcessingService = imageProcessor) {
  const galleryStore = useGalleryStore()
  const currentHandle = ref<ImageHandle | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function load(path: string): Promise<ImageHandle> {
    isLoading.value = true
    error.value = null
    try {
      const handle = await service.load(path)
      currentHandle.value = handle
      galleryStore.clearEditingHistory()
      return handle
    } catch (e) {
      error.value = e instanceof Error ? e.message : '图像加载失败'
      throw e
    } finally {
      isLoading.value = false
    }
  }

  async function adjustColor(params: ColorParams): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.adjustColor(currentHandle.value, params)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'color', params: { ...params }, timestamp: Date.now() })
    return newHandle
  }

  async function applyLut(lutPath: string): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.applyLut(currentHandle.value, lutPath)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'lut', params: { lutPath }, timestamp: Date.now() })
    return newHandle
  }

  async function smooth(strength: number): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.smooth(currentHandle.value, strength)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'smooth', params: { strength }, timestamp: Date.now() })
    return newHandle
  }

  async function sharpen(strength: number): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.sharpen(currentHandle.value, strength)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'sharpen', params: { strength }, timestamp: Date.now() })
    return newHandle
  }

  async function crop(rect: CropRect): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.crop(currentHandle.value, rect)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'crop', params: { ...rect }, timestamp: Date.now() })
    return newHandle
  }

  async function rotate(angle: number): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.rotate(currentHandle.value, angle)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'rotate', params: { angle }, timestamp: Date.now() })
    return newHandle
  }

  async function vignette(strength: number): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.vignette(currentHandle.value, strength)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'vignette', params: { strength }, timestamp: Date.now() })
    return newHandle
  }

  async function grain(strength: number): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.grain(currentHandle.value, strength)
    currentHandle.value = newHandle
    galleryStore.pushEditAction({ type: 'grain', params: { strength }, timestamp: Date.now() })
    return newHandle
  }

  async function applyPostProcess(params: PostProcessParams): Promise<ImageHandle> {
    if (!currentHandle.value) throw new Error('未加载图像')
    const newHandle = await service.applyPostProcess(currentHandle.value, params)
    currentHandle.value = newHandle
    return newHandle
  }

  async function exportImage(options: ExportOptions): Promise<string> {
    if (!currentHandle.value) throw new Error('未加载图像')
    return service.export(currentHandle.value, options)
  }

  function release(): void {
    if (currentHandle.value) {
      service.release(currentHandle.value)
      currentHandle.value = null
    }
  }

  return {
    currentHandle,
    isLoading,
    error,
    load,
    adjustColor,
    applyLut,
    smooth,
    sharpen,
    crop,
    rotate,
    vignette,
    grain,
    applyPostProcess,
    exportImage,
    release,
  }
}

export type { EditAction }
