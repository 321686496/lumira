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

import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import BasicMessageChannel, { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { BinaryMessenger, TaskQueue } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import MessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/MessageCodec';
import { ByteBuffer } from '@ohos/flutter_ohos/src/main/ets/util/ByteBuffer';


/** Error class for passing custom error details to Flutter via a thrown PlatformException. */
export class FlutterError implements Error {
    /** The error code. */
    public code: string;
    /** The error name. */
    public name: string;
    /** The error message. */
    public message: string;
    /** The error stack. */
    public stack?: string;

    constructor(code: string, name: string, message: string, stack: string) {
        this.code = code;
        this.name = name;
        this.message = message;
        this.stack = stack;
    }
}

function wrapError(error: Error): Array<Object> {
    let errorList: Array<Object> = new Array<Object>(3);
    if (error instanceof FlutterError) {
        let err: FlutterError = error as FlutterError;
        errorList[0] = err.code;
        errorList[1] = err.name;
        errorList[2] = err.message;
    } else {
        errorList[0] = error.toString();
        errorList[1] = error.name;
        errorList[2] = "Cause: " + error.message + ", Stacktrace: " + error.stack;
    }
    return errorList;
}

export enum PigeonSensorType {
    /*
    *  A built-in wide-angle camera.
    *
    *  The wide angle sensor is the default sensor for iOS
    */
    WIDE_ANGLE,
    /* A built-in camera with a shorter focal length than that of the wide-angle camera.*/
    ULTRA_WIDE_ANGLE,
    /* A built-in camera device with a longer focal length than the wide-angle camera.*/
    TELEPHOTO,
    /*
    *  A device that consists of two cameras, one Infrared and one YUV.
    *
    *  iOS only
    */
    TRUE_DEPTH,
    UNKNOWN
}

export enum CamerAwesomePermission {
    STORAGE,
    CAMERA,
    LOCATION,
    RECORD_AUDIO
}

export enum AnalysisImageFormat {
    YUV_420,
    BGRA8888,
    JPEG,
    NV21,
    UNKNOWN
}

export enum AnalysisRotation {
    ROTATION0DEG,
    ROTATION90DEG,
    ROTATION180DEG,
    ROTATION270DEG
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PreviewSize {
    private width: number;

    getWidth(): number {
        return this.width;
    }

    private height: number;

    getHeight(): number {
        return this.height;
    }

    constructor(width: number, height: number) {
        this.width = width;
        this.height = height;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.width);
        arr.push(this.height);
        return arr;
    }

    static fromList(arr: Object[]): PreviewSize {
        let instance: PreviewSize = new PreviewSize(arr[0] as number, arr[1] as number);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class ExifPreferences {
    private saveGPSLocation: boolean;

    getSaveGPSLocation(): boolean {
        return this.saveGPSLocation;
    }

    constructor(saveGPSLocation: boolean) {
        this.saveGPSLocation = saveGPSLocation;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.saveGPSLocation);
        return arr;
    }

    static fromList(arr: Object[]): ExifPreferences {
        let instance: ExifPreferences = new ExifPreferences(arr[0] as boolean);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class VideoOptions {
    private fileType: string;

    getFileType(): string {
        return this.fileType;
    }

    private codec: string;

    getCodec(): string {
        return this.codec;
    }

    constructor(fileType: string, codec: string) {
        this.fileType = fileType;
        this.codec = codec;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.fileType);
        arr.push(this.codec);
        return arr;
    }

    static fromList(arr: Object[]): VideoOptions {
        let instance: VideoOptions = new VideoOptions(arr[0] as string, arr[1] as string);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PigeonSensorTypeDevice {
    private sensorType: PigeonSensorType;

    getSensorType(): PigeonSensorType {
        return this.sensorType;
    }

    private name: string;

    getName(): string {
        return this.name;
    }

    private iso: number;

    getIso(): number {
        return this.iso;
    }

    private flashAvailable: boolean;

    getFlashAvailable(): boolean {
        return this.flashAvailable;
    }

    private uid: string;

    getUid(): string {
        return this.uid;
    }

    constructor(sensorType: PigeonSensorType, name: string, iso: number, flashAvailable: boolean, uid: string) {
        this.sensorType = sensorType;
        this.name = name;
        this.iso = iso;
        this.flashAvailable = flashAvailable;
        this.uid = uid;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.sensorType);
        arr.push(this.name);
        arr.push(this.iso);
        arr.push(this.flashAvailable);
        arr.push(this.uid);
        return arr;
    }

    static fromList(arr: Object[]): PigeonSensorTypeDevice {
        let instance: PigeonSensorTypeDevice =
            new PigeonSensorTypeDevice(PigeonSensorType[PigeonSensorType[arr[0] as number]], arr[1] as string,
                arr[2] as number, arr[3] as boolean, arr[4] as string);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class AndroidFocusSettings {
    private autoCancelDurationInMillis: number;

    getAutoCancelDurationInMillis(): number {
        return this.autoCancelDurationInMillis;
    }

    constructor(autoCancelDurationInMillis: number) {
        this.autoCancelDurationInMillis = autoCancelDurationInMillis;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.autoCancelDurationInMillis);
        return arr;
    }

    static fromList(arr: Object[]): AndroidFocusSettings {
        let instance: AndroidFocusSettings = new AndroidFocusSettings(arr[0] as number);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlaneWrapper {
    private bytes: number[];

    getBytes(): number[] {
        return this.bytes;
    }

    private bytesPerRow: number;

    getBytesPerRow(): number {
        return this.bytesPerRow;
    }

    private bytesPerPixel: number;

    getBytesPerPixel(): number {
        return this.bytesPerPixel;
    }

    private width: number;

    getWidth(): number {
        return this.width;
    }

    private height: number;

    getHeight(): number {
        return this.height;
    }

    constructor(bytes: number[], bytesPerRow: number, bytesPerPixel: number, width: number, height: number) {
        this.bytes = bytes;
        this.bytesPerRow = bytesPerRow;
        this.bytesPerPixel = bytesPerPixel;
        this.width = width;
        this.height = height;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.bytes);
        arr.push(this.bytesPerRow);
        arr.push(this.bytesPerPixel);
        arr.push(this.width);
        arr.push(this.height);
        return arr;
    }

    static fromList(arr: Object[]): PlaneWrapper {
        let instance: PlaneWrapper =
            new PlaneWrapper(arr[0] as number[], arr[1] as number, arr[2] as number, arr[3] as number,
                arr[4] as number);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class CropRectWrapper {
    private left: number;

    getLeft(): number {
        return this.left;
    }

    private top: number;

    getTop(): number {
        return this.top;
    }

    private width: number;

    getWidth(): number {
        return this.width;
    }

    private height: number;

    getHeight(): number {
        return this.height;
    }

    constructor(left: number, top: number, width: number, height: number) {
        this.left = left;
        this.top = top;
        this.width = width;
        this.height = height;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.left);
        arr.push(this.top);
        arr.push(this.width);
        arr.push(this.height);
        return arr;
    }

    static fromList(arr: Object[]): CropRectWrapper {
        let instance: CropRectWrapper =
            new CropRectWrapper(arr[0] as number, arr[1] as number, arr[2] as number, arr[3] as number);
        return instance;
    }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class AnalysisImageWrapper {
    private format: AnalysisImageFormat;

    getFormat(): AnalysisImageFormat {
        return this.format;
    }

    private bytes: Uint8Array;

    getBytes(): Uint8Array {
        return this.bytes;
    }

    private width: number;

    getWidth(): number {
        return this.width;
    }

    private height: number;

    getHeight(): number {
        return this.height;
    }

    private planes: Array<PlaneWrapper>;

    getPlanes(): Array<PlaneWrapper> {
        return this.planes;
    }

    private cropRect: CropRectWrapper;

    getCropRect(): CropRectWrapper {
        return this.cropRect;
    }

    private rotation: AnalysisRotation;

    getRotation(): AnalysisRotation {
        return this.rotation;
    }

    constructor(format: AnalysisImageFormat, bytes: Uint8Array, width: number, height: number,
        planes: Array<PlaneWrapper>, cropRect: CropRectWrapper, rotation: AnalysisRotation) {
        this.format = format;
        this.bytes = bytes;
        this.width = width;
        this.height = height;
        this.planes = planes;
        this.cropRect = cropRect;
        this.rotation = rotation;
    }

    toList(): Object[] {
        let arr: Object[] = new Array();
        arr.push(this.format);
        arr.push(this.bytes);
        arr.push(this.width);
        arr.push(this.height);
        arr.push(this.planes);
        if (this.cropRect instanceof Array) {
            arr.push(this.cropRect);
        } else {
            arr.push(this.cropRect.toList());
        }
        arr.push(this.rotation);
        return arr;
    }

    static fromList(arr: Object[]): AnalysisImageWrapper {
        let instance: AnalysisImageWrapper =
            new AnalysisImageWrapper(AnalysisImageFormat[AnalysisImageFormat[arr[0] as number]], arr[1] as Uint8Array,
                arr[2] as number, arr[3] as number, arr[4] as Array<PlaneWrapper>,
                CropRectWrapper.fromList(arr[5] as Object[]), AnalysisRotation[AnalysisRotation[arr[6] as number]]);
        return instance;
    }
}

export interface Result<T> {
    success(result: T): void;

    error(error: Error): void;
}

class AnalysisImageUtilsCodec extends StandardMessageCodec {
    static INSTANCE: AnalysisImageUtilsCodec = new AnalysisImageUtilsCodec();

    getByte(n: number): number {
        let byteArray = new Uint8Array(1);
        byteArray[0] = n;
        return byteArray[0] as number;
    }

    readValueOfType(type: number, buffer: ByteBuffer): ESObject {
        switch (type) {
            case this.getByte(128):
                return AnalysisImageWrapper.fromList(super.readValue(buffer));
            case this.getByte(129):
                return CropRectWrapper.fromList(super.readValue(buffer));
            case this.getByte(130):
                return PlaneWrapper.fromList(super.readValue(buffer));
            default:
                return super.readValueOfType(type, buffer);
        }
    }

    writeValue(stream: ByteBuffer, value: ESObject): ESObject {
        if (value instanceof AnalysisImageWrapper) {
            stream.writeUint8(this.getByte(128));
            this.writeValue(stream, (value as AnalysisImageWrapper).toList());
        } else if (value instanceof CropRectWrapper) {
            stream.writeUint8(this.getByte(129));
            this.writeValue(stream, (value as CropRectWrapper).toList());
        } else if (value instanceof PlaneWrapper) {
            stream.writeUint8(this.getByte(130));
            this.writeValue(stream, (value as PlaneWrapper).toList());
        } else {
            super.writeValue(stream, value);
        }
    }
}

/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class AnalysisImageUtils {
    abstract nv21toJpeg(nv21Image: AnalysisImageWrapper, jpegQuality: number,
        result: Result<AnalysisImageWrapper>): void;

    abstract yuv420toJpeg(yuvImage: AnalysisImageWrapper, jpegQuality: number,
        result: Result<AnalysisImageWrapper>): void;

    abstract yuv420toNv21(yuvImage: AnalysisImageWrapper, result: Result<AnalysisImageWrapper>): void;

    abstract bgra8888toJpeg(bgra8888image: AnalysisImageWrapper, jpegQuality: number,
        result: Result<AnalysisImageWrapper>): void;

    /** The codec used by AnalysisImageUtils. */
    static getCodec(): MessageCodec<Object> {
        return AnalysisImageUtilsCodec.INSTANCE;
    }

    /*Sets up an instance of `AnalysisImageUtils` to handle messages through the `binaryMessenger`.*/
    static setup(binaryMessenger: BinaryMessenger, api: AnalysisImageUtils | null): void {
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.AnalysisImageUtils.nv21toJpeg",
                    AnalysisImageUtils.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<AnalysisImageWrapper> {
                            success(result: AnalysisImageWrapper): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<AnalysisImageWrapper> = new ResultImp();

                        api!.nv21toJpeg(args[0] as AnalysisImageWrapper, args[1] as number, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.AnalysisImageUtils.yuv420toJpeg",
                    AnalysisImageUtils.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<AnalysisImageWrapper> {
                            success(result: AnalysisImageWrapper): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<AnalysisImageWrapper> = new ResultImp();

                        api!.yuv420toJpeg(args[0] as AnalysisImageWrapper, args[1] as number, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.AnalysisImageUtils.yuv420toNv21",
                    AnalysisImageUtils.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<AnalysisImageWrapper> {
                            success(result: AnalysisImageWrapper): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<AnalysisImageWrapper> = new ResultImp();

                        api!.yuv420toNv21(args[0] as AnalysisImageWrapper, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.AnalysisImageUtils.bgra8888toJpeg",
                    AnalysisImageUtils.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<AnalysisImageWrapper> {
                            success(result: AnalysisImageWrapper): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<AnalysisImageWrapper> = new ResultImp();

                        api!.bgra8888toJpeg(args[0] as AnalysisImageWrapper, args[1] as number, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
    }
}

class CameraInterfaceCodec extends StandardMessageCodec {
    static INSTANCE: CameraInterfaceCodec = new CameraInterfaceCodec();

    getByte(n: number): number {
        let byteArray = new Uint8Array(1);
        byteArray[0] = n;
        return byteArray[0] as number;
    }

    readValueOfType(type: number, buffer: ByteBuffer): ESObject {
        switch (type) {
            case this.getByte(128):
                return AndroidFocusSettings.fromList(super.readValue(buffer));
            case this.getByte(129):
                return ExifPreferences.fromList(super.readValue(buffer));
            case this.getByte(130):
                return PigeonSensorTypeDevice.fromList(super.readValue(buffer));
            case this.getByte(131):
                return PreviewSize.fromList(super.readValue(buffer));
            case this.getByte(132):
                return PreviewSize.fromList(super.readValue(buffer));
            case this.getByte(133):
                return VideoOptions.fromList(super.readValue(buffer));
            default:
                return super.readValueOfType(type, buffer);
        }
    }

    writeValue(stream: ByteBuffer, value: ESObject): ESObject {
        if (value instanceof AndroidFocusSettings) {
            stream.writeUint8(this.getByte(128));
            this.writeValue(stream, (value as AndroidFocusSettings).toList());
        } else if (value instanceof ExifPreferences) {
            stream.writeUint8(this.getByte(129));
            this.writeValue(stream, (value as ExifPreferences).toList());
        } else if (value instanceof PigeonSensorTypeDevice) {
            stream.writeUint8(this.getByte(130));
            this.writeValue(stream, (value as PigeonSensorTypeDevice).toList());
        } else if (value instanceof PreviewSize) {
            stream.writeUint8(this.getByte(131));
            this.writeValue(stream, (value as PreviewSize).toList());
        } else if (value instanceof PreviewSize) {
            stream.writeUint8(this.getByte(132));
            this.writeValue(stream, (value as PreviewSize).toList());
        } else if (value instanceof VideoOptions) {
            stream.writeUint8(this.getByte(133));
            this.writeValue(stream, (value as VideoOptions).toList());
        } else {
            super.writeValue(stream, value);
        }
    }
}

/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class CameraInterface {
    abstract setupCamera(sensor: string, aspectRatio: string, zoom: number, mirrorFrontCamera: boolean,
        enablePhysicalButton: boolean, flashMode: string, captureMode: string, enableImageStream: boolean,
        exifPreferences: ExifPreferences, result: Result<boolean>): void;

    abstract checkPermissions(): Array<string>;

    /*
    *  Returns given [CamerAwesomePermission] list (as String). Location permission might be
    *  refused but the app should still be able to run.
    */
    abstract requestPermissions(saveGpsLocation: boolean, result: Result<Array<string>>): void;

    abstract getPreviewTextureId(): number;

    abstract takePhoto(path: string, result: Result<boolean>): void;

    abstract recordVideo(path: string, options: VideoOptions, result: Result<void>): void;

    abstract pauseVideoRecording(): void;

    abstract resumeVideoRecording(): void;

    abstract receivedImageFromStream(): void;

    abstract stopRecordingVideo(result: Result<boolean>): void;

    abstract getFrontSensors(): Array<PigeonSensorTypeDevice>;

    abstract getBackSensors(): Array<PigeonSensorTypeDevice>;

    abstract start(): boolean;

    abstract stop(): boolean;

    abstract setFlashMode(mode: string): void;

    abstract handleAutoFocus(): void;

    /*
    *  Starts auto focus on a point at ([x], [y]).
    *
    *  On Android, you can control after how much time you want to switch back
    *  to passive focus mode with [androidFocusSettings].
    */
    abstract focusOnPoint(previewSize: PreviewSize, x: number, y: number,
        androidFocusSettings: AndroidFocusSettings): void;

    abstract setZoom(zoom: number): void;

    abstract setMirrorFrontCamera(mirror: boolean): void;

    abstract setSensor(sensor: string, deviceId: string): void;

    abstract setCorrection(brightness: number): void;

    abstract getMaxZoom(): number;

    abstract setCaptureMode(mode: string): void;

    abstract setRecordingAudioMode(enableAudio: boolean, result: Result<boolean>): void;

    abstract availableSizes(): Array<PreviewSize>;

    abstract refresh(): void;

    abstract getEffectivPreviewSize(): Promise<PreviewSize>;

    abstract setPhotoSize(size: PreviewSize): void;

    abstract setPreviewSize(size: PreviewSize): void;

    abstract setAspectRatio(aspectRatio: string): void;

    abstract setupImageAnalysisStream(format: string, width: number, maxFramesPerSecond: number,
        autoStart: boolean): void;

    abstract setExifPreferences(exifPreferences: ExifPreferences, result: Result<boolean>): void;

    abstract startAnalysis(): void;

    abstract stopAnalysis(): void;

    abstract setFilter(matrix: Array<number>): void;

    abstract isVideoRecordingAndImageAnalysisSupported(sensor: string, result: Result<boolean>): void;

    /** The codec used by CameraInterface. */
    static getCodec(): MessageCodec<Object> {
        return CameraInterfaceCodec.INSTANCE;
    }

    /*Sets up an instance of `CameraInterface` to handle messages through the `binaryMessenger`.*/
    static setup(binaryMessenger: BinaryMessenger, api: CameraInterface | null): void {
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setupCamera",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<boolean> {
                            success(result: boolean): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<boolean> = new ResultImp();

                        api!.setupCamera(args[0] as string, args[1] as string, args[2] as number, args[3] as boolean,
                            args[4] as boolean, args[5] as string, args[6] as string, args[7] as boolean,
                            args[8] as ExifPreferences, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.checkPermissions",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: Array<string> = api!.checkPermissions();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.requestPermissions",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<Array<string>> {
                            success(result: Array<string>): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<Array<string>> = new ResultImp();

                        api!.requestPermissions(args[0] as boolean, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.getPreviewTextureId",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: number = api!.getPreviewTextureId();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.takePhoto",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<boolean> {
                            success(result: boolean): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<boolean> = new ResultImp();

                        api!.takePhoto(args[0] as string, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.recordVideo",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<void> {
                            success(result: void): void {
                                let res: Array<Object> = [];
                                res.push(null);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<void> = new ResultImp();

                        api!.recordVideo(args[0] as string, args[1] as VideoOptions, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.pauseVideoRecording",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.pauseVideoRecording();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.resumeVideoRecording",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.resumeVideoRecording();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.receivedImageFromStream",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.receivedImageFromStream();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.stopRecordingVideo",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        class ResultImp implements Result<boolean> {
                            success(result: boolean): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<boolean> = new ResultImp();

                        api!.stopRecordingVideo(resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.getFrontSensors",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: Array<PigeonSensorTypeDevice> = api!.getFrontSensors();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.getBackSensors",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: Array<PigeonSensorTypeDevice> = api!.getBackSensors();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.start",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: boolean = api!.start();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.stop",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: boolean = api!.stop();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setFlashMode",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setFlashMode(args[0] as string);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.handleAutoFocus",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.handleAutoFocus();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.focusOnPoint",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.focusOnPoint(args[0] as PreviewSize, args[1] as number, args[2] as number,
                                args[3] as AndroidFocusSettings);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setZoom",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setZoom(args[0] as number);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setMirrorFrontCamera",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setMirrorFrontCamera(args[0] as boolean);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setSensor",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setSensor(args[0] as string, args[1] as string);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setCorrection",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setCorrection(args[0] as number);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.getMaxZoom",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: number = api!.getMaxZoom();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setCaptureMode",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setCaptureMode(args[0] as string);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setRecordingAudioMode",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<boolean> {
                            success(result: boolean): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<boolean> = new ResultImp();

                        api!.setRecordingAudioMode(args[0] as boolean, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.availableSizes",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: Array<PreviewSize> = api!.availableSizes();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.refresh",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.refresh();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.getEffectivPreviewSize",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    async onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            let output: PreviewSize = await api!.getEffectivPreviewSize();
                            res.push(output);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setPhotoSize",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setPhotoSize(args[0] as PreviewSize);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setPreviewSize",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setPreviewSize(args[0] as PreviewSize);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setAspectRatio",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setAspectRatio(args[0] as string);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setupImageAnalysisStream",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setupImageAnalysisStream(args[0] as string, args[1] as number, args[2] as number,
                                args[3] as boolean);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setExifPreferences",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<boolean> {
                            success(result: boolean): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<boolean> = new ResultImp();

                        api!.setExifPreferences(args[0] as ExifPreferences, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.startAnalysis",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.startAnalysis();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.stopAnalysis",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let res: Array<Object> = [];
                        try {
                            api!.stopAnalysis();
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger, "dev.flutter.pigeon.camerawesome.CameraInterface.setFilter",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;
                        let res: Array<Object> = [];
                        try {
                            api!.setFilter(args[0] as Array<number>);
                            res.push(null);
                        } catch (error) {
                            let wrappedError: Array<Object> = wrapError(error);
                            res = wrappedError;
                        }
                        reply.reply(res);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
        {
            let channel: BasicMessageChannel<Object> =
                new BasicMessageChannel(
                    binaryMessenger,
                    "dev.flutter.pigeon.camerawesome.CameraInterface.isVideoRecordingAndImageAnalysisSupported",
                    CameraInterface.getCodec());
            if (api != null) {
                channel.setMessageHandler({
                    onMessage(message: Object, reply: Reply<Object>) {
                        let args: Array<Object> = message as Array<Object>;

                        class ResultImp implements Result<boolean> {
                            success(result: boolean): void {
                                let res: Array<Object> = [];
                                res.push(result);
                                reply.reply(res);
                            }

                            error(error: Error): void {
                                let wrappedError: Array<Object> = wrapError(error);
                                reply.reply(wrappedError);
                            }
                        }

                        let resultCallback: Result<boolean> = new ResultImp();

                        api!.isVideoRecordingAndImageAnalysisSupported(args[0] as string, resultCallback);
                    }
                });
            } else {
                channel.setMessageHandler(null);
            }
        }
    }
}
