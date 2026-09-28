/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { Any, SurfaceTextureEntry, TextureRegistry } from '@ohos/flutter_ohos'
import { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel'
import { camera } from '@kit.CameraKit'
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit'
import Logger from '../utils/Logger'
import { Constant } from '../utils/Constant'
import CameraUtils from '../utils/CameraUtils'
import { ExifPreferences, PreviewSize, Result } from '../cameraX/Pigeon'
import { AspectRatio, ImageAnalysisBuilder } from '../cameraX/ImageAnalysisBuilder'
import { abilityAccessCtrl, Permissions, UIAbility } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import { fileIo } from '@kit.CoreFileKit'
import { media } from '@kit.MediaKit'
import { Constants } from '../cameraX/Constants'
import { sensor } from '@kit.SensorServiceKit'
import { geoLocationManager } from '@kit.LocationKit'
import { ArkTSUtils, Decimal } from '@kit.ArkTS'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { display } from '@kit.ArkUI'
import { colorSpaceManager } from '@kit.ArkGraphics2D'
import { CameraDeviceChangeListener } from '../sensors/CameraDeviceChangeListener'
// 取景器实时特效 GPU 管线（libpreview_fx.so）：相机预览流→GL 着色器→Flutter Texture。
// 数值语义与 iOS PreviewEffectProcessor 一致（磨皮/锐化/颗粒/暗角/色彩矩阵 WYSIWYG）。
import previewFx from 'libpreview_fx.so'

export enum CaptureMode {
  PHOTO = 'PHOTO',
  VIDEO = 'VIDEO',
  PREVIEW = 'PREVIEW',
  ANALYSIS_ONLY = 'ANALYSIS_ONLY'
}

export enum ConstantsPreview {
  PREVIEW_980 = 980,
  PREVIEW_1080 = 1080,
  PREVIEW_1440 = 1440,
  PREVIEW_1920 = 1920,
  PREVIEW_4096 = 4096,
  PREVIEW_2448 = 2448
}

// 单次拍照请求的连拍安全上下文（FIFO 队列元素）。
// 原单槽位状态（_photoPath/_photoResult/_photoDirectDone）在连拍时会被后一次
// takePhoto 覆盖：photoAvailable 帧写错路径、photoAssetAvailable 与错误的
// path/result 配对，部分照片回退相册增强管线且内容错位/方向异常。
// 队列化后每帧事件按拍照发起顺序与各自 ctx 配对。
export interface PhotoCaptureContext {
  path: string
  result: Result<boolean>
  // photoAvailable 已直出写盘成功标记，同帧 photoAssetAvailable 据此跳过增强回退
  // （避免增强图覆盖原始 JPEG）。注意它只表达「直出成功」，不表达「result 已回调」
  // ——后者由 settled 承担（直出失败时 directDone 会被复位为 false，但 result 已回）。
  directDone: boolean
  // 本帧早帧 fd 直拷落盘的原始 JPEG 路径（见 deliverEarlyFrameFromAsset）。
  // 本设备 photoAvailable 不触发，该文件即「未经相册增强的原始全尺寸 JPEG」；
  // 增强交付看门狗超时时据此把成片降级为原始 JPEG，避免 Dart 侧 10s 超时。
  earlyFramePath?: string
  // result 是否已回调（恰好一次收口）。所有回调路径统一走 settleCaptureCtx：
  // 注意 directDone 不能在「失败」场景兼任该语义——photoAvailable 写盘失败时会
  // 把 directDone 复位为 false 并已回调 success(false)，若只看 directDone，
  // 随后的增强兜底会再次回调 result（Pigeon 二次 reply）。
  settled?: boolean
}

/**
 * 本帧 result 恰好一次的收口：所有成功/失败/兜底路径统一经此回调。
 * 首次调用生效，后续调用静默忽略，杜绝 Pigeon Result 二次 success/error。
 */
function settleCaptureCtx(ctx: PhotoCaptureContext, ok: boolean): void {
  if (ctx.settled === true) {
    return
  }
  ctx.settled = true
  ctx.result.success(ok)
}

// 增强兜底交付的串行队列元素（一次仅一个在飞，见 drainEnhancedQueue）。
export interface EnhancedDeliveryItem {
  photoAsset: photoAccessHelper.PhotoAsset
  path: string
  result: Result<boolean>
  ctx: PhotoCaptureContext | undefined
  // result 是否已结算（交付成功 / 看门狗兜底 / 跳过覆盖）：守卫 result 恰好一次。
  settled: boolean
  // 看门狗定时器 id。修复⑥：不再「入队即起算 7s 固定值」，而是在请求真正开始
  // （离开排队、进入在飞）时按「在飞预算」重挂，同时受「入队绝对截止时间」约束。
  watchdogId: number | undefined
  // 入队时刻（ms）。用于算「入队绝对截止时间」：无论排队多久，入队→交付都不许超过它，
  // 否则会撞上 Dart 侧 10s 超时。
  enqueuedAtMs: number
  // 在飞请求的 handler 引用：必须被持有到交付结束，避免被回收后 onDataPrepared 丢失。
  handler?: MediaDataHandler
}

const TAG: string = 'CameraState'

// 后置相机会话的活动色彩空间（模块级持久，跨 CameraState 实例存活）。
// setupCamera 每次创建新的 CameraState，若用实例字段，App 直接以前置启动
// （持久化 facing）时后置参考将永远缺失，前置色彩空间对齐无法生效。
let backActiveColorSpace: number = -1

export class CameraState implements StreamHandler {
  private events: EventSink | null = null
  private textureEntry: SurfaceTextureEntry | undefined = undefined
  private surfaceId: number = -1
  private uiAbility: UIAbility | undefined = undefined
  private cameraManager: camera.CameraManager | undefined = undefined
  private cameraDevice: camera.CameraDevice | undefined = undefined
  // 相机会话
  private session: camera.PhotoSession | camera.VideoSession | undefined = undefined;
  private cameraInput: camera.CameraInput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  private previewOutput1: camera.PreviewOutput | undefined = undefined;
  private photoOutput: camera.PhotoOutput | undefined = undefined;
  private videoOutput: camera.VideoOutput | undefined = undefined;
  private avRecorder: media.AVRecorder | undefined = undefined;
  private _captureMode: string = CaptureMode.PHOTO
  private _enableImageStream: boolean = false
  private _exifPreferences: ExifPreferences = new ExifPreferences(false)
  private _sensor: string = 'BACK'
  private _aspectRatio: string = AspectRatio.RATIO_4_3
  private zoom: number = 0
  private _mirrorFrontCamera: boolean = false
  // AE 锁定（长按 AE/AF）状态与锁定时的测光点：
  // OHOS 在 EXPOSURE_MODE_LOCKED 下 setExposureBias 不生效，锁定后用户拖动曝光
  // 需按「回 AUTO 应用新 EV → 用同一测光点重新锁定」处理（见 setExposureBias）。
  private _aeLocked: boolean = false
  private _aeLockPoint: camera.Point | undefined = undefined
  private enablePhysicalButton: boolean = false
  private flashMode: string = 'AUTO'
  private isRecording: boolean = false;
  private _videoPath: string | undefined = undefined
  private _enableAudioRecording: boolean = true
  private previewProfilesArray: Array<camera.Profile> | undefined = undefined
  private photoProfilesArray: Array<camera.Profile> | undefined = undefined
  private _colorMatrix: Array<number> = []
  private _imageAnalysisBuilder: ImageAnalysisBuilder | undefined = undefined
  // 拍照结果监听（photoAssetAvailable 增强兜底时调用，按队列配对的本帧
  // path/result 落盘，不由注入方闭包捕获——连拍时闭包会被后一次调用覆盖）。
  // ctx 透传本帧请求上下文：增强交付在途期间若 photoAvailable 直出完成
  // （directDone 置位），onEnhancedDataPrepared 据此跳过增强图写盘、且不重复回调
  // result，防止覆盖原始 JPEG / Pigeon Result 二次回调。
  private _handlePhotoCb: (photoAsset: photoAccessHelper.PhotoAsset, path: string, result: Result<boolean>, ctx?: PhotoCaptureContext) => void = () => {
  }
  // 连拍安全的拍照请求队列（替代原单槽位 _photoPath/_photoResult/_photoDirectDone）：
  // - directQueue 供 photoAvailable 逐帧消费（直出原始 JPEG 写盘）；
  // - assetQueue 供 photoAssetAvailable 逐帧消费（直出失败的帧走增强兜底）。
  // 两通道各自按拍照发起顺序保序，与框架事件到达的交错顺序无关。
  private _photoDirectQueue: PhotoCaptureContext[] = []
  private _photoAssetQueue: PhotoCaptureContext[] = []
  // 增强兜底交付串行闸门（修复④）：实测本机 MediaAssetManager.requestImageData
  // 仅在「单请求在飞」时回调 onDataPrepared——单张时 2.1s 交付成功，多个并发在飞
  // 时全部不交付（连拍 5 张全部 10s 超时的直接原因）。修复③ 移除单槽位
  // photoRequestId 守卫后，增强交付从「单发」退化为「并发」，故在此显式恢复：
  // FIFO 队列 + 一次仅一个 requestImageData 在飞。
  private _enhancedQueue: EnhancedDeliveryItem[] = []
  private _enhancedInFlightItem: EnhancedDeliveryItem | undefined = undefined
  // 单帧交付看门狗（ms），自「请求真正开始（进入在飞）」起算——修复⑥。
  // 修复⑤真机日志证明：入队即起算会被「排队等待」白吃掉预算（4 连拍时第 4 帧的请求
  // 刚发出 64ms 就被看门狗开火，而它的 onDataPrepared 在 3.35s 后才到达、本可成功）。
  // 改为在飞起算后，排队多久都不影响单帧的在飞预算。
  private _enhancedWatchdogMs: number = 7000
  // 入队绝对截止（ms）：自入队起算。无论排队 + 在飞多久，都必须在此之前回 result，
  // 否则撞上 Dart 侧 10s 超时（实测兜底拷贝仅 ~30ms，故 9s 留足余量）。
  private _enhancedQueueDeadlineMs: number = 9000
  // 分阶段拍照：一阶段低质量帧（水印动画源）数据请求 id 与早帧监听器引用。
  // 每次拍照复位，防止上一帧残留导致本帧早帧请求被误跳过。
  private _earlyFrameRequestId: string | undefined = undefined
  // 惰性解析：早帧送达时才取 listener.events（Dart 拍照前订阅通道后才非空）。
  private _photoEarlyFrameListener: PhotoEarlyFrameStreamListener | null = null
  private videoFd: number | undefined = undefined
  private degree: number = 0;
  // 重力传感器常驻订阅标记（订阅中 degree 由回调持续刷新缓存）。
  private _degreeSubscribed: boolean = false
  // 取景器实时特效管线：相机预览写入 FX 消费端 surface（OH_NativeImage），
  // 渲染线程 GL 处理后输出到 Flutter 纹理 surface。0 = 未创建/失败（直写回退）。
  private previewFxSurfaceId: number = 0
  private previewProfile: camera.Profile | undefined = undefined
  private cameraPosition: camera.CameraPosition | undefined = undefined
  private _cameraDeviceChangeListener: CameraDeviceChangeListener | undefined = undefined
  private _supportedCameras: Array<camera.CameraDevice> | undefined = undefined
  lock_: ArkTSUtils.locks.AsyncLock = new ArkTSUtils.locks.AsyncLock();

  constructor(uiAbility: UIAbility, textureRegistry: TextureRegistry, textureId: number, sensor: string,
    aspectRatio: string, zoom: number,
    mirrorFrontCamera: boolean, enablePhysicalButton: boolean, flashMode: string, captureMode: string,
    enableImageStream: boolean,
    exifPreferences: ExifPreferences) {
    this.uiAbility = uiAbility
    this.textureEntry = textureRegistry!!.registerTexture(textureId)
    this.surfaceId = this.textureEntry.getSurfaceId()
    this._sensor = sensor
    this._aspectRatio = aspectRatio
    this.zoom = zoom
    this._mirrorFrontCamera = mirrorFrontCamera
    this.enablePhysicalButton = enablePhysicalButton
    this.flashMode = flashMode
    this._captureMode = captureMode
    this.enableImageStream = enableImageStream
    this._exifPreferences = exifPreferences
  }

  onListen(args: Any, events: EventSink): void {
    this.imageAnalysisBuilder!!.previewStreamSink = events
  }

  onCancel(args: Any): void {
    if (this.events != null) {
      this.imageAnalysisBuilder!!.previewStreamSink!!.endOfStream()
      this.imageAnalysisBuilder!!.previewStreamSink = undefined
    }
  }

  public getCameraManager(): camera.CameraManager | undefined {
    return this.cameraManager;
  }

  public get cameraDeviceChangeListener(): CameraDeviceChangeListener | undefined {
    return this._cameraDeviceChangeListener;
  }

  public set cameraDeviceChangeListener(arg: CameraDeviceChangeListener | undefined) {
    this._cameraDeviceChangeListener = arg;
  }

  public get supportedCameras(): Array<camera.CameraDevice> | undefined {
    return this._supportedCameras;
  }

  /**
   * 初始化相机
   *
   * @param sensor 相机位置
   * @param aspectRatio 纵横比
   * @param zoom 缩放比
   * @param mirrorFrontCamera 是否镜像拍照
   * @param enablePhysicalButton 是否支持物理按钮
   * @param flashMode 闪光灯模式
   * @param captureMode 捕捉模式
   * @param enableImageStream 启用图像流
   * @param exifPreferences 是否保存GPS信息
   * @returns
   */
  async initCamera(): Promise<boolean> {
    return this.lock_.lockAsync(async () => {
      await this.releaseCamera()
      // 重力传感器常驻订阅：持续缓存设备旋转角，takePhoto 关键路径
      // 不再等待一次性传感器读数（sensor.once 从发起到回包可达数十至数百 ms）。
      this.startDegreeSensor()
      // 获取相机管理器实例
      if (!this.cameraManager) {
        this.cameraManager = this.getCameraManagerFn();
      }

      if (this.cameraManager === undefined) {
        Logger.error(TAG, 'cameraManager is undefined');
        return false;
      }

      // 获取支持指定的相机设备对象
      this.cameraDevice = this.getCameraDevice(this._sensor)

      // 创建相机输入流
      try {
        this.cameraInput = this.cameraManager.createCameraInput(this.cameraDevice);
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(TAG, 'Failed to createCameraInput errorCode = ' + err.code);
      }
      if (this.cameraInput === undefined) {
        return false;
      }

      // 监听cameraInput错误信息
      this.cameraInput.on('error', this.cameraDevice, (error: BusinessError) => {
        Logger.error(`Camera input error code: ${error.code}`);
      })

      // 打开相机
      await this.cameraInput.open();

      let isPhotosorVideos = false;
      if (this.captureMode === CaptureMode.VIDEO && this._videoPath) {
        isPhotosorVideos = await this.videoConfig();
      } else {
        isPhotosorVideos = await this.photoConfig();
      }

      if (!isPhotosorVideos) {
        return false;
      }

      // 如果图像分析，需要创建第二路预览流
      if (this.enableImageStream && this.imageAnalysisBuilder) {
        // 创建预览输出流,其中参数 surfaceId 参考上文 XComponent 组件，预览流为XComponent组件提供的surface
        try {
          if (this.imageAnalysisBuilder.surfaceId) {
            this.previewOutput1 =
              this.cameraManager!.createPreviewOutput(this.previewProfile,
                this.imageAnalysisBuilder.surfaceId)
            Logger.debug(TAG, 'previewOutput1 is created!');
          } else {
            this.imageAnalysisBuilder.initCameraFun = this.initCamera
            Logger.debug(TAG, 'previewOutput1 is created err, surfaceId is null!');
            return false
          }
        } catch (error) {
          let err = error as BusinessError;
          Logger.error(TAG, `Failed to create the PreviewOutput1 instance. error code: ${err.code}`);
        }
      }

      //创建会话
      try {
        if (this.captureMode === CaptureMode.VIDEO && this._videoPath) {
          this.session = this.cameraManager!.createSession(camera.SceneMode.NORMAL_VIDEO) as camera.VideoSession;
        } else {
          this.session = this.cameraManager!.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession;
        }
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(TAG, 'Failed to create the session instance. errorCode = ' + err.code);
      }
      if (this.session === undefined) {
        return false;
      }
      // 监听session错误信息
      this.session.on('error', (error: BusinessError) => {
        Logger.error(`Capture session error code: ${error.code}`);
      });

      // 开始配置会话
      try {
        this.session.beginConfig();
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(TAG, 'Failed to beginConfig. errorCode = ' + err.code);
      }

      // 向会话中添加相机输入流
      try {
        this.session.addInput(this.cameraInput);
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(TAG, 'Failed to addInput. errorCode = ' + err.code);
      }

      // 向会话中添加预览输出流
      try {
        if (this.previewOutput) {
          this.session.addOutput(this.previewOutput)
        }
        if (this.previewOutput1) {
          this.session.addOutput(this.previewOutput1)
        }
        if (this.photoOutput) {
          this.session.addOutput(this.photoOutput)
        }
        if (this.videoOutput) {
          this.session.addOutput(this.videoOutput)
        }
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(TAG, 'Failed to addOutput(previewOutput). errorCode = ' + err.code);
      }

      // 前后置色彩空间对齐必须在 config 状态完成（beginConfig 与 commitConfig 之间）。
      // setColorSpace/getActiveColorSpace/getSupportedColorSpaces 仅在此窗口有效；
      // commitConfig 之后调用会抛 7400103 "Session not config"，导致前置白平衡档位
      // 在 ISP 默认色彩空间不同的设备上呈现错误色偏。
      this.applyColorSpaceAlignment()

      // 提交会话配置
      await this.session.commitConfig();

      // 拍照画质优先策略（API 21+）：显式切回 HIGH_QUALITY。
      // 2026-09-05 实测：去掉 HIGH_QUALITY（系统默认速度优先）后 capture 仍 ~2.0s
      // （与 HIGH_QUALITY 的 ~2.2s 基本持平）—— 该延迟是 OHOS 框架 photoAvailable
      // 投递延迟，与画质模式无关。既然速度无收益，按用户已确认决策保留画质优先，
      // 清晰度不因速度优化被牺牲。
      if (deviceInfo.sdkApiVersion >= 21 && this.photoOutput) {
        try {
          if (this.photoOutput.isPhotoQualityPrioritizationSupported(camera.PhotoQualityPrioritization.HIGH_QUALITY)) {
            this.photoOutput.setPhotoQualityPrioritization(camera.PhotoQualityPrioritization.HIGH_QUALITY);
            Logger.info(TAG, 'photoOutput quality prioritization set to HIGH_QUALITY');
          } else {
            Logger.info(TAG, 'photoOutput HIGH_QUALITY prioritization not supported, keep default');
          }
        } catch (error) {
          let err = error as BusinessError;
          Logger.error(TAG, 'setPhotoQualityPrioritization failed. errorCode = ' + err.code);
        }
      }

      // 开启前置录像镜像
      if (deviceInfo.sdkApiVersion >= 15 && this.captureMode === CaptureMode.VIDEO && this._videoPath) {
        const isMirrorSupported = this.videoOutput?.isMirrorSupported();
        Logger.info(TAG, `videoOutput isMirrorSupported: ${isMirrorSupported}`);
        if (isMirrorSupported) {
          this.videoOutput?.enableMirror(this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT ?
            this._mirrorFrontCamera : false)
        }
      }

      this.setPreviewRotation()
      // 设置闪光灯模式
      this.setFlashFn(this.flashMode)
      this.setZoom(this.zoom)

      try {
        // 启动会话
        await this.session.start().then(() => {
          Logger.info(TAG, 'Promise returned to indicate the session start success.');
          // 注册对焦状态监听（仅日志观测），确认触控对焦是否真正触发
          this.registerFocusStateListener()
          if (this.enableImageStream && this.imageAnalysisBuilder) {
            this.imageAnalysisBuilder.start()
          }
        })
      } catch (e) {
        Logger.error(TAG, 'Promise returned to indicate the session start error.');
      }
      return true;
    })
  }

  /**
   * 拍照配置
   */
  private async photoConfig(): Promise<boolean> {

    const sceneModes: camera.SceneMode[] = this.cameraManager!.getSupportedSceneModes(this.cameraDevice);
    const cameraOutputCap: camera.CameraOutputCapability =
      this.cameraManager!.getSupportedOutputCapability(this.cameraDevice, camera.SceneMode.NORMAL_PHOTO);

    let isSupportPhotoMode: boolean = sceneModes.indexOf(camera.SceneMode.NORMAL_PHOTO) >= 0;
    if (!isSupportPhotoMode) {
      return false;
    }

    const previewProfilesArray: camera.Profile[] = cameraOutputCap.previewProfiles;
    const photoProfilesArray: camera.Profile[] = cameraOutputCap.photoProfiles;

    this.getPreviewProfile(previewProfilesArray);

    if (!this.previewProfile) {
      Logger.error(TAG, `photoConfig previewProfile undefined`);
      return false;
    }

    // photoProfiles 数组的排列顺序在不同机型上并不一致（降序/升序都可能），不能依赖下标排序。
    // 在像素上限 MAX_PHOTO_PIXELS 内按面积选最大档位：上限保证拍照速度（过高分辨率拖慢 capture()），
    // 取最大保证源图不至于太小导致前端放大后成片模糊。
    // 优先取"与预览宽高比匹配（浮点容差）"里面积最大的档位，避免成片取景框被裁切；无匹配则退而求其次。
    const previewW = this.previewProfile!!.size.width;
    const previewH = this.previewProfile!!.size.height;
    const previewAspect = previewW / previewH;
    const maxPixels = Constants.MAX_PHOTO_PIXELS;
    const byAreaDesc = (a: camera.Profile, b: camera.Profile): number =>
      (b.size.width * b.size.height) - (a.size.width * a.size.height);
    const byAreaAsc = (a: camera.Profile, b: camera.Profile): number =>
      (a.size.width * a.size.height) - (b.size.width * b.size.height);
    // 拍照档位在像素上限内选择：上限 5M（MAX_PHOTO_PIXELS）保证 capture() 编码+写盘速度
    //（老 8.2M 档实测拖慢拍照 ~2.6s，是 OHOS 出片慢主因），同时为成片管线 desiredSize 解码
    // 提供 ~1.6x 超采样（5MP 档对 1600 目标 1.62x，锐度接近旧 8.2M 的 ~2x，不明显掉画质）。
    // 在 ≤MAX_PHOTO_PIXELS 内优先取与预览宽高比匹配、面积最大的档位，避免成片取景框被裁切。
    const underCap: camera.Profile[] = [...photoProfilesArray]
      .filter((p: camera.Profile) => p.size.width * p.size.height <= maxPixels);
    const aspectMatched: camera.Profile[] = [...underCap]
      .filter((p: camera.Profile) =>
        Math.abs(p.size.width / p.size.height - previewAspect) / previewAspect < 0.02)
      .sort(byAreaDesc);
    let photoProfile: camera.Profile | undefined = aspectMatched[0];
    if (!photoProfile) {
      // 无精确宽高比匹配时，退而求其次取像素上限内面积最大的档位，宁可稍裁切也不可因低分辨率而糊。
      photoProfile = [...underCap].sort(byAreaDesc)[0];
    }
    if (!photoProfile) {
      // 所有档位均超过像素上限（仅提供超高分辨率档位）时，取面积最小档位以保速。
      photoProfile = [...photoProfilesArray].sort(byAreaAsc)[0];
    }
    if (!photoProfile) {
      Logger.error(TAG, `photoConfig photoProfile undefined`);
      return false;
    }
    Logger.info(TAG, `photoConfig photoProfile=${photoProfile.size.width}x${photoProfile.size.height} ` +
      `preview=${previewW}x${previewH} total=${photoProfilesArray.length} maxPixels=${maxPixels}`);
    // 诊断（桥接日志）：真机档位阶梯 + 最终选中档。用于判定「成片分辨率上限」是否还能提高
    // （真机现状：成片恒为 1440x1920，早帧与成片同源同尺寸，故成片无分辨率级升级空间）。
    const photoLadder = photoProfilesArray
      .map((p: camera.Profile) => `${p.size.width}x${p.size.height}`)
      .join(',')
    bridgeNativeLog(`[perf-cam] photoProfile chosen=${photoProfile.size.width}x${photoProfile.size.height} ` +
      `preview=${previewW}x${previewH} maxPixels=${maxPixels} ladder=[${photoLadder}]`)

    // 创建预览流输出。
    // 取景器实时特效 GPU 管线：预览流写入 FX 消费端（OH_NativeImage），渲染线程
    // 经 GL 着色器（色彩矩阵→锐化→颗粒→磨皮→暗角）输出到 Flutter 纹理 surface；
    // 顶点着色器按 OH_NativeImage_GetTransformMatrixV2 的矩阵采样（含相机预览
    // 旋转与 GL 翻转，与引擎直写路径同约定）。
    // 输出窗口几何必须与 Dart 侧 Texture widget 纵横比一致：getEffectivPreviewSize
    // 在「竖屏 + 相机 orientation 90/270」时交换宽高，此处同规则交换，否则画面被拉伸。
    // 创建失败（返回 0）时回退相机直写 Flutter surface 的旧路径
    // （仅色彩矩阵由 Dart ColorFiltered 预览，细节参数仅成片生效）。
    const camOrientation = this.cameraDevice?.cameraOrientation
    const displayRot = this.getDisplayRotation()
    const swapForPortrait = displayRot !== display.Orientation.LANDSCAPE &&
      displayRot !== display.Orientation.LANDSCAPE_INVERTED &&
      (camOrientation === camera.ImageRotation.ROTATION_90 ||
        camOrientation === camera.ImageRotation.ROTATION_270)
    const fxOutWidth = swapForPortrait ? this.previewProfile!!.size.height
      : this.previewProfile!!.size.width
    const fxOutHeight = swapForPortrait ? this.previewProfile!!.size.width
      : this.previewProfile!!.size.height
    this.previewFxSurfaceId = previewFx.createPreviewFx(this.surfaceId, fxOutWidth, fxOutHeight,
      this.previewProfile!!.size.width, this.previewProfile!!.size.height)
    const previewSurface: string = this.previewFxSurfaceId > 0
      ? this.previewFxSurfaceId.toString() : this.surfaceId?.toString()
    this.previewOutput = this.cameraManager!.createPreviewOutput(this.previewProfile, previewSurface);
    if (this.previewOutput === undefined) {
      Logger.error(TAG, 'Failed to create the preview stream.');
      return false;
    }

    // 创建拍照流输出。
    this.photoOutput = this.cameraManager!.createPhotoOutput(photoProfile);
    if (this.photoOutput === undefined) {
      Logger.error(TAG, 'Failed to create the photoOutput.');
      return false;
    }

    // 拍照监听事件
    this.photoOutputCallBack();

    return true;
  }

  /**
   * 录像配置
   */
  public async videoConfig(): Promise<boolean> {

    try {

      const sceneModes: camera.SceneMode[] = this.cameraManager!.getSupportedSceneModes(this.cameraDevice);
      const cameraOutputCap: camera.CameraOutputCapability =
        this.cameraManager!.getSupportedOutputCapability(this.cameraDevice, camera.SceneMode.NORMAL_VIDEO);

      let isSupportVideoMode: boolean = sceneModes.indexOf(camera.SceneMode.NORMAL_VIDEO) >= 0;
      if (!isSupportVideoMode) {
        return false;
      }

      const previewProfilesArray: camera.Profile[] = cameraOutputCap.previewProfiles;
      const videoProfilesArray: camera.VideoProfile[] = cameraOutputCap.videoProfiles;

      this.previewProfilesArray = previewProfilesArray;
      this.getPreviewProfile(previewProfilesArray);

      if (!this.previewProfile) {
        Logger.error(TAG, `prepareAVRecorder previewProfile undefined`);
        return false;
      }

      // 创建预览流输出。
      this.previewOutput = this.cameraManager!.createPreviewOutput(this.previewProfile, this.surfaceId?.toString());
      if (this.previewOutput === undefined) {
        Logger.error(TAG, 'Failed to create the preview stream.');
        return false;
      }

      const profileRatioH = this.previewProfile.size.height / this.previewProfile.size.width;

      let videoProfile: undefined | camera.VideoProfile = videoProfilesArray.find((profile: camera.VideoProfile) => {
        return profile.size.width <= ConstantsPreview.PREVIEW_1920 &&
          profile.size.width >= ConstantsPreview.PREVIEW_1080 &&
          profile.size.height >= ConstantsPreview.PREVIEW_1080 &&
          profile.size.height === profileRatioH * profile.size.width &&
          profile.frameRateRange.max === Constants.MAX_VIDEO_FRAME &&
          profile.format == camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP;
      })

      // 没有1080P的分辨率
      if (!videoProfile) {
        videoProfile = videoProfilesArray.reverse().find((profile: camera.VideoProfile) => {
          return profile.size.height === profileRatioH * profile.size.width &&
            profile.frameRateRange.max >= Constants.MIN_VIDEO_FRAME &&
            profile.format == camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP;
        })
      }

      if (!videoProfile) {
        Logger.error(TAG, `prepareAVRecorder videoProfile undefined`);
        return false;
      }

      Logger.info(TAG, `prepareAVRecorder videoProfile: ${JSON.stringify(videoProfile)}`);

      this.avRecorder = await media.createAVRecorder();

      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.MICROPHONE'];
      await atManager.requestPermissionsFromUser(this.uiAbility!!.context, permissions)

      const file: fileIo.File = fileIo.openSync(this._videoPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      this.videoFd = file.fd;

      let videoConfig: media.AVRecorderConfig = {
        videoSourceType: media.VideoSourceType.VIDEO_SOURCE_TYPE_SURFACE_YUV,
        profile: {
          fileFormat: media.ContainerFormatType.CFT_MPEG_4,
          videoBitrate: Constants.VIDEO_BITRATE,
          videoCodec: media.CodecMimeType.VIDEO_AVC,
          videoFrameWidth: videoProfile.size.width,
          videoFrameHeight: videoProfile.size.height,
          videoFrameRate: 30
        },
        url: `fd://${this.videoFd.toString()}`,
        rotation: 0, // 录制时，会再次修改
      };

      if (this._enableAudioRecording) {
        videoConfig.audioSourceType = media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC
        videoConfig.profile.audioBitrate = Constants.AUDIO_BITRATE
        videoConfig.profile.audioChannels = Constants.AUDIO_CHANNELS
        videoConfig.profile.audioCodec = media.CodecMimeType.AUDIO_AAC
        videoConfig.profile.audioSampleRate = Constants.AUDIO_SAMPLE_RATE
      }

      Logger.info(TAG, `prepareAVRecorder videoConfig: ${JSON.stringify(videoConfig)}`);

      await this.avRecorder!!.prepare(videoConfig);

      let videoSurfaceId = await this.avRecorder.getInputSurface()
      // 创建videoOutPut输出对象
      this.videoOutput = this.createVideoOutputFn(this.cameraManager!, videoSurfaceId, videoProfile);

      if (this.videoOutput === undefined) {
        Logger.error(TAG, 'Failed to create the photoOutput.');
        return false;
      }

    } catch (error) {
      Logger.error(TAG, `Failed to getInputSurface by avRecorder. error = ${(error as BusinessError).message}`);
      return false
    }
    return true;
  }

  public getTargetRatio(): number {
    const screen = display.getDefaultDisplaySync();
    const foldAbleStatus = display.getFoldStatus();

    const isPortrait =
      Math.min(screen.width, screen.height) <= ConstantsPreview.PREVIEW_980 &&
        foldAbleStatus === display.FoldStatus.FOLD_STATUS_FOLDED;

    if (isPortrait) {
      return CameraUtils.getPreconfigRatioNum(AspectRatio.RATIO_1_1);
    } else if (this.cameraDevice?.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT
      && this.captureMode === CaptureMode.VIDEO) {
      return CameraUtils.getPreconfigRatioNum(AspectRatio.RATIO_16_9);
    }
    return CameraUtils.getPreconfigRatioNum(this.aspectRatio);
  }

  private getPreviewProfile(previewProfilesArray: camera.Profile[]) {

    const targetRatio = this.getTargetRatio();
    const screen = display.getDefaultDisplaySync();
    const screenRatio = screen.height / screen.width;

    const candidates = previewProfilesArray
      .filter(pf => pf.size.width / pf.size.height === targetRatio)
      .sort((a, b) => {
        const diffA = screenRatio > targetRatio ?
          Math.abs(a.size.width - screen.width) :
          Math.abs(a.size.height - screen.height);
        const diffB = screenRatio > targetRatio ?
          Math.abs(b.size.width - screen.width) :
          Math.abs(b.size.height - screen.height);
        return diffA - diffB;
      });
    this.previewProfile = candidates[0];
  }

  async getImageReceiverSurfaceId(receiver: image.ImageReceiver): Promise<string | undefined> {
    let imageReceiverSurfaceId: string | undefined = undefined;
    if (receiver !== undefined) {
      Logger.info(TAG, 'receiver is not undefined');
      imageReceiverSurfaceId = await receiver.getReceivingSurfaceId();
      Logger.info(`ImageReceived id: ${imageReceiverSurfaceId}`);
    } else {
      Logger.error(TAG, 'createImageReceiver failed');
    }
    return imageReceiverSurfaceId;
  }

  // 暂停录制对应的流程
  async pauseRecordingProcess() {
    if (this.avRecorder != undefined && this.avRecorder.state === 'started') { // 仅在started状态下调用pause为合理状态切换
      await this.avRecorder.pause();
      await this.videoOutput!!.stop(); // 停止相机出流
    }
  }

  // 恢复录制对应的流程
  async resumeRecordingProcess() {
    if (this.avRecorder != undefined && this.avRecorder.state === 'paused') { // 仅在paused状态下调用resume为合理状态切换
      await this.videoOutput!!.start(); // 启动相机出流
      await this.avRecorder.resume();
    }
  }

  async createAVRecorder(): Promise<media.AVRecorder | undefined> {
    let avRecorder: media.AVRecorder | undefined = undefined;
    try {
      avRecorder = await media.createAVRecorder();
    } catch (error) {
      Logger.error(TAG, `createAVRecorder error: ${error}`);
    }
    return avRecorder;
  }

  /**
   * 创建videoOutPut输出对象
   */
  createVideoOutputFn(cameraManager: camera.CameraManager, surfaceId: string,
    videoProfile: camera.VideoProfile): camera.VideoOutput | undefined {
    let videoOutput: camera.VideoOutput | undefined = undefined;
    try {
      videoOutput = cameraManager.createVideoOutput(videoProfile, surfaceId);
      Logger.info(TAG, `createVideoOutputFn success: ${videoOutput}`);
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `createVideoOutputFn failed: ${JSON.stringify(err)}`);
    }
    return videoOutput;
  }

  getCameraDevice(sensor: string): camera.CameraDevice | undefined {
    // 获取支持指定的相机设备对象
    let cameras = this.getSupportedCamerasFn(this.cameraManager!!);
    if (cameras.length < 1) {
      return undefined
    }
    // 相机位置
    let cameraPosition: number = sensor === Constant.FRONT ? camera.CameraPosition.CAMERA_POSITION_FRONT :
      camera.CameraPosition.CAMERA_POSITION_BACK;
    let cameraDevice = cameras.find((cd: camera.CameraDevice) => {
      return cd.cameraPosition === cameraPosition
    })

    // 防止折叠态获取不到指定的相机
    if (!cameraDevice) {
      cameraDevice = cameras[0];
      this._sensor =
        cameraDevice.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT ? Constant.FRONT : Constant.BACK;
      this._cameraDeviceChangeListener?.onChanged(this._sensor);
    }
    this.cameraPosition = cameraDevice.cameraPosition;
    return cameraDevice;
  }

  isVideoRecordingAndImageAnalysisSupported(sensor: string, result: Result<boolean>) {
    // 相机位置
    let cameraDevices = this.getCameraDevice(sensor)
    let coc: camera.CameraOutputCapability | undefined =
      this.cameraManager?.getSupportedOutputCapability(cameraDevices, camera.SceneMode.NORMAL_VIDEO)
    if (coc === undefined || coc.videoProfiles.length < 1) {
      result.success(false)
    }
    result.success(true)
  }

  /**
   * 启动录制
   */
  async startVideo(): Promise<void> {
    Logger.info(TAG, 'startVideo is called');
    try {
      const degree = await this.getCurrentDeviceDegree();
      await this.avRecorder?.updateRotation(this.getVideoRotation(degree))
      await this.videoOutput?.start();
      await this.avRecorder?.start();
      this.isRecording = true;
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `startVideo err: ${JSON.stringify(err)}`);
    }
    Logger.info(TAG, 'startVideo End of call');
  }

  /**
   * 停止录制
   */
  async stopVideo(): Promise<void> {
    Logger.info(TAG, 'stopVideo is called');
    if (!this.isRecording) {
      Logger.info(TAG, 'not in recording');
      return;
    }
    try {
      if (this.avRecorder) {
        await this.avRecorder.stop();
      }
      if (this.videoOutput) {
        await this.videoOutput.stop();
      }
      if (this.videoFd) {
        fileIo.closeSync(this.videoFd)
      }
      this.isRecording = false;
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `stopVideo err: ${JSON.stringify(err)}`);
    }
    Logger.info(TAG, 'stopVideo End of call');
  }

  /**
   * 设置分辨率
   *
   * @param size
   */
  setPreviewSize(size: camera.Size): void {
    let previewOutSize = this.previewOutput?.getActiveProfile().size
    let cameraOrentation = this.cameraDevice?.cameraOrientation
    if (size != undefined) {
      if (cameraOrentation === camera.ImageRotation.ROTATION_90 ||
        cameraOrentation === camera.ImageRotation.ROTATION_270) {
        previewOutSize!!.width = size.height
        previewOutSize!!.height = size.width
      } else {
        previewOutSize!!.width = size.width
        previewOutSize!!.height = size.height
      }
    }
  }

  /**
   * 获取支持指定的相机设备对象
   */
  getSupportedCamerasFn(cameraManager: camera.CameraManager): Array<camera.CameraDevice> {
    this._supportedCameras = [];
    try {
      this._supportedCameras = cameraManager.getSupportedCameras();
      Logger.info(TAG,
        `getSupportedCameras success: ${this._supportedCameras}, length: ${this._supportedCameras?.length}`);
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `getSupportedCameras failed: ${JSON.stringify(err)}`);
    }
    return this._supportedCameras;
  }

  /**
   * 获取相机管理器实例
   */
  getCameraManagerFn(): camera.CameraManager | undefined {
    if (this.cameraManager) {
      return this.cameraManager;
    }
    let cameraManager: camera.CameraManager | undefined = undefined;
    try {
      cameraManager = camera.getCameraManager(this.uiAbility!!.context);
      Logger.info(TAG, `getCameraManager success: ${cameraManager}`);
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `getCameraManager failed: ${JSON.stringify(err)}`);
    }
    return cameraManager;
  }

  /**
   * 闪关灯
   */
  setFlashFn(flashMode: string): void {
    try {
      // 检测是否有闪关灯
      let hasFlash = this.session!!.hasFlash();
      if (!hasFlash) {
        Logger.error(TAG, `hasFlash success, hasFlash: ${hasFlash}`);
        return
      }

      let mode: camera.FlashMode = camera.FlashMode.FLASH_MODE_AUTO
      switch (flashMode) {
        case 'NONE':
          mode = camera.FlashMode.FLASH_MODE_CLOSE
          break
        case 'ON':
          mode = camera.FlashMode.FLASH_MODE_OPEN
          break
        case 'AUTO':
          mode = camera.FlashMode.FLASH_MODE_AUTO
          break
        case 'ALWAYS':
          mode = camera.FlashMode.FLASH_MODE_ALWAYS_OPEN
          break
      }
      // 检测闪光灯模式是否支持
      let isFlashModeSupported = this.session!!.isFlashModeSupported(mode);
      if (!isFlashModeSupported) {
        Logger.error(TAG, `isFlashModeSupported success, isFlashModeSupported: ${isFlashModeSupported}`);
        return
      }
      // 设置闪光灯模式
      this.session?.setFlashMode(mode);
      this.flashMode = flashMode
    } catch (e) {
      Logger.error(TAG, `setFlashFn error: ${(e as BusinessError).code}`);
    }
  }

  /**
   * 设置缩放比
   */
  setZoom(zoom: number): void {
    // 检测对焦模式是否支持
    Logger.info(TAG, `setZoom is called`);
    this.session?.setZoomRatio(zoom)
  }

  /**
   * 对焦模式
   */
  setFocusMode(focusMode: camera.FocusMode): void {
    // 检测对焦模式是否支持
    Logger.info(TAG, `setFocusMode is called`);
    let isSupported = this.session?.isFocusModeSupported(focusMode);
    Logger.info(TAG, `setFocusMode isSupported: ${isSupported}`);
    // 设置对焦模式
    if (!isSupported) {
      return;
    }
    this.session?.setFocusMode(focusMode);
  }

  /**
   * 更新取景器实时特效参数（色彩矩阵 + 锐化/磨皮/暗角/颗粒）。
   *
   * 数值语义与 iOS PreviewEffectProcessor.updateEffects 一致：
   * - matrix：Flutter 20 元素 ColorFilter（恒等时传 null → 着色器跳过矩阵 pass）
   * - vignette/smooth/sharpen/grain：0..100 原始强度（原生侧按 iOS 同曲线折算）
   *
   * 管线未创建（录像模式/初始化竞态/创建失败回退）时原生侧安静忽略。
   */
  updatePreviewEffects(hasMatrix: boolean, matrix: number[] | null, vignette: number,
    smooth: number, sharpen: number, grain: number): void {
    try {
      // 诊断（2026-09-19 前置白平衡软件模拟）：确认矩阵是否到达原生层。
      const dbgM = matrix && matrix.length >= 20 ? `${matrix[0]}/${matrix[6]}/${matrix[12]}` : 'null'
      Logger.info(TAG, `updatePreviewEffects hasMatrix=${hasMatrix} m=${dbgM} v=${vignette} s=${smooth}`);
      if (hasMatrix && matrix !== null && matrix !== undefined && matrix.length >= 20) {
        const m = new Float64Array(20)
        for (let i = 0; i < 20; i++) {
          m[i] = matrix[i]
        }
        previewFx.updatePreviewFxParams(true, m, vignette, smooth, sharpen, grain)
      } else {
        previewFx.updatePreviewFxParams(false, null, vignette, smooth, sharpen, grain)
      }
    } catch (error) {
      Logger.error(TAG, `updatePreviewEffects fail: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 释放会话及其相关参数
   */
  async releaseCamera(): Promise<void> {
    Logger.info(TAG, 'releaseCamera is called');

    // 相机释放时停止重力传感器常驻订阅（与相机生命周期一致）。
    this.stopDegreeSensor()

    // 销毁取景器实时特效 GPU 管线（含渲染线程/GL/EGL/NativeImage 全链资源）。
    // initCamera 首步即 releaseCamera，故相机重建（切镜头/切比例/折叠等）路径统一在此收敛。
    try {
      previewFx.destroyPreviewFx()
      this.previewFxSurfaceId = 0
    } catch (error) {
      Logger.error(TAG, `destroyPreviewFx fail: ${JSON.stringify(error)}`)
    }

    try {
      await this.session?.stop();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `session stop fail: error: ${JSON.stringify(err)}`);
    }

    try {
      await this.previewOutput?.release();
      await this.previewOutput1?.release()
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `previewOutput release fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.previewOutput = undefined;
      this.previewOutput1 = undefined
    }

    try {
      this.photoOutput?.off("captureStartWithInfo");
      this.photoOutput?.off("frameShutter");
      this.photoOutput?.off("captureEnd");
      this.photoOutput?.off("photoAvailable");
      this.photoOutput?.off("photoAssetAvailable");

      // 相机释放：清空未完成的拍照请求队列，快速失败等待中的 Dart 回调
      // （连拍中途切镜头/释放时避免 future 挂到 10s 超时）。
      // 两通道共享同一 ctx 引用，用 Set 去重后统一回调。
      const pendingCtx = new Set<PhotoCaptureContext>()
      while (this._photoDirectQueue.length > 0) {
        pendingCtx.add(this._photoDirectQueue.shift()!)
      }
      while (this._photoAssetQueue.length > 0) {
        pendingCtx.add(this._photoAssetQueue.shift()!)
      }
      if (pendingCtx.size > 0) {
        Logger.info(TAG, `releaseCamera: fail ${pendingCtx.size} pending capture(s)`);
        for (const c of pendingCtx) {
          settleCaptureCtx(c, false)
        }
      }

      // 增强交付串行队列同样必须在释放时收敛：否则排队中的帧要白等到看门狗
      // （最长 7s）才回 result，表现为「切镜头/退出后卡一会儿才报拍照失败」。
      const inFlight = this._enhancedInFlightItem
      this._enhancedInFlightItem = undefined
      if (inFlight !== undefined) {
        this.settleEnhancedItem(inFlight, false)
      }
      while (this._enhancedQueue.length > 0) {
        this.settleEnhancedItem(this._enhancedQueue.shift()!!, false)
      }

      await this.photoOutput?.release();
    } catch (error) {
      let err = error as BusinessError;
      console.error(`photoOutput release fail: error: ${err}`);
    } finally {
      this.photoOutput = undefined;
    }

    try {
      await this.videoOutput?.release();
    } catch (error) {
      let err = error as BusinessError;
      console.error(`videoOutput release fail: error: ${err}`);
    } finally {
      this.videoOutput = undefined;
    }

    try {
      await this.cameraInput?.close();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `cameraInput close fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.cameraInput = undefined;
    }

    try {
      await this.avRecorder?.release();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `avRecorder release fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.avRecorder = undefined;
    }

    try {
      await this.session?.release();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `session release fail: error: ${JSON.stringify(err)}`);
    } finally {
      this.session = undefined;
    }

    this.imageAnalysisBuilder?.finish()

    Logger.info(TAG, 'releaseCamera success');
  }

  async getEffectivPreviewSize(): Promise<PreviewSize> {
    let size = this.previewOutput?.getActiveProfile().size
    if (!size) {
      await this.initCamera()
      size = this.previewOutput?.getActiveProfile().size
    }

    let previewSize = new PreviewSize(0.01, 0.01);

    if (!size) {
      return previewSize
    }

    if (size.width / size.height != CameraUtils.getPreconfigRatioNum(this._aspectRatio)) {
      await this.initCamera()
      size = this.previewOutput?.getActiveProfile().size
    }

    let cameraOrentation = this.cameraDevice?.cameraOrientation
    let displayRotation = this.getDisplayRotation();

    if (size != undefined) {
      // 值为1时，表示显示设备屏幕顺时针旋转为90°；值为3时，表示显示设备屏幕顺时针旋转为270°。
      if (displayRotation === display.Orientation.LANDSCAPE ||
        displayRotation === display.Orientation.LANDSCAPE_INVERTED) {
        previewSize = new PreviewSize(size.width + 0.01, size.height + 0.01)
      } else if (cameraOrentation === camera.ImageRotation.ROTATION_90 ||
        cameraOrentation === camera.ImageRotation.ROTATION_270) {
        previewSize = new PreviewSize(size.height + 0.01, size.width + 0.01)
      } else {
        previewSize = new PreviewSize(size.width + 0.01, size.height + 0.01)
      }
    }
    return previewSize
  }

  /**
   * 以指定参数触发一次拍照。
   *
   * 修复①：ctx 入队时机后移——仅在 photoOutput.capture() 被框架受理（Promise
   * resolve）后才 push 进两通道队列。此前「先入队再 capture」时，capture() 抛
   * 7400102（忙窗口拒绝，实测连拍忙窗口 0.4-0.7s）会让 ctx 滞留队列，后续帧按
   * FIFO 出队时错配到滞留 ctx（照片写错路径、回错 result）。
   * 修复②：capture() 抛 7400102 时在原生内部按 ~300ms 间隔排队重试（≤20 次
   * ≈6s，小于 Dart 侧 10s 超时），不丢帧、不把错误抛回调用方。
   * 全程保证 result 恰好回调一次：受理成功后由 photoAvailable/photoAssetAvailable
   * 链路回调；受理失败/相机已释放由本方法直接 success(false)。
   */
  async takePhoto(path: string, result: Result<boolean>): Promise<void> {
    const degree = await this.getCurrentDeviceDegree();
    let photoSettings: camera.PhotoCaptureSetting = {
      quality: camera.QualityLevel.QUALITY_LEVEL_HIGH, // 官方推荐高画质，降低JPEG压缩对清晰度的影响
      mirror: this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT ? this._mirrorFrontCamera : false,
      rotation: this.getPhotoRotation(degree)
    };
    // 直出标记 per-capture：directDone 记录在本帧 ctx 上，连拍时各帧互不干扰。
    // 复位分阶段拍照早帧请求 id，允许本帧重新发起 FAST_MODE 早帧交付。
    this._earlyFrameRequestId = undefined

    if (this._exifPreferences.getSaveGPSLocation()) {
      try {
        let location: geoLocationManager.Location = await geoLocationManager.getCurrentLocation()
        photoSettings.location = location
        Logger.info(TAG, `takePicture photoSettings.location = { latitude: ${photoSettings.location.latitude},
                longitude: ${photoSettings.location.longitude}, altitude: ${photoSettings.location.altitude}}`);
      } catch (e) {
        Logger.info(TAG, `getCurrentLocation call Failed! error: ${(e as BusinessError).code}`);
      }
    }
    takePhotoStartAt = Date.now()
    const ctx: PhotoCaptureContext = { path: path, result: result, directDone: false }
    // capture() 忙窗口（7400102）重试参数：实测忙窗口 0.4-0.7s，300ms 间隔 ≤20 次
    //（最长 ~6s）足够覆盖，且小于 Dart 侧 takePhoto 的 10s 超时。
    const captureRetryMax = 20
    const captureRetryIntervalMs = 300
    for (let attempt = 1; attempt <= captureRetryMax; attempt++) {
      if (this.photoOutput === undefined) {
        // releaseCamera 已释放输出：本 ctx 尚未入队（修复①），不会走 releaseCamera
        // 的队列 drain 回调，必须在此回 result，否则 Dart 侧悬挂至 10s 超时。
        bridgeNativeLog(`[probe] capture() attempt#${attempt} abort: photoOutput released +${Date.now() - takePhotoStartAt}ms`)
        settleCaptureCtx(ctx, false)
        return
      }
      try {
        await this.photoOutput!!.capture(photoSettings);
        // 受理成功：框架按提交顺序交付本帧（photoAvailable/photoAssetAvailable），
        // 入队顺序 = 受理顺序 = 帧交付顺序，FIFO 配对成立。
        this._photoDirectQueue.push(ctx)
        this._photoAssetQueue.push(ctx)
        bridgeNativeLog(`[probe] capture() attempt#${attempt} accepted after ${Date.now() - takePhotoStartAt}ms directQ=${this._photoDirectQueue.length} assetQ=${this._photoAssetQueue.length}`)
        Logger.info(TAG, 'takePicture end');
        // [性能拆解] 快照后 JPEG 交付是否为主要耗时：对比本行与 photoAvailable saved 的 elapsed。
        return
      } catch (e) {
        // ArkTS 限制：throw 只接受 Error（类）派生类型；此处不再向上抛——所有失败
        // 路径都在本方法内收敛并保证 result 恰好回调一次。
        const be = e as BusinessError
        // 忙窗口判定：真机实测该错误可能 code=undefined、错误号只出现在 message
        // 文本里（'capture() failed code=7400102 msg=Operation not allowed.'），
        // 原严格等号 be?.code === 7400102 会恒判 false → 重试从未触发（日志
        // retry=false），受理失败帧直接 success(false) 表现为「拍照失败」。
        // 故按 number 与 message 文本双路判定。
        const busyByCode = Number(be?.code) === 7400102
        const busyByMsg = be?.message !== undefined && String(be.message).indexOf('7400102') >= 0
        const busy = busyByCode || busyByMsg
        const willRetry = busy && attempt < captureRetryMax
        bridgeNativeLog(`[probe] capture() attempt#${attempt} THREW after ${Date.now() - takePhotoStartAt}ms code=${be?.code} msg=${be?.message} retry=${willRetry}`)
        if (willRetry) {
          const wait: Promise<void> = new Promise((resolve) => {
            setTimeout(() => { resolve() }, captureRetryIntervalMs)
          })
          await wait
          continue
        }
        settleCaptureCtx(ctx, false)
        return
      }
    }
  }

  /**
   * 监听拍照事件
   */
  photoOutputCallBack(): void {
    try {
      // 监听拍照开始
      this.photoOutput!!.on('captureStartWithInfo',
        (err: BusinessError, captureStartInfo: camera.CaptureStartInfo): void => {
          Logger.info(TAG,
            `photoOutputCallBack captureStartWithInfo success: ${JSON.stringify(captureStartInfo)}`);
          bridgeNativeLog(`[probe] captureStart id=${captureStartInfo?.captureId}`);
        });
      // 监听拍照帧输出捕获
      this.photoOutput!!.on('frameShutter',
        (err: BusinessError, frameShutterInfo: camera.FrameShutterInfo): void => {
          Logger.info(TAG, `photoOutputCallBack frameShutter captureId:
          ${frameShutterInfo.captureId}, timestamp: ${frameShutterInfo.timestamp}`);
          // [probe] 决定性信号：传感器是否真的出了这帧。并发发起两次若此处只打一行，
          // 说明第 2 次压根没被框架抓帧（属 (a) 被丢弃）；若打两行说明抓了帧，
          // 缺失的只是后续交付回调（属 (b) 回调被吞）。
          bridgeNativeLog(`[probe] frameShutter id=${frameShutterInfo?.captureId} ts=${frameShutterInfo?.timestamp}`);
        });
      // 监听拍照结束
      this.photoOutput!!.on('captureEnd', (err: BusinessError, captureEndInfo: camera.CaptureEndInfo): void => {
        Logger.info(TAG, `photoOutputCallBack captureEnd captureId:
          ${captureEndInfo.captureId}, frameCount: ${captureEndInfo.frameCount}`);
        bridgeNativeLog(`[probe] captureEnd id=${captureEndInfo?.captureId} frameCount=${captureEndInfo?.frameCount}`);
      });
      // 监听拍照异常
      this.photoOutput!!.on('error', (data: BusinessError): void => {
        Logger.info(TAG, `photoOutPut data: ${JSON.stringify(data)}`);
        bridgeNativeLog(`[probe] photoOutput error code=${data?.code} msg=${data?.message}`);
      });
      // 拍照原始帧直出（绕过系统相册增强管线，避免"取景器正常、拍照偏黄"）。
      // photoAvailable 返回相机原始 JPEG buffer，直接写盘，不经过相册色彩增强。
      // 连拍安全：从 directQueue 出队本帧的请求上下文，写盘路径/回调与发起
      // 顺序一一配对，后一次 takePhoto 不再覆盖前一次的单槽位状态。
      this.photoOutput!!.on('photoAvailable',
        (err: BusinessError, photo: camera.Photo) => {
          Logger.info(TAG, 'photoAvailable begin');
          bridgeNativeLog(`[perf-cam] photoAvailable begin elapsed=${Date.now() - takePhotoStartAt}ms`);
          const ctx = this._photoDirectQueue.shift()
          if (ctx === undefined) {
            Logger.error(TAG, 'photoAvailable: no pending capture request, skip');
            bridgeNativeLog(`[probe] photoAvailable DROPPED: no pending request`)
            return
          }
          bridgeNativeLog(`[probe] photoAvailable shift path=${ctx.path} directQLeft=${this._photoDirectQueue.length}`)
          if (err && err.code !== 0) {
            Logger.error(TAG, `photoAvailable error: ${err.code}`);
            settleCaptureCtx(ctx, false)
            return
          }
          if (!photo || !photo.main) {
            Logger.error(TAG, 'photoAvailable: photo or photo.main is null');
            settleCaptureCtx(ctx, false)
            return
          }
          const imageObj = photo.main
          // 同步置位直出标记（在任何异步回调之前），确保同帧 photoAssetAvailable 被跳过，
          // 不会用相册增强图覆盖原始 JPEG。仅在写盘失败时复位以允许增强图回退。
          ctx.directDone = true
          imageObj.getComponent(image.ComponentType.JPEG,
            (errCode: BusinessError, component: image.Component) => {
              bridgeNativeLog(`[perf-cam] getComponent(jpeg) cb elapsed=${Date.now() - takePhotoStartAt}ms`);
              if (!errCode && component && component.byteBuffer) {
                try {
                  const buffer = component.byteBuffer as ArrayBuffer
                  const file = fileIo.openSync(ctx.path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
                  const written = fileIo.writeSync(file.fd, buffer)
                  fileIo.closeSync(file)
                  bridgeNativeLog(`[perf-cam] photoAvailable: saved raw JPEG bytes=${written} elapsed=${Date.now() - takePhotoStartAt}ms to ${ctx.path}`)
                  settleCaptureCtx(ctx, true)
                } catch (e) {
                  Logger.error(TAG, `photoAvailable save failed: ${JSON.stringify(e)}`)
                  ctx.directDone = false
                  settleCaptureCtx(ctx, false)
                }
              } else {
                Logger.error(TAG, `photoAvailable getComponent failed: code=${errCode?.code}, path=${ctx.path}`)
                ctx.directDone = false
                settleCaptureCtx(ctx, false)
              }
              imageObj.release()
            });
        });

      this.photoOutput!!.on('photoAssetAvailable',
        (err: BusinessError, photoAsset: photoAccessHelper.PhotoAsset) => {
          Logger.info(TAG, 'photoAssetAvailable begin');
          bridgeNativeLog(`[perf-cam] photoAssetAvailable begin elapsed=${Date.now() - takePhotoStartAt}ms`);
          // 连拍安全：从 assetQueue 出队本帧的请求上下文（与 photoAvailable 的
          // directQueue 各自保序），直出/增强判定与本帧 ctx 配对。
          // 出队必须先于 err 判定：原实现 err 时直接 return，该帧 ctx 既不回 result
          // 也不出队，Dart 侧 future 悬挂至 10s 超时。
          const ctx = this._photoAssetQueue.shift()
          if (ctx === undefined) {
            Logger.error(TAG, 'photoAssetAvailable: no pending capture request, skip');
            bridgeNativeLog(`[probe] photoAssetAvailable DROPPED: no pending request`)
            return;
          }
          bridgeNativeLog(`[probe] photoAssetAvailable shift path=${ctx.path} directDone=${ctx.directDone} assetQLeft=${this._photoAssetQueue.length}`)
          if (err) {
            Logger.error(TAG, `photo is err: ${err.code}`);
            settleCaptureCtx(ctx, false)
            return;
          }
          // 若 photoAvailable 已直出写盘（原始 JPEG，绕过相册色彩增强），
          // 则跳过相册增强图的 saveCameraPhoto，避免其异步回调覆盖直出文件。
          // 仅当直出失败（ctx.directDone 为 false）时才走增强图回退。
          if (ctx.directDone) {
            // 分阶段拍照：成片已由 photoAvailable 直出，另发起 FAST_MODE 早帧交付，
            // 一阶段低质量图（~672ms）作为水印动画源提前送达 Dart 触发动画，
            // 二阶段全质量图因成片已写出而跳过。
            Logger.info(TAG, 'photoAssetAvailable: raw JPEG written, request early anim frame');
            bridgeNativeLog(`[perf-cam] requestEarlyFrame: raw JPEG direct-written, requesting early anim frame elapsed=${Date.now() - takePhotoStartAt}ms`);
            this.requestEarlyFrameForAnimation(photoAsset);
            return;
          }
          // 增强兜底路径（photoAvailable 未在本设备触发，directDone 为 false）：
          // 先快：立即只读 fd 拷出 asset 原始 JPEG 作为早帧（~800ms 送达 Dart，
          // 缩略图/初版成片提前上屏）。本设备无分段式拍照能力（photoAvailable 与
          // FAST_MODE requestImageData 均不回调），photoAssetAvailable 时原始文件
          // 已落盘，直接读文件是唯一 ~1s 内的早帧来源。
          // 后真：成片仍由 _handlePhotoCb(HIGH_QUALITY_MODE) 增强交付（实测单发明发
          // ~2.1s，质量不变）。注意该交付在原生侧被串行化成「一次仅一个在飞」，并挂
          // 看门狗——本机并发在飞时 requestImageData 完全不回调，串行+看门狗兜底
          // （降级用上面已落盘的原始 JPEG）才能保证每帧都在 Dart 10s 超时前回 result。
          Logger.info(TAG, 'photoAssetAvailable: enhanced path, fd early frame + HIGH_QUALITY final');
          bridgeNativeLog(`[perf-cam] fallback: fd early frame + HIGH_QUALITY deliver elapsed=${Date.now() - takePhotoStartAt}ms`);
          this.deliverEarlyFrameFromAsset(photoAsset, ctx);
          this._handlePhotoCb(photoAsset, ctx.path, ctx.result, ctx);
        });
    } catch (err) {
      Logger.error(TAG, 'photoOutputCallBack error');
    }
  }

  /**
   * 增强兜底交付入口（由 _handlePhotoCb 调用）：把本帧加入串行队列并挂看门狗。
   *
   * 修复④定案（修复①②③真机验证失败后）：本机 requestImageData 仅在「单请求在飞」
   * 时交付，并发在飞时全部不回调——修复③ 移除单槽 photoRequestId 后增强交付退化为
   * 并发，连拍 2 张以上全部 10s 超时（真机日志：5 个请求在飞，无一条 onDataPrepared）。
   * 因此这里不再依赖「单槽守卫」这种隐式单发，而是显式串行化：FIFO + 一次仅一个
   * 在飞；并挂看门狗，超时（含排队积压、本机饿死）时降级用同帧已落盘的原始 JPEG
   * 交付，保证每帧 result 恰好回调一次且必然早于 Dart 侧 10s 超时。
   */
  async saveCameraPhoto(path: string, photoAsset: photoAccessHelper.PhotoAsset,
    result: Result<boolean>, ctx?: PhotoCaptureContext) {
    const item: EnhancedDeliveryItem = {
      photoAsset: photoAsset,
      path: path,
      result: result,
      ctx: ctx,
      settled: false,
      watchdogId: undefined,
      enqueuedAtMs: Date.now()
    }
    this._enhancedQueue.push(item)
    bridgeNativeLog(`[perf-cam] enhanced: enqueue path=${path} qLen=${this._enhancedQueue.length}`)
    // 入队先挂「绝对截止」看门狗：排队等待中的帧同样受保护，入队→交付绝不超过
    // _enhancedQueueDeadlineMs（防撞 Dart 10s）。请求真正开始时会改挂「在飞预算」。
    this.armEnhancedWatchdog(item, this._enhancedQueueDeadlineMs)
    this.drainEnhancedQueue()
  }

  /**
   * 重挂看门狗（修复⑥）。调用方给期望预算，但结果绝不越过「入队绝对截止时间」：
   * - 入队时传 _enhancedQueueDeadlineMs（只受绝对截止约束）；
   * - 请求进入在飞时传 _enhancedWatchdogMs（把排队时间还给本帧，但仍不越绝对截止）。
   */
  private armEnhancedWatchdog(item: EnhancedDeliveryItem, budgetMs: number): void {
    if (item.watchdogId !== undefined) {
      clearTimeout(item.watchdogId)
      item.watchdogId = undefined
    }
    const deadlineLeft = item.enqueuedAtMs + this._enhancedQueueDeadlineMs - Date.now()
    const effective = Math.max(1, Math.min(budgetMs, deadlineLeft))
    item.watchdogId = setTimeout(() => {
      this.onEnhancedWatchdog(item)
    }, effective)
  }

  /** 串行 drain：一次仅放行一个增强交付请求（单发是本机 requestImageData 可用前提）。 */
  private drainEnhancedQueue(): void {
    if (this._enhancedInFlightItem !== undefined) {
      return
    }
    while (this._enhancedQueue.length > 0) {
      const item = this._enhancedQueue.shift()!!
      if (item.settled) {
        // 排队期间看门狗已兜底结算，跳过（其 result 已回调）。
        continue
      }
      this._enhancedInFlightItem = item
      bridgeNativeLog(`[perf-cam] enhanced: start requestImageData(HIGH_QUALITY) path=${item.path} qLeft=${this._enhancedQueue.length}`)
      // 修复⑥：请求真正开始 → 改挂「在飞预算」，把此前排队等待的时间还给本帧
      // （仍受入队绝对截止约束）。这是修复⑤日志中第 2/4 帧被误杀的唯一原因。
      this.armEnhancedWatchdog(item, this._enhancedWatchdogMs)
      const handler = new MediaDataHandler(this, item)
      // 持有 handler 引用至交付结束（随 item 一起被队列/看门狗引用），
      // 防止 ArkTS 回收该对象导致 onDataPrepared 永不回调。
      item.handler = handler
      let requestOptions: photoAccessHelper.RequestOptions = {
        // 兜底路径也需要全质量图：FAST_MODE 仅接收一阶段低质量图会导致成片模糊，
        // 改 HIGH_QUALITY_MODE 接收二阶段全质量图。正常拍照仍以 photoAvailable 原始帧直出为主，
        // 此路径仅在 photoAvailable 未触发时兜底。
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
      }
      photoAccessHelper.MediaAssetManager.requestImageData(this.uiAbility?.context, item.photoAsset,
        requestOptions, handler)
        .then((id: string) => {
          bridgeNativeLog(`[perf-cam] enhanced: requestId=${id} path=${item.path}`)
        })
        .catch((err: BusinessError) => {
          Logger.error(TAG, `enhanced requestImageData failed: ${err.code}, ${err.message}`)
          bridgeNativeLog(`[perf-cam] enhanced: requestImageData FAILED code=${err.code} msg=${err.message}`)
          this.settleEnhancedFromFallback(item)
        })
      return
    }
  }

  /** 增强图数据到达：写盘并结算；已结算 / 已直出 / 数据异常均按「跳过或兜底」收敛。 */
  // 注意：由 MediaDataHandler（独立类）转交调用，不能声明为 private，否则 ArkTS 编译报
  // 「Property 'onEnhancedDataPrepared' is private and only accessible within class」。
  async onEnhancedDataPrepared(item: EnhancedDeliveryItem, data: ArrayBuffer): Promise<void> {
    try {
      if (item.settled) {
        // 看门狗已兜底并回过 result：晚到数据不得再覆盖已交付文件、更不得二次回调。
        bridgeNativeLog(`[perf-cam] enhanced: late data skipped (settled) path=${item.path}`)
        return
      }
      if (data === undefined) {
        Logger.error('Error occurred when preparing data');
        bridgeNativeLog(`[perf-cam] enhanced: data undefined, fallback path=${item.path}`)
        await this.settleEnhancedFromFallback(item)
        return
      }
      if (item.ctx?.directDone === true) {
        // 同帧 photoAvailable 已直出写盘并回调过 result：跳过增强覆盖（否则原始 JPEG
        // 被相册增强管线二次处理），且不得重复回调 result，只静默结算释放闸门。
        Logger.info(TAG, 'enhanced: skip overwrite, direct JPEG already saved')
        bridgeNativeLog(`[perf-cam] enhanced: skip overwrite (directDone) path=${item.path}`)
        item.settled = true
        return
      }
      // 直接落盘全质量 JPEG buffer，不做 createPixelMap + effectKit 重编码：
      // 避免在主线程逐像素处理后阻塞拍照（速度），也避免二次压缩损失清晰度（质量）。
      // 成片颜色由应用内 Dart 处理器统一处理，无需在原生层二次上色。
      // TRUNC：兜底路径可能已写入更大的原始 JPEG，不截断会残留尾部字节。
      const file = await fileIo.open(item.path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
      const written = fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      Logger.info(TAG, `enhanced delivered bytes=${written}`);
      bridgeNativeLog(`[perf-cam] enhanced: saved bytes=${written} to ${item.path}`)
      this.settleEnhancedItem(item, true)
    } catch (error) {
      Logger.error(`Failed to write the photo file.code ${error.code},message is ${error.message}`);
      bridgeNativeLog(`[perf-cam] enhanced: write FAILED code=${error.code} msg=${error.message}`)
      await this.settleEnhancedFromFallback(item)
    } finally {
      // 正常交付 / 跳过覆盖 / 兜底失败都要释放串行闸门（幂等：非在飞项时无副作用）。
      this.finishEnhancedItem(item)
    }
  }

  /** 看门狗：在飞交付未按时回调（本机并发饿死、卡片异常）时兜底，避免 10s 超时。 */
  private onEnhancedWatchdog(item: EnhancedDeliveryItem): void {
    if (item.settled) {
      return
    }
    bridgeNativeLog(`[perf-cam] enhanced: WATCHDOG fired path=${item.path}`)
    this.settleEnhancedFromFallback(item)
  }

  /**
   * 兜底结算（看门狗超时 / requestImageData reject / 写盘失败）。
   *
   * 修复⑤：不再拿「早帧文件」当成品来源。真机日志证明原实现把早帧原样拷成成片
   * （`fallback raw JPEG bytes=2573382` 与同帧 `earlyFrameFd: copied bytes=2573382`
   * 逐字节相同）→ 成片与早帧完全一样，与「先快后真」契约冲突。
   * 现改为「现取一次 asset 只读 fd 直拷」：这是媒体库当前真实落盘版本，可能已被
   * 升级为二阶段全清图（早帧副本是 ~0.6s 时点的版本）；本次拷贝字节数与早帧字节数
   * 一并打日志，便于判定媒体库是否升级了磁盘文件。
   * 仅当连 asset 原文件都读不到时，才退回早帧副本（内容同源、仅版本可能更早），
   * 避免丢照片；全都失败才 success(false)，让 Dart 立即报错而不是悬挂 10s。
   */
  private async settleEnhancedFromFallback(item: EnhancedDeliveryItem): Promise<void> {
    if (item.settled || item.ctx?.directDone === true) {
      // 已结算，或同帧 photoAvailable 已直出（不得用兜底图覆盖原始 JPEG）：
      // 统一走 settleEnhancedItem 静默收口并释放闸门（result 已回过则不再重复回调）。
      this.settleEnhancedItem(item, true)
      return
    }
    bridgeNativeLog(`[perf-cam] enhanced: fallback -> fresh asset read ` +
      `earlyFrameBytes=${this.earlyFrameSize(item)} path=${item.path}`)
    this.settleEnhancedFromAssetFd(item, 1)
  }

  /** 同帧早帧副本字节数（无早帧返回 -1）：仅作日志对照，判定媒体库是否升级了原文件。 */
  private earlyFrameSize(item: EnhancedDeliveryItem): number {
    const earlyPath = item.ctx?.earlyFramePath
    if (earlyPath === undefined) {
      return -1
    }
    try {
      return fileIo.statSync(earlyPath).size
    } catch (e) {
      return -1
    }
  }

  /** 兜底首选：直接取 asset 只读 fd 直拷到目标路径（带一次重试，覆盖 14000011 抖动）。 */
  private settleEnhancedFromAssetFd(item: EnhancedDeliveryItem, attempt: number): void {
    item.photoAsset.getReadOnlyFd().then((fd: number) => {
      // 注意：fd 必须等 copyFile 真正完成后再 close——不能用 finally 同步关闭，
      // 否则会在异步拷贝在飞时把源 fd 关掉（拷贝失败/截断）。
      let destFd: number = -1
      try {
        destFd = fileIo.openSync(item.path,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC).fd
      } catch (e) {
        bridgeNativeLog(`[perf-cam] enhanced: fallback fd open FAILED ${JSON.stringify(e)}`)
        item.photoAsset.close(fd).catch(() => {
        })
        this.settleEnhancedItem(item, false)
        return
      }
      fileIo.copyFile(fd, destFd).then(() => {
        fileIo.closeSync(destFd)
        item.photoAsset.close(fd).catch(() => {
        })
        const size = fileIo.statSync(item.path).size
        bridgeNativeLog(`[perf-cam] enhanced: fallback asset copy bytes=${size} ` +
          `earlyFrameBytes=${this.earlyFrameSize(item)} attempt=${attempt}`)
        this.settleEnhancedItem(item, size > 20 * 1024)
      }).catch((e: BusinessError) => {
        fileIo.closeSync(destFd)
        item.photoAsset.close(fd).catch(() => {
        })
        bridgeNativeLog(`[perf-cam] enhanced: fallback fd copy FAILED code=${e.code}`)
        this.settleEnhancedFromEarlyFrame(item)
      })
    }).catch((err: BusinessError) => {
      if (attempt < 2) {
        bridgeNativeLog(`[perf-cam] enhanced: fallback getReadOnlyFd FAILED code=${err.code} attempt=${attempt}, retry`)
        setTimeout(() => {
          this.settleEnhancedFromAssetFd(item, attempt + 1)
        }, 150)
      } else {
        bridgeNativeLog(`[perf-cam] enhanced: fallback getReadOnlyFd FAILED after ${attempt} attempts code=${err.code}`)
        this.settleEnhancedFromEarlyFrame(item)
      }
    })
  }

  /**
   * 最后手段：连 asset 原文件都读不到时，退回同帧早帧副本（内容与成片同源、
   * 仅版本可能更早），以免丢照片；早帧不可用才 success(false)。
   * 该分支只在 fd 直读彻底失败时触发，正常兜底不会走到这里。
   */
  private settleEnhancedFromEarlyFrame(item: EnhancedDeliveryItem): void {
    const earlyPath = item.ctx?.earlyFramePath
    if (earlyPath !== undefined) {
      try {
        if (fileIo.statSync(earlyPath).size > 20 * 1024) {
          const src = fileIo.openSync(earlyPath, fileIo.OpenMode.READ_ONLY)
          const dest = fileIo.openSync(item.path,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
          try {
            fileIo.copyFileSync(src.fd, dest.fd)
          } finally {
            fileIo.closeSync(src)
            fileIo.closeSync(dest)
          }
          const size = fileIo.statSync(item.path).size
          bridgeNativeLog(`[perf-cam] enhanced: LAST-RESORT early frame copy bytes=${size} to ${item.path}`)
          this.settleEnhancedItem(item, true)
          return
        }
        bridgeNativeLog(`[perf-cam] enhanced: LAST-RESORT early frame too small`)
      } catch (e) {
        bridgeNativeLog(`[perf-cam] enhanced: LAST-RESORT early frame FAILED ${JSON.stringify(e)}`)
      }
    }
    this.settleEnhancedItem(item, false)
  }

  /** 结算一帧增强交付：result 恰好回调一次，并释放串行闸门放行下一帧。 */
  private settleEnhancedItem(item: EnhancedDeliveryItem, ok: boolean): void {
    if (!item.settled) {
      // ctx 存在时统一经 settleCaptureCtx 收口（它自带「恰好一次」守卫，可安全
      // 覆盖「photoAvailable 已直出并回过分」的场景，不再重复 success）。
      const ctx = item.ctx
      if (ctx !== undefined) {
        settleCaptureCtx(ctx, ok)
      } else {
        item.result.success(ok)
      }
    }
    item.settled = true
    this.finishEnhancedItem(item)
  }

  /** 释放串行闸门（仅当结算的确实是在飞项）并继续 drain 下一帧。 */
  private finishEnhancedItem(item: EnhancedDeliveryItem): void {
    if (item.watchdogId !== undefined) {
      clearTimeout(item.watchdogId)
      item.watchdogId = undefined
    }
    if (this._enhancedInFlightItem === item) {
      this._enhancedInFlightItem = undefined
    }
    this.drainEnhancedQueue()
  }

  /**
   * 分阶段拍照：一阶段低质量帧（水印动画源）快速交付。
   *
   * 成片已由 photoAvailable 原始 JPEG 直出，此处单独用 FAST_MODE 请求同一
   * photoAsset 的低质量图（官方"分段式拍照"一阶段，实测 ~672ms 先于成片到达）。
   * 低质量图写入 cacheDir 临时文件后，经 EventChannel 'camerawesome/photo_early_frame'
   * 通知 Dart 提前触发水印动画，无需等待成片 capture()（~1.9s）返回。
   *
   * FAST_MODE 下 onDataPrepared 回调两次：第一次低质量（写动画源 + 发事件），
   * 第二次全质量（成片已由 photoAvailable 写出，直接跳过）。
   * 注意：此路径经过相册增强管线，仅用作短暂动画源；最终成片仍走 photoAvailable 直出。
   */
  private requestEarlyFrameForAnimation(photoAsset: photoAccessHelper.PhotoAsset): void {
    if (this._earlyFrameRequestId) {
      Logger.info(TAG, 'requestEarlyFrameForAnimation: already requested, skip');
      return
    }
    const context = this.uiAbility?.context
    if (!context) {
      Logger.error(TAG, 'requestEarlyFrameForAnimation: uiAbility context missing');
      return
    }
    const earlyPath = `${context.cacheDir}/anim_early_${Date.now()}.jpg`
    let requestOptions: photoAccessHelper.RequestOptions = {
      deliveryMode: photoAccessHelper.DeliveryMode.FAST_MODE,
    }
    const handler = new EarlyFrameHandler(earlyPath, this._photoEarlyFrameListener?.events ?? null)
    try {
      bridgeNativeLog(`[perf-cam] requestEarlyFrame: calling requestImageData(FAST_MODE) path=${earlyPath}`)
      photoAccessHelper.MediaAssetManager.requestImageData(context, photoAsset, requestOptions, handler)
        .then((id: string) => {
          this._earlyFrameRequestId = id
          Logger.info(TAG, `requestEarlyFrameForAnimation: requestId=${id} path=${earlyPath}`)
          bridgeNativeLog(`[perf-cam] requestEarlyFrame: OK requestId=${id}`)
        })
        .catch((err: BusinessError) => {
          Logger.error(TAG, `requestEarlyFrameForAnimation failed: ${err.code}, ${err.message}`)
          bridgeNativeLog(`[perf-cam] requestEarlyFrame FAILED code=${err.code} msg=${err.message}`)
          this._earlyFrameRequestId = undefined
        })
    } catch (err) {
      let e = err as BusinessError
      Logger.error(TAG, `requestEarlyFrameForAnimation exception: ${e.code}, ${e.message}`)
      bridgeNativeLog(`[perf-cam] requestEarlyFrame EXCEPTION code=${e.code} msg=${e.message}`)
      this._earlyFrameRequestId = undefined
    }
  }

  /**
   * 快速早帧（无分段式拍照能力的设备兜底）：photoAssetAvailable（~700ms）时
   * 通过只读 fd 直接拷出 asset 原始 JPEG，写入 cacheDir 并经
   * 'camerawesome/photo_early_frame' 通知 Dart。原始文件此刻已完整落盘
   * （分段/增强只影响 requestImageData 的交付时机，不影响磁盘文件），
   * fd 直读绕开 MediaAssetManager 请求队列，~100ms 内完成拷贝。
   * 仅作早帧（初版成片/缩略图），成片仍走 HIGH_QUALITY 增强交付，互不影响。
   * ctx.earlyFramePath 记录该文件：增强交付看门狗超时时以它作为成片兜底来源。
   */
  private deliverEarlyFrameFromAsset(photoAsset: photoAccessHelper.PhotoAsset, ctx?: PhotoCaptureContext): void {
    const sink = this._photoEarlyFrameListener?.events ?? null
    if (!sink) {
      Logger.info(TAG, 'deliverEarlyFrameFromAsset: early-frame sink not ready, skip');
      return
    }
    const context = this.uiAbility?.context
    if (!context) {
      Logger.error(TAG, 'deliverEarlyFrameFromAsset: uiAbility context missing');
      return
    }
    const earlyPath = `${context.cacheDir}/anim_early_${Date.now()}.jpg`
    this.tryEarlyFrameFd(photoAsset, sink, earlyPath, 1, ctx)
  }

  /**
   * getReadOnlyFd 带重试：实测部分场景（如前置摄像头）photoAssetAvailable 触发时
   * 媒体库内部尚未就绪（14000011 medialibrary inner fail），150ms 后重试可成功。
   * 共 3 次，均失败则放弃早帧（成片路径不受影响）。
   */
  private tryEarlyFrameFd(photoAsset: photoAccessHelper.PhotoAsset,
    sink: EventSink, earlyPath: string, attempt: number, ctx?: PhotoCaptureContext): void {
    photoAsset.getReadOnlyFd().then(async (fd: number) => {
      try {
        const dest = fileIo.openSync(earlyPath,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
        await fileIo.copyFile(fd, dest.fd)
        fileIo.closeSync(dest)
        const size = fileIo.statSync(earlyPath).size
        if (size > 20 * 1024) {
          // 记录本帧原始 JPEG 落盘路径：增强交付看门狗超时时据此降级交付成片。
          if (ctx !== undefined) {
            ctx.earlyFramePath = earlyPath
          }
          bridgeNativeLog(`[perf-cam] earlyFrameFd: copied bytes=${size} ` +
            `elapsed=${Date.now() - takePhotoStartAt}ms attempt=${attempt} to ${earlyPath}`)
          sink.success(earlyPath)
        } else {
          bridgeNativeLog(`[perf-cam] earlyFrameFd: too small (${size}B), skip`)
        }
      } catch (e) {
        let be = e as BusinessError
        bridgeNativeLog(`[perf-cam] earlyFrameFd: copy FAILED code=${be.code} msg=${be.message}`)
      } finally {
        photoAsset.close(fd).catch(() => {
        })
      }
    }).catch((err: BusinessError) => {
      if (attempt < 3) {
        bridgeNativeLog(`[perf-cam] earlyFrameFd: getReadOnlyFd FAILED code=${err.code} ` +
          `attempt=${attempt}, retry in 150ms`)
        setTimeout(() => {
          this.tryEarlyFrameFd(photoAsset, sink, earlyPath, attempt + 1, ctx)
        }, 150)
      } else {
        bridgeNativeLog(`[perf-cam] earlyFrameFd: getReadOnlyFd FAILED after ${attempt} ` +
          `attempts code=${err.code} msg=${err.message}, give up`)
      }
    })
  }

  setFocusPoint(previewSize: PreviewSize, x: number, y: number) {
    // 触控对焦：CameraKit 契约下 setFocusPoint 仅在 FOCUS_MODE_AUTO 模式有效，
    // 会根据对焦点执行一次「单次自动对焦」并锁定（与 iOS AVCaptureFocusModeAutoFocus 一致）。
    // ⚠️ 严禁在此把模式切回 FOCUS_MODE_CONTINUOUS_AUTO：该模式不支持对焦点，且会立即取消
    // 刚触发的单次对焦，导致「黄框出现但画面没有任何对焦效果」。切回连续对焦的时机由
    // setFocusAndExposureLockFn(locked=false) 控制（App 进入拍摄页与长按解锁时）。
    const nx = y / previewSize.getHeight()
    const ny = 1 - x / previewSize.getWidth()
    Logger.info(TAG, `setFocusPoint normalized=(${nx.toFixed(3)}, ${ny.toFixed(3)})`)
    this.session?.setFocusPoint({ x: nx, y: ny })
  }

  /**
   * 注册对焦状态监听（仅用于观测/验证触控对焦是否真正触发，只打日志，不切换对焦模式）。
   * 注意：不得在 FOCUS_STATE_FOCUSED 后自动切回 CONTINUOUS_AUTO——那会破坏 App 的
   * 「长按 AE/AF 锁定」功能；切回时机统一由 setFocusAndExposureLockFn(locked=false) 控制。
   */
  private registerFocusStateListener(): void {
    this.session?.on('focusStateChange', (err: BusinessError, focusState: camera.FocusState) => {
      if (err !== undefined && err.code !== 0) {
        Logger.error(TAG, `focusStateChange error code: ${err.code}`);
        return;
      }
      Logger.info(TAG, `focusStateChange focusState: ${focusState}`);
    });
  }

  /**
   * 设置曝光补偿
   * @param brightness
   */
  setExposureBias(brightness: number): void {
    Logger.debug(TAG, `setCorrection is called`);
    // brightness∈[0,1] 编码 EV∈[-3,+3]（0.5=0EV，与应用侧滑块一致）。
    // OHOS setExposureBias 的单位即 EV（stops），必须把 [0,1] 解码成真实 EV，
    // 否则原字面 [0,1] 会被当成 [0,1]EV，导致 -3 曝光仍是中性（等效原相机 0 曝光）。
    const ev = (brightness - 0.5) * 6.0;
    // AE 锁定态下 bias 不生效（对齐原相机「锁定后拖动拉曝光」）：
    // 先回 AUTO 让新 EV 生效，再用锁定时的测光点重新锁定，保持 AE 语义不变。
    if (this._aeLocked && this._aeLockPoint !== undefined) {
      this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_AUTO)
      this.session?.setExposureBias(ev)
      this.session?.setMeteringPoint(this._aeLockPoint)
      this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_LOCKED)
      return
    }
    this.session?.setExposureBias(ev)
  }

  /**
   * 长按锁定 AE/AF：x/y 为像素坐标（相对 previewSize），与 focusOnPoint 一致。
   * locked=true：对焦 AFA 到触点 + 曝光锁定到触点；locked=false：恢复连续自动。
   */
  setFocusAndExposureLockFn(locked: boolean, previewSize: PreviewSize, x: number, y: number): void {
    if (locked) {
      // 对焦：自动对焦到触点
      this.setFocusMode(camera.FocusMode.FOCUS_MODE_AUTO)
      this.setFocusPoint(previewSize, x, y)
      // 曝光：锁定模式 + 测光点
      if (this.session?.isExposureModeSupported(camera.ExposureMode.EXPOSURE_MODE_LOCKED)) {
        const meteringPoint: camera.Point = { x: y / previewSize.getHeight(), y: 1 - x / previewSize.getWidth() }
        this.session?.setMeteringPoint(meteringPoint)
        this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_LOCKED)
        // 记下锁定状态与测光点：锁定后拖动曝光需用同一测光点重新锁定
        this._aeLocked = true
        this._aeLockPoint = meteringPoint
      }
    } else {
      this._aeLocked = false
      this._aeLockPoint = undefined
      if (this.session?.isExposureModeSupported(camera.ExposureMode.EXPOSURE_MODE_AUTO)) {
        this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_AUTO)
      }
      this.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO)
    }
  }

  /**
   * 设置白平衡（传感器级，取景实时生效、直出即带）。
   * 预设：auto/daylight/cloudy/fluorescent/incandescent → 对应 WhiteBalanceMode。
   * 手动 k（3000–8000）：CameraKit 支持连续开尔文，用 setWhiteBalance + getWhiteBalanceRange 真值。
   * @param mode
   * @param k 手动色温（开尔文），可选；提供时优先使用连续色温
   */
  setWhiteBalanceFn(mode: string, k?: number): void {
    try {
      if (!this.session) {
        Logger.error(TAG, `setWhiteBalanceFn: session not ready, skipped`);
        return
      }
      // 前置固定 AUTO（学醒图路线，2026-09-19）：前置 ISP 预设增益表偏红不可信
      //（非 auto 档 R 通道高 30~40%），原生档位不应用；档位视觉由 Dart 软件色温
      // 矩阵（frontWbCompensation → previewFx 最内层对角增益）模拟。auto 档放行。
      if (this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT &&
        (k !== undefined && k !== null || mode !== 'auto')) {
        Logger.info(TAG, `setWhiteBalanceFn: front keeps AUTO, req mode=${mode} k=${k}`);
        return
      }
      // 手动色温：OHOS WhiteBalance 支持连续开尔文（API 20+）。
      // 手动 K 需先切换 MANUAL 模式再下发连续值；无回读变化时回退到预设模式。
      if (k !== undefined && k !== null) {
        this.setManualWhiteBalance(k)
        return
      }
      // 前置与后置统一走原生预设模式 setWhiteBalanceMode。
      // 2026-09-19 用户真机实测：前置「MANUAL + 映射色温」在本设备画面无任何变化
      //（HDI 接受 setWhiteBalance 但 ISP 不应用，前置 MANUAL 连续色温不可用），
      // 此前为绕开前置偏红而做的 MANUAL 特判反而让前置白平衡完全失效。
      // 后置预设模式实测正常，故前置不再特判，与后置共用同一路径。
      // 若后续发现前置预设档位偏色，应在不改变模式路径的前提下另行校准。
      // 预设模式映射
      let wbMode: camera.WhiteBalanceMode = camera.WhiteBalanceMode.AUTO
      switch (mode) {
        case 'auto':
          wbMode = camera.WhiteBalanceMode.AUTO
          break
        case 'cloudy':
          wbMode = camera.WhiteBalanceMode.CLOUDY
          break
        case 'incandescent':
          wbMode = camera.WhiteBalanceMode.INCANDESCENT
          break
        case 'fluorescent':
          wbMode = camera.WhiteBalanceMode.FLUORESCENT
          break
        case 'daylight':
          wbMode = camera.WhiteBalanceMode.DAYLIGHT
          break
        default:
          wbMode = camera.WhiteBalanceMode.AUTO
      }
      if (this.session.isWhiteBalanceModeSupported(wbMode)) {
        this.session?.setWhiteBalanceMode(wbMode)
        const activeMode = this.session.getWhiteBalanceMode()
        const activeValue = this.session.getWhiteBalance()
        Logger.info(TAG, `setWhiteBalanceFn set mode: ${wbMode}; active=${activeMode}; value=${activeValue}; supported=true`);
      } else {
        Logger.error(TAG, `setWhiteBalanceFn: mode not supported, mode: ${wbMode}`);
      }
    } catch (e) {
      Logger.error(TAG, `setWhiteBalanceFn error: ${(e as BusinessError).code}`);
    }
  }

  /**
   * 前置相机输出颜色继承后置相机会话的颜色空间（必须在 config 状态调用）。
   *
   * 同一场景下前后置 ISP 的默认 color space 可能不同，导致相同白平衡档位在
   * 前置呈现不同色偏。后置已与系统相机一致，因此在后置启动时记录其活动
   * color space（模块级 backActiveColorSpace，跨 CameraState 实例存活）；
   * 前置启动时优先切换到该空间。
   *
   * 时序铁律：setColorSpace/getActiveColorSpace/getSupportedColorSpaces 只在
   * config 状态有效（beginConfig 与 commitConfig 之间）；commitConfig 之后调用
   * 会抛 7400103 "Session not config"。此方法必须在 addOutput 之后、
   * commitConfig 之前调用。
   */
  private applyColorSpaceAlignment(): void {
    const session = this.session
    if (!session) {
      return
    }
    let active: number = colorSpaceManager.ColorSpace.UNKNOWN
    let supported: Array<number> = []
    try {
      active = session.getActiveColorSpace()
      supported = session.getSupportedColorSpaces().map((item: colorSpaceManager.ColorSpace): number => item)
    } catch (e) {
      Logger.info(TAG, `applyColorSpaceAlignment: query failed, keep default, err=${JSON.stringify(e)}`)
      return
    }
    Logger.info(TAG, `applyColorSpaceAlignment: position=${this.cameraPosition}; active=${active}; supported=${JSON.stringify(supported)}; back=${backActiveColorSpace}`)
    if (this.cameraPosition !== camera.CameraPosition.CAMERA_POSITION_FRONT) {
      backActiveColorSpace = active
      return
    }
    let target = backActiveColorSpace >= 0
      ? backActiveColorSpace
      : colorSpaceManager.ColorSpace.SRGB
    if (active === target || !supported.includes(target)) {
      return
    }
    try {
      session.setColorSpace(target as colorSpaceManager.ColorSpace)
      Logger.info(TAG, `applyColorSpaceAlignment: set front active ${active} -> ${target}`)
    } catch (e) {
      Logger.error(TAG, `applyColorSpaceAlignment: setColorSpace failed, err=${JSON.stringify(e)}`)
    }
  }

  private setManualWhiteBalance(k: number): boolean {
    if (!this.session) {
      return false
    }
    // OHOS 手动色温属于 MANUAL 模式。部分前置 ISP 不会响应“只设值、不切模式”。
    let manualSupported = false
    try {
      manualSupported = this.session.isWhiteBalanceModeSupported(camera.WhiteBalanceMode.MANUAL)
    } catch (e) {
      Logger.error(TAG, `setManualWhiteBalance: manual support check failed, err=${JSON.stringify(e)}`)
    }
    if (!manualSupported) {
      Logger.error(TAG, 'setManualWhiteBalance: MANUAL mode not supported')
      return false
    }
    try {
      this.session.setWhiteBalanceMode(camera.WhiteBalanceMode.MANUAL)
    } catch (e) {
      Logger.error(TAG, `setManualWhiteBalance: set MANUAL mode failed, err=${JSON.stringify(e)}`)
      return false
    }
    // 真机实测（2026-09-19）：前置 getWhiteBalanceRange 返回空（HDI return code 3，
    // Napi "whiteBalanceRange is empty"），但 MANUAL 模式本身设置成功。
    // 范围查询失败 ≠ 色温下发失败——不再直接放弃，改用保守假设范围 [2800,8000]
    // clamp 后继续尝试 setWhiteBalance，以「回读一致」判定是否真正生效；
    // 下发抛错或回读不一致时才回退预设模式（保持原有不退化语义）。
    let range: Array<number> | undefined = undefined
    try {
      range = this.session.getWhiteBalanceRange()
    } catch (e) {
      Logger.error(TAG, `setManualWhiteBalance: getWhiteBalanceRange failed, err=${JSON.stringify(e)}`)
    }
    let lo = 2800
    let hi = 8000
    let rangeStr = 'assumed[2800,8000]'
    if (range !== undefined && range !== null && range.length >= 2) {
      lo = range[0]
      hi = range[1]
      rangeStr = JSON.stringify(range)
    } else {
      Logger.info(TAG, 'setManualWhiteBalance: empty range, try assumed range [2800,8000] anyway')
    }
    const value: number = Math.min(Math.max(k, lo), hi)
    try {
      this.session.setWhiteBalance(value)
    } catch (e) {
      Logger.error(TAG, `setManualWhiteBalance: set value failed, err=${JSON.stringify(e)}`)
      return false
    }
    // 回读验证。前置预设档位是「已知偏色」路径，回退没有任何收益，因此：
    // - 回读抛错（部分 HDI 未实现 getWhiteBalance）→ 信下发成功，返回 true；
    // - 回读为 0（预设模式下的旧值，多为「未实现回读」）→ 同上信成功；
    // - 回读到具体值 → 与目标比对，一致才算生效。
    let curVal: number = -1
    try {
      curVal = this.session.getWhiteBalance()
    } catch (e) {
      Logger.info(TAG, `setManualWhiteBalance: readback threw, trust set success, err=${JSON.stringify(e)}`)
      return true
    }
    if (curVal === 0 && value !== 0) {
      Logger.info(TAG, `setManualWhiteBalance: readback 0 (unimplemented?), trust set success, K=${value}`)
      return true
    }
    Logger.info(TAG, `setManualWhiteBalance K: ${value}; range=${rangeStr}; after=${curVal}`);
    return Math.abs(curVal - value) <= 1
  }

  getMaxZoom(): number {
    let zoomRatios = this.session?.getZoomRatioRange()
    if (zoomRatios == undefined) {
      return 0
    }

    let maxZoom = zoomRatios[0]
    for (let zr of zoomRatios) {
      maxZoom = maxZoom > zr ? maxZoom : zr
    }
    return maxZoom
  }

  getMinZoom(): number {
    let zoomRatios = this.session?.getZoomRatioRange()
    if (zoomRatios == undefined) {
      return 0
    }
    let minZoom = zoomRatios[0]
    for (let zr of zoomRatios) {
      minZoom = minZoom < zr ? minZoom : zr
    }
    return minZoom
  }

  /**
   * 获取支持的所有分辨率
   *
   * @returns
   */
  getAllPriveiwSize(): PreviewSize[] {
    let psList: Array<PreviewSize> = []
    for (let pf of this.previewProfilesArray!!) {
      psList.push(new PreviewSize(pf.size.width, pf.size.height))
    }
    return psList
  }

  private getVideoRotation(degree: number): camera.ImageRotation {
    let videoRotation: camera.ImageRotation = camera.ImageRotation.ROTATION_0;
    try {
      videoRotation = this.videoOutput?.getVideoRotation(degree) ?? videoRotation;
    } catch (error) {
      // 失败返回错误码error.code并处理
      let err = error as BusinessError;
      Logger.error(TAG, `The videoOutput.getVideoRotation call failed. error code: ${err.code}`);
    }
    return videoRotation;
  }

  private getPhotoRotation(degree: number): camera.ImageRotation {
    let photoRotation: camera.ImageRotation = camera.ImageRotation.ROTATION_0;
    try {
      photoRotation = this.photoOutput?.getPhotoRotation(degree) ?? photoRotation;
    } catch (error) {
      // 失败返回错误码error.code并处理
      let err = error as BusinessError;
      Logger.error(TAG, `The photoOutput.getPhotoRotation call failed. error code: ${err.code}`);
    }
    return photoRotation;
  }

  public setPreviewRotation() {
    try {
      if (this.previewOutput) {
        let displayRotation = this.getDisplayRotation();
        let imageRotation = displayRotation * camera.ImageRotation.ROTATION_90;
        let previewRotation = this.previewOutput?.getPreviewRotation(imageRotation);
        this.previewOutput?.setPreviewRotation(previewRotation, false);
        this.previewOutput1?.setPreviewRotation(previewRotation, false);
      }
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `setPreviewRotation failed. error code: ${err.code}`);
    }
  }

  public getDisplayRotation(): number {
    let displayRotation = display.getDefaultDisplaySync().rotation;
    return displayRotation;
  }

  public set enableImageStream(value: boolean) {
    this._enableImageStream = value
  }

  public get enableImageStream(): boolean {
    return this._enableImageStream
  }

  public set captureMode(value: string) {
    this._captureMode = value
  }

  public get captureMode(): string {
    return this._captureMode
  }

  public set sensor(value: string) {
    this._sensor = value
  }

  public get sensor(): string {
    return this._sensor
  }

  public set aspectRatio(value: string) {
    this._aspectRatio = value
  }

  public get aspectRatio(): string {
    return this._aspectRatio
  }

  public set handlePhotoCb(value: (photoAsset: photoAccessHelper.PhotoAsset, path: string, result: Result<boolean>) => void) {
    this._handlePhotoCb = value
  }

  // 分阶段拍照早帧监听器引用（由插件在 initCamera 时注入，Dart 订阅通道后才非空）
  public set photoEarlyFrameListener(value: PhotoEarlyFrameStreamListener | null) {
    this._photoEarlyFrameListener = value
  }

  public set mirrorFrontCamera(value: boolean) {
    this._mirrorFrontCamera = value
  }

  public set videoPath(value: string) {
    this._videoPath = value
  }

  public set enableAudioRecording(value: boolean) {
    this._enableAudioRecording = value
  }

  public set exifPreferences(value: ExifPreferences) {
    this._exifPreferences = value
  }

  public set colorMatrix(value: Array<number>) {
    this._colorMatrix = value
  }

  public get colorMatrix(): Array<number> {
    return this._colorMatrix
  }

  public set imageAnalysisBuilder(value: ImageAnalysisBuilder | undefined) {
    this._imageAnalysisBuilder = value
  }

  public get imageAnalysisBuilder(): ImageAnalysisBuilder | undefined {
    return this._imageAnalysisBuilder
  }

  private async getCurrentDeviceDegree(): Promise<number> {
    // 常驻订阅已就绪：直接返回缓存角（快门关键路径零等待）。
    // 缓存仅在有效读数（非 0）时更新，平放（z 主导）保留上次有效方向，
    // 与原 getGravity()===0 时回退 this.degree 的语义一致。
    if (this._degreeSubscribed) {
      return this.degree
    }
    let deviceDegree: number = await this.getGravity();
    deviceDegree = deviceDegree === 0 ? this.degree : deviceDegree;
    if (deviceDegree !== this.degree) {
      this.degree = deviceDegree;
    }
    return deviceDegree;
  }

  /**
   * 重力传感器常驻订阅：持续更新 [degree] 缓存。
   * takePhoto/startVideo 等关键路径改读缓存，消除 sensor.once 的
   * 单次读数等待（数十至数百 ms 快门延迟的固定组成部分）。
   */
  private startDegreeSensor(): void {
    if (this._degreeSubscribed) {
      return
    }
    if (!canIUse('SystemCapability.Sensors.Sensor')) {
      Logger.info(TAG, 'degree sensor: SystemCapability.Sensors.Sensor unavailable')
      return
    }
    try {
      sensor.on(sensor.SensorId.GRAVITY, (data: sensor.GravityResponse) => {
        const d = this.getRealData(data)
        // 0 = 平放/无效读数（getRealData 对 z 主导姿态返回 0），保留上次有效方向。
        if (d !== 0) {
          this.degree = d
        }
      })
      this._degreeSubscribed = true
      Logger.info(TAG, 'degree sensor: subscribed (continuous cache)')
    } catch (error) {
      let err = error as BusinessError
      Logger.error(TAG, `degree sensor on failed, code=${err.code}`)
    }
  }

  private stopDegreeSensor(): void {
    if (!this._degreeSubscribed) {
      return
    }
    try {
      sensor.off(sensor.SensorId.GRAVITY)
    } catch (error) {
      let err = error as BusinessError
      Logger.error(TAG, `degree sensor off failed, code=${err.code}`)
    }
    this._degreeSubscribed = false
  }

  private async getGravity(): Promise<number> {
    if (!canIUse('SystemCapability.Sensors.Sensor')) {
      Logger.info(TAG, 'Sensor can not use!');
      return -1;
    }
    let sensors: sensor.Sensor[];
    try {
      sensors = await sensor.getSensorList();
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(`getSensorList failed, error: ${err.code}`);
      return -1; // 异常场景下返回默认值
    }
    let isSupported = false;
    for (let i = 0; i < sensors.length; i++) {
      if (sensors[i].sensorId === sensor.SensorId.GRAVITY) {
        isSupported = true;
        break;
      }
    }
    try {
      if (isSupported === true) {
        const promise: Promise<number> = new Promise((resolve) => {
          sensor.once(sensor.SensorId.GRAVITY, (data: sensor.GravityResponse) => {
            resolve(this.getRealData(data));
          });
        })
        return promise;
      } else {
        const promise: Promise<number> = new Promise((resolve) => {
          sensor.once(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
            resolve(this.getRealData(data as sensor.GravityResponse));
          });
        })
        return promise;
      }
    } catch (error) {
      let err = error as BusinessError;
      Logger.error(TAG, `Get GRAVITY or ACCELEROMETER data error code: ${err.code}`);
      return -1;
    }
  }

  private getRealData(data: sensor.GravityResponse): number {
    let getDeviceDegree: number = 0;
    let x = data.x;
    let y = data.y;
    let z = data.z;
    if ((x * x + y * y) * 3 < z * z) {
      return getDeviceDegree;
    } else {
      try {
        let sd: Decimal = Decimal.atan2(y, -x);
        let sc: Decimal = Decimal.round(Number(sd) / Math.PI * 180);
        getDeviceDegree = 90 - Number(sc);
        getDeviceDegree = getDeviceDegree >= 0 ? getDeviceDegree % 360 : getDeviceDegree % 360 + 360;
      } catch (error) {
        let err = error as BusinessError;
        Logger.error(`decimal failed, error: ${err.code}`);
      }
    }
    return getDeviceDegree;
  }
}

