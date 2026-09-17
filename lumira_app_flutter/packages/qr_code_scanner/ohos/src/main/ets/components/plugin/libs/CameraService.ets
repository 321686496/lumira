/*
 * Copyright (c) 2022-2023 Huawei Device Co., Ltd.
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

import image from '@ohos.multimedia.image';
import { camera } from '@kit.CameraKit';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Log, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit';
import { ChannelMethods } from './ChannelMethods';
import { ConstCodeFormat } from './Constants';
import { MyDebounceSingletonUtil } from './util'

const TAG = '[CameraService] :';
const IMG_DEFAULT_SIZE_WIDTH: number = px2vp(display.getDefaultDisplaySync().width);
const IMG_DEFAULT_SIZE_HEIGHT: number = px2vp(display.getDefaultDisplaySync().height);

/**
 * 相机服务
 */
class CameraService {
  private cameraManager: camera.CameraManager | undefined = undefined;
  private camerasDevices: Array<camera.CameraDevice> | undefined = undefined;
  private curcamerasDevice: camera.CameraDevice | undefined = undefined;
  private cameraInput: camera.CameraInput | undefined = undefined;
  private photoOutput: camera.PhotoOutput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  // 第二路预览输出（imageReceiver 扫码流），initCamera 每次都会新建，
  // 必须跟踪并在下次初始化 / 释放时一并 release，否则反复进出扫码页后
  // 相机输出资源耗尽，导致后续 open 失败、取景器黑屏。
  private previewOutput2: camera.PreviewOutput | undefined = undefined;
  private photoSession: camera.PhotoSession | null = null;
  private context: Context | null = null;
  private isStop: boolean = false;
  // initCamera 串行化：onLoad→scan() 与 WINDOW_SHOWN→onPageShow 会各自
  // 触发一次 initCamera，并发执行 createCameraInput + open() 会抢占相机
  // 设备导致初始化失败、取景器黑屏。用进行中的 Promise 将调用串行排队。
  private initPromise: Promise<void> | null = null;
  // 上一次成功初始化使用的 surfaceId 与前后置，用于去重：重复调用
  // （同 surface 同摄像头且会话仍在运行）直接跳过，不重建会话。
  private lastSurfaceId: string = '';
  private lastFront: boolean = false;
  public imageReceiver: image.ImageReceiver;
  private captureSize: camera.Size = { width: 864, height: 480 } as camera.Size;

  constructor(context: Context, imgReceiver?: image.ImageReceiver) {
    this.context = context;
    const previewSize: camera.Size = { width: 1920, height: 1080 } as camera.Size;
    if (imgReceiver === undefined) {
      this.imageReceiver = image.createImageReceiver(previewSize, image.ImageFormat.JPEG, 1);
    } else {
      this.imageReceiver = image.createImageReceiver(previewSize, imgReceiver.format, imgReceiver.capacity);
    }
  }

  setSize() {
    let maxLen: number = Math.max(IMG_DEFAULT_SIZE_WIDTH, IMG_DEFAULT_SIZE_HEIGHT);
    let minLen: number = Math.min(IMG_DEFAULT_SIZE_WIDTH, IMG_DEFAULT_SIZE_HEIGHT);
    const RATIO: number = 16 / 9;
    const cameraHeight = maxLen;
    const cameraWidth = maxLen / RATIO;
    let size: image.Size = {
      width: cameraWidth,
      height: cameraHeight
    }
  }

  getCameraManager(context: Context): camera.CameraManager {
    return camera.getCameraManager(context);
  }

  async getImageReceiverSurfaceId(receiver: image.ImageReceiver): Promise<string | undefined> {
    let ImageReceiverSurfaceId: string | undefined = undefined;
    if (receiver !== undefined) {
      let ImageReceiverSurfaceId: string = await receiver.getReceivingSurfaceId();
    } else {
      console.error('createImageReceiver failed');
    }
    return ImageReceiverSurfaceId;
  }

