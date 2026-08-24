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

import { EventSink, StreamHandler } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel'
import { abilityAccessCtrl, Context, PermissionRequestResult, Permissions } from '@kit.AbilityKit'
import Logger from '../utils/Logger'
import { BusinessError } from '@ohos.base'
import { Any } from '@ohos/flutter_ohos'

const TAG = 'CameraPermissions'

export class CameraPermissions implements StreamHandler {
    events: EventSink | null = null

    onListen(args: Any, events: EventSink): void {
        this.events = events
    }

    onCancel(args: Any): void {
        if (this.events != null) {
            this.events!!.endOfStream()
            this.events = null
        }
    }

    /**
     * 获取权限
     */
    async requestPermissions(context: Context, saveGPS: boolean): Promise<string[]> {
        let atManager = abilityAccessCtrl.createAtManager();
        let permissions: Array<Permissions> = [
            'ohos.permission.CAMERA',
            'ohos.permission.MICROPHONE'
        ];

        if (saveGPS) {
            permissions.push('ohos.permission.APPROXIMATELY_LOCATION')
        }

        let permissionsResult: Array<Permissions> = []
        await atManager.requestPermissionsFromUser(context, permissions)
            .then((reqResult: PermissionRequestResult): void => {
                Logger.info(TAG, 'request Permissions success!');
                for (let index = 0; index < reqResult.authResults.length; index++) {
                    const element = reqResult.authResults[index];
                    if (element === 0) {
                        permissionsResult.push(permissions[index])
                    }
                }
            })
            .catch((error: BusinessError): void => {
                Logger.info(TAG, `requestPermissionsFromUser call Failed! error: ${error.code}`);
            });
        return permissionsResult;
    }
}