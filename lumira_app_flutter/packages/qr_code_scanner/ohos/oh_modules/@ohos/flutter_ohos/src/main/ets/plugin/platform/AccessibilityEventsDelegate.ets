/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on AccessibilityEventsDelegate.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import AccessibilityBridge from '../../view/AccessibilityBridge';

export class AccessibilityEventsDelegate {
  private accessibilityBridge: AccessibilityBridge | null = null;

  requestSendAccessibilityEvent(accessibilityBridge: AccessibilityBridge): boolean {
    if (accessibilityBridge == null) {
      return false;
    }
    return true;
  }

  onAccessibilityHoverEvent(accessibilityBridge: AccessibilityBridge): boolean {
    if (accessibilityBridge == null) {
      return false;
    }
    return true;
  }

  setAccessibilityBridge (accessibilityBridge: AccessibilityBridge | null): void {
    this.accessibilityBridge = accessibilityBridge;
  }
}