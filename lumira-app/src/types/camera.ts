/**
 * 相机参数类型定义
 * 对应前端文档 7.1 CameraService 接口
 */

/** 相机初始化配置 */
export interface CameraConfig {
  defaultCamera: 'front' | 'back'
  defaultTemplateId?: string
  enableOverlay: boolean
  enableAlignment: boolean
}

/** 相机运行时参数 */
export interface CameraParams {
  evBias: number
  isoMode: 'auto' | 'manual'
  iso: number
  shutterSpeed: string
  whiteBalance: string
  whiteBalanceKelvin?: number
  focusMode: 'auto' | 'manual'
  filterPreset: string
  flashMode: 'off' | 'auto' | 'on'
  lens: 'main' | 'wide' | 'tele'
}

/** 默认相机参数 */
export const DEFAULT_CAMERA_PARAMS: CameraParams = {
  evBias: 0,
  isoMode: 'auto',
  iso: 100,
  shutterSpeed: '1/200',
  whiteBalance: 'auto',
  focusMode: 'auto',
  filterPreset: 'none',
  flashMode: 'auto',
  lens: 'main',
}

/** 拍摄结果 */
export interface PhotoResult {
  path: string
  width: number
  height: number
  capturedAt: number
}

/** 水平检测结果 */
export interface LevelDetection {
  isLevel: boolean
  angle: number
}

/** 对齐检测结果 */
export interface AlignmentStatus {
  isLevel: boolean
  subjectAligned: boolean
  message: string
}
