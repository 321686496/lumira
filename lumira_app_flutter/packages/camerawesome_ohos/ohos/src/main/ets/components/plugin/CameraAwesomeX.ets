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

import {
  AbilityAware,
  AbilityPluginBinding,
  Any,
  EventChannel,
  FlutterPlugin,
  FlutterPluginBinding,
  TextureRegistry
} from '@ohos/flutter_ohos';
import { AnalysisImageConverter } from '../cameraX/AnalysisImageConverter';
import { AspectRatio, ImageAnalysisBuilder } from '../cameraX/ImageAnalysisBuilder';
import {
  AnalysisImageUtils,
  AndroidFocusSettings,
  CameraInterface,
  ExifPreferences,
  PigeonSensorTypeDevice,
  PreviewSize,
  Result,
  VideoOptions
} from '../cameraX/Pigeon';
import Logger from '../utils/Logger';
import { BusinessError } from '@ohos.base';
import UIAbility from '@ohos.app.ability.UIAbility';
import { CameraPermissions } from '../cameraX/CameraPermissions';
import { CameraAbilityLifecycle } from '../cameraX/CameraAbilityLifecycle';
import { CameraState, CaptureMode } from '../cameraX/CameraState';
import { PhysicalButtonsHandler } from '../cameraX/PhysicalButtonsHandler';
import { camera } from '@kit.CameraKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { OrientationStreamListener } from '../cameraX/OrientationStreamListener';
import { CameraDeviceChangeListener } from '../sensors/CameraDeviceChangeListener';
import { SensorOrientationListener } from '../sensors/SensorOrientationListener';
import { display } from '@kit.ArkUI';
import { DisplayRotationListener } from '../display/DisplayRotationListener';
import window from '@ohos.window';

const TAG: string = 'CameraAwesomeX';

/** CameraAwesomeX **/
export default class CameraAwesomeX extends CameraInterface implements FlutterPlugin, AbilityAware {
  uiAbility: UIAbility | undefined = undefined
  binding: FlutterPluginBinding | undefined = undefined
  textureRegistry: TextureRegistry | null = null
  cameraPermissions: CameraPermissions = new CameraPermissions()
  imageStreamChannel: EventChannel | undefined = undefined
  cameraState: CameraState | null = null
  physicalButtonHandler: PhysicalButtonsHandler | undefined
  orientationStreamListener: OrientationStreamListener | undefined
  private textureId: number = -1
  private colorMatrix: Array<number> = []
  private abilityLifecycleCallback: CameraAbilityLifecycle | undefined = undefined
  private sensorOrientationListener: SensorOrientationListener = new SensorOrientationListener()
  private displayRotationListener: DisplayRotationListener = new DisplayRotationListener()
  private cameraDeviceChangeListener: CameraDeviceChangeListener = new CameraDeviceChangeListener()
  private lastWindowStatusType: window.WindowStatusType | undefined = undefined
  private displayRotation: number = 0;
  // 监听折叠屏状态
  private foldStatusCallback =
    (err: BusinessError, info: camera.FoldStatusInfo): void => this.registerFoldStatusChanged(err, info);

