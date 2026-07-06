/**
 * 原生插件接口类型定义
 * 这些接口描述原生插件（LumiraCamera / LumiraImageProcessor）的能力
 * 在测试/H5环境中使用 Mock 实现
 */

/** 图像句柄 */
export interface ImageHandle {
  id: string
  width: number
  height: number
  path?: string
  data?: Uint8Array
}

/** 调色参数 */
export interface ColorParams {
  brightness: number
  contrast: number
  saturation: number
  temperature: number
  tint: number
}

/** 原生相机插件接口 */
export interface NativeCameraPlugin {
  initialize(config: unknown): Promise<void>
  startPreview(container: unknown): Promise<void>
  stopPreview(): Promise<void>
  setOverlay(layer: unknown): Promise<void>
  setOverlayOpacity(opacity: number): Promise<void>
  setParameters(params: unknown): Promise<void>
  getParameters(): Promise<unknown>
  capture(): Promise<string>
  switchCamera(): Promise<void>
  detectLevel(): Promise<{ isLevel: boolean; angle: number }>
  release(): Promise<void>
}

/** 原生图像处理插件接口 */
export interface NativeImageProcessorPlugin {
  load(path: string): Promise<unknown>
  adjustColor(handle: unknown, params: unknown): Promise<unknown>
  applyLut(handle: unknown, lutPath: string): Promise<unknown>
  smooth(handle: unknown, strength: number): Promise<unknown>
  sharpen(handle: unknown, strength: number): Promise<unknown>
  crop(handle: unknown, rect: unknown): Promise<unknown>
  rotate(handle: unknown, angle: number): Promise<unknown>
  vignette(handle: unknown, strength: number): Promise<unknown>
  grain(handle: unknown, strength: number): Promise<unknown>
  applyPostProcess(handle: unknown, params: unknown): Promise<unknown>
  export(handle: unknown, options: unknown): Promise<string>
  release(handle: unknown): void
}

/** 原生存储插件接口（SQLite） */
export interface NativeStoragePlugin {
  openDatabase(name: string): Promise<void>
  executeSql(sql: string, params?: unknown[]): Promise<unknown[]>
  selectSql<T>(sql: string, params?: unknown[]): Promise<T[]>
  closeDatabase(): Promise<void>
}
