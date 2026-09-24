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
import common from '@ohos.app.ability.common';
import { Any } from '@ohos/flutter_ohos';
import { MethodResult } from '@ohos/flutter_ohos';

export default class EventHub {
  public static readonly EVENT_QRCODE_STARTSCAN = "qrcode_start_scan";
  public static readonly EVENT_QRCODE_STOPSCAN = "qrcode_stop_scan";
  public static readonly EVENT_QRCODE_FLIPCAMERA = "qrcode_flip_camera";
  public static readonly EVENT_QRCODE_TOGGLEFLASH = "qrcode_toggle_flash";
  public static readonly EVENT_QRCODE_PAUSECAMERA = "qrcode_pause_camera";
  public static readonly EVENT_QRCODE_RESUM = "qrcode_resum";
  public static readonly EVENT_QRCODE_GETCAMERAINFO = "qrcode_get_camera_info";
  public static readonly EVENT_QRCODE_GETFLASHINFO = "qrcode_get_flash_info";
  public static readonly EVENT_QRCODE_GETSYSTEMFEATURES = "qrcode_get_system_features";
  public static readonly EVENT_QRCODE_CHANGESCANAREA = "qrcode_change_scan_area";
  public static readonly EVENT_QRCODE_INVERTSCAN = "qrcode_invert_scan";

  public static emitStartScan(context: common.Context, args: Any) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_STARTSCAN, args);
  }

  public static emitStopScan(context: common.Context, args: Any) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_STOPSCAN, args);
  }

  public static emitFlipCamera(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_FLIPCAMERA, result);
  }

  public static emitToggleFlash(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_TOGGLEFLASH, result);
  }

  public static emitPauseCamera(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_PAUSECAMERA, result);
  }

  public static emitResum(context: common.Context) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_RESUM);
  }

  public static emitGetCameraInfo(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_GETCAMERAINFO, result);
  }

  public static emitGetFlashInfo(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_GETFLASHINFO, result);
  }

  public static emitGetSystemFeatures(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_GETSYSTEMFEATURES, result);
  }

  public static emitChangeScanArea(context: common.Context, arg: Any) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_CHANGESCANAREA, arg);
  }

  public static emitInvertScan(context: common.Context, result: MethodResult) {
    context.eventHub.emit(EventHub.EVENT_QRCODE_INVERTSCAN, result);
  }

  public static onStartScan(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_STARTSCAN, (args: Any) => {
      callBack(args)
    });
  }

  public static onStopScan(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_STOPSCAN, (args: Any) => {
      callBack(args)
    });
  }

  public static onFlipCamera(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_FLIPCAMERA, (args: Any) => {
      callBack(args)
    });
  }

  public static onToggleFlash(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_TOGGLEFLASH, (args: Any) => {
      callBack(args)
    });
  }

  public static onPauseCamera(context: common.Context, callBack: (...arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_PAUSECAMERA, (...args: Any) => {
      callBack(args)
    });
  }

  public static onResum(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_RESUM, (args: Any) => {
      callBack(args)
    });
  }

  public static onGetCameraInfo(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_GETCAMERAINFO, (args: Any) => {
      callBack(args)
    });
  }

  public static onGetFlashInfo(context: common.Context, callBack: (result: MethodResult) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_GETFLASHINFO, (result: MethodResult) => {
      callBack(result)
    });
  }

  public static onGetSystemFeatures(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_GETSYSTEMFEATURES, (args: Any) => {
      callBack(args)
    });
  }

  public static onChangeScanArea(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_CHANGESCANAREA, (...args: Any) => {
      callBack(args)
    });
  }

  public static onInvertScan(context: common.Context, callBack: (arg: Any) => void) {
    context.eventHub.on(EventHub.EVENT_QRCODE_INVERTSCAN, (...args: Any) => {
      callBack(args)
    });
  }

  public static offStartScan(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_STARTSCAN);
  }

  public static offStopScan(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_STOPSCAN);
  }

  public static offFlipCamera(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_FLIPCAMERA);
  }

  public static offToggleFlash(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_TOGGLEFLASH);
  }

  public static offPauseCamera(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_PAUSECAMERA);
  }

  public static offResum(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_RESUM);
  }

  public static offGetCameraInfo(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_GETCAMERAINFO);
  }

  public static offGetFlashInfo(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_GETFLASHINFO);
  }

  public static offChangeScanArea(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_CHANGESCANAREA);
  }

  public static offSystemFeatures(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_GETSYSTEMFEATURES);
  }

  public static offInvertScan(context: common.Context) {
    context.eventHub.off(EventHub.EVENT_QRCODE_INVERTSCAN);
  }

  public static offAll(context: common.Context) {
    EventHub.offStartScan(context);
    EventHub.offStopScan(context);
    EventHub.offFlipCamera(context);
    EventHub.offToggleFlash(context);
    EventHub.offPauseCamera(context);
    EventHub.offResum(context);
    EventHub.offGetCameraInfo(context);
    EventHub.offGetFlashInfo(context);
    EventHub.offSystemFeatures(context);
    EventHub.offChangeScanArea(context);
    EventHub.offInvertScan(context);
  }
}