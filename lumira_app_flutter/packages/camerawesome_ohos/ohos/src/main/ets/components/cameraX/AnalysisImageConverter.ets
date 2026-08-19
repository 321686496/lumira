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

import { AnalysisImageUtils, AnalysisImageWrapper, Result, AnalysisImageFormat } from './Pigeon';
import image from '@ohos.multimedia.image';
import buffer from '@ohos.buffer';
import { BusinessError } from '@kit.BasicServicesKit';

export class AnalysisImageConverter extends AnalysisImageUtils {
    nv21toJpeg(nv21Image: AnalysisImageWrapper, jpegQuality: number, result: Result<AnalysisImageWrapper>): void {
        let opts: image.InitializationOptions = {
            editable: true,
            srcPixelFormat: image.PixelMapFormat.NV21,
            pixelFormat: image.PixelMapFormat.BGRA_8888,
            size: {
                height: nv21Image.getWidth(),
                width: nv21Image.getHeight()
            }
        }

        let arryBuffer = buffer.from(nv21Image.getBytes()).buffer
        image.createPixelMap(arryBuffer, opts).then((pixelMap: image.PixelMap) => {
            console.info('Succeeded in creating pixelmap.');
            const imagePackerApi: image.ImagePacker = image.createImagePacker();

            let packOpts: image.PackingOption = { format: "image/jpeg", quality: jpegQuality }
            imagePackerApi.packing(pixelMap, packOpts)
                .then((data: ArrayBuffer) => {
                    console.info('Succeeded in packing the image.');
                    result.success(new AnalysisImageWrapper(
                        AnalysisImageFormat.JPEG,
                        new Uint8Array(data),
                        nv21Image.getWidth(),
                        nv21Image.getHeight(),
                        nv21Image.getPlanes(),
                        nv21Image.getCropRect(),
                        nv21Image.getRotation()
                    ))
                }).catch((error: BusinessError) => {
                console.error(`Failed to pack the image.code ${error.code},message is ${error.message}`);
            })
        }).catch((error: BusinessError) => {
            console.error(`Failed to create pixelmap. code is ${error.code}, message is ${error.message}`);
        })
    }

    yuv420toJpeg(yuvImage: AnalysisImageWrapper, jpegQuality: number, result: Result<AnalysisImageWrapper>): void {
        throw new Error('Method not implemented.');
    }

    yuv420toNv21(yuvImage: AnalysisImageWrapper, result: Result<AnalysisImageWrapper>): void {
        throw new Error('Method not implemented.');
    }

    bgra8888toJpeg(bgra8888image: AnalysisImageWrapper, jpegQuality: number,
        result: Result<AnalysisImageWrapper>): void {
        let opts: image.InitializationOptions = {
            editable: true,
            pixelFormat: image.PixelMapFormat.BGRA_8888,
            size: {
                height: bgra8888image.getWidth(),
                width: bgra8888image.getHeight()
            }
        }

        let arryBuffer = buffer.from(bgra8888image.getBytes()).buffer
        image.createPixelMap(arryBuffer, opts).then((pixelMap: image.PixelMap) => {
            console.info('Succeeded in creating pixelmap.');
            const imagePackerApi: image.ImagePacker = image.createImagePacker();

            let packOpts: image.PackingOption = { format: "image/jpeg", quality: jpegQuality }
            imagePackerApi.packing(pixelMap, packOpts)
                .then((data: ArrayBuffer) => {
                    console.info('Succeeded in packing the image.');
                    result.success(new AnalysisImageWrapper(
                        AnalysisImageFormat.JPEG,
                        new Uint8Array(data),
                        bgra8888image.getWidth(),
                        bgra8888image.getHeight(),
                        bgra8888image.getPlanes(),
                        bgra8888image.getCropRect(),
                        bgra8888image.getRotation()
                    ))
                }).catch((error: BusinessError) => {
                console.error(`Failed to pack the image.code ${error.code},message is ${error.message}`);
            })
        }).catch((error: BusinessError) => {
            console.error(`Failed to create pixelmap. code is ${error.code}, message is ${error.message}`);
        })
    }
}