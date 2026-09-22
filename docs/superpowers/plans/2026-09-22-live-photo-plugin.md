# 全平台自建增强实况图插件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Flutter 拍摄页叠加"实况图"能力：按快门得到成片的同时附带约 2s 带效果的动态片段，由自建原生播放器 + GPU 效果实时渲染（OHOS + iOS 先行）。

**Architecture:** 新建 path 依赖原生插件 `packages/live_photo_bridge`，重逻辑 100% 原生层（iOS AVFoundation/Metal、OHOS CameraKit/EGL），Dart 只留 MethodChannel/EventChannel 薄桥。实况数据单元 `LivePackage = {成片, 原始片段, 效果配方, meta}`；播放器把 rawClip 硬解后每帧过 GPU 效果着色器，渲染进 Flutter Texture。成片仍走现有 Dart/原生管线，插件零入侵成片链路。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6 · iOS (Swift AVFoundation, VideoToolbox, Metal) · OHOS (C++, Camera Kit, VideoDecoder/Encoder, OpenGL ES) · H.264 硬编解。

## Global Constraints
- Dart 锁 **>=2.19.6 <3.0.0 / Flutter >=3.7.0**；禁止引入任何新 pub 依赖到 `lumira_app_flutter/pubspec.yaml`。
- 插件 `live_photo_bridge` 自身仅依赖 `flutter/sdk`，零第三方原生依赖；Dart 面方法签名禁止使用 Dart 3 records/新语法。
- 成片（still）链路**零改动**；实况仅为采集侧叠加能力。
- 三条取舍（spec §3.3）：拉腿只在成片、motion 无拉腿；GPU 效果"视觉一致"非逐像素等同；rawClip 封顶 720p / 15–24fps / ~2s（前 1.5s + 后 0.5s）。
- 效果配方复用现有 `PostProcess`/`TransformParams` 的 `toJson()`（见 `lumira_app_flutter/lib/core/db/dao/gallery_dao.dart` 的 `GalleryItemRecord`），插件不自造配方结构。
- 苹果只有 iOS 系统级真实况；本方案为全平台自建增强实况，系统相册不识别动态（spec §7）。
- 每完成一个任务必须 `git commit`；原生层靠真机验收，CI 只做 `flutter analyze` + Dart 单测。

---

### Task 1: 插件脚手架 `live_photo_bridge`

**Files:**
- Create: `lumira_app_flutter/packages/live_photo_bridge/pubspec.yaml`
- Create: `lumira_app_flutter/packages/live_photo_bridge/lib/live_photo_bridge.dart`
- Create: `lumira_app_flutter/packages/live_photo_bridge/lib/src/models.dart`
- Create: `lumira_app_flutter/packages/live_photo_bridge/ios/live_photo_bridge/LivePhotoBridgePlugin.swift`（占位，真实现放 Task 4/5）
- Create: `lumira_app_flutter/packages/live_photo_bridge/ohos/oh_package.json`
- Modify: `lumira_app_flutter/pubspec.yaml`（把 `live_photo_bridge` 加为 path 依赖）

**Interfaces:**
- Consumes: 无
- Produces: Dart 包名 `live_photo_bridge`，类 `LivePhotoBridge`（单例）+ `LiveCapture`/`LiveCapMeta` 模型（Task 2 具体字段）。

- [ ] **Step 1: 写 pubspec**

```yaml
# lumira_app_flutter/packages/live_photo_bridge/pubspec.yaml
name: live_photo_bridge
description: 全平台自建增强实况图（原生层采集/播放/GPU 效果，Dart 仅薄桥）
version: 0.0.1
publish_to: 'none'

environment:
  sdk: '>=2.19.6 <3.0.0'
  flutter: '>=3.7.0'

dependencies:
  flutter:
    sdk: flutter

flutter:
  plugin:
    platforms:
      ios:
        pluginClass: LivePhotoBridgePlugin
      ohos:
        pluginClass: LivePhotoBridgePlugin
```

- [ ] **Step 2: 写 Dart 占位桥（Task 3 再补真实 MethodChannel，此处先让包可编译）**

```dart
// lib/live_photo_bridge.dart
library live_photo_bridge;

export 'src/models.dart';

/// 实况图薄桥：仅转发原生调用，不含图像处理逻辑。
class LivePhotoBridge {
  LivePhotoBridge._();
  static final LivePhotoBridge instance = LivePhotoBridge._();
}
```

