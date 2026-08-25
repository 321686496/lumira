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

import EventHub from './libs/EventHub';
import QrCaptureView from './QrCaptureView';
import { camera } from '@kit.CameraKit';
import { scanBarcode, customScan } from '@kit.ScanKit';
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { Any, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { PermissionsUtil } from './libs/PermissionsUtil';
import { CameraService } from './libs/CameraService'
import { display, window } from '@kit.ArkUI';
import { ChannelMethods } from './libs/ChannelMethods';

const TAG: string = '[OhosView]: '

@Entry
@Component
export struct OhosView {
  @Prop params: Params;
  @Prop channel: MethodChannel | null = null;
  @State isFlashlight: boolean = false; // Whether the flashlight is turned on.
  @State isSensorLight: boolean = false; // Record the current environment brightness status.
  @State isScanned: boolean = false;
  @State cameraHeight: number = 300; // Sets the XComponent height. The default unit is vp.
  @State cameraWidth: number = 300; // Sets the XComponent width. The default unit is vp.
  @State userGrant: boolean = false;
  @State surfaceId: string = '';
  @State cameraScreenOffsetX: number = 0;
  @State cameraScreenOffsetY: number = 0;
  @State isStop: boolean = false;
  @State isOpen: boolean = false;
  @State isFront: boolean = false;
  @State result: Array<scanBarcode.ScanResult> = [];
  @State data: Array<string> = [];
  @State isVertical: boolean = true;
  @State scanAreaWidth: number = 150;
  @State scanAreaHeight: number = 150;
  @State cutOutBottomOffset: number = 0;
  private mXComponentController: XComponentController = new XComponentController();
  private context: Context = getContext(this);
  private cameraService: CameraService | null = new CameraService(this.context);
  private windowClass: window.Window | null = null;
  private barcodeFormats: Array<number> = [];
  private timerId: number = -1;
  private FLASH_TIME_OUT: number = 200; // 闪光灯延时触发，若不延时会被认为还在其他应用界面，不支持闪光灯模式

  async aboutToAppear() {
    this.isScanned = false;
    this.isStop = false;
    this.onEmitEvents();
    this.setDisplay();
    this.init();
    window.getLastWindow(this.context).then((windowClass) => {
      this.windowClass = windowClass;
      windowClass.on('windowEvent', (data) => {
        if (data === window.WindowEventType.WINDOW_SHOWN) {
          this.onPageShow();
        }
        if (data === window.WindowEventType.WINDOW_HIDDEN) {
          this.onPageHide();
        }
      });
    })
    this.cameraService!.onImageArrival(this.cameraService!.imageReceiver, this.channel, this.barcodeFormats);
  }

  aboutToDisappear() {
    this.cameraService?.releaseCamera()
    EventHub.offAll(this.context);
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
    }
    this.windowClass?.off('windowEvent');
  }

  onPageShow(): void {
    this.cameraService!.initCamera(this.surfaceId, this.isFront)
    if (!this.isFront) {
      this.timerId = setTimeout(() => {
        this.cameraService?.setFlashMode(this.isOpen)
      }, this.FLASH_TIME_OUT)
    }
  }

  onPageHide(): void {
    this.cameraService!.preFrontRelease(this.isStop);
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
    }
  }

  onEmitEvents() {
    // 注册监听事件
    const context = getContext(this) as common.UIAbilityContext;
    // 开始扫描
    EventHub.onStartScan(context, async (args: Any) => {
      this.channel = args.channel;
      this.barcodeFormats = args.barcodeFormats || [];
    });

    // 暂停扫描
    EventHub.onPauseCamera(context, async (result: MethodResult) => {
      if (this.isStop) {
        return;
      }
      // 暂停闪光灯
      this.cameraService?.setFlashMode(false);
      this.cameraService?.stopCamera().then(() => {
        this.isStop = true;
        result.success(null)
      })
    });

    // 切换摄像头
    EventHub.onFlipCamera(context, async (result: MethodResult) => {
      console.info(TAG + 'onFlipCamera success');
      this.isFront = !this.isFront;
      this.cameraService?.preFrontRelease(this.isStop).then(() => {
        this.cameraService?.initCamera(this.surfaceId, this.isFront).then(() => {
          this.cameraService?.setFlashMode(this.isOpen); // 切换到后置摄像头后重制闪光灯状态
        })
      })
    });

    // 切换摄像头
    EventHub.onToggleFlash(context, (result: MethodResult) => {
      this.setTorchMode(result);
    });

    // 重新扫描
    EventHub.onResum(context, (result: MethodResult) => {
      this.restartCustomScan(result);
    });

    // 获取闪光灯状态
    EventHub.onGetFlashInfo(context, (result: MethodResult) => {
      if (this.isStop) {
        result.success(this.isOpen);
        return;
      }
      result.success(this.isOpen);
    });

    // 获取相机支持功能
    EventHub.onGetSystemFeatures(context, async (result: MethodResult) => {
      const fatures = new Map<string, boolean | string | undefined>();
      const hasFrontCamera = this.cameraService?.hasCamera('front');
      const hasBackCamera = this.cameraService?.hasCamera();
      const hasFlash = this.cameraService?.hasFlashCamera();
      const activeCamera = this.cameraService?.activeCamera();
      fatures.set('hasFrontCamera', hasFrontCamera);
      fatures.set('hasBackCamera', hasBackCamera);
      fatures.set('hasFlash', hasFlash);
      fatures.set('activeCamera', activeCamera);
      result.success(fatures);
    });

    // 获取预览区域
    EventHub.onChangeScanArea(context, (res: Any) => {
      console.info(TAG + 'onChangeScanArea enter success' + JSON.stringify(res));
      this.scanAreaWidth = res.scanAreaWidth;
      this.scanAreaHeight = res.scanAreaHeight;
    });

    // 设置图像倒置
    EventHub.onInvertScan(context, (res: Any) => {
      console.info(TAG + 'onInvertScan enter success' + JSON.stringify(res));
    });
  }

  // 检查权限 初始化相机 开始扫描
  async init() {
    const permissions: Array<Permissions> = ['ohos.permission.CAMERA'];
    let grantStatus = await PermissionsUtil.checkAccessToken(permissions[0]);
    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      this.userGrant = true;
    } else {
      this.requestCameraPermission();
    }
  }

  // 申请权限
  async requestCameraPermission() {
    let grantStatus = await PermissionsUtil.reqPermissionsFromUser(this.context);
    let length: number = grantStatus.length;
    for (let i = 0; i < length; i++) {
      if (grantStatus[i] === 0) {
        this.userGrant = true;
      } else {
        console.error(TAG + 'no CameraPermission');
        this.userGrant = false;
      }
    }
    if (!this.userGrant) {
      this.channel!.invokeMethod(ChannelMethods.CHANNEL_METHOD_ON_PERMISSION_SET, this.userGrant);
    }
  }

  // 扫一扫初始化
  scan() {
    const cameraManager = camera.getCameraManager(this.context);
    this.cameraService!.createCamera(cameraManager);
    this.cameraService!.initCamera(this.surfaceId);
  }

  setDisplay() {
    // 默认竖屏
    let displayClass = display.getDefaultDisplaySync();
    const displayHeight = px2vp(displayClass.height);
    const displayWidth = px2vp(displayClass.width);
    let maxLen: number = Math.max(displayWidth, displayHeight);
    let minLen: number = Math.min(displayWidth, displayHeight);
    const RATIO: number = 16 / 9;
    this.cameraHeight = maxLen;
    this.cameraWidth = maxLen / RATIO;
  }

  // 检查权限 没有的话申请权限
  async checkPermission(result: MethodResult) {
    const permissions: Array<Permissions> = ['ohos.permission.CAMERA'];
    let grantStatus = await PermissionsUtil.checkAccessToken(permissions[0]);
    if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      this.userGrant = true;
    } else {
      this.requestCameraPermission();
    }
  }

  // 重新扫描
  restartCustomScan(result: MethodResult) {
    if (this.isStop) {
      this.initCamera(result);
    } else {
      // 如果本来就不是暂停状态就不需要额外的处理逻辑
      // this.cameraService?.stopCamera().then(() => {
      //   this.initCamera(result);
      // })
    }
  }

  // 设置手电筒开关 N
  // 设置闪光灯开关 Y
  setTorchMode(result: MethodResult) {
    if (!this.cameraService?.hasFlash()) {
      result.success(null)
      return;
    }
    this.isOpen = !this.isOpen;
    // 前端的手电筒其实时后端的闪光灯
    this.cameraService?.setFlashMode(this.isOpen);
    result.success(null)
  }

  // 初始化相机
  initCamera(result: MethodResult) {
    this.cameraService?.initCamera(this.surfaceId, this.isFront)
      .then(() => {
        this.isStop = false;
        this.torchModeOn(result, 'initCamera');
        result.success(true);
      })
  }

  // 如果状态开, 则打开
  torchModeOn(result: MethodResult, type: string = '') {
    if (this.isOpen) {
      setTimeout(() => {
        this.cameraService?.setFlashMode(this.isOpen);
      }, this.FLASH_TIME_OUT);
    }
  }

  barCodeViewNotSet(result: MethodResult) {
    result.error(
      ChannelMethods.ERROR_CODE_NOT_SET,
      ChannelMethods.ERROR_MESSAGE_NOT_SET,
      null
    )
  }

  build() {
    Stack() {
      if (this.userGrant) {
        Column() {
          XComponent({
            id: 'componentId',
            type: XComponentType.SURFACE,
            controller: this.mXComponentController
          })
            .onLoad(() => {
              this.surfaceId = this.mXComponentController.getXComponentSurfaceId();
              this.scan()
            })
            .width(this.cameraWidth)
            .height(this.cameraHeight)
        }
        .height('100%')
        .width('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.userGrant ? Color.Transparent : Color.Black)
  }
}

@Builder
export function buildOhosView(params: Params) {
  OhosView({
    params: params,
    channel: (params.platformView as QrCaptureView).getChannel()
  })
}