  /**
   * 初始化相机
   *
   * @param sensor 传感器
   * @param aspectRatio 纵横比
   * @param zoom 焦距
   * @param mirrorFrontCamera 前置摄像头是否镜像拍照
   * @param enablePhysicalButton 启用物理按钮
   * @param flashMode 闪光模式
   * @param captureMode 捕捉模式
   * @param enableImageStream 启用图像流
   * @param exifPreferences exif首选项
   * @param result 返回结果
   */
  async setupCamera(sensor: string, aspectRatio: string, zoom: number, mirrorFrontCamera: boolean,
    enablePhysicalButton: boolean, flashMode: string, captureMode: string, enableImageStream: boolean,
    exifPreferences: ExifPreferences, result: Result<boolean>): Promise<void> {

    Logger.debug(TAG, 'setupCamera 相机初始化');

    try {
      if (enablePhysicalButton) {
        this.physicalButtonHandler?.startListen()
      } else {
        this.physicalButtonHandler?.endListen()
      }

      this.textureId = this.textureRegistry!!.getTextureId()

      this.cameraState =
        new CameraState(this.uiAbility!!, this.textureRegistry!!, this.textureId, sensor, aspectRatio, zoom,
          mirrorFrontCamera,
          enablePhysicalButton, flashMode,
          captureMode, enableImageStream, exifPreferences)
      this.abilityLifecycleCallback!!.cameraState = this.cameraState

      // 初始化相机
      await this.cameraState.initCamera()
      // 设置滤镜
      this.cameraState.colorMatrix = this.colorMatrix

      this.orientationStreamListener =
        new OrientationStreamListener([this.sensorOrientationListener]);
      if (this.abilityLifecycleCallback) {
        this.abilityLifecycleCallback.orientationStreamListener = this.orientationStreamListener;
      }

      this.imageStreamChannel?.setStreamHandler(this.cameraState)

      this.cameraState?.getCameraManager()?.on('foldStatusChange', this.foldStatusCallback);

      this.cameraState!!.cameraDeviceChangeListener = this.cameraDeviceChangeListener;

      this.rotationChanged();

      result.success(true)
    } catch (e) {
      let err = e as BusinessError;
      Logger.error(TAG, `initCamera fail: ${JSON.stringify(err)}`);
      result.success(false)
    }
  }

  checkPermissions(): string[] {
    throw new Error('Method not implemented.');
  }

  /**
   * 申请权限
   *
   * @param saveGpsLocation
   * @param result
   */
  async requestPermissions(saveGpsLocation: boolean, result: Result<string[]>): Promise<void> {
    Logger.debug(TAG, `requestPermissions is called`);
    let permissions = await this.cameraPermissions.requestPermissions(this.uiAbility!!.context, saveGpsLocation)
    let resultPermissions: Array<string> = []
    for (let p of permissions) {
      switch (p) {
        case 'ohos.permission.CAMERA':
          resultPermissions.push('camera')
          break;
        case 'ohos.permission.MICROPHONE':
          resultPermissions.push('record_audio')
          break
        case 'ohos.permission.APPROXIMATELY_LOCATION':
          resultPermissions.push('location')
          break
      }
    }
    result.success(resultPermissions)
  }

  getPreviewTextureId(): number {
    Logger.debug(TAG, `getPreviewTextureId is called`);
    return this.textureId
  }

  takePhoto(path: string, result: Result<boolean>): void {
    Logger.debug(TAG, `takePhoto is called`);
    this.cameraState!!.handlePhotoCb = async (photoAsset: photoAccessHelper.PhotoAsset) => {
      await this.cameraState?.saveCameraPhoto(path, photoAsset, result)
    }
    this.cameraState?.takePhoto()
  }

  recordVideo(path: string, options: VideoOptions, result: Result<void>): void {
    Logger.debug(TAG, `recordVideo is called`);
    this.cameraState!!.videoPath = path
    this.cameraState!!.initCamera().then(async () => {
      await this.cameraState?.startVideo()
      result.success()
    }).catch((error: Any) => {
      result.error(error)
    }).finally(() => {
      Logger.debug(TAG, 'recordVideo end');
    })
  }

  async pauseVideoRecording(): Promise<void> {
    Logger.debug(TAG, `pauseVideoRecording is called`);
    await this.cameraState?.pauseRecordingProcess()
  }

  async resumeVideoRecording(): Promise<void> {
    Logger.debug(TAG, `resumeVideoRecording is called`);
    await this.cameraState?.resumeRecordingProcess()
  }

  receivedImageFromStream(): void {
    Logger.debug(TAG, `receivedImageFromStream is called`);
    this.cameraState?.imageAnalysisBuilder?.finish()
  }

  async stopRecordingVideo(result: Result<boolean>): Promise<void> {
    Logger.debug(TAG, `stopRecordingVideo is called`);
    await this.cameraState?.stopVideo()
    result.success(true)
  }

