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

// photoAvailable 直出写盘所需的路径与结果回调。
// ArkTS 强制对象类型必须显式声明为 class/interface，禁止匿名对象字面量类型。
export interface PhotoPathResult {
  path: string
  result: Result<boolean>
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
  directDone: boolean
}

const TAG: string = 'CameraState'

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
  // path/result 落盘，不由注入方闭包捕获——连拍时闭包会被后一次调用覆盖）
  private _handlePhotoCb: (photoAsset: photoAccessHelper.PhotoAsset, path: string, result: Result<boolean>) => void = () => {
  }
  // 连拍安全的拍照请求队列（替代原单槽位 _photoPath/_photoResult/_photoDirectDone）：
  // - directQueue 供 photoAvailable 逐帧消费（直出原始 JPEG 写盘）；
  // - assetQueue 供 photoAssetAvailable 逐帧消费（直出失败的帧走增强兜底）。
  // 两通道各自按拍照发起顺序保序，与框架事件到达的交错顺序无关。
  private _photoDirectQueue: PhotoCaptureContext[] = []
  private _photoAssetQueue: PhotoCaptureContext[] = []
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
          c.result.success(false)
        }
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
   * 以指定参数触发一次拍照
   */
  async takePhoto(): Promise<void> {
    const degree = await this.getCurrentDeviceDegree();
    let photoSettings: camera.PhotoCaptureSetting = {
      quality: camera.QualityLevel.QUALITY_LEVEL_HIGH, // 官方推荐高画质，降低JPEG压缩对清晰度的影响
      mirror: this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT ? this._mirrorFrontCamera : false,
      rotation: this.getPhotoRotation(degree)
    };
    // 直出标记改为 per-capture（photoPathResult 入队的 ctx.directDone），
    // 连拍时各帧互不干扰，无需在每次拍摄前复位单槽位标记。
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
    await this.photoOutput?.capture(photoSettings);
    Logger.info(TAG, `takePhoto capture() returned after ${Date.now() - takePhotoStartAt}ms`);
    Logger.info(TAG, 'takePicture end');
    // [性能拆解] 快照后 JPEG 交付是否为主要耗时：对比本行与 photoAvailable saved 的 elapsed。
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
        });
      // 监听拍照帧输出捕获
      this.photoOutput!!.on('frameShutter',
        (err: BusinessError, frameShutterInfo: camera.FrameShutterInfo): void => {
          Logger.info(TAG, `photoOutputCallBack frameShutter captureId:
          ${frameShutterInfo.captureId}, timestamp: ${frameShutterInfo.timestamp}`);
        });
      // 监听拍照结束
      this.photoOutput!!.on('captureEnd', (err: BusinessError, captureEndInfo: camera.CaptureEndInfo): void => {
        Logger.info(TAG, `photoOutputCallBack captureEnd captureId:
          ${captureEndInfo.captureId}, frameCount: ${captureEndInfo.frameCount}`);
      });
      // 监听拍照异常
      this.photoOutput!!.on('error', (data: BusinessError): void => {
        Logger.info(TAG, `photoOutPut data: ${JSON.stringify(data)}`);
      });
      // 拍照原始帧直出（绕过系统相册增强管线，避免"取景器正常、拍照偏黄"）。
      // photoAvailable 返回相机原始 JPEG buffer，直接写盘，不经过相册色彩增强。
      // 连拍安全：从 directQueue 出队本帧的请求上下文，写盘路径/回调与发起
      // 顺序一一配对，后一次 takePhoto 不再覆盖前一次的单槽位状态。
      this.photoOutput!!.on('photoAvailable',
        (err: BusinessError, photo: camera.Photo) => {
          Logger.info(TAG, 'photoAvailable begin');
          Logger.info(TAG, `[perf-cam] photoAvailable begin elapsed=${Date.now() - takePhotoStartAt}ms`);
          const ctx = this._photoDirectQueue.shift()
          if (ctx === undefined) {
            Logger.error(TAG, 'photoAvailable: no pending capture request, skip');
            return
          }
          if (err && err.code !== 0) {
            Logger.error(TAG, `photoAvailable error: ${err.code}`);
            ctx.result.success(false)
            return
          }
          if (!photo || !photo.main) {
            Logger.error(TAG, 'photoAvailable: photo or photo.main is null');
            ctx.result.success(false)
            return
          }
          const imageObj = photo.main
          // 同步置位直出标记（在任何异步回调之前），确保同帧 photoAssetAvailable 被跳过，
          // 不会用相册增强图覆盖原始 JPEG。仅在写盘失败时复位以允许增强图回退。
          ctx.directDone = true
          imageObj.getComponent(image.ComponentType.JPEG,
            (errCode: BusinessError, component: image.Component) => {
              Logger.info(TAG, `[perf-cam] getComponent(jpeg) cb elapsed=${Date.now() - takePhotoStartAt}ms`);
              if (!errCode && component && component.byteBuffer) {
                try {
                  const buffer = component.byteBuffer as ArrayBuffer
                  const file = fileIo.openSync(ctx.path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
                  const written = fileIo.writeSync(file.fd, buffer)
                  fileIo.closeSync(file)
                  Logger.info(TAG, `photoAvailable: saved raw JPEG bytes=${written} elapsed=${Date.now() - takePhotoStartAt}ms to ${ctx.path}`)
                  ctx.result.success(true)
                } catch (e) {
                  Logger.error(TAG, `photoAvailable save failed: ${JSON.stringify(e)}`)
                  ctx.directDone = false
                  ctx.result.success(false)
                }
              } else {
                Logger.error(TAG, `photoAvailable getComponent failed: code=${errCode?.code}, path=${ctx.path}`)
                ctx.directDone = false
                ctx.result.success(false)
              }
              imageObj.release()
            });
        });

      this.photoOutput!!.on('photoAssetAvailable',
        (err: BusinessError, photoAsset: photoAccessHelper.PhotoAsset) => {
          Logger.info(TAG, 'photoAssetAvailable begin');
          if (err) {
            Logger.error(TAG, 'photo is err');
            return;
          }
          // 连拍安全：从 assetQueue 出队本帧的请求上下文（与 photoAvailable 的
          // directQueue 各自保序），直出/增强判定与本帧 ctx 配对。
          const ctx = this._photoAssetQueue.shift()
          if (ctx === undefined) {
            Logger.error(TAG, 'photoAssetAvailable: no pending capture request, skip');
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
            this.requestEarlyFrameForAnimation(photoAsset);
            return;
          }
          this._handlePhotoCb(photoAsset, ctx.path, ctx.result);
        });
    } catch (err) {
      Logger.error(TAG, 'photoOutputCallBack error');
    }
  }

  async saveCameraPhoto(path: string, photoAsset: photoAccessHelper.PhotoAsset, result: Result<boolean>) {
    Logger.info(TAG, 'saveCameraPhoto');
    if (photoRequestId) {
      Logger.debug(TAG, 'saveCameraPhoto has photoRequestId = ' + photoRequestId);
      return
    }
    try {
      let requestOptions: photoAccessHelper.RequestOptions = {
        // 兜底路径也需要全质量图：FAST_MODE 仅接收一阶段低质量图会导致成片模糊，
        // 改 HIGH_QUALITY_MODE 接收二阶段全质量图。正常拍照仍以 photoAvailable 原始帧直出为主，
        // 此路径仅在 photoAvailable 未触发时兜底。
        deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE,
      }
      savePhotoPath = path
      takePhotoResult = result

      let handler = new MediaDataHandler();
      photoRequestId =
        await photoAccessHelper.MediaAssetManager.requestImageData(this.uiAbility?.context, photoAsset,
          requestOptions, handler);
    } catch (err) {
      let error = err as BusinessError
      Logger.error(TAG, `apply saveCameraPhoto failed with error: ${error.code}, ${error.message}`);
      result.success(false)
    }
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
      photoAccessHelper.MediaAssetManager.requestImageData(context, photoAsset, requestOptions, handler)
        .then((id: string) => {
          this._earlyFrameRequestId = id
          Logger.info(TAG, `requestEarlyFrameForAnimation: requestId=${id} path=${earlyPath}`)
        })
        .catch((err: BusinessError) => {
          Logger.error(TAG, `requestEarlyFrameForAnimation failed: ${err.code}, ${err.message}`)
          this._earlyFrameRequestId = undefined
        })
    } catch (err) {
      let e = err as BusinessError
      Logger.error(TAG, `requestEarlyFrameForAnimation exception: ${e.code}, ${e.message}`)
      this._earlyFrameRequestId = undefined
    }
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
        this.session?.setMeteringPoint({ x: y / previewSize.getHeight(), y: 1 - x / previewSize.getWidth() })
        this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_LOCKED)
      }
    } else {
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
      // 手动色温：OHOS WhiteBalance 支持连续开尔文（API 20+）。
      // 官方 Method 2：直接用 getWhiteBalanceRange + setWhiteBalance，不切 MANUAL 模式。
      // 若「模式 + 值」同时设置，只生效一种且模式优先，会覆盖掉手动值（回读恒为 0）。
      if (k !== undefined && k !== null) {
        let range: Array<number> = []
        try {
          range = this.session.getWhiteBalanceRange()
        } catch (e) {
          Logger.error(TAG, `setWhiteBalanceFn: getWhiteBalanceRange failed, err=${JSON.stringify(e)}`)
        }
        let value: number = k
        if (range && range.length >= 2) {
          value = Math.min(Math.max(k, range[0]), range[1])
        }
        this.session?.setWhiteBalance(value)
        Logger.info(TAG, `setWhiteBalanceFn set manual K: ${value}; range=${JSON.stringify(range)}`);
        // 回读确认是否真正生效
        let curVal: number | undefined = this.session.getWhiteBalance()
        Logger.info(TAG, `setWhiteBalanceFn set manual AFTER: value=${curVal}`)
        return
      }
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
        Logger.info(TAG, `setWhiteBalanceFn set mode: ${wbMode}; supported=true`);
      } else {
        Logger.error(TAG, `setWhiteBalanceFn: mode not supported, mode: ${wbMode}`);
      }
    } catch (e) {
      Logger.error(TAG, `setWhiteBalanceFn error: ${(e as BusinessError).code}`);
    }
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

  public set photoPathResult(value: PhotoPathResult) {
    // 连拍安全：每次拍照入队独立的请求上下文（两通道共享同一引用），
    // photoAvailable / photoAssetAvailable 各自从对应队列按序消费，
    // 后一次 takePhoto 不再覆盖前一次的路径/回调。
    const ctx: PhotoCaptureContext = { path: value.path, result: value.result, directDone: false }
    this._photoDirectQueue.push(ctx)
    this._photoAssetQueue.push(ctx)
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

let savePhotoPath: string | undefined = undefined
let takePhotoResult: Result<boolean> | undefined = undefined
let photoRequestId: string | undefined = undefined
let takePhotoStartAt: number = 0

class MediaDataHandler implements photoAccessHelper.MediaAssetDataHandler<ArrayBuffer> {
  async onDataPrepared(data: ArrayBuffer) {
    if (data === undefined || savePhotoPath === undefined || takePhotoResult === undefined) {
      Logger.error('Error occurred when preparing data');
      return;
    }
    // 直接落盘全质量 JPEG buffer，不做 createPixelMap + effectKit 重编码：
    // 避免在主线程逐像素处理后阻塞拍照（速度），也避免二次压缩损失清晰度（质量）。
    // 成片颜色由应用内 Dart 处理器统一处理，无需在原生层二次上色。
    try {
      const file = await fileIo.open(savePhotoPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const written = fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      Logger.info(`photoAssetAvailable: saved bytes=${written} elapsed=${Date.now() - takePhotoStartAt}ms`);
      takePhotoResult.success(true);
    } catch (error) {
      Logger.error(`Failed to write the photo file.code ${error.code},message is ${error.message}`);
      takePhotoResult?.success(false);
    } finally {
      photoRequestId = undefined;
    }
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

  async onDataPrepared(data: ArrayBuffer) {
    if (data === undefined || data.byteLength === 0) {
      Logger.error('EarlyFrameHandler: data is empty');
      return;
    }
    if (this.delivered) {
      Logger.info(`[perf-cam] EarlyFrameHandler: full-quality skipped elapsed=${Date.now() - takePhotoStartAt}ms`);
      return;
    }
    this.delivered = true
    try {
      const file = await fileIo.open(this.path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      const written = fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);
      Logger.info(`[perf-cam] EarlyFrameHandler: saved early anim frame bytes=${written} ` +
        `elapsed=${Date.now() - takePhotoStartAt}ms to ${this.path}`);
      this.sink?.success(this.path)
    } catch (error) {
      Logger.error(`EarlyFrameHandler: write failed. code ${(error as BusinessError).code}, ` +
        `message ${(error as BusinessError).message}`);
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