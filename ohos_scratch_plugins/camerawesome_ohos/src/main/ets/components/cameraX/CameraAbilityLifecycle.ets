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

import { AbilityLifecycleCallback, UIAbility } from "@kit.AbilityKit";
import { CameraState } from "../cameraX/CameraState"
import { OrientationStreamListener } from "../cameraX/OrientationStreamListener"
import window from "@ohos.window";
import Logger from '../utils/Logger';

const TAG: string = 'CameraAbilityLifecycle'

export class CameraAbilityLifecycle extends AbilityLifecycleCallback {
  private _cameraState: CameraState | undefined = undefined;
  private _orientationStreamListener: OrientationStreamListener | undefined = undefined;
  private _windowStatusType: window.WindowStatusType = window.WindowStatusType.UNDEFINED;
  private _window: window.Window | undefined;
  private _firstInitWindow : boolean = false;

  public set cameraState(value: CameraState | undefined) {
    this._cameraState = value;
  }

  public get cameraState(): CameraState | undefined {
    return this._cameraState;
  }

  public set orientationStreamListener(value: OrientationStreamListener | undefined) {
    this._orientationStreamListener = value;
  }

  public get orientationStreamListener(): OrientationStreamListener | undefined {
    return this._orientationStreamListener;
  }

  public get windowStatusType(): window.WindowStatusType {
    return this._windowStatusType;
  }

  onAbilityForeground(ability: UIAbility): void {
    if (this._cameraState) {
      this._cameraState.initCamera()
    }
    if (this._orientationStreamListener) {
      this._orientationStreamListener.onSensor();
    }
  }

  onAbilityBackground(ability: UIAbility): void {
    if (this._cameraState) {
      this._cameraState.releaseCamera()
    }
    if (this._orientationStreamListener) {
      this._orientationStreamListener.offSensor();
    }
  }

  onWindowStageCreate(ability: UIAbility, windowStage: window.WindowStage): void {
    this.getMainWindow(windowStage)
  }

  // 防止 onWindowStageCreate 不回调
  onWindowStageActive(ability: UIAbility, windowStage: window.WindowStage): void {
    this.getMainWindow(windowStage)
  }

  onWindowStageDestroy(ability: UIAbility, windowStage: window.WindowStage): void {
    this.offWindowStatusChange();
  }

  private getMainWindow(windowStage: window.WindowStage){
    if(!this._window){
      windowStage.getMainWindow().then((window) => {
        this._window = window;
        this.onWindowStatusChange();
      })
    }
  }

  private onWindowStatusChange() {
    try {
      this._window?.on('windowStatusChange', (windowStatusType: window.WindowStatusType) => {
        // 4 表示APP自由悬浮形式窗口模式。。
        // 5 表示APP分屏模式。
        this._windowStatusType = windowStatusType
      });
    } catch (err) {
      Logger.error(TAG, `on windowStatusChange error: ${err}`);
    }
  }

  private offWindowStatusChange() {
    try {
      this._window?.off('windowStatusChange');
    } catch (err) {
      Logger.error(TAG, `off windowStatusChange error: ${err}`);
    }
  }

}