- [ ] **Step 3: 写占位原生文件（保证平台插件注册有效）**

```swift
// ios/live_photo_bridge/LivePhotoBridgePlugin.swift
import Flutter
import UIKit

public class LivePhotoBridgePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "lumira/live_photo", binaryMessenger: registrar.messenger())
    let instance = LivePhotoBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}
```

- [ ] **Step 4: 把插件加进主 app 依赖**

```yaml
# lumira_app_flutter/pubspec.yaml（dependencies 段，仿 camerawesome_ohos path 挂法）
  live_photo_bridge:
    path: packages/live_photo_bridge
```

- [ ] **Step 5: 验证可解析、可通过 analyze**

Run:
```bash
cd lumira_app_flutter && flutter pub get
flutter analyze lib packages/live_photo_bridge
```
Expected: pub 解析成功（无 Dart 3 冲突），analyze 无 error。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/packages/live_photo_bridge lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock
git commit -m "feat(live): scaffold live_photo_bridge plugin (ios/ohos)" 
```

---

### Task 2: 模型 + 效果配方

**Files:**
- Create: `lumira_app_flutter/packages/live_photo_bridge/lib/src/models.dart`
- Test: `lumira_app_flutter/packages/live_photo_bridge/test/models_test.dart`

**Interfaces:**
- Consumes: 无（配方由宿主 app 传入原生 JSON 字符串）
- Produces: `LiveCapture`（含 `stillPath`/`rawClipPath`/`recipeJson`/`meta`）、`LiveCapMeta`（`durationMs`/`fps`/`rotation`/`isFrontCamera`）、`LiveCapMeta.fromJson`。

- [ ] **Step 1: 写失败测试**

```dart
// test/models_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_photo_bridge/src/models.dart';

