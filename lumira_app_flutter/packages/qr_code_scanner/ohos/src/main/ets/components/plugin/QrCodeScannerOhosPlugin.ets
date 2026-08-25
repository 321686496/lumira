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

import {
  BinaryMessenger,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodChannel,
} from '@ohos/flutter_ohos';
import QRCaptureViewFactory from './QrCaptureViewFactory'

/** QrCodeScannerOhosPlugin **/
export default class QrCodeScannerOhosPlugin implements FlutterPlugin {
  private channel: MethodChannel | null = null;
  public messenger: BinaryMessenger | null = null;
  private context: Context | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "QrCodeScannerOhosPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.messenger = binding.getBinaryMessenger();
    this.context = binding.getApplicationContext();
    // 注册自定义视图
    const qRCaptureViewFactory = new QRCaptureViewFactory(this);
    binding.getPlatformViewRegistry()
      .registerViewFactory(QRCaptureViewFactory.VIEW_TYPE_ID, qRCaptureViewFactory);

  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }
}