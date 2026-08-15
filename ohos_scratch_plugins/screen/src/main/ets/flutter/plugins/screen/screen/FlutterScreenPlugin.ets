/*
* Copyright (c) 2024 SwanLink (Jiangsu) Technology Development Co., LTD.
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


import settings from '@ohos.settings';
import window from '@ohos.window';
import FlutterManager from '@ohos/flutter_ohos/src/main/ets/embedding/ohos/FlutterManager';
import { AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos/index';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = "FlutterScreenPlugin"

export class FlutterScreenPlugin implements FlutterPlugin, MethodCallHandler {
  private channelName: string = "github.com/clovisnicolas/flutter_screen"
  private abilityPluginBinding: AbilityPluginBinding | null = null;
  private channel: MethodChannel | null = null
  private mainWindow: window.Window | null = null;
  private lastSetBrightness: number | null = null;

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), this.channelName)
    this.channel?.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null)
    this.channel = null
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityPluginBinding = binding;
  }

  onDetachedFromAbility(): void {
    this.abilityPluginBinding = null;
    this.mainWindow = null;
    this.lastSetBrightness = null;
  }

  getWindow(): void {
    this.mainWindow = FlutterManager.getInstance()
      .getWindowStage(FlutterManager.getInstance().getUIAbility(this.abilityPluginBinding?.getAbility().context))
      .getMainWindowSync();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      if (!this.mainWindow) {
        this.getWindow();
      }
      switch (call.method) {
        case "brightness":
          result.success(this.getBrightness());
          break;
        case "setBrightness":
          let brightnessValue = parseFloat(call.argument("brightness"));
          this.mainWindow?.setWindowBrightness(brightnessValue);
          this.lastSetBrightness = Number(brightnessValue);
          result.success(null);
          break;
        case "isKeptOn":
          let flags: boolean = this.mainWindow?.getWindowProperties().isKeepScreenOn || false
          result.success(flags);
          break;
        case "keepOn":
          let on: boolean = call.argument("on");
          if (on) {
            Log.i(TAG, "Keeping screen on ");
            this.mainWindow?.setWindowKeepScreenOn(true);
          } else {
            Log.i(TAG, "Not keeping screen on");
            this.mainWindow?.setWindowKeepScreenOn(false);
          }
          result.success(null);
          break;

        default:
          result.notImplemented();
          break;
      }
    } catch (e) {
      Log.e(TAG, "set screen brightness failed");
      if (call.method === "brightness") {
        result.success(1.0);
      } else {
        result.error("ERROR", "操作失败", null);
      }
    }
  }

  getBrightness(): number {
    if (this.lastSetBrightness !== null && this.lastSetBrightness !== undefined && !isNaN(this.lastSetBrightness) && this.lastSetBrightness >= 0 && this.lastSetBrightness <= 1.0) {
      return Number(this.lastSetBrightness);
    }
    try {
      const brightness = this.mainWindow?.getWindowProperties().brightness;
      if (brightness !== undefined && brightness !== null && !isNaN(brightness) && brightness >= 0 && brightness <= 1.0) {
        this.lastSetBrightness = Number(brightness);
        return this.lastSetBrightness;
      }
    } catch (err) {
      Log.e(TAG, "get window brightness failed");
    }
    let result: number = 1.0;
    try {
      let value = settings.getValueSync(
        this.abilityPluginBinding?.getAbility().context,
        settings.display.SCREEN_BRIGHTNESS_STATUS,
        '100',
        settings.domainName.DEVICE_SHARED
      )
      result = parseFloat(value) / 255;
      if (result < 0 || isNaN(result)) result = 0.0;
      if (result > 1.0) result = 1.0;
    } catch (err) {
      result = 1.0;
      Log.e(TAG, "get screen brightness failed");
    }
    return Number(result);
  }
}