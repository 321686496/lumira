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

import { camera } from '@kit.CameraKit';
import { AspectRatio } from '../cameraX/ImageAnalysisBuilder'

export default class CameraUtils {
    static getPreconfigRatio(ratio: string): camera.PreconfigRatio {
        switch (ratio) {
            case AspectRatio.RATIO_1_1:
                return camera.PreconfigRatio.PRECONFIG_RATIO_1_1
            case AspectRatio.RATIO_16_9:
                return camera.PreconfigRatio.PRECONFIG_RATIO_16_9
            default:
                return camera.PreconfigRatio.PRECONFIG_RATIO_4_3
        }
    }

    static getPreconfigRatioNum(ratio: string): number {
        switch (ratio) {
            case AspectRatio.RATIO_1_1:
                return 1
            case AspectRatio.RATIO_16_9:
                return 16/9
            default:
                return 4/3
        }
    }
}