  // 创建相机
  async createCamera(cameraManager: camera.CameraManager): Promise<void> {
    if (!this.cameraManager) {
      this.cameraManager = cameraManager;
    }
    // 获取支持的相机设备对象
    this.camerasDevices = this.cameraManager!.getSupportedCameras();
    if (!this.camerasDevices) {
      return;
    }
    console.info(TAG + 'createCamera success');
  }

  // 获取相机信息
  getCameraInfo(front: boolean = false): number {
    if (!this.context) {
      return -1;
    }
    if (!this.cameraManager) {
      this.cameraManager = this.getCameraManager(this.context);
    }
    // 获取支持的相机设备对象
    this.camerasDevices = this.cameraManager!.getSupportedCameras();
    if (!this.camerasDevices) {
      return -1;
    }
    this.curcamerasDevice = front ? this.camerasDevices[1] : this.camerasDevices[0];
    return front ? 1 : 0;
  }

  // 获取相机信息
  getFlashInfo(): boolean {
    const torchMode = this.cameraManager!.getTorchMode();
    return torchMode === camera.TorchMode.ON;
  }

  // 判断是否有前后置摄像头
  hasCamera(type: string = 'front') {
    const cameraPosition =
      type === 'front' ? camera.CameraPosition.CAMERA_POSITION_FRONT : camera.CameraPosition.CAMERA_POSITION_BACK;
    let flag = false;
    if (this.camerasDevices && this.camerasDevices.length) {
      let backCamera = this.camerasDevices.find(el => el.cameraPosition === cameraPosition);
      if (backCamera) {
        flag = true;
      }
    }
    return flag;
  }

  // 判断是否支持手电筒
  hasFlashCamera(): boolean {
    return this.isTorchSupported()
  }

  // 获取当前激活相机
  activeCamera(): string | undefined {
    return this.curcamerasDevice?.cameraId;
  }

  getPreviewProfilesObj(): camera.Profile | undefined {
    // 获取profile对象
    let profiles: camera.CameraOutputCapability =
      this.cameraManager!.getSupportedOutputCapability(this.curcamerasDevice,
        camera.SceneMode.NORMAL_PHOTO); // 获取对应相机设备profiles
    let previewProfiles: Array<camera.Profile> = profiles.previewProfiles;
    let captureSize: camera.Size = { width: 1920, height: 1080 } as camera.Size;
    let previewProfilesObj = previewProfiles.find((profile: camera.Profile) => {
      return profile.size.width === captureSize.width && profile.size.height === captureSize.height;
    });
    return previewProfilesObj;
  }

  // 初始化相机并开始捕获预览流
  async initCamera(XComponentSurfaceId: string, front: boolean = false): Promise<void> {
    // 首次打开扫一扫的授权流程中，onPageShow 可能在 XComponent onLoad 之前触发，
    // 传入空 surfaceId。此时若继续启动相机，会以空 surfaceId 创建预览输出并抢占
    // 相机输入，随后真正携带有效 surfaceId 的初始化反而失败导致黑屏。这里兜底拦截。
    if (!XComponentSurfaceId) {
      console.error(TAG + 'initCamera skip: empty XComponentSurfaceId');
      return;
    }
    // 串行化：若上一次 initCamera 仍在进行中（onLoad 与 onPageShow 双触发、
    // 或快速切换前后置），先等待其完成，避免并发 open 相机互相抢占导致黑屏。
    if (this.initPromise) {
      try {
        await this.initPromise;
      } catch (error) {
        const err = error as BusinessError;
        console.error(TAG + `previous initCamera failed: ${err.message}`);
      }
    }
    // 去重：同 surface、同前后置且会话仍在运行（如 onLoad 与 WINDOW_SHOWN
    // 接连触发），跳过重复初始化，避免重建会话瞬间画面黑屏闪烁。
    if (XComponentSurfaceId === this.lastSurfaceId && front === this.lastFront &&
      this.photoSession && !this.isStop) {
      return;
    }
    this.initPromise = this.doInitCamera(XComponentSurfaceId, front);
    try {
      await this.initPromise;
    } finally {
      this.initPromise = null;
    }
  }

