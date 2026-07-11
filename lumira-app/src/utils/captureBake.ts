/**
 * 拍照烘焙工具
 *
 * 将视频帧/图片源绘制到 Canvas，应用所有滤镜效果，
 * 然后导出为 dataURL。保证按下快门生成的照片包含所有调整效果。
 *
 * 流程：
 * 1. drawImage 将源绘制到 Canvas
 * 2. ctx.filter 应用 CSS filter（亮度/对比度/饱和度/色温/LUT）
 * 3. 像素级处理：暗角、颗粒、锐化、磨皮
 * 4. 导出为 dataURL（JPEG）
 */

import type { CameraParams, PostProcess } from '@/types/template'
import {
  buildCanvasFilter,
  getVignetteStrength,
  getGrainStrength,
  getSharpenStrength,
  getSmoothStrength
} from './filterRecipe'

/** 烘焙输入参数 */
export interface BakeInput {
  /** 源图/视频元素（HTMLImageElement | HTMLVideoElement | HTMLCanvasElement） */
  source: HTMLImageElement | HTMLVideoElement | HTMLCanvasElement
  /** 源宽度（视频时为 videoWidth，图片时为 naturalWidth） */
  sourceWidth: number
  /** 源高度 */
  sourceHeight: number
  /** 相机参数 */
  camera: Partial<CameraParams>
  /** 后期参数 */
  post: Partial<PostProcess>
  /** 输出宽度（默认 = 源宽度） */
  outputWidth?: number
  /** 输出高度（默认 = 源高度） */
  outputHeight?: number
  /** JPEG 质量 0-1（默认 0.92） */
  quality?: number
}

/** 烘焙结果 */
export interface BakeResult {
  /** data URL */
  dataUrl: string
  /** 宽度 */
  width: number
  /** 高度 */
  height: number
  /** 文件大小（字节，估算） */
  size: number
}

/**
 * 烘焙照片：从源元素截取一帧，应用所有滤镜，导出为 dataURL
 */
export function bakePhoto(input: BakeInput): Promise<BakeResult> {
  return new Promise((resolve, reject) => {
    const {
      source,
      sourceWidth,
      sourceHeight,
      camera,
      post,
      outputWidth = sourceWidth,
      outputHeight = sourceHeight,
      quality = 0.92
    } = input

    if (!sourceWidth || !sourceHeight) {
      reject(new Error('源尺寸无效'))
      return
    }

    try {
      const canvas = document.createElement('canvas')
      canvas.width = outputWidth
      canvas.height = outputHeight
      const ctx = canvas.getContext('2d')
      if (!ctx) {
        reject(new Error('Canvas 2D context 不可用'))
        return
      }

      // 1. 应用 CSS filter（brightness/contrast/saturate/hue-rotate/sepia/LUT）
      const filterStr = buildCanvasFilter(camera, post)
      if (filterStr) {
        // Canvas 2D filter 属性在部分浏览器支持
        ;(ctx as unknown as { filter: string }).filter = filterStr
      }

      // 2. 绘制源到 Canvas
      ctx.drawImage(source, 0, 0, sourceWidth, sourceHeight, 0, 0, outputWidth, outputHeight)

      // 重置 filter，后续做像素级处理
      ;(ctx as unknown as { filter: string }).filter = 'none'

      // 3. 像素级处理：暗角 / 颗粒 / 锐化 / 磨皮
      const vignette = getVignetteStrength(post)
      const grain = getGrainStrength(post)
      const sharpen = getSharpenStrength(post)
      const smooth = getSmoothStrength(post)

      if (vignette > 0 || grain > 0 || sharpen > 0 || smooth > 0) {
        const imageData = ctx.getImageData(0, 0, outputWidth, outputHeight)
        const data = imageData.data

        if (vignette > 0) applyVignette(data, outputWidth, outputHeight, vignette)
        if (grain > 0) applyGrain(data, outputWidth, outputHeight, grain)
        if (sharpen > 0) applySharpen(data, outputWidth, outputHeight, sharpen)
        if (smooth > 0) applySmooth(data, outputWidth, outputHeight, smooth)

        ctx.putImageData(imageData, 0, 0)
      }

      // 4. 导出为 dataURL
      const dataUrl = canvas.toDataURL('image/jpeg', quality)
      // 估算大小：base64 长度 * 3/4
      const size = Math.floor((dataUrl.length - 22) * 3 / 4)

      resolve({ dataUrl, width: outputWidth, height: outputHeight, size })
    } catch (err) {
      reject(err)
    }
  })
}

/**
 * 暗角效果：边缘变暗
 */
function applyVignette(
  data: Uint8ClampedArray,
  width: number,
  height: number,
  strength: number
): void {
  const cx = width / 2
  const cy = height / 2
  const maxDist = Math.sqrt(cx * cx + cy * cy)

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const dx = x - cx
      const dy = y - cy
      const dist = Math.sqrt(dx * dx + dy * dy)
      // 0.5 以下不变，0.5-1.0 线性变暗
      const ratio = dist / maxDist
      if (ratio > 0.5) {
        const factor = 1 - (ratio - 0.5) * 2 * strength
        const idx = (y * width + x) * 4
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
function applyGrain(
  data: Uint8ClampedArray,
  width: number,
  height: number,
  strength: number
): void {
  const intensity = strength * 30 // 最大 ±30
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
function applySharpen(
  data: Uint8ClampedArray,
  width: number,
  height: number,
  strength: number
): void {
  // 锐化卷积核
  const amount = strength * 2
  const kernel = [
    0, -amount, 0,
    -amount, 1 + 4 * amount, -amount,
    0, -amount, 0
  ]
  const src = new Uint8ClampedArray(data)
  const kSize = 3
  const kHalf = 1

  for (let y = kHalf; y < height - kHalf; y++) {
    for (let x = kHalf; x < width - kHalf; x++) {
      const idx = (y * width + x) * 4
      for (let c = 0; c < 3; c++) {
        let sum = 0
        for (let ky = 0; ky < kSize; ky++) {
          for (let kx = 0; kx < kSize; kx++) {
            const px = x + kx - kHalf
            const py = y + ky - kHalf
            const pIdx = (py * width + px) * 4 + c
            sum += src[pIdx] * kernel[ky * kSize + kx]
          }
        }
        data[idx + c] = clamp(sum)
      }
    }
  }
}

/**
 * 磨皮：简单模糊（降低高频细节）
 */
function applySmooth(
  data: Uint8ClampedArray,
  width: number,
  height: number,
  strength: number
): void {
  const radius = Math.max(1, Math.floor(strength * 3))
  const src = new Uint8ClampedArray(data)

  // 简单盒式模糊
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * 4
      let r = 0, g = 0, b = 0, count = 0

      for (let dy = -radius; dy <= radius; dy++) {
        for (let dx = -radius; dx <= radius; dx++) {
          const px = x + dx
          const py = y + dy
          if (px >= 0 && px < width && py >= 0 && py < height) {
            const pIdx = (py * width + px) * 4
            r += src[pIdx]
            g += src[pIdx + 1]
            b += src[pIdx + 2]
            count++
          }
        }
      }

      // 混合原始值与模糊值（strength 控制混合比例）
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
