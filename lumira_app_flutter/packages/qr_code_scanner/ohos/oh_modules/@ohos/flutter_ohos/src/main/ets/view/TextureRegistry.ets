/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TextureRegistry.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import image from '@ohos.multimedia.image';

export interface TextureRegistry {

  createSurfaceTexture(): SurfaceTextureEntry;
  getTextureId(): number;
  registerTexture(textureId: number): SurfaceTextureEntry;
  registerSurfaceTexture(receiver: image.ImageReceiver): SurfaceTextureEntry;
  registerPixelMap(pixelMap: PixelMap): number;
  setTextureBackGroundPixelMap(textureId: number, pixelMap: PixelMap): void;
  setTextureBackGroundColor(textureId: number, color: number): void;
  setTextureBufferSize(textureId: number, width: number, height: number): void;
  unregisterTexture(textureId: number): void;
  onTrimMemory(level: number) : void;
  notifyTextureResizing(textureId: number, width: number, height: number): void;
}

export interface SurfaceTextureEntry {
  getTextureId(): number;

  getSurfaceId(): number;

  getImageReceiver(): image.ImageReceiver;

  release(): void;
}

export interface OnFrameConsumedListener {
  onFrameConsumed(): void;
}

export interface OnTrimMemoryListener {
  onTrimMemory(level: number) : void;
}