  private async doInitCamera(XComponentSurfaceId: string, front: boolean): Promise<void> {
    try {
      await this.doInitCameraInner(XComponentSurfaceId, front);
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG + `initCamera failed: ${err.message}`);
      // 失败清理：回收已创建的输入 / 会话 / 输出，避免半初始化状态
      // 占住相机设备，导致后续重试或下一次进入页面黑屏。
      await this.teardownSession();
    }
  }

  private async doInitCameraInner(XComponentSurfaceId: string, front: boolean): Promise<void> {
    // 相机管理器 / 设备列表就绪兜底：onPageShow 直接触发 initCamera 时
    // createCamera 可能尚未被调用，此时 this.cameraManager / camerasDevices
    // 为空，若不补建会静默 return，相机永远不启动、取景器黑屏。
    if (!this.cameraManager) {
      if (!this.context) {
        return;
      }
      this.cameraManager = camera.getCameraManager(this.context);
    }
    if (!this.camerasDevices) {
      this.camerasDevices = this.cameraManager.getSupportedCameras();
    }
    if (!this.camerasDevices || this.camerasDevices.length === 0) {
      return;
    }
    // 释放上一轮会话与输出：initCamera 可能被多次触发（前后台切换 / 切换
    // 前后置），不释放旧资源会泄漏相机输出，多次进出后 open 失败黑屏。
    await this.teardownSession();
    // 前置
    if (front && this.camerasDevices.length > 1) {
      this.curcamerasDevice = this.camerasDevices[1]
    } else {
      this.curcamerasDevice = this.camerasDevices[0]
    }
    // 获取支持的模式类型
    let sceneModes: Array<camera.SceneMode> = this.cameraManager!.getSupportedSceneModes(this.curcamerasDevice);
    let isSupportPhotoMode: boolean = sceneModes.indexOf(camera.SceneMode.NORMAL_PHOTO) >= 0;
    if (!isSupportPhotoMode) {
      console.error(TAG + 'photo mode not support');
      return;
    }
    // 预览流1
    let previewProfilesObj: camera.Profile | undefined = this.getPreviewProfilesObj();
    // 预览流2
    let previewProfilesObj2: camera.Profile | undefined = this.getPreviewProfilesObj();
    // 创建 预览流1 输出对象
    let previewOutput: camera.PreviewOutput =
      this.cameraManager!.createPreviewOutput(previewProfilesObj, XComponentSurfaceId);
    // 创建 预览流2 输出对象
    let imageReceiverSurfaceId: string = await this.imageReceiver.getReceivingSurfaceId();
    let previewOutput2: camera.PreviewOutput =
      this.cameraManager!.createPreviewOutput(previewProfilesObj2, imageReceiverSurfaceId);
    // 创建cameraInput对象
    this.cameraInput = this.cameraManager!.createCameraInput(this.curcamerasDevice);
    // 打开相机
    await this.cameraInput.open();
    // 会话流程
    this.photoSession =
      this.cameraManager!.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession;
    // 开始配置会话
    this.photoSession.beginConfig();
    // 把CameraInput加入到会话
    this.photoSession.addInput(this.cameraInput);
    // 把 预览流1 加入到会话
    this.photoSession.addOutput(previewOutput);
    // 把 预览流2 加入到会话
    this.photoSession.addOutput(previewOutput2);
    // 提交配置信息
    await this.photoSession.commitConfig();
    // 会话开始
    await this.photoSession.start();
    // 启动成功后才记录输出与去重标记，失败路径走 catch 清理，
    // 避免半初始化状态被去重逻辑误判为「已就绪」。
    this.previewOutput = previewOutput;
    this.previewOutput2 = previewOutput2;
    this.lastSurfaceId = XComponentSurfaceId;
    this.lastFront = front;
    // 对焦模式
    this.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
    this.isStop = false;
  }

  // 停止并释放当前会话与全部输出（输入 / 会话 / 两路预览输出），
  // 供重新初始化与页面销毁复用，防止预览输出泄漏耗尽相机资源。
  private async teardownSession(): Promise<void> {
    try {
      await this.photoSession?.stop();
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG + `teardown stop failed: ${err.message}`);
    }
    try {
      await this.cameraInput?.close();
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG + `teardown close input failed: ${err.message}`);
    }
    try {
      await this.photoSession?.release();
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG + `teardown release session failed: ${err.message}`);
    }
    try {
      await this.previewOutput?.release();
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG + `teardown release preview failed: ${err.message}`);
    }
    try {
      await this.previewOutput2?.release();
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG + `teardown release preview2 failed: ${err.message}`);
    }
    this.photoSession = null;
    this.cameraInput = undefined;
    this.previewOutput = undefined;
    this.previewOutput2 = undefined;
    // 会话与输出已全部释放，状态回到「已停止」：保证后续 resume / 重进页面
    // 事件能正确触发重新初始化，而不是误判仍在运行而跳过。
    this.isStop = true;
  }

  /**
   * 对焦模式
   */
  setFocusMode(focusMode: camera.FocusMode): void {
    // 检测对焦模式是否支持
    let isSupported = this.photoSession!.isFocusModeSupported(focusMode);
    // 设置对焦模式
    if (!isSupported) {
      return;
    }
    this.photoSession!.setFocusMode(focusMode);
  }

  // 设置预览流
  setPreView() {
    // 获取profile对象
    let profiles: camera.CameraOutputCapability =
      this.cameraManager!.getSupportedOutputCapability(this.curcamerasDevice,
        camera.SceneMode.NORMAL_PHOTO); // 获取对应相机设备profiles
    let previewProfiles: Array<camera.Profile> = profiles.previewProfiles;
    let previewProfilesObj = previewProfiles.find((profile: camera.Profile) => {
      return profile.size.width === this.captureSize.width && profile.size.height === this.captureSize.height;
    });
    return previewProfilesObj;
  }

  setAutoFocus() {
    // 判断是否支持连续自动变焦模式
    let focusModeStatus: boolean = false;
    try {
      let status: boolean = this.photoSession!.isFocusModeSupported(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
      focusModeStatus = status;
    } catch (error) {
      let err = error as BusinessError;
      console.error(`${TAG}Failed to check whether the focus mode is supported. error: ${JSON.stringify(err)}`);
    }
    if (focusModeStatus) {
      // 设置连续自动变焦模式
      try {
        this.photoSession!.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
      } catch (error) {
        let err = error as BusinessError;
        console.error(`${TAG}Failed to set the focus mode. error: ${JSON.stringify(err)}`);
      }
    }
  }

  // 相机会话是否已成功启动（供初始化失败后的重试判断）
  isCameraRunning(): boolean {
    return !this.isStop && this.photoSession != null;
  }

  // 获取预览流并解析
  onImageArrival(receiver: image.ImageReceiver, channel: MethodChannel | null,
    barcodeFormats: Array<number> = []): void {
    receiver.on('imageArrival', () => {
      if (this.isStop) {
        return;
      }
      receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
        if (err || nextImage === undefined) {
          console.error(TAG + ' onImageArrival err');
          return;
        }
        nextImage.getComponent(image.ComponentType.JPEG, (err: BusinessError, imgComponent: image.Component) => {
          if (err || imgComponent === undefined) {
          }
          if (imgComponent && imgComponent.byteBuffer as ArrayBuffer) {
            // do something...
            this.decodeImageBuffer(imgComponent, nextImage.size.width, nextImage.size.height, channel, barcodeFormats);
          } else {
            console.error(TAG + ' byteBuffer is null');
          }
          nextImage.release();
        })
      })
    })
  }

  // 从ImageReceiver获取imgComponent: image.Component，预览流设置的宽高: width, height
  decodeImageBuffer(imgComponent: image.Component, width: number, height: number, channel: MethodChannel | null,
    barcodeFormats: Array<number> = []) {
    if (MyDebounceSingletonUtil.getInstance().isDebounced(TAG + 'Debounced', 200)) {
      return;
    }
    let byteImg: detectBarcode.ByteImage = {
      byteBuffer: imgComponent.byteBuffer,
      width: width,
      height: height,
      format: detectBarcode.ImageFormat.NV21
    };
    let options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.ALL],
      enableMultiMode: false,
      enableAlbum: false
    };
    detectBarcode.decodeImage(byteImg, options).then((detectBarcode: detectBarcode.DetectResult) => {
      if (detectBarcode.scanResults.length) {
        const res = detectBarcode.scanResults[0];
        if (!res || !res.originalValue) {
          return
        }
        const codes = new Map<string, string | object>();
        codes.set('code', res.originalValue);
        codes.set('type', ConstCodeFormat.BarcodeFormatToString(res.scanType));
        codes.set("bytes", new Uint8Array(byteImg.byteBuffer));
        channel!.invokeMethod(ChannelMethods.CHANNEL_METHOD_ON_RECOGNIZE_QR, codes)
      }
    }).catch((error: BusinessError) => {
      console.error(TAG + error.message);
    })
  }

  // 变焦
  setZoomRatio(scalValue: number) {
    // 判断是否支持连续自动变焦模式
    let focusModeStatus: boolean = false;
    try {
      let status: boolean = this.photoSession!.isFocusModeSupported(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
      focusModeStatus = status;
    } catch (error) {
      let err = error as BusinessError;
      console.error(`${TAG}Failed to check whether the focus mode is supported. error: ${JSON.stringify(err)}`);
    }
    if (focusModeStatus) {
      // 设置连续自动变焦模式
      try {
        this.photoSession!.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO);
      } catch (error) {
        let err = error as BusinessError;
        console.error(`${TAG}Failed to set the focus mode. error: ${JSON.stringify(err)}`);
      }
    }
    // 获取相机支持的可变焦距比范围
    let zoomRatioRange: Array<number> = [];
    try {
      zoomRatioRange = this.photoSession!.getZoomRatioRange();
    } catch (error) {
      let err = error as BusinessError;
      console.error(`${TAG}Failed to get the zoom ratio range. error: ${JSON.stringify(err)}`);
    }
    if (zoomRatioRange.length <= 0) {
      return;
    }
    let ratioValue = 1
    if (scalValue < zoomRatioRange[0]) {
      ratioValue = zoomRatioRange[0]
    } else if (scalValue > zoomRatioRange[1]) {
      ratioValue = zoomRatioRange[1]
    } else {
      ratioValue = scalValue
    }
    // 设置可变焦距比
    try {
      this.photoSession!.setZoomRatio(ratioValue);
    } catch (error) {
      let err = error as BusinessError;
      console.error(`${TAG}Failed to set the zoom ratio value. error: ${JSON.stringify(err)}`);
    }
  }

  // 手电筒开关
  setTorchMode(isOpen: boolean, result: MethodResult): boolean {
    try {
      if (!this.cameraManager) {
        Log.e(TAG, "cameraManager is undefined");
        return false;
      }
      if (!this.isTorchSupported()) {
        return false;
      }
      const newMode = isOpen ? camera.TorchMode.ON : camera.TorchMode.OFF;
      if (!this.isTorchModeSupported(newMode)) {
        return false;
      }

      this.cameraManager.setTorchMode(newMode);
      const currentMode = this.cameraManager.getTorchMode();
      if (currentMode != newMode) {
        Log.e(TAG, "failed to setTorchMode");
        return false;
      }
      return true;
    } catch (err) {
      Log.e(TAG, "failed to etTorchMode ", err.code, err.message);
      return false;
    }
  }

  // 支持手电筒
  isTorchSupported(): boolean {
    let isSupported = this.cameraManager!.isTorchSupported();
    return isSupported;
  }

  // 支持设置手电筒
  isTorchModeSupported(torchMode: camera.TorchMode): boolean {
    let isSupported = this.cameraManager!.isTorchModeSupported(torchMode);
    return isSupported;
  }

  // 闪光灯开关
  setFlashMode(isOpen: boolean): void {
    // 设备是否支持闪光灯，可使用方法hasFlash
    // 设备是否支持指定的闪光灯模式，可使用方法isFlashModeSupported
    if (!this.hasFlash()) {
      Log.e("setFlashMode hasFlash", "The camera device does not have flash.", null);
      return;
    }
    const newMode = isOpen ? camera.FlashMode.FLASH_MODE_ALWAYS_OPEN : camera.FlashMode.FLASH_MODE_CLOSE;

    if (!this.isFlashModeSupported(newMode)) {
      Log.e("setFlashMode isFlashModeSupported", " The flash mode is unsupported.", null);
      return;
    }
    try {
      this.photoSession!.setFlashMode(newMode);
    } catch (error) {
      Log.e("setFlashMode", "The setFlashMode call failed", null);
      const err = error as BusinessError;
      console.error(`The setFlashMode call failed: ${err.code}`);
    }
  }

  // 检测是否有闪光灯
  hasFlash(): boolean {
    let status: boolean = false;
    try {
      status = this.photoSession!.hasFlash();
    } catch (error) {
      // 失败返回错误码error.code并处理
      const err = error as BusinessError;
      console.error(`The hasFlash call failed. error code: ${err.code}`);
    }
    return status;
  }

  //检测闪光灯模式是否支持
  isFlashModeSupported(mode: camera.FlashMode): boolean {
    let status: boolean = false;
    try {
      status = this.photoSession!.isFlashModeSupported(mode);
    } catch (error) {
      // 失败返回错误码error.code并处理
      const err = error as BusinessError;
      console.error(`The isFlashModeSupported call failed. error code: ${err.code}`);
    }
    return status;
  }

  /**
   * 以指定参数触发一次拍照
   */
  takePicture() {
    let photoSetting: camera.PhotoCaptureSetting = {
      rotation: camera.ImageRotation.ROTATION_0,
      quality: camera.QualityLevel.QUALITY_LEVEL_MEDIUM,
      mirror: false
    };
    this.photoOutput?.capture(photoSetting);
  }

  // 切换前置后置前释放相机流
  stopCamera(): Promise<void> {
    if (!this.photoSession) {
      // 会话尚未建立（如暂停先于初始化完成到达）时直接置位，避免空引用崩溃
      this.isStop = true;
      return Promise.resolve();
    }
    return this.photoSession.stop().then(() => {
      this.isStop = true;
    });
  }

  // 切换前置后置前释放相机流
  async preFrontRelease(isStop: boolean) {
    // 若初始化仍在进行中，先等待其结束再释放，避免释放与初始化交错执行
    // 导致相机状态错乱（后续 initCamera 已内置 teardown，会重新建流）。
    if (this.initPromise) {
      try {
        await this.initPromise;
      } catch (_) {
        // 初始化失败即无资源可释放
      }
    }
    await this.teardownSession();
  }

  /**
   * 释放相机
   */
  async releaseCamera() {
    if (this.initPromise) {
      try {
        await this.initPromise;
      } catch (_) {
        // 初始化失败即无资源可释放
      }
    }
    await this.teardownSession();
    await this.imageReceiver.release();
  }
}

export { CameraService }