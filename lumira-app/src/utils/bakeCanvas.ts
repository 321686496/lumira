/**
 * 跨平台 canvas 烘焙核心函数
 *
 * H5 与 App-Plus（Android/iOS）共用同一逻辑。
 * 调用方负责创建对应平台的 canvas 与 2D context，
 * 再传入本函数完成绘制、滤镜应用、像素级处理与导出。
 *
 * 流程：
 * 1. ctx.filter 应用 CSS filter（含 ISO 修正）
 * 2. drawImage 将源绘制到 canvas
 * 3. 像素级处理：filter 降级、暗角、颗粒、锐化、磨皮
 * 4. toDataURL 导出为 JPEG dataURL
 */

import type { CameraParams, PostProcess } from '@/types/template'
import {
  buildCssFilter,
  getVignetteStrength,
  getGrainStrength,
  getSharpenStrength,
  getSmoothStrength
} from './filterRecipe'

/**
 * 跨平台 canvas 烘焙核心函数
 * H5 与 App-Plus 共用同一逻辑
 *
 * @param canvas 平台对应的 canvas 元素
 * @param ctx canvas 2D context
 * @param img 源图像（HTMLImageElement | HTMLVideoElement | HTMLCanvasElement | App-Plus 对应对象）
 * @param w 源宽度
 * @param h 源高度
 * @param camera 相机参数
 * @param post 后期参数
 * @param quality JPEG 质量 0-1，默认 0.92
 * @returns JPEG data URL
 */
export function bakePhotoForCanvas(
  canvas: any,
  ctx: any,
  img: any,
  w: number,
  h: number,
  camera: Partial<CameraParams>,
  post: Partial<PostProcess>,
  quality = 0.92
): string {
  if (!w || !h) {
    throw new Error('源尺寸无效')
  }

  // 1. CSS filter（含 ISO 修正）
  const filterStr = buildCssFilter(camera, post)
  let filterSupported = true
  try {
    ctx.filter = filterStr
  } catch {
    filterSupported = false
  }

  // 2. drawImage
  ctx.drawImage(img, 0, 0, w, h, 0, 0, w, h)
  ctx.filter = 'none'

  // 3. 像素级处理
  const vignette = getVignetteStrength(post)
  const grain = getGrainStrength(post, camera.iso)
  const sharpen = getSharpenStrength(post)
  const smooth = getSmoothStrength(post)

  if (!filterSupported || vignette > 0 || grain > 0 || sharpen > 0 || smooth > 0) {
    const imageData = ctx.getImageData(0, 0, w, h)
    const data = imageData.data

    // 降级：CSS filter 不支持时，应用像素级 filter 近似
    if (!filterSupported) {
      applyFilterFromPost(data, w, h, camera, post)
    }
    if (vignette > 0) applyVignette(data, w, h, vignette)
    if (grain > 0) applyGrain(data, w, h, grain)
    if (sharpen > 0) applySharpen(data, w, h, sharpen)
    if (smooth > 0) applySmooth(data, w, h, smooth)

    ctx.putImageData(imageData, 0, 0)
  }

  // 4. toDataURL
  return canvas.toDataURL('image/jpeg', quality)
}

/**
 * 像素级 filter 近似（ctx.filter 不支持时降级）
 * 仅处理亮度/对比度/饱和度/色温/ISO，复杂 LUT 不在此处理
 */
