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

import { EventSink, StreamHandler } from "@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel";
import { audio } from '@kit.AudioKit';
import { Any } from "@ohos/flutter_ohos";
import Logger from "../utils/Logger"

const TAG = "PhysicalButtonsHandler"

export class PhysicalButtonsHandler implements StreamHandler {
    sink: EventSink | undefined
    audioVolumeManager: audio.AudioVolumeManager | undefined
    volumeGroupManager: audio.AudioVolumeGroupManager | undefined

    constructor() {
        let audioManager = audio.getAudioManager();
        this.audioVolumeManager = audioManager.getVolumeManager();
    }

    async startListen() {
        this.volumeGroupManager = await this.audioVolumeManager?.getVolumeGroupManager(audio.DEFAULT_VOLUME_GROUP_ID)
        this.audioVolumeManager?.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
            Logger.debug(TAG, `VolumeType of stream: ${volumeEvent.volumeType} `);
            Logger.debug(TAG, `Volume level: ${volumeEvent.volume} `);
            Logger.debug(TAG, `Whether to updateUI: ${volumeEvent.updateUi} `);
            let volume = this.volumeGroupManager?.getVolumeSync(audio.AudioVolumeType.MEDIA)
            if (volumeEvent.volume > volume!!) {
                this.sink?.success("VOLUME_UP")
            } else {
                this.sink?.success("VOLUME_DOWN")
            }
        });
    }

    endListen() {
        this.audioVolumeManager?.off('volumeChange')
    }

    onListen(args: Any, events: EventSink): void {
        this.sink = events
    }

    onCancel(args: Any): void {
        if (this.sink != undefined) {
            this.sink?.endOfStream()
            this.sink = undefined
        }
        this.endListen
    }
}