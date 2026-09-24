/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
 */
 
import image from '@ohos.multimedia.image';

export class SurfaceTextureWrapper {
  private receiver: image.ImageReceiver;
  private released: boolean = false;
  private attached: boolean = false;

  constructor(receiver: image.ImageReceiver) {
    this.receiver = receiver;
  }

  getImageReceiver(): image.ImageReceiver {
    return this.receiver;
  }
}