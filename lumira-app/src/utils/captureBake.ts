/**
 * 拍照烘焙工具（H5 端）
 *
 * 跨平台核心逻辑见 bakeCanvas.ts，
 * 本文件仅负责 H5 端的 canvas 创建与封装。
 *
 * 流程：
 * 1. document.createElement('canvas') 创建 H5 canvas
 * 2. 调用 bakePhotoForCanvas 完成绘制、滤镜、像素处理、导出
 * 3. 返回 dataURL 与元信息
 */

import type { CameraParams, PostProcess } from '@/types/template'
import { bakePhotoForCanvas } from './bakeCanvas'

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
 * H5 端实现：创建 DOM canvas，调用跨平台 bakePhotoForCanvas
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

      const dataUrl = bakePhotoForCanvas(
        canvas,
        ctx,
        source,
        sourceWidth,
        sourceHeight,
        camera,
        post,
        quality
      )
      // 估算大小：base64 长度 * 3/4
      const size = Math.floor((dataUrl.length - 22) * 3 / 4)

      resolve({ dataUrl, width: outputWidth, height: outputHeight, size })
    } catch (err) {
      reject(err)
    }
  })
}