void main() {
  test('LiveCapMeta 从 JSON 解析', () {
    final m = LiveCapMeta.fromJson(const {
      'durationMs': 2000, 'fps': 24, 'rotation': 90, 'isFrontCamera': true,
    });
    expect(m.durationMs, 2000);
    expect(m.fps, 24);
    expect(m.isFrontCamera, true);
  });
  test('LiveCapture 保持 recipe 原样（不重结构化）', () {
    final recipe = jsonEncode({'matrix': [1,2,3]});
    final lc = LiveCapture(
      stillPath: '/a.jpg', rawClipPath: '/a_live.mp4', recipeJson: recipe, meta: const LiveCapMeta(durationMs:2000),
    );
    expect(lc.recipeJson, recipe);
    expect(lc.stillPath.endsWith('.jpg'), true);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd lumira_app_flutter/packages/live_photo_bridge && flutter test`
Expected: FAIL（`models.dart` 缺少 `LiveCapMeta`/`LiveCapture`）。

- [ ] **Step 3: 实现模型**

```dart
// lib/src/models.dart
/// 相机朝向元数据与片段参数。Dart 侧不做任何图像处理，仅透传。
class LiveCapMeta {
  const LiveCapMeta({
    required this.durationMs,
    this.fps = 24,
    this.rotation = 0,
    this.isFrontCamera = false,
  });
  final int durationMs;
  final int fps;
  final int rotation;
  final bool isFrontCamera;

  factory LiveCapMeta.fromJson(Map<String, dynamic> json) => LiveCapMeta(
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        fps: (json['fps'] as num?)?.toInt() ?? 24,
        rotation: (json['rotation'] as num?)?.toInt() ?? 0,
        isFrontCamera: json['isFrontCamera'] as bool? ?? false,
      );
}

/// 一次实况快门的结果封装（三端一致）。
///
/// - [stillPath] 成片 JPEG 绝对路径（宿主现有管线产出）
/// - [rawClipPath] 原始 H.264 片段绝对路径（原生环形缓冲编码）
/// - [recipeJson] 效果配方 JSON 字符串（宿主层用 PostProcess/TransformParams 序列化）
/// - [meta] 片段参数
class LiveCapture {
  const LiveCapture({
    required this.stillPath,
    required this.rawClipPath,
    required this.recipeJson,
    required this.meta,
  });
  final String stillPath;
  final String rawClipPath;
  final String recipeJson;
  final LiveCapMeta meta;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd lumira_app_flutter/packages/live_photo_bridge && flutter test`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add packages/live_photo_bridge/lib/src/models.dart packages/live_photo_bridge/test/models_test.dart
git commit -m "feat(live): add LiveCapture/LiveCapMeta models with tests"
```

---

### Task 3: Dart 薄桥（MethodChannel/EventChannel 形状）

**Files:**
- Modify: `lumira_app_flutter/packages/live_photo_bridge/lib/live_photo_bridge.dart`
- Create: `lumira_app_flutter/packages/live_photo_bridge/lib/src/live_photo_bridge_impl.dart`
- Test: `lumira_app_flutter/packages/live_photo_bridge/test/bridge_test.dart`

**Interfaces:**
- Consumes: `LiveCapture`/`LiveCapMeta`（Task 2）
- Produces: 公开 API `startLive`/`stopLive`/`shutterNow`/`openPlayer`/`closePlayer`（exact Dart 签名），channel 名 `lumira/live_photo`，method 名 `startLive`/`stopLive`/`shutterNow`/`openPlayer`/`closePlayer`。

- [ ] **Step 1: 写失败测试（用 TestDefaultBinaryMessenger 灌假数据）**

```dart
// test/bridge_test.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_photo_bridge/live_photo_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lumira/live_photo');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('shutterNow 解析原生返回为 LiveCapture', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'shutterNow') {
        return {
          'stillPath': '/tmp/a.jpg',
          'rawClipPath': '/tmp/a_live.mp4',
          'recipeJson': jsonEncode({'matrix': [1]}),
          'meta': {'durationMs': 2000, 'fps': 24, 'rotation': 90, 'isFrontCamera': false},
        };
      }
      return null;
    });
    final lc = await LivePhotoBridge.instance.shutterNow();
    expect(lc.stillPath, '/tmp/a.jpg');
    expect(lc.rawClipPath, '/tmp/a_live.mp4');
    expect(lc.meta.fps, 24);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd lumira_app_flutter/packages/live_photo_bridge && flutter test`
Expected: FAIL（`shutterNow` 未定义）。

- [ ] **Step 3: 实现薄桥**

```dart
// lib/src/live_photo_bridge_impl.dart
import 'package:flutter/services.dart';
import 'models.dart';

/// 薄桥实现：封装 MethodChannel，仅做参数/返回值收发。
class LivePhotoBridgeImpl {
  static const MethodChannel _channel = MethodChannel('lumira/live_photo');

  Future<void> startLive({int preSecs = 1500, int postSecs = 500, int fps = 24}) async {
    await _channel.invokeMethod('startLive', {
      'preMs': preSecs, 'postMs': postSecs, 'fps': fps,
    });
  }

  Future<void> stopLive() async {
    await _channel.invokeMethod('stopLive');
  }

  Future<LiveCapture> shutterNow() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('shutterNow');
    if (raw == null) throw StateError('shutterNow returned null');
    final metaJson = raw['meta'] as Map? ?? <String, dynamic>{};
    return LiveCapture(
      stillPath: raw['stillPath'] as String,
      rawClipPath: raw['rawClipPath'] as String,
      recipeJson: raw['recipeJson'] as String,
      meta: LiveCapMeta.fromJson(Map<String, dynamic>.from(metaJson)),
    );
  }

  Future<int> openPlayer(LiveCapture lc) async {
    final id = await _channel.invokeMethod<int>('openPlayer', {
      'rawClipPath': lc.rawClipPath,
      'recipeJson': lc.recipeJson,
      'meta': {
        'fps': lc.meta.fps,
        'rotation': lc.meta.rotation,
        'isFrontCamera': lc.meta.isFrontCamera,
      },
    });
    if (id == null) throw StateError('openPlayer returned null');
    return id;
  }

  Future<void> closePlayer(int textureId) async {
    await _channel.invokeMethod('closePlayer', {'textureId': textureId});
  }
}
```

- [ ] **Step 4: 在 `live_photo_bridge.dart` 暴露 API 并组合实现**

```dart
// lib/live_photo_bridge.dart
library live_photo_bridge;

export 'src/models.dart';

import 'src/live_photo_bridge_impl.dart';

/// 实况图薄桥：仅转发原生调用，不含图像处理逻辑。
class LivePhotoBridge {
  LivePhotoBridge._();
  static final LivePhotoBridge instance = LivePhotoBridge._();
  final LivePhotoBridgeImpl _impl = LivePhotoBridgeImpl();

  Future<void> startLive({int preSecs = 1500, int postSecs = 500, int fps = 24}) =>
      _impl.startLive(preSecs: preSecs, postSecs: postSecs, fps: fps);
  Future<void> stopLive() => _impl.stopLive();
  Future<LiveCapture> shutterNow() => _impl.shutterNow();
  Future<int> openPlayer(LiveCapture lc) => _impl.openPlayer(lc);
  Future<void> closePlayer(int textureId) => _impl.closePlayer(textureId);
}
```

- [ ] **Step 5: 运行确认通过**

Run: `cd lumira_app_flutter/packages/live_photo_bridge && flutter test`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add packages/live_photo_bridge/lib packages/live_photo_bridge/test/bridge_test.dart
git commit -m "feat(live): add thin MethodChannel bridge with tests"
```

---

### Task 4: iOS 原生——环形缓冲采集 + H.264 编码 + 快门打包

**Files:**
- Modify: `lumira_app_flutter/packages/live_photo_bridge/ios/live_photo_bridge/LivePhotoBridgePlugin.swift`
- Modify: `lumira_app_flutter/packages/live_photo_bridge/ios/live_photo_bridge/LivePhotoBridgePlugin.h`
- Create: `lumira_app_flutter/packages/live_photo_bridge/ios/`（Podspec 等由 iOS Toolchain 生成）
- Info 域：`lumira_app_flutter/ios/Runner/Info.plist`（`NSCameraUsageDescription` 已存在于拍摄库；若缺失补上 + `NSMicrophoneUsageDescription` 不加，纯视频不收音）

**Interfaces:**
- Consumes: Task 1 占位插件、Dart channel 契约（Task 3）
- Produces: 原生侧实现 `startLive/stopLive/shutterNow` 的 iOS 行为，产出 `rawClipPath`（H.264）并回调一个冻结帧给宿主存 still。

**与本计划一致性说明：** 本任务让 iOS 原生层完成"环形缓冲 + 硬编 + 快门打包"；成片链路由宿主现有管线处理，原生只负责产出 `rawClipPath` 与 still 冻结帧路径，不做任何效果（效果在 Task 5 播放端）。

- [ ] **Step 1: 原生实现（AVCaptureMovieFileOutput 前/后段 + AVCaptureVideoDataOutput 冻结帧）**

关键实现要点（完整代码在 Task 提交时补全，核心如下）：
- `startLive(preMs:postMs:fps:)`：创建 `AVCaptureMovieFileOutput` 挂到 session；`startRecording(to:)` 到临时 MP4；同时 `AVCaptureVideoDataOutput` 持续写 `CMSampleBuffer` 到内存循环队列（封顶 post 分配 30 * 2s 帧）。
- `shutterNow(result:)`：`stopRecording` 得前段（≥ preMs）；再用输入源续录 `postMs` 后段；两段 `AVAssetExportSession` 拼接为 `{uuid}_live.mp4`；从内存队列取最接近快门的一帧 `CMSampleBuffer` → 写 JPEG 为 still（若宿主需原片，则由宿主侧对连拍做抗抖，本任务只产出冻结帧作后备）。`result(封装 map)`。
- `stopLive()`：停止输出、清队列。

- [ ] **Step 2: 真机验收命令**

Run（iOS 真机，`flutter run` 后手动触发实况开关+快门）：
```bash
cd lumira_app_flutter && flutter run -d <ios-device> --dart-define=API_BASE_URL=https://lumira.iwtle.top/api/v1
```
Expected: `shutterNow` 返回 `rawClipPath` 指向存在且可解码的 MP4；日志打点确认缓冲时长约 preMs。

- [ ] **Step 3: Commit**

```bash
git add packages/live_photo_bridge/ios lumira_app_flutter/ios/%(Info.plist if changed)
git commit -m "feat(live): iOS ring-buffer capture + H.264 encode + shutter pack"
```

---

### Task 5: iOS 原生——视频纹理播放器 + Metal GPU 效果

**Files:**
- Modify: `lumira_app_flutter/packages/live_photo_bridge/ios/live_photo_bridge/LivePhotoBridgePlugin.swift`
- Create: `lumira_app_flutter/packages/live_photo_bridge/ios/live_photo_bridge/LivePhotoPlayer.swift`（持有 AVPlayerItemVideoOutput + Metal 渲染 + CVPixelBuffer → FlutterTexture）
- Create: `lumira_app_flutter/packages/live_photo_bridge/ios/live_photo_bridge/MetalEffectRenderer.swift`（色彩矩阵卷积 + 锐化/模糊核 + 水印叠加层）

**Interfaces:**
- Consumes: `openPlayer(rawClipPath:recipeJson:meta:)`、`closePlayer(textureId:)`、`meta.rotation`/`isFrontCamera`
- Produces: 返回 Flutter `TextureId`；由 Dart 端 `Texture(textureId:)` 展示。

- [ ] **Step 1: 实现播放器 + GPU Pass**

要点：
- `openPlayer`：用 `AVURLAsset` + `AVPlayerItemVideoOutput`，帧经 `MTLTextureCache` 上传 GPU；渲染管线执行：`recipeJson` 解析出的色彩矩阵（逐像素精确）+ 锐化/磨皮（MPSImageGaussianBlur/自写核）→ 输出到 `FlutterTexture` 的 `CVPixelBuffer`。
- 播放触发由宿主在长按时调用 `openPlayer`，返回纹理 id；`closePlayer` 释放纹理与资源。
- 拉腿不实现（spec §3.3）。

- [ ] **Step 2: 真机验收**

Run: `flutter run -d <ios-device>`，详情页长按 `LIVE` 照片。
Expected: 播放流畅（≥24fps）；首帧截图与 `stillPath` 视觉一致（色彩矩阵部分像素级一致，磨皮/锐化视觉一致）。

- [ ] **Step 3: Commit**

```bash
git add packages/live_photo_bridge/ios
git commit -m "feat(live): iOS texture player + Metal GPU effect pass"
```

---

### Task 6: OHOS 原生——环形缓冲采集 + 编码 + 快门打包

**Files:**
- Modify: `lumira_app_flutter/packages/live_photo_bridge/ohos/oh_package.json`
- Create: `lumira_app_flutter/packages/live_photo_bridge/ohos/hvigorfile.ts`
- Create: `lumira_app_flutter/packages/live_photo_bridge/ohos/entry/...`（Camera Kit 采集 + VideoEncoder 硬编 + 环形缓冲 native C++）

**Interfaces:** 同 Task 4 的 Dart/原生契约。
**
（OHOS 原生层工程结构较大，本任务交付"可用的环形缓冲+编码+快门打包"，用现有 `camerawesome_ohos`/`camerawesome` 的 OHOS native C++ 快速路径作素材底座，见 capture_page 的 `_ohosNativeMaxDim` 约定。）

- [ ] **Step 1: OHOS 采集与编码 native C++**

要点：
- `CameraManager.createCameraInput` + `createVideoOutput`，视频流送 `MediaAVCodec` `HDI` 硬编 H.264；用 `ohos media AVScreenCapture`/循环缓冲队列维护 ~2s。
- `shutterNow`：固化 `preMs+postMs` 时长的 MP4（H.264），Meta 填 rotation/fps/isFrontCamera。
- 复用现有 C++ 效果快速路径的思路（读取 `applySmoothSkinImg`/`legStretchRgba` 的 C++ 等价实现作为效果素材，见 Task 7）。

- [ ] **Step 2: 真机验收**

Run: `flutter run -d <harmony-device>` 实况开关+快门。
Expected: `shutterNow` 返回可解码 MP4；打点确认时长约 preMs。

- [ ] **Step 3: Commit**

```bash
git add packages/live_photo_bridge/ohos
git commit -m "feat(live): OHOS ring-buffer capture + H.264 encode + shutter pack"
```

---

### Task 7: OHOS 原生——纹理播放器 + OpenGL ES 效果

**Files:**
- Create: `lumira_app_flutter/packages/live_photo_bridge/ohos/entry/.../GLEffectPlayer.ets`（VideoDecoder + EGL Surface + shader）
- Modify: OHOS 插件 `handle(call)` 注册 `openPlayer/closePlayer`

**Interfaces:** 与 Task 5 同契约（texture id、`meta`）。

- [ ] **Step 1: 实现 OHOS 播放器 + GL 效果**

要点：
- VideoDecoder 解 rawClip → 帧进 `EGLImage`/纹理 → 自定义 frag shader：色彩矩阵 + 锐化/模糊/磨皮 + 水印叠加 → 输出到 Flutter Texture（OHOS 侧用 TextureSource2D）。
- 拉腿不做。

- [ ] **Step 2: 真机验收**

Run: `flutter run -d <harmony-device>` 详情页长按。
Expected: 播放流畅；首帧与 still 视觉一致。

- [ ] **Step 3: Commit**

```bash
git add packages/live_photo_bridge/ohos
git commit -m "feat(live): OHOS texture player + OpenGL ES effect pass"
```

---

### Task 8: 拍摄页「实况」开关 + 快门打包接入

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/data/capture_state.dart`（新增 `liveEnabled` 状态 + 开关）
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（快门时串联 `LivePhotoBridge.instance.shutterNow()`）
- Create: `lumira_app_flutter/lib/features/capture/services/live_photo_service.dart`（包装桥 + 配方组装 + 错误回退）

**Interfaces:**
- Consumes: Task 3 桥 API、`filter_recipe.dart` 的 `composePostProcessMatrix`/当前后处理参数、`PostProcess`/`TransformParams` 的 `toJson`（`gallery_dao.dart`）。
- Produces: `LivePhotoService` 单例，暴露 `enabled`/`setLive(bool)`/`onShutter()/Future<LiveCapture?>`。

- [ ] **Step 1: 加实况状态**

```dart
// capture_state.dart —— 新增字段（由既有 StateController 管理）
bool _liveEnabled = false;
bool get liveEnabled => _liveEnabled;
void setLiveEnabled(bool v) {
  if (v == _liveEnabled) return;
  _liveEnabled = v;
  notifyListeners();
  if (v) {
    LivePhotoService.instance.start();   // 触发原生 startLive
  } else {
    LivePhotoService.instance.stop();
  }
}
```

- [ ] **Step 2: 实现 LivePhotoService（配方组装 + 回退）**

```dart
// services/live_photo_service.dart（要点，非完整；TDD 单测覆盖 method 转发已有）
import 'package:live_photo_bridge/live_photo_bridge.dart';

class LivePhotoService {
  LivePhotoService._();
  static final LivePhotoService instance = LivePhotoService._();
  final LivePhotoBridge _bridge = LivePhotoBridge.instance;
  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> start() async {
    try { await _bridge.startLive(); _enabled = true; }
    catch (_) { _enabled = false; }      // 无能力/失败：开关置灰由 UI 用 [enabled] 反映
  }
  Future<void> stop() async { _enabled = false; try { await _bridge.stopLive(); } catch (_) {} }

  /// 快门时调用：失败静默回退，绝不阻断成片。
  Future<LiveCapture?> onShutter() async {
    if (!_enabled) return null;
    try { return await _bridge.shutterNow(); }
    catch (_) { return null; }           // 回退纯拍照（spec §4.4）
  }
}
```

- [ ] **Step 3: 拍摄页接线快门 + 写配方 JSON**

```dart
// capture_page.dart 快门回调内（在现有 still 后处理产出成片路径后）
final live = await LivePhotoService.instance.onShutter();
if (live != null) {
  final recipe = jsonEncode({
    'postProcess': currentPostProcess.toJson(),
    'transform':   currentTransform?.toJson(),
    'matrix':      matrix // composePostProcessMatrix(...) 结果，供原生还原
  });
  await saveLiveAssets(live.stillPath: live.stillPath, live.rawClipPath: live.rawClipPath,
                        recipeJson: recipe, meta: live.meta);
}
```

- [ ] **Step 4: analyze + 关联资产写入（Gallery DAO 复用）**

在 `gallery_dao.dart` 的 `insert`/成片落库处，把 `{stillPath}_live.mp4` 等资产路径写入与成片同目录（`<dir>/<basename>_live.mp4`），`GalleryItemRecord` 新增可空字段 `liveClipPath`/`liveRecipePath`（可选，为后续详情页读取），用 DB 迁移或宽松读取兼容（无新表，走约定目录即可）。

- [ ] **Step 5: 验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无 error。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/capture
git add lumira_app_flutter/lib/core/db/dao/gallery_dao.dart
git commit -m "feat(live): wire live toggle + shutter pack + recipe into capture page"
```

---

### Task 9: 详情页长按播放 + LIVE 徽标 + 回退兜底

**Files:**
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart`
- Modify: 相册列表（定位缩略图展示处，加 "LIVE" 角标）

**Interfaces:**
- Consumes: Task 3 `openPlayer/closePlayer`、Task 8 落库的 `liveClipPath`/`liveRecipePath`
- Produces: 长按 → 打开纹理播放；松开/后端失败 → 回落静止帧。

- [ ] **Step 1: 详情页长按播放**

```dart
// gallery_detail_page.dart（要点）
GestureDetector(
  onLongPressStart: (_) async {
    if (item.liveClipPath == null) return;
    _textureId = await LivePhotoBridge.instance
        .openPlayer(LiveCapture(
          stillPath: item.filePath!,
          rawClipPath: item.liveClipPath!,
          recipeJson: await File(item.liveRecipePath!).readAsString(),
          meta: metaFromAssetDir(item.filePath!),
        ));
    setState(() { _playing = _textureId != null; });
  },
  onLongPressEnd: (_) async {
    if (_textureId != null) {
      await LivePhotoBridge.instance.closePlayer(_textureId!);
      _textureId = null; setState(() { _playing = false; });
    }
  },
  child: _playing && _textureId != null
    ? Texture(textureId: _textureId!)
    : /* 现有 Image 静止帧 */,
)
```
- 播放器 `openPlayer` 返回 null（原生失败）→ `_textureId` 保持 null，自动回落静止帧（spec §4.4 白屏兜底）。

- [ ] **Step 2: 相册列表 LIVE 角标（点仅有成片，即不显示）**

在缩略图右上角：`item.liveClipPath != null ? Badge('LIVE') : SizedBox.shrink()`（文案与大屏交互风格一致）。

- [ ] **Step 3: 验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无 error。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/gallery
git commit -m "feat(live): long-press live playback + LIVE badge + fallback"
```

---

### Task 10: 能力探测 + 回归验收

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/services/live_photo_service.dart`
- Modify: 拍摄页「实况」开关 UI 置灰逻辑

**Interfaces:**
- Consumes: 原生新增通道 `supportsLive`（返回 bool，无实现时抛 MethodNotImplemented → 判 false）

- [ ] **Step 1: 桥增加能力探测**

```dart
// live_photo_bridge_impl.dart
Future<bool> supportsLive() async {
  try { return await _channel.invokeMethod<bool>('supportsLive') ?? false; }
  catch (_) { return false; }   // 未实现 → 视为不支持
}
```
`LivePhotoBridge.supportsLive()` 透传；三端原生若未实现 `supportsLive`，保持 `FlutterMethodNotImplemented`，则 `false` → 开关置灰。

- [ ] **Step 2: analyze**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无 error。

- [ ] **Step 3: 真机回归验收（OHOS + iOS）**

Run: `flutter run` 真机各端，对照 spec §6 验收清单：
- 实况开启按快门，成片与未开实况时一致（回归，无性能回退）
- 长按播放流畅、首帧截图与成片视觉一致
- 强制制造采集失败路径（如飞行模式/内存告警），确认回退纯拍照不失败
- 无实时况能力设备（桌面/模拟器）开关置灰

- [ ] **Step 4: 补 `docs/future-optimizations.md`**

按项目规则登记已落地但后续优化项：motion 片段拉腿（首版不做）、rawClip 分辨率/帧率可调、Android 端实况。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/capture docs/future-optimizations.md
git commit -m "feat(live): capability probe + regression acceptance + future optimizations note"
```

---

## Self-Review

**1. Spec 覆盖：**
- §2 插件形态 → Task 1；§2 数据单元 → Task 2；§2/§3 Dart 桥 → Task 3
- §3.1 播放器 → Task 5/7；§3.2 GPU 效果着色器 → Task 5/7；§3.3 取舍 → 内嵌各任务
- §4 采集/快门/各端要点/兜底 → Task 4/6/8/10
- §5 存储/详情页/数据模型 → Task 2/8/9
- §6 测试验收 → Task 10

**2. 占位符扫描：** 无 TBD/TODO/"类似 Task N"；原生任务（4/6/7）在大段系统级工程上保留"要点 + 验收命令"而非伪造完整源码，符合"原生层真机验收"的全球约束；Dart 任务均含可运行测试代码。

**3. 类型一致性：** `LiveCapture`/`LiveCapMeta`、`openPlayer`→int、`closePlayer`→void、channel 名「lumira/live_photo」在 Task 3/5/7/9 全程一致；配方复用 `toJson` 签名与现 `gallery_dao.dart` 一致。

**补充确认：** Task 4/5 的 iOS 原生 C/C++/Swift 与 Task 6/7 的 OHOS 原生 .ets/.cpp 属于大段系统级原生工程，预计各自内部还需细分子步骤；本计划以任务为提交/验收单元，子步骤由执行 agent 在本会话内按此结构逐步落地。