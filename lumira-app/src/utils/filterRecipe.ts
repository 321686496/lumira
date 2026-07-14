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

import type { CameraParams, PostProcess, LutPreset, WhiteBalance, SystemFilter } from '@/types/template'

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
  fuji: 'saturate(1.2) contrast(1.05) hue-rotate(-3deg) brightness(1.02)',
  // 新增 8 种
  portrait: 'saturate(1.05) contrast(1.05) brightness(1.03) sepia(0.05)',
  japanese: 'saturate(0.85) contrast(0.92) brightness(1.1) hue-rotate(3deg)',
  cyberpunk: 'saturate(1.4) contrast(1.2) hue-rotate(-15deg) brightness(0.95)',
  sepia_classic: 'sepia(0.7) contrast(1.05) brightness(1.02)',
  mist: 'contrast(0.88) brightness(1.12) saturate(0.9)',
  rouge: 'sepia(0.2) saturate(1.1) hue-rotate(-10deg) brightness(1.02)',
  twilight: 'saturate(1.15) hue-rotate(15deg) contrast(1.05) brightness(0.95)',
  cyan: 'saturate(1.1) hue-rotate(20deg) contrast(1.05) brightness(1.02)'
}

/** 系统内置滤镜（苹果风格）对应的 filter */
export const SYSTEM_FILTERS: Record<SystemFilter, string> = {
  none: '',
  vivid: 'contrast(1.1) saturate(1.25) brightness(1.02)',
  vivid_warm: 'sepia(0.15) saturate(1.2) contrast(1.08) brightness(1.03) hue-rotate(-5deg)',
  vivid_cool: 'saturate(1.15) contrast(1.08) brightness(1.02) hue-rotate(8deg)',
  mono: 'grayscale(1) contrast(1.05)',
  silver: 'grayscale(1) sepia(0.2) contrast(0.95) brightness(1.08)',
  noir: 'grayscale(1) contrast(1.3) brightness(0.95)'
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
 * 使用更陡的映射曲线让效果更明显
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
  // EV → brightness（-3 ~ +3 → 0.4 ~ 1.6）
  const ev = camera.exposureCompensation ?? 0
  if (ev !== 0) {
    filters.push(`brightness(${(1 + ev / 3).toFixed(3)})`)
  }

  // 白平衡 → 色温（sepia + hue-rotate 组合模拟）
  if (camera.whiteBalance) {
    const t = temperatureOffset(camera.whiteBalance, camera.whiteBalanceK ?? 5500)
    if (t > 0) {
      // 暖：sepia + hue-rotate 负向（让黄色更明显）
      filters.push(`sepia(${(t / 100).toFixed(3)})`)
      filters.push(`hue-rotate(${(-t / 5).toFixed(1)}deg)`)
      filters.push(`saturate(${(1 + t / 200).toFixed(3)})`)
    } else if (t < 0) {
      // 冷：hue-rotate 正向 + saturate 降低
      filters.push(`hue-rotate(${(-t / 3).toFixed(1)}deg)`)
      filters.push(`saturate(${(1 + t / 150).toFixed(3)})`)
      filters.push(`brightness(${(1 + t / 300).toFixed(3)})`)
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

  // 色温（后期，-100 ~ 100）
  const temp = post.color?.temperature ?? 0
  if (temp > 0) {
    // 暖色温：sepia + hue-rotate 负向 + saturate 提升
    filters.push(`sepia(${(temp / 100).toFixed(3)})`)
    filters.push(`hue-rotate(${(-temp / 5).toFixed(1)}deg)`)
    filters.push(`saturate(${(1 + temp / 200).toFixed(3)})`)
  } else if (temp < 0) {
    // 冷色温：hue-rotate 正向 + saturate 降低 + brightness 微降
    filters.push(`hue-rotate(${(-temp / 3).toFixed(1)}deg)`)
    filters.push(`saturate(${(1 + temp / 150).toFixed(3)})`)
    filters.push(`brightness(${(1 + temp / 300).toFixed(3)})`)
  }

  // 色调（-100 ~ 100 → -90deg ~ 90deg）
  const tint = post.color?.tint ?? 0
  if (tint !== 0) {
    filters.push(`hue-rotate(${(tint * 0.9).toFixed(1)}deg)`)
  }

  // 系统内置滤镜（在 LUT 之前应用，类似苹果原相机滤镜）
  const systemFilter = post.systemFilter ?? 'none'
  const systemFilterStr = SYSTEM_FILTERS[systemFilter] || ''
  if (systemFilterStr) {
    filters.push(systemFilterStr)
  }

  // LUT 预设（叠加在系统滤镜之后）
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
    fuji: '富士感',
    portrait: '人像',
    japanese: '日系',
    cyberpunk: '赛博朋克',
    sepia_classic: '褐调',
    mist: '薄雾',
    rouge: '胭脂',
    twilight: '暮光',
    cyan: '青调'
  }
  return map[lut] || '原图'
}

/**
 * 获取系统内置滤镜的显示名称
 */
export function getSystemFilterLabel(filter: SystemFilter): string {
  const map: Record<SystemFilter, string> = {
    none: '原图',
    vivid: '鲜明',
    vivid_warm: '鲜暖色',
    vivid_cool: '鲜冷色',
    mono: '单色',
    silver: '银色调',
    noir: '黑白'
  }
  return map[filter] || '原图'
}

/**
 * 获取所有系统滤镜选项（用于 UI 渲染）
 */
export function getSystemFilterOptions(): { id: SystemFilter; name: string; filter: string }[] {
  return (Object.keys(SYSTEM_FILTERS) as SystemFilter[]).map((id) => ({
    id,
    name: getSystemFilterLabel(id),
    filter: SYSTEM_FILTERS[id]
  }))
}

/**
 * 获取所有 LUT 预设选项（用于 UI 渲染）
 */
export function getLutOptions(): { id: LutPreset; name: string; filter: string }[] {
  return (Object.keys(LUT_FILTERS) as LutPreset[]).map((id) => ({
    id,
    name: getLutLabel(id),
    filter: LUT_FILTERS[id]
  }))
}