  getFrontSensors(): PigeonSensorTypeDevice[] {
    Logger.debug(TAG, `getFrontSensors is called`);
    return []
  }

  getBackSensors(): PigeonSensorTypeDevice[] {
    Logger.debug(TAG, `getBackSensors is called`);
    return []
  }

  start(): boolean {
    Logger.debug(TAG, `start is called`);
    return true
  }

  stop(): boolean {
    Logger.debug(TAG, `stop is called`);
    this.cameraState?.releaseCamera()
    return true
  }

  setFlashMode(mode: string): void {
    Logger.debug(TAG, `setFlashMode is called`);
    this.cameraState?.setFlashFn(mode)
  }

  handleAutoFocus(): void {
    Logger.debug(TAG, `handleAutoFocus is called`);
    throw new Error('Method not implemented.');
  }

  focusOnPoint(previewSize: PreviewSize, x: number, y: number, androidFocusSettings: AndroidFocusSettings): void {
    Logger.debug(TAG, `focusOnPoint is called`);
    this.cameraState?.setFocusMode(camera.FocusMode.FOCUS_MODE_AUTO)
    this.cameraState?.setFocusPoint(previewSize, x, y)
  }

  setZoom(zoom: number): void {
    Logger.debug(TAG, `setZoom is called`);
    this.cameraState?.setZoom(zoom)
  }

  setMirrorFrontCamera(mirror: boolean): void {
    Logger.debug(TAG, `setMirrorFrontCamera is called`);
    this.cameraState!!.mirrorFrontCamera = mirror
  }

  async setSensor(sensor: string, deviceId: string): Promise<void> {
    Logger.debug(TAG, `setSensor is called`);
    if (this.cameraState && this.cameraState.sensor !== sensor
      && this.cameraState.supportedCameras && this.cameraState.supportedCameras.length > 1) {
      this.cameraState.sensor = sensor
      this.cameraState.aspectRatio = AspectRatio.RATIO_4_3
      await this.cameraState!!.initCamera()
    }
  }

  /**
   * 设置曝光补偿
   * @param brightness
   */
  setCorrection(brightness: number): void {
    Logger.debug(TAG, `setCorrection is called`);
    this.cameraState?.setExposureBias(brightness)
  }

  /**
   * 设置白平衡模式与色温
   * @param mode 预设模式：auto / daylight / cloudy / fluorescent / incandescent
   * @param temperatureK 手动色温（开尔文），可选；提供时优先使用连续色温
   */
  setWhiteBalance(mode: string, temperatureK?: number): void {
    Logger.info(TAG, `setWhiteBalance is called, mode: ${mode}, temperatureK: ${temperatureK}`);
    this.cameraState?.setWhiteBalanceFn(mode, temperatureK)
  }

  getMaxZoom(): number {
    Logger.debug(TAG, `getMaxZoom is called`);
    return this.cameraState!!.getMaxZoom()
  }

  getMinZoom(): number {
    Logger.debug(TAG, `getMinZoom is called`);
    return this.cameraState!!.getMinZoom()
  }

  setCaptureMode(mode: string): void {
    Logger.debug(TAG, `setCaptureMode is called`);
    if (this.cameraState!!.captureMode != mode) {
      this.cameraState!!.captureMode = mode
      if (this.cameraState!!.captureMode == CaptureMode.VIDEO) {
        // 获取应用缓存路径
        const cacheDir = this.uiAbility!!.context.cacheDir;
        this.cameraState!!.videoPath = `${cacheDir}/temp.mp4`;
      }
      this.cameraState!!.initCamera().then(async () => {
        this.rotationChanged();
      }).catch((error: Any) => {
        Logger.debug(TAG, `recordVideo error ： ${error}`);
      })
    }
  }

  setRecordingAudioMode(enableAudio: boolean, result: Result<boolean>): void {
    Logger.debug(TAG, `setRecordingAudioMode is called`);
    this.cameraState!!.enableAudioRecording = enableAudio
    result.success(true)
  }

  availableSizes(): PreviewSize[] {
    Logger.debug(TAG, `availableSizes is called`);
    return this.cameraState!!.getAllPriveiwSize()
  }

