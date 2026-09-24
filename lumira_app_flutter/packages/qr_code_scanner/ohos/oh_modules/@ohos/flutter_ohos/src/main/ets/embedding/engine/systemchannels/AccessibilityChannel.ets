/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on AccessibilityChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import BasicMessageChannel, { MessageHandler, Reply} from '../../../plugin/common/BasicMessageChannel';
import HashMap from '@ohos.util.HashMap';
import FlutterNapi, {AccessibilityDelegate} from '../FlutterNapi';
import { Action } from '../../../view/AccessibilityBridge'
import StandardMessageCodec from '../../../plugin/common/StandardMessageCodec';
import StringUtils from '../../../util/StringUtils';
import Any from '../../../plugin/common/Any';
import flutter from 'libflutter.so';
import { ByteBuffer } from '../../../util/ByteBuffer';

/**
* 辅助功能channel
*/
export default class AccessibilityChannel implements MessageHandler<object>{
    private static TAG = "AccessibilityChannel";
    private static CHANNEL_NAME = "flutter/accessibility";
    private channel: BasicMessageChannel<object>;
    private flutterNapi: FlutterNapi;
    private handler: AccessibilityMessageHandler;
    private nextReplyId: number = 1;

    onMessage(message: object, reply: Reply<object>): void {
        if (this.handler == null) {
            Log.i(AccessibilityChannel.TAG, "handler = NULL");
            reply.reply(StringUtils.stringToArrayBuffer(""));
            return;
        }
        let annotatedEvent: HashMap<string, Any> = message as HashMap<string, Any>;
        let type: string = annotatedEvent.get("type") as string;
        let data: HashMap<string, Any> = annotatedEvent.get("data") as HashMap<string, Any>;

        Log.i(AccessibilityChannel.TAG, "Received " + type + " message.");
        switch (type) {
            case "announce": {
                Log.i(AccessibilityChannel.TAG, "Announce");
                let announceMessage: string = data.get("message");
                if (announceMessage != null) {
                    Log.i(AccessibilityChannel.TAG, "message is " + announceMessage);
                    this.handler.announce(announceMessage);
                }
                break;
            }
            case "tap": {
              Log.i(AccessibilityChannel.TAG, "Tag");
              let nodeId: number = annotatedEvent.get("nodeId");
                if (nodeId != null) {
                  this.handler.onTap(nodeId);
                }
                break;
            }
            case "longPress": {
                Log.i(AccessibilityChannel.TAG, "LongPress");
                let nodeId: number = annotatedEvent.get("nodeId");
                if (nodeId != null) {
                    this.handler.onLongPress(nodeId);
                }
                break;
            }
            case "tooltip": {
                Log.i(AccessibilityChannel.TAG, "ToolTip");
                let tooltipMessage: string = data.get("message");
                if (tooltipMessage != null) {
                    this.handler.onTooltip(tooltipMessage);
                }
                break;
            }
        }
        reply.reply(StringUtils.stringToArrayBuffer(""));
    }

    constructor(dartExecutor: DartExecutor, flutterNapi: FlutterNapi) {
        Log.i(AccessibilityChannel.TAG, "Channel entered");
        this.channel = new BasicMessageChannel<object>(dartExecutor, AccessibilityChannel.CHANNEL_NAME, StandardMessageCodec.INSTANCE);
        this.channel.setMessageHandler(this);
        this.flutterNapi = flutterNapi;
        this.handler = new DefaultHandler(this.flutterNapi);
    }

    onOhosAccessibilityEnabled(): void {
        let replyId: number = this.nextReplyId++;
        this.flutterNapi.setSemanticsEnabledWithRespId(true, replyId);
        Log.i(AccessibilityChannel.TAG, "onOhosAccessibilityEnabled = true");
    }

    onOhosAccessibilityFeatures(accessibilityFeatureFlags: number): void {
        let replyId: number = this.nextReplyId++;
        this.flutterNapi.setAccessibilityFeatures(accessibilityFeatureFlags, replyId);
        Log.i(AccessibilityChannel.TAG, "onOhosAccessibilityFeatures");
    }

    dispatchSemanticsAction(virtualViewId: number, action: Action): void {
        let replyId: number = this.nextReplyId++;
        this.flutterNapi.dispatchSemanticsAction(virtualViewId, action, replyId);
        Log.i(AccessibilityChannel.TAG, "dispatchSemanticsAction");
    }

    setAccessibilityMessageHandler(handler: AccessibilityMessageHandler): void {
      this.handler = handler;
      let replyId: number = this.nextReplyId++;
      this.flutterNapi.setAccessibilityDelegate(handler, replyId);
    }

}

export interface AccessibilityMessageHandler extends AccessibilityDelegate {
    announce(message: string): void;
    onTap(nodeId: number): void;
    onLongPress(nodeId: number): void;
    onTooltip(message: string): void;
}

export class DefaultHandler implements AccessibilityMessageHandler {
  private static TAG = "AccessibilityMessageHandler";
  private flutterNapi: FlutterNapi;

  constructor(flutterNapi: FlutterNapi) {
    this.flutterNapi = flutterNapi;
  }

  announce(message: string): void {
    Log.i(DefaultHandler.TAG,  "handler announce.");
    flutter.nativeAccessibilityAnnounce(this.flutterNapi.nativeShellHolderId!, message);
  }

  onTap(nodeId: number): void {
    Log.i(DefaultHandler.TAG,  "handler onTap.");
    flutter.nativeAccessibilityOnTap(this.flutterNapi.nativeShellHolderId!, nodeId);
  }

  onLongPress(nodeId: number): void {
    Log.i(DefaultHandler.TAG,  "handler onLongPress.");
    flutter.nativeAccessibilityOnLongPress(this.flutterNapi.nativeShellHolderId!, nodeId);
  }

  onTooltip(message: string): void {
    Log.i(DefaultHandler.TAG,  "handler onTooltip.");
    flutter.nativeAccessibilityOnTooltip(this.flutterNapi.nativeShellHolderId!, message);
  }

  accessibilityStateChange(state: Boolean): void{
    Log.i(DefaultHandler.TAG,  "handler accessibilityStateChange");
  }
}