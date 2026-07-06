/**
 * 相机服务
 * 对应前端文档 7.1 CameraService
 * 在测试/H5环境使用 Mock 实现，在 App 环境代理原生插件
 */
import type { CameraConfig, CameraParams, PhotoResult, LevelDetection } from '@/types/camera'
import type { OverlayLayer } from '@/types/overlay'
import { DEFAULT_CAMERA_PARAMS } from '@/types/camera'

/** 相机服务接口 */
export interface CameraService {
  initialize(config: CameraConfig): Promise<void>
  startPreview(viewContainer?: unknown): Promise<void>
  stopPreview(): Promise<void>
  setOverlay(layer: OverlayLayer): Promise<void>
  setOverlayOpacity(opacity: number): Promise<void>
  setParameters(params: Partial<CameraParams>): Promise<void>
  getParameters(): Promise<CameraParams>
  capture(): Promise<PhotoResult>
  switchCamera(): Promise<void>
  detectLevel(): Promise<LevelDetection>
  release(): Promise<void>
  isAvailable(): boolean
}

/**
 * Mock 相机服务实现
 * 用于测试和 H5 环境，不依赖原生插件
 */
export class CameraServiceMockImpl implements CameraService {
  private initialized = false
  private previewing = false
  private currentParams: CameraParams = { ...DEFAULT_CAMERA_PARAMS }
  private overlay: OverlayLayer | null = null
  private overlayOpacity = 0.5
  private currentCamera: 'front' | 'back' = 'back'
  private captureCount = 0

  async initialize(config: CameraConfig): Promise<void> {
    this.currentCamera = config.defaultCamera
    this.initialized = true
  }

  async startPreview(viewContainer?: unknown): Promise<void> {
    void viewContainer
    if (!this.initialized) {
      throw new Error('相机未初始化')
    }
    this.previewing = true
  }

  async stopPreview(): Promise<void> {
    this.previewing = false
  }

  async setOverlay(layer: OverlayLayer): Promise<void> {
    this.overlay = layer
    this.overlayOpacity = layer.opacity
  }

  async setOverlayOpacity(opacity: number): Promise<void> {
    this.overlayOpacity = Math.max(0, Math.min(1, opacity))
  }

  async setParameters(params: Partial<CameraParams>): Promise<void> {
    this.currentParams = { ...this.currentParams, ...params }
  }

  async getParameters(): Promise<CameraParams> {
    return { ...this.currentParams }
  }

  async capture(): Promise<PhotoResult> {
    if (!this.previewing) {
      throw new Error('相机预览未启动')
    }
    this.captureCount++
    const path = `mock://capture/${Date.now()}_${this.captureCount}.jpg`
    return {
      path,
      width: 1080,
      height: 1920,
      capturedAt: Date.now(),
    }
  }

  async switchCamera(): Promise<void> {
    this.currentCamera = this.currentCamera === 'front' ? 'back' : 'front'
  }

  async detectLevel(): Promise<LevelDetection> {
    return {
      isLevel: true,
      angle: 0,
    }
  }

  async release(): Promise<void> {
    this.previewing = false
    this.initialized = false
    this.overlay = null
  }

  isAvailable(): boolean {
    return true
  }
}

/**
 * 原生相机服务实现（App 环境）
 * 代理 LumiraCamera 原生插件
 */
export class CameraServiceNativeImpl implements CameraService {
  private initialized = false
  private previewing = false
  private currentParams: CameraParams = { ...DEFAULT_CAMERA_PARAMS }
  private overlayOpacity = 0.5

  private get plugin(): unknown {
    // uni-app 原生插件引用
    return (uni as unknown as { requireNativePlugin: (name: string) => unknown }).requireNativePlugin('LumiraCamera')
  }

  async initialize(config: CameraConfig): Promise<void> {
    try {
      const plugin = this.plugin as { initialize: (config: unknown) => Promise<void> }
      await plugin.initialize(config)
      this.initialized = true
    } catch (e) {
      throw new Error('相机不可用')
    }
  }

  async startPreview(viewContainer?: unknown): Promise<void> {
    void viewContainer
    const plugin = this.plugin as { startPreview: () => Promise<void> }
    await plugin.startPreview()
    this.previewing = true
  }

  async stopPreview(): Promise<void> {
    const plugin = this.plugin as { stopPreview: () => Promise<void> }
    await plugin.stopPreview()
    this.previewing = false
  }

  async setOverlay(layer: OverlayLayer): Promise<void> {
    const plugin = this.plugin as { setOverlay: (layer: unknown) => Promise<void> }
    await plugin.setOverlay(layer)
    this.overlayOpacity = layer.opacity
  }

  async setOverlayOpacity(opacity: number): Promise<void> {
    const plugin = this.plugin as { setOverlayOpacity: (opacity: number) => Promise<void> }
    await plugin.setOverlayOpacity(opacity)
    this.overlayOpacity = opacity
  }

  async setParameters(params: Partial<CameraParams>): Promise<void> {
    const plugin = this.plugin as { setParameters: (params: unknown) => Promise<void> }
    await plugin.setParameters(params)
    this.currentParams = { ...this.currentParams, ...params }
  }

  async getParameters(): Promise<CameraParams> {
    return { ...this.currentParams }
  }

  async capture(): Promise<PhotoResult> {
    const plugin = this.plugin as { capture: () => Promise<string> }
    const path = await plugin.capture()
    return {
      path,
      width: 1080,
      height: 1920,
      capturedAt: Date.now(),
    }
  }

  async switchCamera(): Promise<void> {
    const plugin = this.plugin as { switchCamera: () => Promise<void> }
    await plugin.switchCamera()
  }

  async detectLevel(): Promise<LevelDetection> {
    const plugin = this.plugin as { detectLevel: () => Promise<LevelDetection> }
    return plugin.detectLevel()
  }

  async release(): Promise<void> {
    const plugin = this.plugin as { release: () => Promise<void> }
    await plugin.release()
    this.previewing = false
    this.initialized = false
  }

  isAvailable(): boolean {
    return true
  }
}

/** 根据环境返回合适的实现 */
function createCameraService(): CameraService {
  // #ifdef APP-PLUS
  return new CameraServiceNativeImpl()
  // #endif
  // #ifndef APP-PLUS
  return new CameraServiceMockImpl()
  // #endif
}

export const cameraService = createCameraService()