  refresh(): void {
    Logger.debug(TAG, `refresh is called`);
  }

  async getEffectivPreviewSize(): Promise<PreviewSize> {
    Logger.debug(TAG, `getEffectivPreviewSize is called`);
    let pSize = await this.cameraState!!.getEffectivPreviewSize()
    return pSize
  }

  setPhotoSize(size: PreviewSize): void {
    Logger.debug(TAG, `setPhotoSize is called`);
  }

  setPreviewSize(size: PreviewSize): void {
    Logger.debug(TAG, `setPreviewSize is called`);
    this.cameraState?.setPreviewSize({
      width: size.getWidth(), height: size.getHeight()
    })
  }

  async setAspectRatio(aspectRatio: string): Promise<void> {
    Logger.debug(TAG, `setAspectRatio is called`);
    this.cameraState!!.aspectRatio = aspectRatio
  }

  setupImageAnalysisStream(format: string, width: number, maxFramesPerSecond: number, autoStart: boolean): void {
    Logger.debug(TAG, `setupImageAnalysisStream is called`);
    this.cameraState!!.imageAnalysisBuilder = ImageAnalysisBuilder.configure(
      this.cameraState!!.aspectRatio ? this.cameraState!!.aspectRatio : AspectRatio.RATIO_4_3,
      format, width, maxFramesPerSecond)
    this.cameraState!!.enableImageStream = autoStart
    this.cameraState?.initCamera()
  }

  setExifPreferences(exifPreferences: ExifPreferences, result: Result<boolean>): void {
    Logger.debug(TAG, `setExifPreferences is called`);
    if (exifPreferences.getSaveGPSLocation()) {
      let atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(this.uiAbility?.context, ['ohos.permission.APPROXIMATELY_LOCATION'])
        .then((data): void => {
          if (data.authResults[0] === 0) {
            Logger.info(TAG, 'request Permissions success!');
            this.cameraState!!.exifPreferences = exifPreferences
            result.success(true)
          } else {
            Logger.info(TAG, 'request Permissions failed!');
            result.success(false)
          }
        })
        .catch((error: BusinessError): void => {
          Logger.info(TAG, `requestPermissionsFromUser call Failed! error: ${error.code}`);
          result.success(false)
        });
    } else {
      this.cameraState!!.exifPreferences = exifPreferences
      result.success(true)
    }
  }

  startAnalysis(): void {
    Logger.debug(TAG, `startAnalysis is called`);
    this.cameraState!!.enableImageStream = true
    this.cameraState?.initCamera()
  }

  stopAnalysis(): void {
    Logger.debug(TAG, `stopAnalysis is called`);
    this.cameraState!!.enableImageStream = false
    this.cameraState!!.imageAnalysisBuilder?.stop()
  }

  setFilter(matrix: number[]): void {
    Logger.debug(TAG, `setFilter is called`);
    if (this.cameraState) {
      this.colorMatrix = matrix
      this.cameraState.colorMatrix = matrix
    } else {
      this.colorMatrix = matrix
    }
  }

  isVideoRecordingAndImageAnalysisSupported(sensor: string, result: Result<boolean>): void {
    Logger.debug(TAG, `isVideoRecordingAndImageAnalysisSupported is called`);
    this.cameraState?.isVideoRecordingAndImageAnalysisSupported(sensor, result)
  }

  getUniqueClassName(): string {
    Logger.debug(TAG, `getUniqueClassName is called`);
    return "CameraAwesomeX"
  }

