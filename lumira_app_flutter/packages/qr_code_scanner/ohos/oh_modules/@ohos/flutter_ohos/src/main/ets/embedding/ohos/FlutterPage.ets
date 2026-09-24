/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import Log from '../../util/Log';
import { FlutterView } from '../../view/FlutterView';
import FlutterManager from './FlutterManager';
import { DVModel, DVModelChildren, DynamicView } from '../../view/DynamicView/dynamicView';
import deviceInfo from '@ohos.deviceInfo';
import flutter from 'libflutter.so';

const TAG = "FlutterPage";

export const OHOS_FLUTTER_PAGE_UPDATE = "ohos_flutter_page_update";

/**
 * 基础page组件，承载XComponent组件
 */
@Component
export struct FlutterPage {
  @Prop safeAreaEdges: SafeAreaEdge[] | undefined = [];
  @Prop safeAreaTypes: SafeAreaType[] | undefined = [];
  @Prop viewId: string = ""
  @Prop xComponentType: XComponentType = XComponentType.SURFACE
  onFocusListener?: () => void | undefined;
  onBlurListener?: () => void | undefined;
  isFocusFlag: boolean = false;
  defaultFocusOnTouch = false;

  @Builder
  doNothingBuilder() {
  }

  @BuilderParam splashScreenView: () => void = this.doNothingBuilder;

