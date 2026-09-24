/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import image from '@ohos.multimedia.image';
import { BusinessError } from '@ohos.base';
import { SurfaceTextureEntry, TextureRegistry } from '../../../view/TextureRegistry';
import { FlutterAbility } from '../../ohos/FlutterAbility';
import FlutterNapi from '../FlutterNapi';
import { SurfaceTextureWrapper } from './SurfaceTextureWrapper';
import Log from '../../../util/Log';

const TAG = "FlutterRenderer"
export class FlutterRenderer implements TextureRegistry {
  private flutterNapi: FlutterNapi;
  private static globalTextureId: number = 0;

  constructor(flutterNapi: FlutterNapi) {
    this.flutterNapi = flutterNapi;
  }

  /**
   * @deprecated since 3.7
   */
  createSurfaceTexture(): SurfaceTextureEntry {
    let receiver: image.ImageReceiver = this.getImageReceiver();
    return this.registerSurfaceTexture(receiver);
  }

  getTextureId(): number {
    let nextTextureId: number = FlutterRenderer.globalTextureId + 1;
    FlutterRenderer.globalTextureId = FlutterRenderer.globalTextureId + 1;
    Log.i(TAG, "getTextureId: " + nextTextureId)
    return nextTextureId;
  }

  registerTexture(textureId: number): SurfaceTextureEntry {
    let surfaceTextureRegistryEntry = new SurfaceTextureRegistryEntry(textureId);
    let surfaceId = this.flutterNapi.registerTexture(textureId);
    Log.i(TAG, "registerTexture, surfaceId=" + surfaceId);
    surfaceTextureRegistryEntry.setSurfaceId(surfaceId);
    return surfaceTextureRegistryEntry;
  }

  /**
   * @deprecated since 3.7
   */
  registerSurfaceTexture(receiver: image.ImageReceiver): SurfaceTextureEntry {
    let nextTextureId: number = FlutterRenderer.globalTextureId + 1;
    FlutterRenderer.globalTextureId = FlutterRenderer.globalTextureId + 1;
    let surfaceTextureRegistryEntry = new SurfaceTextureRegistryEntry(nextTextureId);
    surfaceTextureRegistryEntry.setImageReceiver(receiver);
    this.registerImage(surfaceTextureRegistryEntry.getTextureId(), surfaceTextureRegistryEntry.textureWrapper());
    return surfaceTextureRegistryEntry;
  }

  registerPixelMap(pixelMap: PixelMap): number {
    let nextTextureId: number = this.getTextureId();
    this.flutterNapi.registerPixelMap(nextTextureId, pixelMap);
    return nextTextureId;
  }

  setTextureBackGroundPixelMap(textureId: number, pixelMap: PixelMap): void {
    this.flutterNapi.setTextureBackGroundPixelMap(textureId, pixelMap);
  }

  setTextureBackGroundColor(textureId: number, color: number): void {
    this.flutterNapi.setTextureBackGroundColor(textureId, color);
  }

  setTextureBufferSize(textureId: number, width: number, height: number): void {
    this.flutterNapi.setTextureBufferSize(textureId, width, height);
  }

  notifyTextureResizing(textureId: number, width: number, height: number): void {
    this.flutterNapi.notifyTextureResizing(textureId, width, height);
  }

  unregisterTexture(textureId: number): void {
    this.flutterNapi.unregisterTexture(textureId);
  }
  onTrimMemory(level: number) {
    throw new Error('Method not implemented.');
  }

  /**
   * @deprecated since 3.7
   */
  private getImageReceiver(): image.ImageReceiver {
    let receiver: image.ImageReceiver = image.createImageReceiver(640, 480, 4, 8);
    if (receiver !== undefined) {
      Log.i(TAG, '[camera test] ImageReceiver is ok');
    } else {
      Log.i(TAG, '[camera test] ImageReceiver is not ok');
    }
    return receiver;
  }

  /**
   * @deprecated since 3.7
   */
  private registerImage(textureId: number, surfaceTextureWrapper: SurfaceTextureWrapper): void {
    let receiver = surfaceTextureWrapper.getImageReceiver();
    receiver.on('imageArrival', () => {
      receiver.readNextImage((err: BusinessError, nextImage: image.Image) => {
        if (err || nextImage === undefined) {
          return;
        }
        this.flutterNapi.initNativeImage(textureId, nextImage);
        Log.i(TAG, "[camera test] format: " + nextImage.format);
        nextImage.release((err : BusinessError) =>{
          if (err != undefined) {
            Log.i(TAG, 'Failed to release the image source instance.');
          } else {
            Log.i(TAG, 'Succeeded in releasing the image source instance.');
          }
        });
      })
    })
  }

}

export class SurfaceTextureRegistryEntry implements SurfaceTextureEntry {
  private textureId: number = 0;
  private surfaceId: number = 0;
  private surfaceTextureWrapper: SurfaceTextureWrapper | null = null;
  private released: boolean = false;

  constructor(id: number) {
    this.textureId = id;
  }

  /**
   * @deprecated since 3.7
   */
  getImageReceiver(): image.ImageReceiver {
    return this.surfaceTextureWrapper!.getImageReceiver();
  }

  setImageReceiver(receiver: image.ImageReceiver): void {
    this.surfaceTextureWrapper = new SurfaceTextureWrapper(receiver);
  }

  getTextureId(): number {
    return this.textureId;
  }

  getSurfaceId(): number {
    return this.surfaceId;
  }

  setSurfaceId(surfaceId: number): void {
    this.surfaceId = surfaceId;
  }

  textureWrapper(): SurfaceTextureWrapper {
    return this.surfaceTextureWrapper!;
  }
  release() {
    throw new Error('Method not implemented.');
  }
}