function applyFilterFromPost(
  data: Uint8ClampedArray,
  w: number,
  h: number,
  camera: Partial<CameraParams>,
  post: Partial<PostProcess>
): void {
  const brightness = post.color?.brightness ?? 0
  const contrast = post.color?.contrast ?? 0
  const saturation = post.color?.saturation ?? 0
  const temperature = post.color?.temperature ?? 0

  const bFactor = 1 + brightness / 100
  const cFactor = 1 + contrast / 100
  const sFactor = 1 + saturation / 100

  // ISO 修正
  const iso = camera.iso
  const isoBrightness = iso && iso > 200 ? 1 + (iso - 200) / 6400 * 0.3 : 1

  for (let i = 0; i < data.length; i += 4) {
    let r = data[i]
    let g = data[i + 1]
    let b = data[i + 2]

    // 亮度
    r *= bFactor * isoBrightness
    g *= bFactor * isoBrightness
    b *= bFactor * isoBrightness

    // 对比度
    r = (r - 128) * cFactor + 128
    g = (g - 128) * cFactor + 128
    b = (b - 128) * cFactor + 128

    // 饱和度
    const gray = 0.299 * r + 0.587 * g + 0.114 * b
    r = gray + (r - gray) * sFactor
    g = gray + (g - gray) * sFactor
    b = gray + (b - gray) * sFactor

    // 色温（暖色 +r -b，冷色 -r +b）
    const tempShift = temperature / 100
    r += tempShift
    b -= tempShift

    data[i] = clamp(r)
    data[i + 1] = clamp(g)
    data[i + 2] = clamp(b)
  }
}

/**
 * 暗角效果：边缘变暗
 */
function applyVignette(data: Uint8ClampedArray, w: number, h: number, strength: number): void {
  const cx = w / 2
  const cy = h / 2
  const maxDist = Math.sqrt(cx * cx + cy * cy)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const dx = x - cx
      const dy = y - cy
      const dist = Math.sqrt(dx * dx + dy * dy)
      const ratio = dist / maxDist
      if (ratio > 0.5) {
        const factor = 1 - (ratio - 0.5) * 2 * strength
        const idx = (y * w + x) * 4
        data[idx] = data[idx] * factor
        data[idx + 1] = data[idx + 1] * factor
        data[idx + 2] = data[idx + 2] * factor
      }
    }
  }
}

/**
 * 颗粒效果：随机噪点
 */
function applyGrain(data: Uint8ClampedArray, _w: number, _h: number, strength: number): void {
  const intensity = strength * 30
  for (let i = 0; i < data.length; i += 4) {
    const noise = (Math.random() - 0.5) * intensity
    data[i] = clamp(data[i] + noise)
    data[i + 1] = clamp(data[i + 1] + noise)
    data[i + 2] = clamp(data[i + 2] + noise)
  }
}

/**
 * 锐化：简单卷积核
 */
function applySharpen(data: Uint8ClampedArray, w: number, h: number, strength: number): void {
  const amount = strength * 2
  const kernel = [
    0, -amount, 0,
    -amount, 1 + 4 * amount, -amount,
    0, -amount, 0
  ]
  const src = new Uint8ClampedArray(data)
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const idx = (y * w + x) * 4
      for (let c = 0; c < 3; c++) {
        let sum = 0
        for (let ky = 0; ky < 3; ky++) {
          for (let kx = 0; kx < 3; kx++) {
            const px = x + kx - 1
            const py = y + ky - 1
            const pIdx = (py * w + px) * 4 + c
            sum += src[pIdx] * kernel[ky * 3 + kx]
          }
        }
        data[idx + c] = clamp(sum)
      }
    }
  }
}

/**
 * 磨皮：简单盒式模糊（降低高频细节）
 */
function applySmooth(data: Uint8ClampedArray, w: number, h: number, strength: number): void {
  const radius = Math.max(1, Math.floor(strength * 3))
  const src = new Uint8ClampedArray(data)
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const idx = (y * w + x) * 4
      let r = 0, g = 0, b = 0, count = 0
      for (let dy = -radius; dy <= radius; dy++) {
        for (let dx = -radius; dx <= radius; dx++) {
          const px = x + dx
          const py = y + dy
          if (px >= 0 && px < w && py >= 0 && py < h) {
            const pIdx = (py * w + px) * 4
            r += src[pIdx]
            g += src[pIdx + 1]
            b += src[pIdx + 2]
            count++
          }
        }
      }
      const mix = strength * 0.6
      data[idx] = clamp(src[idx] * (1 - mix) + (r / count) * mix)
      data[idx + 1] = clamp(src[idx + 1] * (1 - mix) + (g / count) * mix)
      data[idx + 2] = clamp(src[idx + 2] * (1 - mix) + (b / count) * mix)
    }
  }
}

/** 限制 0-255 */
function clamp(v: number): number {
  return v < 0 ? 0 : v > 255 ? 255 : v
}