let takePhotoStartAt: number = 0

// 增强兜底交付 handler（修复④）：仅作适配层——数据到达即转交 CameraState
// onEnhancedDataPrepared 统一处理（写盘 / 兜底 / 结算 / 释放串行闸门），
// 自身不持有 path/result/ctx 单槽位，连拍时多个在途请求互不覆盖。
//
// 修复⑤（关键，根因）：`onDataPrepared` 必须是**箭头函数属性**，不能写成类方法。
// 框架回调不保证按 `handler.onDataPrepared(...)` 绑定调用；一旦 unbound 调用，
// 类方法里的 `this` 为 undefined，回调在取成员时抛错并被框架静默吞掉 →
// onDataPrepared 永不生效（真机表现：`requestId` 正常返回、7/7 帧零回调、
// 只能等看门狗兜底）。旧实现用模块级全局、完全不依赖 this，反而能正常交付。
// 官方示例同样注明「使用箭头函数确保 this 引用不会丢失」。
class MediaDataHandler implements photoAccessHelper.MediaAssetDataHandler<ArrayBuffer> {
  private owner: CameraState
  private item: EnhancedDeliveryItem

  constructor(owner: CameraState, item: EnhancedDeliveryItem) {
    this.owner = owner
    this.item = item
  }

  onDataPrepared = async (data: ArrayBuffer, map?: Map<string, string>): Promise<void> => {
    // 首行只依赖闭包（不取 this.owner）之外的最小状态：即使后续处理抛错，
    // 这一行也能证明「回调确实到达」。
    bridgeNativeLog(`[perf-cam] enhanced: onDataPrepared enter bytes=${data === undefined ? -1 : data.byteLength} ` +
      `quality=${map?.get('quality') ?? 'n/a'} path=${this.item.path}`)
    await this.owner.onEnhancedDataPrepared(this.item, data)
  }
}

