/**
 * 滤镜配方系统
 *
 * 将模板的相机参数 + 后期参数 转换为 CSS / Canvas filter 字符串。
 * 同时用于实时预览（CSS）和最终照片烘焙（Canvas）。
 *
 * 参数映射说明：
 * - EV (-3 ~ +3) → brightness(1 + ev/3)
 * - 对比度 (-100 ~ 100) → contrast(1 + v/100)
 * - 饱和度 (-100 ~ 100) → saturate(1 + v/100)
 * - 色温 (-100 ~ 100) → warm/cool via sepia + hue-rotate
 * - 色调 (-100 ~ 100) → hue-rotate
 * - 暗角 / 颗粒 / 锐化 → Canvas 像素级处理（不在 filter 中）
 * - LUT 预设 → 预定义复合 filter 链
 */

import type { CameraParams, PostProcess, LutPreset, WhiteBalance } from '@/types/template'

/** LUT 预设对应的复合 filter（不含基础调整） */
const LUT_FILTERS: Record<LutPreset, string> = {
  none: '',
  // 电影感：橙青调，高对比
  cinematic: 'contrast(1.15) saturate(0.9) hue-rotate(-8deg) brightness(0.97)',
  // 复古胶片：暖色 + 颗粒感（颗粒另算）
  vintage: 'sepia(0.35) contrast(1.1) brightness(1.05) saturate(0.85)',
  // 黑白
  bw: 'grayscale(1) contrast(1.1)',
  // 暖色胶片
  warm_film: 'sepia(0.2) saturate(1.15) brightness(1.03) hue-rotate(-5deg)',
  // 冷色胶片
  cool_film: 'saturate(0.9) brightness(0.98) hue-rotate(8deg)',
  // 柔色
  pastel: 'contrast(0.92) saturate(0.85) brightness(1.08)',
  // 富士胶片感
  fuji: 'saturate(1.2) contrast(1.05) hue-rotate(-3deg) brightness(1.02)'
}

/** 白平衡预设 → 色温偏移（K） */
const WB_K: Record<WhiteBalance, number> = {
  daylight: 5500,
  cloudy: 6500,
  shade: 7500,
  tungsten: 3200,
  fluorescent: 4000,
  custom: 5500 // 用 whiteBalanceK 字段
}

/**
 * 计算白平衡对色温的影响（返回 -100 ~ 100 的偏移量）
 * 5500K 为中性（0），高于 5500 偏暖（+），低于 5500 偏冷（-）
 */
function temperatureOffset(wb: WhiteBalance, wbK: number): number {
  const k = wb === 'custom' ? wbK : WB_K[wb]
  // 映射：3200K → -100, 5500K → 0, 7500K → +100
  return Math.max(-100, Math.min(100, (k - 5500) / 20))
}

/**
 * 构建相机 + 后期的 CSS filter 字符串（用于实时预览）
 * @param camera 相机参数
 * @param post 后期参数（可选，默认空对象）
 * @returns CSS filter 字符串，如 "brightness(1.3) contrast(1.1) saturate(1.2)"
 */
export function buildCssFilter(
  camera: Partial<CameraParams>,
  post: Partial<PostProcess> = {}
): string {
  const filters: string[] = []

  // ===== 相机参数 =====
  // EV → brightness
  const ev = camera.exposureCompensation ?? 0
  if (ev !== 0) {
    filters.push(`brightness(${(1 + ev / 3).toFixed(3)})`)
  }

  // 白平衡 → 色温（sepia + hue-rotate 模拟）
  if (camera.whiteBalance) {
    const t = temperatureOffset(camera.whiteBalance, camera.whiteBalanceK ?? 5500)
    if (t > 0) {
      // 暖：sepia 轻微增加 + hue-rotate 微负
      filters.push(`sepia(${(t / 200).toFixed(3)})`)
      filters.push(`hue-rotate(${(-t / 10).toFixed(1)}deg)`)
    } else if (t < 0) {
      // 冷：hue-rotate 正向 + saturate 轻微降低
      filters.push(`hue-rotate(${(-t / 5).toFixed(1)}deg)`)
      filters.push(`saturate(${(1 + t / 200).toFixed(3)})`)
    }
  }

  // ===== 后期参数 =====
  // 亮度（后期 brightness 与 EV 叠加）
  const brightness = post.color?.brightness ?? 0
  if (brightness !== 0) {
    filters.push(`brightness(${(1 + brightness / 100).toFixed(3)})`)
  }

  // 对比度
  const contrast = post.color?.contrast ?? 0
  if (contrast !== 0) {
    filters.push(`contrast(${(1 + contrast / 100).toFixed(3)})`)
  }

  // 饱和度
  const saturation = post.color?.saturation ?? 0
  if (saturation !== 0) {
    filters.push(`saturate(${(1 + saturation / 100).toFixed(3)})`)
  }

  // 色温（后期）
  const temp = post.color?.temperature ?? 0
  if (temp > 0) {
    filters.push(`sepia(${(temp / 200).toFixed(3)})`)
    filters.push(`hue-rotate(${(-temp / 10).toFixed(1)}deg)`)
  } else if (temp < 0) {
    filters.push(`hue-rotate(${(-temp / 5).toFixed(1)}deg)`)
  }

  // 色调
  const tint = post.color?.tint ?? 0
  if (tint !== 0) {
    filters.push(`hue-rotate(${(tint / 2).toFixed(1)}deg)`)
  }

  // LUT 预设（叠加在基础调整之后）
  const lut = post.lut ?? 'none'
  const lutFilter = LUT_FILTERS[lut] || ''
  if (lutFilter) {
    filters.push(lutFilter)
  }

  return filters.join(' ')
}

/**
 * 构建 Canvas 2D context 使用的 filter 字符串
 * Canvas filter 与 CSS filter 语法基本一致
 */
export function buildCanvasFilter(
  camera: Partial<CameraParams>,
  post: Partial<PostProcess> = {}
): string {
  return buildCssFilter(camera, post)
}

/**
 * 计算暗角强度（0-1，用于 Canvas 像素处理）
 */
export function getVignetteStrength(post: Partial<PostProcess>): number {
  return (post.vignette ?? 0) / 100
}

/**
 * 计算颗粒强度（0-1，用于 Canvas 像素处理）
 */
export function getGrainStrength(post: Partial<PostProcess>): number {
  return (post.grain ?? 0) / 100
}

/**
 * 计算锐化强度（0-1，用于 Canvas 卷积处理）
 */
export function getSharpenStrength(post: Partial<PostProcess>): number {
  return (post.sharpen ?? 0) / 100
}

/**
 * 磨皮强度（0-1，用于 Canvas 像素处理）
 */
export function getSmoothStrength(post: Partial<PostProcess>): number {
  return (post.smoothStrength ?? 0) / 100
}

/**
 * 获取 LUT 预设的显示名称
 */
export function getLutLabel(lut: LutPreset): string {
  const map: Record<LutPreset, string> = {
    none: '原图',
    cinematic: '电影感',
    vintage: '复古胶片',
    bw: '黑白',
    warm_film: '暖色胶片',
    cool_film: '冷色胶片',
    pastel: '柔色',
    fuji: '富士感'
  }
  return map[lut] || '原图'
}
