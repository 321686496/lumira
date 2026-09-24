/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on KeyboardManager.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/
import TextInputPlugin from '../../plugin/editing/TextInputPlugin';
import FlutterEngine from '../engine/FlutterEngine';
import KeyEventChannel, { FlutterKeyEvent } from '../engine/systemchannels/KeyEventChannel';
import { KeyEventHandler } from './KeyEventHandler';
import { KeyCode } from '@kit.InputKit';

export default class KeyboardManager {
  private keyEventChannel: KeyEventChannel | null = null
  private keyEventHandler: KeyEventHandler;

  constructor(engine: FlutterEngine, textInputPlugin: TextInputPlugin) {
    this.keyEventChannel = new KeyEventChannel(engine.dartExecutor)
    this.keyEventHandler = new KeyEventHandler(textInputPlugin);
  }

  onKeyPreIme(event: KeyEvent): boolean {
    return false;
  }

  onKeyEvent(event: KeyEvent): boolean {
    this.keyEventChannel?.sendFlutterKeyEvent(new FlutterKeyEvent(event), event.type == KeyType.Up, {
      onFrameworkResponse: (isEventHandled: boolean): void => {
      }
    })
    this.keyEventHandler.handleKeyEvent(event);
    return false;
  }
}