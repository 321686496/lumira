import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import Logger from '../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { camera } from '@kit.CameraKit';

const TAG: string = 'GetImageWorker'

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

let isRunning = false
let mImageReceiver: image.ImageReceiver | undefined = undefined
let maxFramesPerSecond = 5

workerPort.onmessage = (e: MessageEvents) => {
    let type = ''
    if (e.data.type) {
        type = e.data.type as string
    } else {
        type = e.data as string
    }
    Logger.debug(TAG, "接收到主线程发送的消息: type = " + type)
    switch (type) {
        case 'finish':
            isRunning = false
            Logger.debug(TAG, "接收到主线程发送的消息: isRunning = " + isRunning)
            break
        case 'start':
            // 开始常驻任务
            getImageFromImageReceiver();
            break
        case 'creat':
            const width = e.data.width as number
            const height = e.data.height as number
            maxFramesPerSecond = e.data.maxFramesPerSecond as number
            initImageReceiver(width, height)
            break
        case 'releaseImageReceiver':
            mImageReceiver?.release()
            break
        default:
            break
    }
}

workerPort.onmessageerror = (e: MessageEvents) => {
    Logger.error(TAG, "接收消息出现错误：" + e.data as string)
}

async function initImageReceiver(width: number, height: number) {
    if (!mImageReceiver) {
        mImageReceiver = image.createImageReceiver({ width: width, height: height }, image.ImageFormat.JPEG, 1)
    }
    workerPort.postMessage({ type: 'surfaceId', surfaceId: await mImageReceiver.getReceivingSurfaceId() })
}

function getImageFromImageReceiver() {
    mImageReceiver!!.on('imageArrival', () => {
        Logger.debug(TAG, "build imageArrival isRunning = " + isRunning)
        if (!isRunning) {
            isRunning = true
            mImageReceiver?.readLatestImage((err: BusinessError, latestImage: image.Image) => {
                if (err || latestImage === undefined) {
                    Logger.error(TAG, 'readLatestImage failed');
                    return;
                }

                latestImage.getComponent(image.ComponentType.JPEG,
                    (err: BusinessError, imgComponent: image.Component) => {
                        if (err || imgComponent === undefined) {
                            Logger.error(TAG, 'getComponent failed');
                        }

                        if (imgComponent && imgComponent.byteBuffer as ArrayBuffer) {
                            let map = new Map<string, Object>();
                            map.set('height', latestImage.size.height)
                            map.set('width', latestImage.size.width)
                            map.set('format', 'nv21')
                            map.set('rotation', `rotation${camera.ImageRotation.ROTATION_90}deg`)
                            let rect = new Map<string, Number>()
                            rect.set('left', latestImage.clipRect.y)
                            rect.set('top', latestImage.clipRect.x)
                            rect.set('right', latestImage.clipRect.y + latestImage.clipRect.size.width)
                            rect.set('bottom', latestImage.clipRect.x + latestImage.clipRect.size.height)
                            map.set('cropRect', rect)

                            Logger.debug(TAG, 'get image map success');
                            workerPort.postMessage(
                                {
                                    type: 'map',
                                    map: map,
                                    rowStride: imgComponent.rowStride,
                                    pixelStride: imgComponent.pixelStride,
                                    buffer: imgComponent.byteBuffer as ArrayBuffer
                                }, [imgComponent.byteBuffer as ArrayBuffer])
                        } else {
                            Logger.error(TAG, 'byteBuffer is null');
                        }

                        setTimeout(() => {
                            // 确保当前buffer没有在使用的情况下，可进行资源释放
                            latestImage.release();
                        }, Math.round(1000 * 50 / maxFramesPerSecond))
                    })
            })
        }
    })
}