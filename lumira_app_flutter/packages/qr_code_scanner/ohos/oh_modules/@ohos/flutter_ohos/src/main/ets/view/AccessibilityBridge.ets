/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on AccessibilityBridge.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import AccessibilityChannel, {AccessibilityMessageHandler} from '../embedding/engine/systemchannels/AccessibilityChannel';
import { ByteBuffer } from '../util/ByteBuffer';
import Log from '../util/Log';

const TAG = "AccessibilityBridge";

export default class AccessibilityBridge {
  constructor() {}
}

export class AccessibilityManager {
  private fontWeightScale: number | null = null;

  setFontWeightScale(fontWeightScale: number): void {
    this.fontWeightScale  = fontWeightScale;
    Log.i(TAG, 'setFontWeightScale: ' + JSON.stringify(this.fontWeightScale));
  }

  getFontWeightScale(): number {
    Log.i(TAG, 'getFontWeightScale: ' + JSON.stringify(this.fontWeightScale));
    return this.fontWeightScale!;
  }
}

export enum Action {
  TAP = 1 << 0,
  LONG_PRESS = 1 << 1,
  SCROLL_LEFT = 1 << 2,
  SCROLL_RIGHT = 1 << 3,
  SCROLL_UP = 1 << 4,
  SCROLL_DOWN = 1 << 5,
  INCREASE = 1 << 6,
  DECREASE = 1 << 7,
  SHOW_ON_SCREEN = 1 << 8,
  MOVE_CURSOR_FORWARD_BY_CHARACTER = 1 << 9,
  MOVE_CURSOR_BACKWARD_BY_CHARACTER = 1 << 10,
  SET_SELECTION = 1 << 11,
  COPY = 1 << 12,
  CUT = 1 << 13,
  PASTE = 1 << 14,
  DID_GAIN_ACCESSIBILITY_FOCUS = 1 << 15,
  DID_LOSE_ACCESSIBILITY_FOCUS = 1 << 16,
  CUSTOM_ACTION = 1 << 17,
  DISMISS = 1 << 18,
  MOVE_CURSOR_FORWARD_BY_WORD = 1 << 19,
  MOVE_CURSOR_BACKWARD_BY_WORD = 1 << 20,
  SET_NEXT = 1 << 21,
};