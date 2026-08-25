/*
* Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd.
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

import { CameraService } from './libs/CameraService';
import { Any, MethodCall, MethodChannel } from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import QrCodeScannerOhosPlugin from './QrCodeScannerOhosPlugin';
import ChannelDelegateImpl from './libs/ChannelDelegateImpl';
import QrCaptureView from './QrCaptureView';
import common from '@ohos.app.ability.common';
import EventHub from './libs/EventHub';


const TAG = "[QrCodeViewManager] :"
const METHOD_CHANNEL_NAME = "net.touchcapture.qr.flutterqr/qrview"


export class QrCodeViewManager extends ChannelDelegateImpl {
  private plugin: QrCodeScannerOhosPlugin | null = null
  public windowAutoincrementId: number = 0
  public debuggingEnabled = false;
  public qrCaptureView: QrCaptureView | null = null;
  cameraWidth: number = 0;
  cameraHeight: number = 0;
  private context: Context;
  private cameraService: CameraService;

  constructor(context: Context, plugin: QrCodeScannerOhosPlugin, id: number) {
    super(new MethodChannel(plugin.messenger!, METHOD_CHANNEL_NAME + '_' + id));
    this.context = context;
    this.plugin = plugin;
    this.cameraService = new CameraService(this.context);

  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const context = getContext(this) as common.UIAbilityContext;
    switch (call.method) {
      case "startScan":
        console.info(TAG + ' ==================startScan ');
        const barcodeFormats = call.args as Array<number>;
        EventHub.emitStartScan(this.context,
          { result: result, barcodeFormats: barcodeFormats, channel: this.getChannel() });
        break;
      case "changeScanArea":
        const scanAreaWidth: Any = call.argument('scanAreaWidth');
        const scanAreaHeight: Any = call.argument('scanAreaHeight');
        const cutOutBottomOffset: Any = call.argument('cutOutBottomOffset');
        console.info(TAG + ' ==================changeScanArea  cutOutBottomOffset');
        EventHub.emitChangeScanArea(context,
          { scanAreaWidth: scanAreaWidth, scanAreaHeight: scanAreaHeight, cutOutBottomOffset: cutOutBottomOffset });
        result.success(true);
        break;
      case "getFlashInfo":
        console.info(TAG + ' ==================getFlashInfo');
        EventHub.emitGetFlashInfo(context, result);
      case "getCameraInfo":
        const cameraIndex = this.cameraService.getCameraInfo();
        result.success(cameraIndex);
        console.info(TAG + ' ==================getCameraInfo');
        break;
      case "flipCamera":
        console.info(TAG + ' ==================flipCamera ');
        EventHub.emitFlipCamera(context, result);
        break;

      case "toggleFlash":
        console.info(TAG + ' ==================toggleFlash ');
        EventHub.emitToggleFlash(context, result);
        break;
      case "pauseCamera":
        console.info(TAG + ' ==================pauseCamera ');
        EventHub.emitPauseCamera(context, result);
        break;
      case "stopCamera":
        console.info(TAG + ' ==================stopCamera ');
        EventHub.emitPauseCamera(context, result);
        break;
      case "resumeCamera":
        console.info(TAG + ' ==================resumeCamera ');
        EventHub.emitResum(context);
        break;
      case "getSystemFeatures":
        console.info(TAG + ' ==================getSystemFeatures ');
        EventHub.emitGetSystemFeatures(context, result);
        break;

      case "invertScan":
        console.info(TAG + ' ==================invertScan ');
        EventHub.emitInvertScan(context, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  public dispose(): void {
    super.dispose();
    this.plugin = null;
  }
}