/**
 * 相机组合式函数（跨平台）
 *
 * - H5：使用 getUserMedia + <video> 元素
 * - App-Plus：使用 uni.createCameraContext
 * - 小程序：使用 <camera> 组件（需要在 template 中放置）
 *
 * 统一接口：
 * - startPreview() 启动预览
 * - stopPreview() 停止预览
 * - capture() 拍照（截帧 → Canvas 烘焙 → dataURL）
 * - switchCamera() 切换前后置
 * - setFlash() 设置闪光灯
 * - release() 释放资源
 */

import { ref, onUnmounted } from 'vue'
import { bakePhoto, type BakeResult } from '@/utils/captureBake'
import type { CameraParams, PostProcess, FlashMode } from '@/types/template'

export type CameraFacing = 'front' | 'back'
export type CameraPlatform = 'h5' | 'app-plus' | 'mp'

export interface UseCameraOptions {
  /** 初始前后置 */
  facing?: CameraFacing
  /** 初始闪光灯模式 */
  flash?: FlashMode
  /** 平台（自动检测） */
  platform?: CameraPlatform
}

export function useCamera(options: UseCameraOptions = {}) {
  const facing = ref<CameraFacing>(options.facing || 'back')
  const flashMode = ref<FlashMode>(options.flash || 'off')
  const isReady = ref(false)
  const hasPermission = ref(false)
  const error = ref<string>('')

  // H5 平台的视频元素和 MediaStream
  let videoEl: HTMLVideoElement | null = null
  let mediaStream: MediaStream | null = null

  // 检测平台
  const platform: CameraPlatform = (() => {
    if (options.platform) return options.platform
    // #ifdef H5
    return 'h5'
    // #endif
    // #ifdef APP-PLUS
    return 'app-plus'
    // #endif
    // #ifdef MP
    return 'mp'
    // #endif
    return 'h5'
  })()

  /**
   * 绑定视频元素（H5 平台）
   * 在 onMounted 中调用，传入 <video> ref
   */
  function bindVideoElement(el: HTMLVideoElement) {
    videoEl = el
  }

  /**
   * 启动相机预览
   */
  async function startPreview(): Promise<void> {
    error.value = ''
    if (platform === 'h5') {
      return startH5Preview()
    }
    // App-Plus / 小程序需要在 template 中放置 <camera> 组件
    // 这里仅标记就绪
    isReady.value = true
    hasPermission.value = true
  }

  /** H5 平台预览 */
  async function startH5Preview(): Promise<void> {
    if (!navigator.mediaDevices?.getUserMedia) {
      error.value = '当前浏览器不支持相机 API'
      return
    }

    try {
      const constraints: MediaStreamConstraints = {
        video: {
          facingMode: facing.value === 'front' ? 'user' : 'environment',
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        },
        audio: false
      }

      mediaStream = await navigator.mediaDevices.getUserMedia(constraints)
      hasPermission.value = true

      if (videoEl) {
        videoEl.srcObject = mediaStream
        await videoEl.play()
      }
      isReady.value = true
    } catch (err) {
      const e = err as DOMException
      if (e.name === 'NotAllowedError') {
        error.value = '相机权限被拒绝，请在浏览器设置中允许'
      } else if (e.name === 'NotFoundError') {
        error.value = '未找到相机设备'
      } else {
        error.value = `相机启动失败: ${e.message || e.name}`
      }
      hasPermission.value = false
      isReady.value = false
    }
  }

  /**
   * 停止预览
   */
  async function stopPreview(): Promise<void> {
    if (platform === 'h5') {
      if (mediaStream) {
        mediaStream.getTracks().forEach(t => t.stop())
        mediaStream = null
      }
      if (videoEl) {
        videoEl.srcObject = null
      }
    }
    isReady.value = false
  }

  /**
   * 拍照：截取当前帧 + 应用所有滤镜 + 烘焙为 dataURL
   * @param camera 相机参数
   * @param post 后期参数
   * @returns BakeResult（含 dataUrl）
   */
  async function capture(
    camera: Partial<CameraParams>,
    post: Partial<PostProcess>
  ): Promise<BakeResult> {
    if (!isReady.value) {
      throw new Error('相机未就绪')
    }

    if (platform === 'h5' && videoEl) {
      const sw = videoEl.videoWidth
      const sh = videoEl.videoHeight
      if (!sw || !sh) {
        throw new Error('视频流尚未就绪')
      }
      return bakePhoto({
        source: videoEl,
        sourceWidth: sw,
        sourceHeight: sh,
        camera,
        post,
        outputWidth: sw,
        outputHeight: sh,
        quality: 0.92
      })
    }

    // App-Plus / 小程序平台：通过组件 API 拍照
    // TODO: 实现 createCameraContext.takePhoto 的调用
    throw new Error('当前平台暂不支持拍照')
  }

  /**
   * 切换前后置摄像头
   */
  async function switchCamera(): Promise<void> {
    facing.value = facing.value === 'front' ? 'back' : 'front'
    if (platform === 'h5') {
      // H5 需要重新获取流
      await stopPreview()
      await startPreview()
    }
  }

  /**
   * 设置闪光灯模式
   */
  function setFlash(mode: FlashMode): void {
    flashMode.value = mode
    if (platform === 'h5' && mediaStream) {
      // H5 通过 torch 约束控制
      const videoTrack = mediaStream.getVideoTracks()[0]
      if (videoTrack) {
        const capabilities = videoTrack.getCapabilities?.() as MediaTrackCapabilities & { torch?: boolean }
        if (capabilities?.torch) {
          videoTrack.applyConstraints({
            advanced: [{ torch: mode === 'torch' || mode === 'on' } as MediaTrackConstraintSet]
          }).catch(() => {})
        }
      }
    }
  }

  /**
   * 释放所有资源
   */
  async function release(): Promise<void> {
    await stopPreview()
    videoEl = null
  }

  // 组件卸载时自动清理
  onUnmounted(() => {
    release().catch(() => {})
  })

  return {
    facing,
    flashMode,
    isReady,
    hasPermission,
    error,
    platform,
    bindVideoElement,
    startPreview,
    stopPreview,
    capture,
    switchCamera,
    setFlash,
    release
  }
}
