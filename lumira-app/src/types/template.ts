/**
 * .pptpl 模板文件类型定义
 * 对应 PRD 3.2 模板文件格式
 */

/** 模板元数据 */
export interface TemplateMeta {
  id: string
  name: string
  author?: string
  version: string
  category?: string
  tags?: string[]
  price?: number
  cover?: string
  description?: string
  thumbnail?: string
  target?: 'lumira' | 'lumira-studio' | 'both'
}

/** 构图叠图类型 */
export type OverlayType = 'rule_of_thirds' | 'grid' | 'leading_lines' | 'custom'

/** 网格类型 */
export type GridType = 'none' | 'thirds' | 'golden' | 'diagonal'

/** 主体框（归一化坐标 0~1） */
export interface SubjectFrame {
  x: number
  y: number
  w: number
  h: number
}

/** 构图叠图配置 */
export interface CompositionOverlay {
  overlayType: OverlayType
  overlayResource?: string
  subjectFrame?: SubjectFrame
  opacity: number
  guideLines?: GuideLine[]
  ruleOfThirds?: boolean
  gridType?: GridType
  aspectRatios?: string[]
}

/** 引导线 */
export interface GuideLine {
  type: 'horizontal' | 'vertical' | 'diagonal' | 'curve'
  start: { x: number; y: number }
  end: { x: number; y: number }
  color?: string
}

/** 姿势参考 */
export interface PoseReference {
  referenceImage?: string
  silhouetteUrl?: string
  description?: string
  position?: { x: number; y: number }
  scale?: number
  rotation?: number
  keyPoints?: Joint[]
}

/** 关节点 */
export interface Joint {
  name: string
  x: number
  y: number
}

/** 相机模式 */
export type CameraMode = 'auto' | 'portrait' | 'landscape' | 'night'

/** 闪光灯模式 */
export type FlashMode = 'off' | 'auto' | 'on'

/** ISO 模式 */
export type IsoMode = 'auto' | 'manual'

/** 白平衡预设 */
export type WhiteBalancePreset = 'daylight' | 'cloudy' | 'auto'

/** 对焦模式 */
export type FocusMode = 'auto' | 'manual'

/** 镜头建议 */
export type LensSuggestion = 'main' | 'wide' | 'tele'

/** 相机参数模板配置 */
export interface TemplateCameraConfig {
  exposureCompensation?: number
  evBias?: number
  isoMode?: IsoMode
  iso?: number
  shutterSpeed?: string
  whiteBalance?: WhiteBalancePreset | string
  whiteBalanceKelvin?: number
  focusMode?: FocusMode
  filterPreset?: string
  lensSuggestion?: LensSuggestion
  suggestedMode?: CameraMode
  flashMode?: FlashMode
}

/** 场景指南 */
export interface SceneGuide {
  description: string
  lightDirection?: string
  shootingDistance?: string
  background?: string
  props?: string[]
  tips?: string
  bestTime?: string
  lightingTip?: string
}

/** 调色参数 */
export interface ColorAdjustment {
  brightness: number
  contrast: number
  saturation: number
  temperature: number
  tint: number
}

/** 后期处理参数包 */
export interface PostProcessParams {
  cropRatio?: string
  color?: ColorAdjustment
  colorParams?: ColorAdjustment
  smoothStrength?: number
  smoothing?: number
  sharpen?: number
  sharpness?: number
  vignette?: number
  grain?: number
  lut?: string
}

/** 完整的拍摄模板（.pptpl 解析后） */
export interface PhotoTemplate {
  meta: TemplateMeta
  composition: CompositionOverlay
  pose?: PoseReference
  camera: TemplateCameraConfig
  sceneGuide?: SceneGuide
  postProcess: PostProcessParams
}

/** 原始模板（未解析/验证前） */
export type RawTemplate = Record<string, unknown>

/** 解析后的模板（带解析状态） */
export interface ResolvedTemplate extends PhotoTemplate {
  resolvedAt: number
  resolvedFrom: string
}

/** 验证结果 */
export interface ValidationResult {
  valid: boolean
  errors: ValidationError[]
}

export interface ValidationError {
  field: string
  message: string
}

/** 兼容性检查结果 */
export interface CompatibilityResult {
  compatible: boolean
  currentVersion: string
  templateVersion: string
  message: string
}

/** 本地存储的模板记录 */
export interface LocalTemplate {
  id: string
  name: string
  source: 'builtin' | 'imported' | 'created'
  pptplJson: string
  coverPath?: string
  createdAt: number
  updatedAt: number
}

/** 模板摘要（列表展示用） */
export interface TemplateSummary {
  id: string
  name: string
  category?: string
  cover?: string
  tags?: string[]
  hasComposition: boolean
  hasPose: boolean
  hasCameraParams: boolean
  hasPostProcess: boolean
}
