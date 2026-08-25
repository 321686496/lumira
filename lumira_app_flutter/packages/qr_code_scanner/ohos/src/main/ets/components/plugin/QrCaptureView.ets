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

import { buildOhosView } from './OhosQrCodeView';
import { CameraService } from './libs/CameraService';
import { MethodChannel, PlatformView } from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';

const TAG: string = "[QrCaptureView] :";

export default class QRCaptureView extends PlatformView {
  private cameraService: CameraService | null = null;
  private userGrant: boolean = false;
  private channel: MethodChannel | null = null;

  constructor(context: Context, channel: MethodChannel | null) {
    super();
    this.cameraService = new CameraService(context);
    this.channel = channel;
  }

  getChannel(): MethodChannel | null {
    return this.channel;
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(buildOhosView);
  }

  getCameraService() {
    return this.cameraService;
  }

  getUserGrant() {
    return this.userGrant;
  }

  dispose(): void {
    console.info(TAG + 'dispose');
  }
}