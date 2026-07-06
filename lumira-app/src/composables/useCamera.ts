/**
 * 相机控制组合式逻辑
 */
import { ref, onUnmounted } from 'vue'
import { cameraService, type CameraService } from '@/services/camera'
import type { CameraConfig, CameraParams, PhotoResult } from '@/types/camera'
import type { OverlayLayer } from '@/types/overlay'
import { useCaptureStore } from '@/stores/capture'

export function useCamera(service: CameraService = cameraService) {
  const store = useCaptureStore()
  const isReady = ref(false)
  const isCapturing = ref(false)
  const error = ref<string | null>(null)

  async function initialize(config: CameraConfig): Promise<void> {
    try {
      await service.initialize(config)
      await service.startPreview()
      store.setActive(true)
      isReady.value = true
      error.value = null
    } catch (e) {
      error.value = e instanceof Error ? e.message : '相机初始化失败'
      isReady.value = false
      throw e
    }
  }

  async function capture(): Promise<PhotoResult> {
    if (isCapturing.value) {
      throw new Error('正在拍摄中，请稍候')
    }
    isCapturing.value = true
    try {
      const result = await service.capture()
      return result
    } finally {
      isCapturing.value = false
    }
  }

  async function setOverlay(layer: OverlayLayer): Promise<void> {
    await service.setOverlay(layer)
  }

  async function setOverlayOpacity(opacity: number): Promise<void> {
    await service.setOverlayOpacity(opacity)
    store.setOverlayOpacity(opacity)
  }

  async function setParameters(params: Partial<CameraParams>): Promise<void> {
    await service.setParameters(params)
    store.updateCameraParameters(params)
  }

  async function getParameters(): Promise<CameraParams> {
    return service.getParameters()
  }

  async function switchCamera(): Promise<void> {
    await service.switchCamera()
  }

  async function detectLevel(): Promise<{ isLevel: boolean; angle: number }> {
    const result = await service.detectLevel()
    store.setAlignmentStatus({
      isLevel: result.isLevel,
      subjectAligned: store.alignmentStatus.subjectAligned,
      message: result.isLevel ? '水平' : `倾斜 ${result.angle.toFixed(1)}°`,
    })
    return result
  }

  async function release(): Promise<void> {
    await service.stopPreview()
    await service.release()
    store.setActive(false)
    isReady.value = false
  }

  onUnmounted(() => {
    if (isReady.value) {
      release().catch(() => {})
    }
  })

  return {
    isReady,
    isCapturing,
    error,
    initialize,
    capture,
    setOverlay,
    setOverlayOpacity,
    setParameters,
    getParameters,
    switchCamera,
    detectLevel,
    release,
  }
}
