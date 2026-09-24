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

import { Any, PlatformView, PlatformViewFactory, StandardMessageCodec } from '@ohos/flutter_ohos';
import { QrCodeViewManager } from './QrCodeViewManager';
import QrCaptureView from './QrCaptureView';
import QrCodeScannerOhosPlugin from './QrCodeScannerOhosPlugin';


export default class QrCaptureViewFactory extends PlatformViewFactory {
  public static VIEW_TYPE_ID = "net.touchcapture.qr.flutterqr/qrview";
  public plugin: QrCodeScannerOhosPlugin;
  public viewId: number | null;
  private qrCodeViewManager: QrCodeViewManager | null = null;

  constructor(plugin: QrCodeScannerOhosPlugin) {
    super(StandardMessageCodec.INSTANCE);
    this.plugin = plugin;
    this.viewId = null;
  }

  public create(context: Context, viewId: number, args: Any): PlatformView {
    //  视图桥接逻辑
    this.qrCodeViewManager = new QrCodeViewManager(context, this.plugin, viewId);
    return new QrCaptureView(context, this.qrCodeViewManager.getChannel());
  }

  getViewId() {
    return this.viewId;
  }
}