  rotationChanged() {
    if (this.cameraState) {
      this.cameraState.setPreviewRotation();
      this.displayRotation = this.cameraState.getDisplayRotation();
      this.displayRotationListener.onRotationChanged(this.displayRotation);
    }
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    Logger.debug(TAG, `onAttachedToEngine is called`);
    this.binding = binding
    this.textureRegistry = binding.getTextureRegistry()
    CameraInterface.setup(binding.getBinaryMessenger(), this)
    AnalysisImageUtils.setup(binding.getBinaryMessenger(), new AnalysisImageConverter())
    // 设置相机权限通道
    new EventChannel(binding.getBinaryMessenger(), "camerawesome/permissions").setStreamHandler(
      this.cameraPermissions
    )
    this.imageStreamChannel = new EventChannel(binding.getBinaryMessenger(), "camerawesome/images")
    this.physicalButtonHandler = new PhysicalButtonsHandler()
    new EventChannel(binding.getBinaryMessenger(), "camerawesome/physical_button").setStreamHandler(
      this.physicalButtonHandler
    )
    new EventChannel(binding.getBinaryMessenger(), "camerawesome/orientation").setStreamHandler(
      this.sensorOrientationListener
    )
    new EventChannel(binding.getBinaryMessenger(), "camerawesome/display_rotation").setStreamHandler(
      this.displayRotationListener
    )
    new EventChannel(binding.getBinaryMessenger(), "camerawesome/camera_device_change").setStreamHandler(
      this.cameraDeviceChangeListener
    )
  }

  private displayOnChange() {
    if (this.cameraState && this.abilityLifecycleCallback) {
      const windowStatusType = this.abilityLifecycleCallback.windowStatusType;
      if (this.orientationStreamListener) {
        this.orientationStreamListener.windowStatusType = windowStatusType;
      }
      Logger.debug(TAG, `display onChange windowStatusType=${windowStatusType}`);
      const displayRotation = this.cameraState?.getDisplayRotation() ?? 0;
      // 小窗、分屏 才有旋转效果
      if (windowStatusType == window.WindowStatusType.FLOATING ||
        windowStatusType == window.WindowStatusType.SPLIT_SCREEN) {
        this.rotationChanged()
      }
      // 从小窗、分屏 切换到全屏时，重新设置预览大小
      else if (this.lastWindowStatusType == window.WindowStatusType.FLOATING ||
        this.lastWindowStatusType == window.WindowStatusType.SPLIT_SCREEN ||
        this.lastWindowStatusType == window.WindowStatusType.MAXIMIZE ||
        this.lastWindowStatusType == window.WindowStatusType.MINIMIZE) {
        this.rotationChanged()
      } else if (this.displayRotation !== displayRotation) {
        // 旋转角度变化更新预览角度
        this.rotationChanged()
      }
      this.lastWindowStatusType = windowStatusType;
    }
  }

  registerFoldStatusChanged(err: BusinessError, foldStatusInfo: camera.FoldStatusInfo) {
    Logger.debug(TAG, `registerFoldStatusChanged foldStatusInfo : ${foldStatusInfo.foldStatus}`);
    this.cameraState?.initCamera().then(async () => {
      this.rotationChanged();
    }).catch((error: Any) => {
      Logger.debug(TAG, 'initCamera error');
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    Logger.debug(TAG, `onDetachedFromEngine is called`);
    this.binding = undefined
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    Logger.debug(TAG, `onAttachedToAbility is called`);
    this.uiAbility = binding.getAbility();
    AppStorage.set('cameraState', this.cameraState);
    // 定义生命周期回调对象
    this.abilityLifecycleCallback = new CameraAbilityLifecycle()
    // 获取应用上下文
    let applicationContext = this.uiAbility.context.getApplicationContext();
    try {
      // 注册应用内生命周期回调
      applicationContext.on('abilityLifecycle', this.abilityLifecycleCallback);
    } catch (err) {
      let code = (err as BusinessError).code;
      let message = (err as BusinessError).message;
      Logger.error(TAG, `Failed to register applicationContext. Code is ${code}, message is ${message}`);
    }
    display.on('change', () => {
      this.displayOnChange();
    })
  }

  onDetachedFromAbility(): void {
    Logger.debug(TAG, `onDetachedFromAbility is called`);
    display.off('change');
    this.cameraState?.getCameraManager()?.off('foldStatusChange', this.foldStatusCallback);
    this.uiAbility = undefined;
    this.abilityLifecycleCallback = undefined;
    this.orientationStreamListener?.offSensor();
  }
}