// 分阶段拍照早帧交付 handler：FAST_MODE 下 onDataPrepared 回调两次。
// 第一次（一阶段低质量图，~672ms）写入 cacheDir 动画源文件并通知 Dart 提前触发水印动画；
// 第二次（二阶段全质量图）因成片已由 photoAvailable 直出，直接跳过避免重复/覆盖。
class EarlyFrameHandler implements photoAccessHelper.MediaAssetDataHandler<ArrayBuffer> {
  private path: string
  private sink: EventSink | null
  private delivered: boolean = false

  constructor(path: string, sink: EventSink | null) {
    this.path = path
    this.sink = sink
  }

  // 同 MediaDataHandler：必须以箭头函数属性声明，避免框架 unbound 调用时丢 this。
  onDataPrepared = async (data: ArrayBuffer, map?: Map<string, string>): Promise<void> => {
    if (data === undefined || data.byteLength === 0) {
      Logger.error('EarlyFrameHandler: data is empty');
      return;
    }
    if (this.delivered) {
      bridgeNativeLog(`[perf-cam] EarlyFrameHandler: full-quality skipped elapsed=${Date.now() - takePhotoStartAt}ms`);
      return;
    }
    this.delivered = true
    try {
      const file = await fileIo.open(this.path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const written = fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      bridgeNativeLog(`[perf-cam] EarlyFrameHandler: saved early anim frame bytes=${written} ` +
        `elapsed=${Date.now() - takePhotoStartAt}ms to ${this.path}`);
      this.sink?.success(this.path)
    } catch (error) {
      Logger.error(`EarlyFrameHandler: write failed. code ${(error as BusinessError).code}, ` +
        `message ${(error as BusinessError).message}`);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 原生诊断日志桥：原生关键拍照/早帧耗时日志经 EventChannel 'camerawesome/native_log'
// 转发到 Dart 侧 debugPrint，只需看 flutter run 一个窗口即可定位性能问题。
// ─────────────────────────────────────────────────────────────────────────
let nativeLogSink: EventSink | null = null

export function bridgeNativeLog(msg: string): void {
  // 仍打 HiLog（保留原始日志），同时转发给 Flutter console。
  Logger.info(TAG, msg)
  nativeLogSink?.success(msg)
}

/** EventChannel 'camerawesome/native_log' 的 StreamHandler：仅持有 events sink，由 Dart 订阅触发。 */
export class NativeLogStreamListener implements StreamHandler {
  onListen(args: Any, events: EventSink): void {
    nativeLogSink = events
  }
  onCancel(args: Any): void {
    if (nativeLogSink) {
      nativeLogSink.endOfStream()
      nativeLogSink = null
    }
  }
}

// EventChannel 'camerawesome/photo_early_frame' 的 StreamHandler：仅持有 events sink，
// 由插件在 initCamera 时注入 CameraState.photoEarlyFrameSink，早帧路径经此通知 Dart。
export class PhotoEarlyFrameStreamListener implements StreamHandler {
  private _events: EventSink | null = null

  onListen(args: Any, events: EventSink): void {
    this._events = events
  }

  onCancel(args: Any): void {
    if (this._events) {
      this._events.endOfStream()
      this._events = null
    }
  }

  public get events(): EventSink | null {
    return this._events
  }
}