  @Builder
  defaultPage() {
    Stack() {
      ForEach(this.rootDvModel!!, (child: ESObject) => {
        DynamicView({
          model: child as DVModel,
          params: child.params,
          events: child.events,
          children: child.children,
          customBuilder: child.builder
        })
      }, (child: ESObject) => `${child.id_}`)


      Text('')
        .id('emptyFocusText' + this.viewId)
        .size({ width: 0, height: 0 })
        .opacity(0)
        .focusable(true)

      XComponent({ id: this.viewId, type: this.xComponentType, libraryname: 'flutter' })
        .id(this.viewId)
        .focusable(true)
        .focusOnTouch(this.defaultFocusOnTouch)
        .onLoad((context) => {
          this.flutterView?.onSurfaceCreated()
          if (deviceInfo.sdkApiVersion < 15) {
            this.getUIContext()?.getAttachedFrameNodeById(this.viewId)?.commonEvent.setOnVisibleAreaApproximateChange(
              { ratios: [0.0, 1.0], expectedUpdateInterval: 0 },
              (isExpanding: boolean, currentRatio: number) => {
                if (isExpanding) {
                  Log.i(TAG, "setOnVisibleAreaApproximateChange -> xcomponentId: " + this.viewId +
                    " isExpanding: " + isExpanding + " ratio: " + currentRatio);
                  flutter.nativeUpdateCurrentXComponentId(this.viewId);
                }
              }
            )
          }
          Log.d(TAG, "XComponent onLoad ");
        })
        .onDestroy(() => {
          Log.d(TAG, "XComponent onDestroy ");
          this.flutterView?.onSurfaceDestroyed()
        })
        .renderFit(RenderFit.TOP_LEFT)
        .backgroundColor(Color.Transparent)
        .expandSafeArea(this.safeAreaTypes, this.safeAreaEdges)

      if (this.showSplashScreen) {
        this.splashScreenView();
      }
    }
    .defaultFocus(true)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      if (this.isNeedUpdate || !this.lastArea || oldValue.width != newValue.width
        || oldValue.height != newValue.height) {
        Log.d(TAG, "onAreaChange, old=" + JSON.stringify(oldValue));
        Log.d(TAG, "onAreaChange, new=" + JSON.stringify(newValue));
        this.lastArea = newValue;
        this.flutterView?.onAreaChange(newValue)
        this.isNeedUpdate = false;
      }
    })
    .onKeyPreIme((event: KeyEvent) => {
      return this.flutterView?.onKeyPreIme(event) ?? false;
    })
    .onKeyEvent((event: KeyEvent) => {
      return this.flutterView?.onKeyEvent(event) ?? false;
    })
    .onDragEnter((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragEnterCbs().forEach(dragEnterCb => {
        dragEnterCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragEnter");
    })
    .onDragMove((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragMoveCbs().forEach(dragMoveCb => {
        dragMoveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragMove");
    })
    .onDragLeave((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragLeaveCbs().forEach(dragLeaveCb => {
        dragLeaveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragLeave");
    })
    .onDrop((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDropCbs().forEach(dropCb => {
        dropCb.do(event, extraParams);
      });
      Log.d(TAG, "onDrop");
    })
    .onFocus(() => {
      Log.d(TAG, "onFocus");
      this.onFocusListener?.();
      this.isFocusFlag = true;
    })
    .onBlur(() => {
      Log.d(TAG, "onBlur");
      this.onBlurListener?.();
      this.isFocusFlag = false;
    })
  }

  @Builder
  mouseWheelPage() {
    Stack() {
      ForEach(this.rootDvModel!!, (child: ESObject) => {
        DynamicView({
          model: child as DVModel,
          params: child.params,
          events: child.events,
          children: child.children,
          customBuilder: child.builder
        })
      }, (child: ESObject) => `${child.id_}`)


      Text('')
        .id('emptyFocusText' + this.viewId)
        .size({ width: 0, height: 0 })
        .opacity(0)
        .focusable(true)

      XComponent({ id: this.viewId, type: this.xComponentType, libraryname: 'flutter' })
        .id(this.viewId)
        .focusable(true)
        .focusOnTouch(this.defaultFocusOnTouch)
        .onLoad((context) => {
          this.flutterView?.onSurfaceCreated()
          if (deviceInfo.sdkApiVersion < 15) {
            this.getUIContext()?.getAttachedFrameNodeById(this.viewId)?.commonEvent.setOnVisibleAreaApproximateChange(
              { ratios: [0.0, 1.0], expectedUpdateInterval: 0 },
              (isExpanding: boolean, currentRatio: number) => {
                if (isExpanding) {
                  Log.i(TAG, "setOnVisibleAreaApproximateChange -> xcomponentId: " + this.viewId +
                    " isExpanding: " + isExpanding + " ratio: " + currentRatio);
                  flutter.nativeUpdateCurrentXComponentId(this.viewId);
                }
              }
            )
          }
          Log.d(TAG, "XComponent onLoad ");
        })
        .onDestroy(() => {
          Log.d(TAG, "XComponent onDestroy ");
          this.flutterView?.onSurfaceDestroyed()
        })
        .renderFit(RenderFit.TOP_LEFT)
        .backgroundColor(Color.Transparent)
        .expandSafeArea(this.safeAreaTypes, this.safeAreaEdges)

      if (this.showSplashScreen) {
        this.splashScreenView();
      }
    }
    .defaultFocus(true)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      if (this.isNeedUpdate || !this.lastArea || oldValue.width != newValue.width
        || oldValue.height != newValue.height) {
        Log.d(TAG, "onAreaChange, old=" + JSON.stringify(oldValue));
        Log.d(TAG, "onAreaChange, new=" + JSON.stringify(newValue));
        this.lastArea = newValue;
        this.flutterView?.onAreaChange(newValue)
        this.isNeedUpdate = false;
      }
    })
    .onKeyPreIme((event: KeyEvent) => {
      return this.flutterView?.onKeyPreIme(event) ?? false;
    })
    .onKeyEvent((event: KeyEvent) => {
      return this.flutterView?.onKeyEvent(event) ?? false;
    })
    .onDragEnter((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragEnterCbs().forEach(dragEnterCb => {
        dragEnterCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragEnter");
    })
    .onDragMove((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragMoveCbs().forEach(dragMoveCb => {
        dragMoveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragMove");
    })
    .onDragLeave((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragLeaveCbs().forEach(dragLeaveCb => {
        dragLeaveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragLeave");
    })
    .onDrop((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDropCbs().forEach(dropCb => {
        dropCb.do(event, extraParams);
      });
      Log.d(TAG, "onDrop");
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionStart", event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionUpdate", event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionEnd", event);
        })
    )
    .onFocus(() => {
      Log.d(TAG, "onFocus");
      this.onFocusListener?.();
      this.isFocusFlag = true;
    })
    .onBlur(() => {
      Log.d(TAG, "onBlur");
      this.onBlurListener?.();
      this.isFocusFlag = false;
    })
  }

  public isFocused(): boolean {
    return this.isFocusFlag;
  }

  @State showSplashScreen: boolean = true;
  @State checkFullScreen: boolean = true;
  @State checkKeyboard: boolean = true;
  @State checkGesture: boolean = true;
  @State checkMouseWheel: boolean = true;
  @State checkAiBar: boolean = true;
  @Prop @Watch("onPaddingChange") paddingTop?: number = undefined;
  @StorageLink('nodeWidth') storageLinkWidth: number = 0;
  @StorageLink('nodeHeight') storageLinkHeight: number = 0;
  @State rootDvModel: DVModelChildren | undefined = undefined
  @State isNeedUpdate: boolean = false;
  private flutterView?: FlutterView | null
  private lastArea?: Area;
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Up | PanDirection.Down });

  aboutToAppear() {
    this.flutterView = FlutterManager.getInstance().getFlutterView(this.viewId);
    if (!this.flutterView) {
      Log.e(TAG, "getFlutterView failed. viewId is " + this.viewId.toString());
    }
    this.flutterView?.addFirstFrameListener(this)

    this.flutterView?.setCheckFullScreen(this.checkFullScreen)
    this.flutterView?.setCheckKeyboard(this.checkKeyboard)
    this.flutterView?.setCheckGesture(this.checkGesture)
    this.flutterView?.setPaddingTop(this.paddingTop)
    this.flutterView?.setCheckAiBar(this.checkAiBar)

    this.rootDvModel = this.flutterView?.getDVModel().children
    getContext().eventHub.on(OHOS_FLUTTER_PAGE_UPDATE, () => {
      this.isNeedUpdate = true;
    })
  }

  aboutToDisappear() {
    this.flutterView?.removeFirstFrameListener(this);
    getContext()?.eventHub.off(OHOS_FLUTTER_PAGE_UPDATE)
  }

  onFirstFrame() {
    this.showSplashScreen = false;
  }

  build() {
    if (this.checkMouseWheel) {
      this.mouseWheelPage();
    } else {
      this.defaultPage();
    }
  }

  onPaddingChange() {
    this.flutterView?.setPaddingTop(this.paddingTop);
  }
}
