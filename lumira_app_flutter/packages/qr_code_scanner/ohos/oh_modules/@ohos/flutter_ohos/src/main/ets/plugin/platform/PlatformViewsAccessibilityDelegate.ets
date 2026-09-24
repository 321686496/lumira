/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on PlatformViewsAccessibilityDelegate.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import AccessibilityBridge from '../../view/AccessibilityBridge';

export interface PlatformViewsAccessibilityDelegate {
  /**
   * Returns the root of the view hierarchy for the platform view with the requested id, or null if
   * there is no corresponding view.
   */
  getPlatformViewById(viewId: number): Object;

  /** Returns true if the platform view uses virtual displays. */
  usesVirtualDisplay(id: number): boolean;

  /**
   * Attaches an accessibility bridge for this platform views accessibility delegate.
   *
   * <p>Accessibility events originating in platform views belonging to this delegate will be
   * delegated to this accessibility bridge.
   */
  attachAccessibilityBridge(accessibilityBridge: AccessibilityBridge): void;

  /**
   * Detaches the current accessibility bridge.
   *
   * <p>Any accessibility events sent by platform views belonging to this delegate will be ignored
   * until a new accessibility bridge is attached.
   */
  detachAccessibilityBridge(): void;
}