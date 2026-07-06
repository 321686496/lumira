/**
 * 照片元数据类型定义
 */

/** 本地照片记录（对应 SQLite LocalPhoto 表） */
export interface LocalPhoto {
  id: string
  templateId: string | null
  imagePath: string
  exifJson: string
  createdAt: number
}

/** EXIF 数据 */
export interface ExifData {
  dateTime?: string
  make?: string
  model?: string
  exposureTime?: string
  fNumber?: number
  iso?: number
  focalLength?: number
  exposureBiasValue?: number
  whiteBalance?: string
  flash?: string
  gpsLatitude?: number
  gpsLongitude?: number
  width?: number
  height?: number
}

/** 编辑动作（用于撤销历史） */
export interface EditAction {
  type: 'color' | 'lut' | 'smooth' | 'sharpen' | 'crop' | 'rotate' | 'vignette' | 'grain'
  params: Record<string, unknown>
  timestamp: number
}

/** 裁剪矩形（归一化坐标 0~1） */
export interface CropRect {
  x: number
  y: number
  w: number
  h: number
}

/** 导出选项 */
export interface ExportOptions {
  format: 'jpeg' | 'png'
  quality: number
  maxWidth?: number
  maxHeight?: number
  withWatermark?: boolean
  outputPath?: string
}
