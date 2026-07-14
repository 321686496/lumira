/**
 * 拍照模板统一接口定义
 * 同步对齐 PRD .pptpl JSON 格式与 AGENT.md PhotoTemplate TS 接口
 */

/** 模板目标主体类型 */
export type Target = 'portrait' | 'landscape' | 'food' | 'street' | 'night' | 'macro' | 'still-life'

/** 构图叠图类型 */
export type OverlayType =
  | 'rule_of_thirds'
  | 'golden_ratio'
  | 'diagonal'
  | 'grid'
  | 'leading_lines'
  | 'center'
  | 'none'

/** 网格细分类型（当 overlayType 为 grid 时生效） */
export type GridType = 'thirds' | 'quarters' | 'golden_spiral'

/** ISO 模式 */
export type IsoMode = 'auto' | 'manual'

/** 白平衡预设 */
export type WhiteBalance = 'daylight' | 'cloudy' | 'shade' | 'tungsten' | 'fluorescent' | 'custom'

/** 闪光模式 */
export type FlashMode = 'off' | 'on' | 'auto' | 'torch'

/** 对焦模式 */
export type FocusMode = 'auto' | 'manual' | 'continuous'

/** 镜头建议 */
export type LensSuggestion = 'wide' | 'main' | 'telephoto' | 'ultra_wide'

/** 镜头类型（仅记录，不真切换硬件） */
export type LensType = '0.5x' | '1x' | '2x' | '3x'

/** 拍照风格（参照苹果原相机） */
export type PhotographicStyle = 'standard' | 'high_contrast' | 'warm' | 'cool' | 'mono'

/** 后期 LUT 预设 */
export type LutPreset =
  | 'none'
  | 'cinematic'
  | 'vintage'
  | 'bw'
  | 'warm_film'
  | 'cool_film'
  | 'pastel'
  | 'fuji'
  // 新增 8 种
  | 'portrait'
  | 'japanese'
  | 'cyberpunk'
  | 'sepia_classic'
  | 'mist'
  | 'rouge'
  | 'twilight'
  | 'cyan'

/** 系统内置滤镜（苹果风格） */
export type SystemFilter =
  | 'none'
  | 'vivid'
  | 'vivid_warm'
  | 'vivid_cool'
  | 'mono'
  | 'silver'
  | 'noir'

/** 剪影资源类型 */
export type SilhouetteType = 'builtin' | 'image' | 'svg'

/**
 * 剪影资源（统一承载内置引用与自定义资源）
 *
 * - builtin: data 为内置 SVG 库 key（如 'standing-profile'）
 * - image:   data 为 base64 data URL（用户导入 PNG/JPG）
 * - svg:     data 为内联 SVG 字符串（用户绘制）
 */
export interface SilhouetteResource {
  type: SilhouetteType
  data: string
  /** 资源原始文件名（仅 type=image 时有意义） */
  filename?: string
  /** 资源大小（KB，仅用于显示） */
  sizeKB?: number
}

/** 模板元信息 */
export interface TemplateMeta {
  id: string
  name: string
  author: string
  version: string
  category: Target
  tags: string[]
  /** 价格（0 = 免费） */
  price: number
  cover: string
  description: string
  /** 参数参考来源（如「样片 EXIF: Pexels #12345」） */
  referenceSource: string
}

/** 构图信息 */
export interface Composition {
  overlayType: OverlayType
  /** 网格细分（仅 overlayType=grid 时生效） */
  gridType?: GridType
  /** 主体建议框（归一化 0-1 坐标） */
  subjectFrame: { x: number; y: number; w: number; h: number }
  /** 叠图透明度 0-1 */
  opacity: number
  /** 建议宽高比，如 '3:4'、'16:9' */
  aspectRatio: string
  /** 构图说明文本 */
  description: string
}

/** 姿势参考 */
export interface Pose {
  silhouette: SilhouetteResource
  /** 归一化位置 0-1 */
  position: { x: number; y: number }
  /** 剪影位置 X 偏移 -100~100（用于精细调整） */
  positionX?: number
  /** 剪影位置 Y 偏移 -100~100 */
  positionY?: number
  /** 缩放 0.5-1.5 */
  scale: number
  /** 旋转角度 -45~45 */
  rotation: number
  /** 姿势描述文本 */
  description: string
}

/** 相机参数 */
export interface CameraParams {
  /** EV 值，-3 ~ +3 */
  exposureCompensation: number
  /** ISO 值（auto 时为建议值） */
  iso: number
  /** 快门，如 '1/200'、'1/30' */
  shutterSpeed: string
  whiteBalance: WhiteBalance
  /** 色温 K 值（custom 时使用） */
  whiteBalanceK: number
  flashMode: FlashMode
  focusMode: FocusMode
  /** 镜头类型（仅记录） */
  lensType?: LensType
  /** 拍照风格 */
  photographicStyle?: PhotographicStyle
  /** HDR 开关 */
  hdr?: boolean
  /** @deprecated 改用 lensType */
  lensSuggestion?: LensSuggestion
  /** @deprecated 改用独立滤镜系统 */
  filterPreset?: string
  /** @deprecated 无意义字段 */
  isoMode?: IsoMode
}

/** 场景指南 */
export interface SceneGuide {
  /** 光线方向，如「逆光 45°」 */
  lightDirection: string
  /** 拍摄距离，如「2-3m」 */
  shootingDistance: string
  /** 背景建议 */
  background: string
  /** 道具建议 */
  props: string[]
  /** 最佳拍摄时间 */
  bestTime: string
  /** 拍摄贴士数组 */
  tips: string[]
}

/** 后期参数 */
export interface PostProcess {
  /** 裁剪比，如 '3:4' */
  cropRatio: string
  color: {
    /** -100 ~ 100 */
    brightness: number
    contrast: number
    saturation: number
    /** 暖/冷 -100 ~ 100 */
    temperature: number
    /** 绿/品 -100 ~ 100 */
    tint: number
  }
  /** 磨皮 0-100 */
  smoothStrength: number
  /** 锐化 0-100 */
  sharpen: number
  /** 暗角 0-100 */
  vignette: number
  /** 颗粒 0-100 */
  grain: number
  /** LUT 预设 */
  lut: LutPreset
  /** 系统内置滤镜（苹果风格） */
  systemFilter?: SystemFilter
}

/** 完整拍照模板 */
export interface PhotoTemplate {
  meta: TemplateMeta
  composition: Composition
  pose: Pose
  camera: CameraParams
  sceneGuide: SceneGuide
  postProcess: PostProcess
}
