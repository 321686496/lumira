/**
 * EXIF 读写工具
 */
import type { ExifData } from '@/types/photo'

/**
 * 解析 EXIF JSON 字符串
 */
export function parseExif(exifJson: string): ExifData {
  if (!exifJson) return {}
  try {
    return JSON.parse(exifJson) as ExifData
  } catch {
    return {}
  }
}

/**
 * 序列化 EXIF 数据为 JSON
 */
export function serializeExif(exif: ExifData): string {
  return JSON.stringify(exif)
}

/**
 * 从 EXIF 数据提取拍摄参数摘要
 */
export function summarizeExif(exif: ExifData): string {
  const parts: string[] = []
  if (exif.exposureTime) parts.push(`快门 ${exif.exposureTime}`)
  if (exif.fNumber) parts.push(`f/${exif.fNumber}`)
  if (exif.iso) parts.push(`ISO ${exif.iso}`)
  if (exif.focalLength) parts.push(`${exif.focalLength}mm`)
  return parts.join(' · ')
}
