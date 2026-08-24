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

import { EventSink } from '@ohos/flutter_ohos/src/main/ets/plugin/common/EventChannel'
import { ErrorEvent, JSON, List, worker } from '@kit.ArkTS'
import Logger from '../utils/Logger'

export enum AspectRatio {
    RATIO_1_1 = 'RATIO_1_1',
    RATIO_4_3 = 'RATIO_4_3',
    RATIO_16_9 = 'RATIO_16_9'
}

const TAG: string = 'ImageAnalysisBuilder'

export class ImageAnalysisBuilder {
    private format: string | undefined = undefined
    private width: number | undefined = undefined
    private height: number | undefined = undefined
    private _previewStreamSink: EventSink | undefined = undefined
    private maxFramesPerSecond: number | undefined = undefined
    private workerInstance: worker.ThreadWorker | undefined = undefined
    surfaceId: string | undefined = undefined

    initCameraFun = () => {}

    private constructor(format: string, width: number, height: number, maxFramesPerSecond: number | undefined) {
        this.format = format
        this.width = width
        this.height = height
        this.maxFramesPerSecond = maxFramesPerSecond
        this.initGetImageWorker()
    }

    static configure(aspectRatio: string, format: string, width: number,
        maxFramesPerSecond: number): ImageAnalysisBuilder {
        Logger.debug(TAG,
            `aspectRatio:${aspectRatio}; format:${format}; width:${width}; maxFramesPerSecond:${maxFramesPerSecond}`)
        let widthOrDefault = 1024
        if (width != null && width > 0) {
            widthOrDefault = width
        }

        let analysisAspectRatio: number = aspectRatio == AspectRatio.RATIO_4_3 ? (4 / 3) : (16 / 9)

        let height = widthOrDefault * (1 / analysisAspectRatio)
        let maxFps: number | undefined = maxFramesPerSecond == 0.0 ? undefined : maxFramesPerSecond
        return new ImageAnalysisBuilder(format, widthOrDefault, height, maxFps)
    }

    initGetImageWorker() {
        this.workerInstance = new worker.ThreadWorker('../workers/GetImageWorker.ets');

        this.workerInstance.onerror = (err: ErrorEvent) => {
            Logger.error(TAG, "子线程发生错误：" + err.message)
            this.workerInstance?.terminate()
        }

        this.workerInstance.postMessage({
            type: 'creat',
            width: this.width,
            height: this.height,
            maxFramesPerSecond: this.maxFramesPerSecond
        })

        this.workerInstance.onmessage = (event) => {
            Logger.debug(TAG, "主线程收到消息:" + event?.data.type as string)
            const type = event?.data.type as string
            switch (type) {
                case 'surfaceId':
                    let surfaceId = event.data.surfaceId as string
                    this.surfaceId = surfaceId
                    this.initCameraFun()
                    break
                case 'map':
                    let map = event.data.map as Map<string, Object>
                    Logger.debug(TAG, "map = " + JSON.stringify(Array.from(map.entries())))
                    let cropRect = map.get('cropRect') as Map<string, number>
                    Logger.debug(TAG, "map.cropRect = " + JSON.stringify(Array.from(cropRect.entries())))
                    let rowStride = event.data.rowStride as number
                    Logger.debug(TAG, "rowStride = " + rowStride)
                    let pixelStride = event.data.pixelStride as number
                    Logger.debug(TAG, "pixelStride = " + pixelStride)
                    let buffer = event.data.buffer as ArrayBuffer
                    map.set('nv21Image', new Uint8Array(buffer))
                    map.set('planes',
                        this.imagePlanesAdapter(new Uint8Array(buffer), rowStride, pixelStride,
                            map.get('width') as number, map.get('height') as number))
                    this._previewStreamSink?.success(map)
                    break
                default:
                    break
            }
        }
    }

    start() {
        Logger.debug(TAG, "start!")
        this.workerInstance?.postMessage('start')
    }

    imagePlanesAdapter(bytes: Uint8Array, rowStride: number, pixelStride: number, width: number, height: number): List<Map<string, Object>> {
        let list = new List<Map<string, Object>>()
        let map = new Map<string, Object>()
        map.set('bytes', bytes)
        map.set('rowStride', rowStride)
        map.set('pixelStride', pixelStride)
        map.set('height', height)
        map.set('width', width)
        list.add(map)
        return list
    }

    finish() {
        Logger.debug(TAG, "finish")
        this.workerInstance?.postMessage('finish')
    }

    /**
     * 销毁worker线程
     */
    stop() {
        Logger.debug(TAG, "stop")
        this.workerInstance?.postMessage('releaseImageReceiver')
        this.workerInstance?.terminate()
    }

    public set previewStreamSink(value: EventSink | undefined) {
        this._previewStreamSink = value
    }

    public get previewStreamSink(): EventSink | undefined {
        return this._previewStreamSink
    }
}