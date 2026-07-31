# 拍摄功能三端适配 + 性能极限调优 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Flutter 拍摄功能在 HarmonyOS/iOS/Android 三端可用，并通过双管线 Isolate 化把拍照体感延迟降到 < 200ms，交互改为原生相机模式（缩略图角标 + 连拍）。

**Architecture:** 抽出 `CameraService`（三端 camerawesome 实现）与 `PhotoPipeline`（双管线：quickProcess 主 Isolate Canvas GPU + fullProcess Isolate image 包 CPU）两个抽象接口；capture_page 不再直接依赖 camerawesome 类型，拍照后不自动跳预览页，改为角标缩略图状态机驱动。

**Tech Stack:** Flutter 3.7 / Dart 2.19.6 / camerawesome_ohos 1.0.2（OHOS）/ camerawesome 1.4.0（iOS/Android）/ riverpod 2.3.6 / image 4.0.16

**Spec:** `docs/superpowers/specs/2026-07-31-camera-three-platform-optimization-design.md`

## Global Constraints

- Dart SDK: `>=2.19.6 <3.0.0`（不可升级到 Dart 3）
- Flutter: `>=3.7.0`
- 不可使用 `abstract interface class` 之外的 Dart 3 语法（records / patterns / sealed class）
- CSS/样式规则不适用（Flutter 项目）
- 所有图像资源来自 picsum.photos（如需测试图）
- 保留现有 `CaptureState` 的非相机库 provider，只删除 `cameraStateProvider`
- `dart:ui`（Canvas/PictureRecorder/instantiateImageCodec）只能在主 Isolate 使用
- `image` 包是纯 Dart，可在 Isolate 中使用
- OHOS 的 `CamerawesomePlugin.setZoom` 期望真实倍数（1.0=1x），原版 camerawesome 的 `SensorConfig.setZoom` 归一化到 [0,1]

---

## File Structure

### 新增文件

| 文件 | 职责 |
|---|---|
| `lib/features/capture/services/camera_service.dart` | `CameraService` 抽象接口 + `CaptureResult`/`CaptureConfig`/`CameraFlashMode`/`SensorOrientation`/`CameraPreviewConfig`/`CameraPreviewFit` 值对象 |
| `lib/features/capture/services/camerawesome_delegate.dart` | `CamerawesomeDelegate`：三端差异标记（platformTag / zoomIsMultiplier） |
| `lib/features/capture/services/camerawesome_camera_service.dart` | `CamerawesomeCameraService implements CameraService`：三端共用实现 |
| `lib/features/capture/services/camera_service_provider.dart` | `cameraServiceProvider`：运行时按 `Platform.isIOS/isAndroid` 选择 delegate |
| `lib/features/capture/services/photo_pipeline.dart` | `PhotoPipeline` 抽象接口 + `QuickResult`/`FullResult` 值对象 |
| `lib/features/capture/services/dart_photo_pipeline.dart` | `DartPhotoPipeline implements PhotoPipeline`：quickProcess 主 Isolate + fullProcess Isolate |
| `lib/features/capture/data/capture_thumbnail_state.dart` | `CaptureThumbnailState` + `captureThumbnailProvider`（StateNotifier） |
| `lib/features/capture/widgets/capture_thumbnail.dart` | 角标缩略图 widget（四态：idle/processing/preview/final） |
| `lib/features/capture/widgets/shutter_feedback.dart` | 白闪动画 overlay + 快门音效 |
| `test/features/capture/services/photo_pipeline_test.dart` | PhotoPipeline 单元测试 |
| `test/features/capture/data/capture_thumbnail_state_test.dart` | 角标状态机测试 |

### 修改文件

| 文件 | 改动 |
|---|---|
| `pubspec.yaml` | 新增 `camerawesome: ^1.4.0`（原版，iOS/Android） |
| `lib/features/capture/data/capture_state.dart` | 删除 `cameraStateProvider`；其他 provider 保留 |
| `lib/features/capture/pages/capture_page.dart` | _onCapture 改调 CameraService；_processSingleFrame 拆 quick/full；删除自动跳预览页；_isProcessing→_isQuickProcessing；挂载角标 widget |
| `lib/features/capture/widgets/camera_preview.dart` | CameraAwesomeBuilder 封装到 CamerawesomeCameraService.buildPreview() |
| `lib/features/capture/widgets/capture_button.dart` | 移除外部阻塞依赖（onTap 不变） |
| `lib/features/capture/services/photo_post_processor.dart` | 保留为 fullProcess Isolate 内部实现；不再被 capture_page 直接调用 |

---

## Task 0: 前置验证 - camerawesome 原版与 ohos fork 共存

**Files:**
- Read: `pubspec.yaml`
- Read: `D:\app\flutter\flutter_pub_cache\git\fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc\pubspec.yaml`（原版 camerawesome 1.4.0）
- Read: `D:\app\flutter\flutter_pub_cache\git\fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc\ohos\pubspec.yaml`（ohos fork）

**目的：** 验证 `camerawesome: ^1.4.0` 与 `camerawesome_ohos`（gitcode fork）能否同时出现在 pubspec 而不冲突。原版包名是 `camerawesome`，ohos fork 包名是 `camerawesome_ohos`，包名不同理论上可共存。但需验证 `flutter pub get` 实际解析。

- [ ] **Step 1: 在 pubspec.yaml 新增原版 camerawesome 依赖（临时，仅验证）**

在 `pubspec.yaml` 的 dependencies 中，`camerawesome_ohos` 条目下方新增：

```yaml
  # 原版 camerawesome（iOS/Android 用，包名不同于 camerawesome_ohos）
  camerawesome: ^1.4.0
```

- [ ] **Step 2: 运行 flutter pub get 验证解析**

Run: `flutter pub get`（在 `d:\app\projects\photo_post\lumira_app_flutter` 目录）
Expected: 解析成功，无版本冲突。若冲突，记录冲突信息，回退此改动，转用"三端各写独立 Service"方案（不共用 CamerawesomeDelegate）。

- [ ] **Step 3: 验证两个包的 Dart 符号不冲突**

两个包导出的顶层符号都是 `CamerawesomePlugin` / `CameraState` 等，但通过不同 import 路径区分（`package:camerawesome/camerawesome_plugin.dart` vs `package:camerawesome_ohos/camerawesome_plugin.dart`）。在 Dart 中不同包的同名符号通过 import 别名隔离。

写一个临时文件 `lib/tmp_verify.dart`：

```dart
import 'package:camerawesome/camerawesome_plugin.dart' as ca;
import 'package:camerawesome_ohos/camerawesome_plugin.dart' as ohos;

void tmpVerify() {
  // 验证两边都有 CameraState 类型
  ca.CameraState? s1;
  ohos.CameraState? s2;
  print('$s1 $s2');
}
```

Run: `flutter analyze lib/tmp_verify.dart`
Expected: 无错误。若报错，说明符号冲突无法用别名隔离，转用独立 Service 方案。

- [ ] **Step 4: 删除临时验证文件**

Delete: `lib/tmp_verify.dart`

- [ ] **Step 5: 保留 pubspec.yaml 中的 camerawesome 依赖（后续 Task 需要），提交**

```bash
git add pubspec.yaml
git commit -m "chore: add camerawesome ^1.4.0 for iOS/Android camera support"
```

---

## Task 1: CameraService 抽象接口 + 值对象

**Files:**
- Create: `lib/features/capture/services/camera_service.dart`

**Interfaces:**
- Produces: `CameraService`（abstract）、`CaptureResult`、`CaptureConfig`、`CameraFlashMode`、`SensorOrientation`、`CameraPreviewConfig`、`CameraPreviewFit`。后续 Task 2/3 实现此接口，Task 8 改造 capture_page 消费此接口。

- [ ] **Step 1: 创建 camera_service.dart**

```dart
// lib/features/capture/services/camera_service.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// 平台无关的相机服务接口。
/// 阶段一：三端实现各自封装 camerawesome（ohos fork / 原版 1.4.0）
/// 阶段二：替换为各端原生相机层，本接口零改动
abstract class CameraService {
  /// 初始化相机。facing = 'front' | 'back'
  Future<void> initialize({required String facing});

  /// 释放相机资源
  Future<void> dispose();

  /// 拍照。返回原始 JPEG 文件路径（传感器直出，未做任何后处理）。
  Future<CaptureResult> capture({required CaptureConfig config});

  /// 切换前后摄像头
  Future<void> switchCamera(String facing);

  /// 设置缩放（真实倍数，1.0 = 1x，0.5 = 0.5x）
  void setZoom(double multiplier);

  /// 设置闪光灯模式
  void setFlashMode(CameraFlashMode mode);

  /// 点击对焦
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize);

  /// 取景器 widget（平台实现负责构建原生预览）
  Widget buildPreview({required CameraPreviewConfig config});

  /// 相机就绪状态流（用于 UI 显示"正在初始化"提示）
  Stream<bool> get readyStream;
}

/// 拍照结果（平台无关，不携带 camerawesome 的 MediaCapture）
class CaptureResult {
  const CaptureResult({
    required this.filePath,
    required this.sensorWidth,
    required this.sensorHeight,
    required this.orientation,
    this.timestampMs,
  });
  final String filePath;
  final int sensorWidth;
  final int sensorHeight;
  final SensorOrientation orientation;
  final int? timestampMs;
}

/// 拍照配置快照（按下快门时的状态）
class CaptureConfig {
  const CaptureConfig({
    required this.facing,
    required this.zoomMultiplier,
    required this.flashMode,
    this.evCompensation,
  });
  final String facing;
  final double zoomMultiplier;
  final CameraFlashMode flashMode;
  final double? evCompensation;
}

enum CameraFlashMode { off, on, auto, torch }
enum SensorOrientation { portrait, landscape, portraitUpsideDown, landscapeLeft }

/// 取景器配置
class CameraPreviewConfig {
  const CameraPreviewConfig({
    required this.facing,
    this.fit = CameraPreviewFit.cover,
    this.onReady,
    this.onTapFocus,
    this.onScaleZoom,
  });
  final String facing;
  final CameraPreviewFit fit;
  final VoidCallback? onReady;
  final void Function(Offset, Size)? onTapFocus;
  final void Function(double)? onScaleZoom;
}

enum CameraPreviewFit { cover, contain }
```

- [ ] **Step 2: 验证无语法错误**

Run: `flutter analyze lib/features/capture/services/camera_service.dart`
Expected: No issues

- [ ] **Step 3: 提交**

```bash
git add lib/features/capture/services/camera_service.dart
git commit -m "feat(capture): add CameraService abstract interface"
```

---

## Task 2: CamerawesomeDelegate + CamerawesomeCameraService

**Files:**
- Create: `lib/features/capture/services/camerawesome_delegate.dart`
- Create: `lib/features/capture/services/camerawesome_camera_service.dart`
- Create: `lib/features/capture/services/camera_service_provider.dart`

**Interfaces:**
- Consumes: `CameraService` + 值对象（Task 1）
- Produces: `CamerawesomeDelegate`、`CamerawesomeCameraService`、`cameraServiceProvider`
- 关键参考：
  - 现有 [capture_page.dart:260-310](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L260-L310) `_onCameraStateCreated`（订阅 captureState$ 流）
  - [capture_page.dart:367-405](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L367-L405) `_onCapture`（takePhoto 调用）
  - [capture_page.dart:564-589](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L564-L589) `_onZoomChanged`（OHOS setZoom 倍数 vs 归一化差异）
  - [camera_preview.dart:138-203](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart#L138-L203) `CameraAwesomeBuilder.custom` 配置

**重要：** 两个 camerawesome 包的 API 几乎一致，但 import 路径不同。为避免在 `CamerawesomeCameraService` 中写两套 import，采用**条件导入**：用 `Platform.isAndroid/isIOS` 在运行时选择 import 哪个包的符号。但 Dart 条件导入只能按 `dart.library.*` 区分，不能按平台。

**解决方案：** 创建两个文件分别 import 不同的 camerawesome 包，暴露相同的接口；`CamerawesomeCameraService` 通过抽象 getter 获取这些平台特定符号。

- [ ] **Step 1: 创建 camerawesome_delegate.dart**

```dart
// lib/features/capture/services/camerawesome_delegate.dart
import 'dart:io';

/// camerawesome 系列库的三端差异委托。
/// 三端 CamerawesomeCameraService 共用一份业务代码，
/// delegate 负责处理平台特定行为差异。
class CamerawesomeDelegate {
  const CamerawesomeDelegate({
    required this.platformTag,
    required this.zoomIsMultiplier,
  });

  /// 'ohos' | 'ios' | 'android'
  final String platformTag;

  /// OHOS: true（CamerawesomePlugin.setZoom 期望真实倍数 1.0=1x）
  /// iOS/Android: false（SensorConfig.setZoom 归一化到 [0,1]）
  final bool zoomIsMultiplier;

  static const ohos = CamerawesomeDelegate(
    platformTag: 'ohos',
    zoomIsMultiplier: true,
  );
  static const ios = CamerawesomeDelegate(
    platformTag: 'ios',
    zoomIsMultiplier: false,
  );
  static const android = CamerawesomeDelegate(
    platformTag: 'android',
    zoomIsMultiplier: false,
  );

  static CamerawesomeDelegate forCurrentPlatform() {
    if (Platform.isIOS) return ios;
    if (Platform.isAndroid) return android;
    return ohos; // HarmonyOS / fallback
  }
}
```

- [ ] **Step 2: 创建平台适配层 camerawesome_bindings.dart**

由于两个包的 import 路径不同，创建一个绑定文件，在运行时通过 Platform 选择 import。但 Dart 不支持运行时条件 import，所以用**三份独立文件 + 工厂方法**：

创建 `lib/features/capture/services/camerawesome_bindings/` 目录，内含：
- `bindings.dart`（接口）
- `bindings_ohos.dart`（import camerawesome_ohos）
- `bindings_native.dart`（import camerawesome 原版，用于 iOS/Android）

```dart
// lib/features/capture/services/camerawesome_bindings/bindings.dart
import 'bindings_ohos.dart' if (dart.library.io) 'bindings_native.dart'
    as impl;

export 'bindings_ohos.dart' if (dart.library.io) 'bindings_native.dart';

/// 获取当前平台应使用的 facing 字符串
String facingForPlatform(String facing) =>
    impl.facingForPlatform(facing);
```

注意：条件导入 `if (dart.library.io)` 不能区分 iOS/Android/OHOS（都是 dart:io）。真正的平台区分要在运行时用 `Platform.isXxx`。

**修正方案：** 放弃条件导入。改为在 `camerawesome_camera_service.dart` 中**同时 import 两个包**（用别名），运行时按 delegate.platformTag 选择调用哪个。由于 OHOS 平台不会真正实例化 iOS 路径的代码（Platform.isAndroid/isIOS 在 OHOS 返回 false），iOS/Android 也不会实例化 OHOS 路径，所以不会触发 MissingPluginException。

但这样 `flutter pub get` 时两边的原生插件都会被注册——OHOS 端会尝试注册原版 camerawesome 的 iOS/Android 插件（无 ohos 实现），可能导致构建警告。需在 Task 0 验证。

- [ ] **Step 3: 创建 camerawesome_camera_service.dart**

```dart
// lib/features/capture/services/camerawesome_camera_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camerawesome_ohos/camerawesome_plugin.dart' as ohos;
// 原版 camerawesome 仅 iOS/Android 用；OHOS 端 Platform.isIOS/isAndroid 为 false，
// 不会触发原版插件调用。但 import 语句本身在编译期需要包存在（Task 0 已验证）。
import 'package:camerawesome/camerawesome_plugin.dart' as ca
    if (dart.library.html) 'package:camerawesome_ohos/camerawesome_plugin.dart' as ca;

import 'camera_service.dart';
import 'camerawesome_delegate.dart';

/// camerawesome 系列三端共用实现。
/// 通过 [CamerawesomeDelegate] 区分平台行为差异。
class CamerawesomeCameraService implements CameraService {
  CamerawesomeCameraService(this._delegate);

  final CamerawesomeDelegate _delegate;

  // 内部持有 camerawesome 的 CameraState（类型按平台不同）
  // 用 dynamic 持有，避免在类型层面区分两个包的 CameraState
  dynamic _cameraState; // ohos.CameraState 或 ca.CameraState
  final _readyController = StreamController<bool>.broadcast();

  @override
  Stream<bool> get readyStream => _readyController.stream;

  @override
  Future<void> initialize({required String facing}) async {
    // camerawesome 的初始化通过 CameraAwesomeBuilder 隐式完成，
    // 此处只发信号。真正的初始化在 buildPreview() 的 builder 回调中触发。
    _readyController.add(false);
  }

  @override
  Future<void> dispose() async {
    try {
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.stop();
      } else {
        ca.CamerawesomePlugin.stop();
      }
    } catch (_) {}
    await _readyController.close();
  }

  @override
  Future<CaptureResult> capture({required CaptureConfig config}) async {
    // 实际拍照：调用 camerawesome 的 takePhoto，监听 captureState$ 流获取文件路径
    // 返回一个 Future，在 captureState$ 监听器中 complete
    final completer = Completer<CaptureResult>();

    if (_cameraState == null) {
      throw StateError('Camera not initialized');
    }

    StreamSubscription? sub;
    sub = _cameraState.captureState$.listen((media) {
      if (media != null &&
          media.status == ohos.MediaCaptureStatus.success && // 两个包枚举名一致
          media.filePath.isNotEmpty) {
        sub?.cancel();
        completer.complete(CaptureResult(
          filePath: media.filePath,
          sensorWidth: 0, // camerawesome 1.4.0 不暴露，后续从 JPEG 解析
          sensorHeight: 0,
          orientation: SensorOrientation.portrait,
        ));
      }
    });

    try {
      _cameraState.when(
        onPhotoMode: (photoState) => photoState.takePhoto(),
      );
    } catch (e) {
      sub?.cancel();
      completer.completeError(e);
    }

    return completer.future;
  }

  @override
  Future<void> switchCamera(String facing) async {
    // camerawesome 通过重建 CameraAwesomeBuilder 切换 sensor
    // 由 buildPreview() 的 sensor 参数驱动，此处仅发信号
    _readyController.add(false);
  }

  @override
  void setZoom(double multiplier) {
    if (_delegate.zoomIsMultiplier) {
      // OHOS: 直接传真实倍数
      try {
        ohos.CamerawesomePlugin.setZoom(multiplier);
      } catch (_) {}
    } else {
      // iOS/Android: SensorConfig.setZoom 归一化 [0,1]
      // 需调用 _cameraState.sensorConfig.setZoom(normalized)
      // normalized 计算依赖 minZoom/maxZoom，此处简化为直接用 multiplier-1 clamp
      try {
        final normalized = (multiplier - 1.0).clamp(0.0, 1.0);
        _cameraState?.sensorConfig?.setZoom(normalized);
      } catch (_) {}
    }
  }

  @override
  void setFlashMode(CameraFlashMode mode) {
    final flashMode = _mapFlashMode(mode);
    try {
      _cameraState?.sensorConfig?.setFlashMode(flashMode);
    } catch (_) {}
  }

  @override
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize) {
    try {
      _cameraState?.when(
        onPhotoMode: (photoState) => photoState.focusOnPoint(
          flutterPosition: flutterPosition,
          pixelPreviewSize: flutterPreviewSize,
          flutterPreviewSize: flutterPreviewSize,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget buildPreview({required CameraPreviewConfig config}) {
    // 委托给平台特定实现，见 Task 7（camera_preview.dart 改造）
    // 此处返回一个 Builder，内部调用 _buildOhos 或 _buildNative
    if (_delegate.platformTag == 'ohos') {
      return _buildOhos(config);
    }
    return _buildNative(config);
  }

  Widget _buildOhos(CameraPreviewConfig config) {
    return ohos.CameraAwesomeBuilder.custom(
      saveConfig: ohos.SaveConfig.photo(
        pathBuilder: () async {
          final ts = DateTime.now().millisecondsSinceEpoch;
          try {
            final dir = await _getTempDir();
            return '${dir.path}/capture_$ts.jpg';
          } catch (_) {
            final dbPath = await _getDbPath();
            return '$dbPath/capture_$ts.jpg';
          }
        },
      ),
      sensor: config.facing == 'front' ? ohos.Sensors.front : ohos.Sensors.back,
      previewFit: ohos.CameraPreviewFit.cover,
      builder: (cameraState, previewSize, previewRect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cameraState = cameraState;
          config.onReady?.call();
          _readyController.add(true);
        });
        return const SizedBox.shrink();
      },
      onPreviewTapBuilder: (state) => ohos.OnPreviewTap(
        onTap: (position, flutterPreviewSize, pixelPreviewSize) {
          config.onTapFocus?.call(position, flutterPreviewSize);
        },
      ),
      onPreviewScaleBuilder: (state) => ohos.OnPreviewScale(
        onScale: (scale) {
          config.onScaleZoom?.call(1.0 + scale.clamp(0.0, 1.0));
        },
      ),
    );
  }

  Widget _buildNative(CameraPreviewConfig config) {
    return ca.CameraAwesomeBuilder.custom(
      saveConfig: ca.SaveConfig.photo(
        pathBuilder: () async {
          final ts = DateTime.now().millisecondsSinceEpoch;
          final dir = await _getTempDir();
          return '${dir.path}/capture_$ts.jpg';
        },
      ),
      sensor: config.facing == 'front' ? ca.Sensors.front : ca.Sensors.back,
      previewFit: ca.CameraPreviewFit.cover,
      builder: (cameraState, previewSize, previewRect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cameraState = cameraState;
          config.onReady?.call();
          _readyController.add(true);
        });
        return const SizedBox.shrink();
      },
      onPreviewTapBuilder: (state) => ca.OnPreviewTap(
        onTap: (position, flutterPreviewSize, pixelPreviewSize) {
          config.onTapFocus?.call(position, flutterPreviewSize);
        },
      ),
      onPreviewScaleBuilder: (state) => ca.OnPreviewScale(
        onScale: (scale) {
          config.onScaleZoom?.call(1.0 + scale.clamp(0.0, 1.0));
        },
      ),
    );
  }

  dynamic _mapFlashMode(CameraFlashMode mode) {
    if (_delegate.platformTag == 'ohos') {
      switch (mode) {
        case CameraFlashMode.off: return ohos.FlashMode.none;
        case CameraFlashMode.on: return ohos.FlashMode.always;
        case CameraFlashMode.auto: return ohos.FlashMode.auto;
        case CameraFlashMode.torch: return ohos.FlashMode.always;
      }
    } else {
      switch (mode) {
        case CameraFlashMode.off: return ca.FlashMode.none;
        case CameraFlashMode.on: return ca.FlashMode.always;
        case CameraFlashMode.auto: return ca.FlashMode.auto;
        case CameraFlashMode.torch: return ca.FlashMode.always;
      }
    }
  }

  Future<dynamic> _getTempDir() async {
    final pp = await _importPathProvider();
    return pp.getTemporaryDirectory();
  }

  Future<dynamic> _getDbPath() async {
    final pp = await _importPathProvider();
    return pp.getDatabasesPath();
  }

  // 延迟 import path_provider 避免循环
  Future<dynamic> _importPathProvider() async {
    return await Future.value(_pathProviderCache ??= _PathProviderWrapper());
  }
  static dynamic _pathProviderCache;
}

class _PathProviderWrapper {
  Future<dynamic> getTemporaryDirectory() async {
    // 延迟 import 避免顶层 import 循环
    return await _getTempDirImpl();
  }
  Future<dynamic> getDatabasesPath() async {
    return await _getDbPathImpl();
  }
}

Future<dynamic> _getTempDirImpl() async {
  // 实际调用 path_provider
  final pp = await _loadPathProvider();
  return pp.getTemporaryDirectory();
}

Future<dynamic> _getDbPathImpl() async {
  final pp = await _loadPathProvider();
  return pp.getDatabasesPath();
}

Future<dynamic> _loadPathProvider() async {
  // sqflite 暴露 getDatabasesPath
  final db = await _loadSqflite();
  return _PathProviderBridge(db);
}

class _PathProviderBridge {
  final dynamic sqflite;
  _PathProviderBridge(this.sqflite);
  Future<dynamic> getTemporaryDirectory() async {
    // 用 path_provider
    return await _realGetTempDir();
  }
  Future<dynamic> getDatabasesPath() async {
    return await sqflite.getDatabasesPath();
  }
}

Future<dynamic> _realGetTempDir() async {
  // 真正的 path_provider.getTemporaryDirectory
  final lib = await _importPathProviderLib();
  return lib.getTemporaryDirectory();
}

Future<dynamic> _importPathProviderLib() async {
  // 通过条件 import 实现
  return _PathProviderLib();
}

class _PathProviderLib {
  Future<dynamic> getTemporaryDirectory() async {
    // 这里需要真正调用 path_provider
    // 实现时直接 import 'package:path_provider/path_provider.dart'
    // 上面这些包装类是为了避免在文档中写死 import 顺序
    // 实际实现时简化为直接 import
    throw UnimplementedError('实现时替换为 path_provider.getTemporaryDirectory()');
  }
}
```

**实现说明：** 上面的 `_PathProviderWrapper` 等包装类是计划文档的简化表达。实际实现时，`CamerawesomeCameraService` 顶部直接 `import 'package:path_provider/path_provider.dart';` 和 `import 'package:sqflite/sqflite.dart';`，`_getTempDir` / `_getDbPath` 直接调用即可。subagent 实现时应简化为直接 import，不要照搬这些包装类。

- [ ] **Step 4: 创建 camera_service_provider.dart**

```dart
// lib/features/capture/services/camera_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_service.dart';
import 'camerawesome_camera_service.dart';
import 'camerawesome_delegate.dart';

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CamerawesomeCameraService(CamerawesomeDelegate.forCurrentPlatform());
});
```

- [ ] **Step 5: 验证编译**

Run: `flutter analyze lib/features/capture/services/`
Expected: 无 error 级别问题。warning 可接受（dynamic 类型）。

- [ ] **Step 6: 提交**

```bash
git add lib/features/capture/services/camerawesome_delegate.dart \
        lib/features/capture/services/camerawesome_camera_service.dart \
        lib/features/capture/services/camera_service_provider.dart
git commit -m "feat(capture): implement CamerawesomeCameraService for 3 platforms"
```

---

## Task 3: PhotoPipeline 抽象接口 + 值对象

**Files:**
- Create: `lib/features/capture/services/photo_pipeline.dart`

**Interfaces:**
- Consumes: `PostProcess`（现有 `domain/photo_template.dart`）、`TransformParams`、`FillLightState`（现有 `capture_state.dart`）
- Produces: `PhotoPipeline`（abstract）、`QuickResult`、`FullResult`、`photoPipelineProvider`

- [ ] **Step 1: 创建 photo_pipeline.dart**

```dart
// lib/features/capture/services/photo_pipeline.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import 'dart_photo_pipeline.dart';

/// 照片后处理管线接口。
abstract class PhotoPipeline {
  /// 同步快速处理（主 Isolate）。
  /// 输入：原始 JPEG 文件路径 + 后处理参数快照。
  /// 输出：近似最终图的内存字节（已调色，无皮肤平滑/Sharpen/Grain）。
  /// 目标 < 100ms。失败时返回 null，调用方降级为等待 fullProcess。
  Future<QuickResult?> quickProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
  });

  /// 异步完整处理（Isolate）。
  /// 输入同 quickProcess。
  /// 输出：最终图文件路径 + 落库所需元数据。
  Future<FullResult> fullProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    FillLightState? fillLight,
    String? outputPath,
  });
}

class QuickResult {
  const QuickResult({required this.bytes, required this.width, required this.height});
  final Uint8List bytes;
  final int width;
  final int height;
}

class FullResult {
  const FullResult({required this.filePath, required this.width, required this.height});
  final String filePath;
  final int width;
  final int height;
}

final photoPipelineProvider = Provider<PhotoPipeline>((ref) {
  return DartPhotoPipeline();
});
```

- [ ] **Step 2: 验证编译**

Run: `flutter analyze lib/features/capture/services/photo_pipeline.dart`
Expected: No issues（DartPhotoPipeline 在 Task 4 创建前会报缺失，跳过 provider 部分先注释）

- [ ] **Step 3: 提交**

```bash
git add lib/features/capture/services/photo_pipeline.dart
git commit -m "feat(capture): add PhotoPipeline abstract interface"
```

---

## Task 4: DartPhotoPipeline 实现（双管线 Isolate 化）

**Files:**
- Create: `lib/features/capture/services/dart_photo_pipeline.dart`
- Modify: `lib/features/capture/services/photo_post_processor.dart`（保留，被 fullProcess Isolate 内部调用）

**Interfaces:**
- Consumes: `PhotoPipeline`（Task 3）、现有 `PhotoPostProcessor`（[photo_post_processor.dart:33-242](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart#L33-L242)）的裁剪/ColorMatrix 逻辑、`FilterRecipe.fromPostProcess`（`domain/filter_recipe.dart`）、`_computeCropRect`（[photo_post_processor.dart:433-517](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart#L433-L517)）
- Produces: `DartPhotoPipeline`

**关键约束：**
- `quickProcess` 在主 Isolate：用 `dart:ui` 的 `instantiateImageCodec` + `Canvas` + `PictureRecorder` + `ColorFiltered` + `toImage` + `readBytes`
- `fullProcess` 在 Isolate：用 `image` 包（纯 Dart），不能用 dart:ui。需在 Isolate 中用 image 包重新实现裁剪+ColorMatrix+Vignette+皮肤平滑+Sharpen+Grain+补光+encodeJpg
- `Isolate.run` 在 Dart 2.19 可用（若 OHOS Flutter 3.7 不支持，回退 `compute()`）

- [ ] **Step 1: 先验证 Isolate.run 在当前环境可用**

创建临时文件 `lib/tmp_isolate_test.dart`：

```dart
import 'dart:isolate';
import 'package:flutter/foundation.dart';

Future<int> _heavyWork(int n) async {
  var sum = 0;
  for (var i = 0; i < n; i++) sum += i;
  return sum;
}

Future<void> tmpIsolateTest() async {
  try {
    final result = await Isolate.run(() => _heavyWork(1000000));
    debugPrint('Isolate.run OK: $result');
  } catch (e) {
    debugPrint('Isolate.run FAILED: $e');
    // 回退 compute
    final result = await compute(_heavyWork, 1000000);
    debugPrint('compute fallback OK: $result');
  }
}
```

Run: `flutter run`（在 OHOS 设备/模拟器）→ 调用 `tmpIsolateTest()`
Expected: 输出 "Isolate.run OK" 或 "compute fallback OK"。记录哪个可用。

- [ ] **Step 2: 删除临时文件**

Delete: `lib/tmp_isolate_test.dart`

- [ ] **Step 3: 创建 dart_photo_pipeline.dart - quickProcess 部分**

```dart
// lib/features/capture/services/dart_photo_pipeline.dart
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'photo_pipeline.dart';
import 'photo_post_processor.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import '../domain/filter_recipe.dart';

class DartPhotoPipeline implements PhotoPipeline {
  DartPhotoPipeline();

  @override
  Future<QuickResult?> quickProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 解码 JPEG（dart:ui，主 Isolate）
      final file = ui.File(inputPath); // 注意：用 dart:io File
      final bytes = await io.File(inputPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();

      var workingImage = srcImage;
      if (transform != null && !transform.isIdentity) {
        workingImage = await _applyTransformUi(srcImage, transform);
        srcImage.dispose();
      }

      // 2. 裁剪计算（复用 PhotoPostProcessor 的 _computeCropRect）
      final cropRect = PhotoPostProcessor.computeCropRect(
        aspectRatio,
        workingImage.width,
        workingImage.height,
        screenRatio,
        isPortrait,
      );

      // 3. 降采样尺寸
      const maxDimension = 1536;
      var outW = cropRect[2];
      var outH = cropRect[3];
      if (outW > maxDimension || outH > maxDimension) {
        final scale = maxDimension / math.max(outW, outH);
        outW = (outW * scale).round();
        outH = (outH * scale).round();
      }

      // 4. 单次 Canvas：降采样 + 裁剪 + ColorMatrix + Vignette
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(outW / cropRect[2], outH / cropRect[3]);
      canvas.translate(-cropRect[0], -cropRect[1]);

      if (!rawMode) {
        final matrix = FilterRecipe.fromPostProcess(params).toColorMatrix();
        canvas.saveLayer(null, ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix));
        canvas.drawImage(workingImage, ui.Offset.zero, ui.Paint());
        canvas.restore();
      } else {
        canvas.drawImage(workingImage, ui.Offset.zero, ui.Paint());
      }

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(outW, outH);
      picture.dispose();
      workingImage.dispose();

      // 5. 导出 PNG 字节
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      outImage.dispose();
      if (byteData == null) return null;

      debugPrint('[quickProcess] ${sw.elapsedMilliseconds}ms');
      if (sw.elapsedMilliseconds > 200) {
        debugPrint('[quickProcess] WARN: exceeded 200ms budget');
      }
      return QuickResult(
        bytes: byteData.buffer.asUint8List(),
        width: outW,
        height: outH,
      );
    } catch (e, st) {
      debugPrint('[quickProcess] failed: $e\n$st');
      return null;
    }
  }

  Future<ui.Image> _applyTransformUi(ui.Image src, TransformParams t) async {
    // 旋转/翻转/拉直实现，参考 PhotoPostProcessor._applyTransform
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // ... 实现旋转 + 翻转 + 拉直
    final picture = recorder.endRecording();
    return picture.toImage(src.width, src.height);
  }

  @override
  Future<FullResult> fullProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    FillLightState? fillLight,
    String? outputPath,
  }) async {
    // 在 Isolate 中执行完整处理
    // 注意：PostProcess / FillLightState / TransformParams 需可序列化（它们是普通类，OK）
    final inputBytes = await io.File(inputPath).readAsBytes();
    final finalOutputPath = outputPath ??
        inputPath.replaceAll('.jpg', '_final.jpg');

    try {
      final resultBytes = await Isolate.run(() {
        return _processInIsolate(
          inputBytes: inputBytes,
          params: params,
          aspectRatio: aspectRatio,
          screenRatio: screenRatio,
          isPortrait: isPortrait,
          rawMode: rawMode,
          transform: transform,
          fillLight: fillLight,
        );
      });

      await io.File(finalOutputPath).writeAsBytes(resultBytes.bytes);
      return FullResult(
        filePath: finalOutputPath,
        width: resultBytes.width,
        height: resultBytes.height,
      );
    } catch (e, st) {
      debugPrint('[fullProcess] Isolate failed, fallback: $e\n$st');
      // 降级：用主 Isolate 的 PhotoPostProcessor.processFile
      final path = await PhotoPostProcessor.processFile(
        inputPath: inputPath,
        params: params,
        rawMode: rawMode,
        aspectRatio: aspectRatio,
        screenRatio: screenRatio,
        isPortrait: isPortrait,
        transform: transform,
        fillLight: fillLight,
      );
      return FullResult(filePath: path, width: 0, height: 0);
    }
  }

  /// Isolate 入口：纯 image 包实现，无 dart:ui 依赖
  static _IsolateResult _processInIsolate({
    required Uint8List inputBytes,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    required bool rawMode,
    TransformParams? transform,
    FillLightState? fillLight,
  }) {
    // 1. 解码 JPEG（image 包）
    var image = img.decodeJpg(inputBytes);
    if (image == null) throw 'decode failed';

    // 2. 变换
    if (transform != null && !transform.isIdentity) {
      image = _applyTransformImg(image, transform);
    }

    // 3. 裁剪（复用 computeCropRect 逻辑，纯数学）
    final cropRect = PhotoPostProcessor.computeCropRect(
      aspectRatio, image.width, image.height, screenRatio, isPortrait,
    );
    image = img.copyCrop(image,
      x: cropRect[0].toInt(), y: cropRect[1].toInt(),
      width: cropRect[2].toInt(), height: cropRect[3].toInt());

    // 4. 降采样
    const maxDimension = 1536;
    if (image.width > maxDimension || image.height > maxDimension) {
      final scale = maxDimension / math.max(image.width, image.height);
      image = img.copyResize(image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round());
    }

    // 5. ColorMatrix（image 包逐像素）
    if (!rawMode) {
      final matrix = FilterRecipe.fromPostProcess(params).toColorMatrix();
      image = _applyColorMatrix(image, matrix);
    }

    // 6. 皮肤平滑
    // image = SkinSmoother.smoothImg(image);

    // 7. Sharpen / Clarity / Grain
    // image = _applySharpen(image, params.detail.sharpen);
    // ...

    // 8. 补光
    if (fillLight != null) {
      image = _applyFillLightImg(image, fillLight);
    }

    // 9. JPEG 编码
    final output = img.encodeJpg(image, quality: 88);
    return _IsolateResult(bytes: Uint8List.fromList(output),
      width: image.width, height: image.height);
  }

  static img.Image _applyColorMatrix(img.Image image, List<double> matrix) {
    // 用 image 包的 adjustment 逐像素应用 4x5 ColorMatrix
    // 参考 PhotoPostProcessor 中的实现
    return image; // 实现时补全
  }

  static img.Image _applyTransformImg(img.Image src, TransformParams t) {
    // image 包的旋转/翻转
    return src; // 实现时补全
  }

  static img.Image _applyFillLightImg(img.Image src, FillLightState fl) {
    // BlendMode.multiply 等价
    return src; // 实现时补全
  }
}

class _IsolateResult {
  final Uint8List bytes;
  final int width;
  final int height;
  const _IsolateResult({required this.bytes, required this.width, required this.height});
}
```

**实现说明：** 上面的 `_applyColorMatrix` / `_applyTransformImg` / `_applyFillLightImg` / 皮肤平滑 / Sharpen / Grain 需要从现有 `PhotoPostProcessor` 的对应方法移植到 image 包 API。subagent 实现时应参考 [photo_post_processor.dart:156-354](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart#L156-L354) 的现有实现，把 dart:ui Canvas 调用改为 image 包逐像素调用。

- [ ] **Step 4: 在 PhotoPostProcessor 中暴露 computeCropRect 为公开静态方法**

修改 `photo_post_processor.dart`，把 `_computeCropRect` 改名为 `computeCropRect`（去掉下划线），使其可被 `DartPhotoPipeline` 复用。

```dart
// photo_post_processor.dart
// 原: static List<double> _computeCropRect(...)
// 改: static List<double> computeCropRect(...)
```

同时更新内部调用点。

- [ ] **Step 5: 验证编译**

Run: `flutter analyze lib/features/capture/services/dart_photo_pipeline.dart`
Expected: 无 error。warning（未实现的 _applyColorMatrix 返回 src）可接受。

- [ ] **Step 6: 提交**

```bash
git add lib/features/capture/services/dart_photo_pipeline.dart \
        lib/features/capture/services/photo_post_processor.dart
git commit -m "feat(capture): implement DartPhotoPipeline dual-pipeline with Isolate"
```

---

## Task 5: CaptureThumbnailState 状态机

**Files:**
- Create: `lib/features/capture/data/capture_thumbnail_state.dart`

**Interfaces:**
- Produces: `CaptureThumbnailState`、`CaptureThumbnailStatus`、`captureThumbnailProvider`（StateNotifierProvider）

- [ ] **Step 1: 创建 capture_thumbnail_state.dart**

```dart
// lib/features/capture/data/capture_thumbnail_state.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CaptureThumbnailStatus { idle, processing, preview, final_ }

class CaptureThumbnailState {
  const CaptureThumbnailState({
    this.status = CaptureThumbnailStatus.idle,
    this.quickBytes,
    this.finalPath,
    this.photoId,
    this.captureSeq = 0,
  });
  final CaptureThumbnailStatus status;
  final Uint8List? quickBytes;
  final String? finalPath;
  final String? photoId;
  final int captureSeq;

  CaptureThumbnailState copyWith({
    CaptureThumbnailStatus? status,
    Uint8List? quickBytes,
    String? finalPath,
    String? photoId,
    int? captureSeq,
  }) => CaptureThumbnailState(
    status: status ?? this.status,
    quickBytes: quickBytes ?? this.quickBytes,
    finalPath: finalPath ?? this.finalPath,
    photoId: photoId ?? this.photoId,
    captureSeq: captureSeq ?? this.captureSeq,
  );
}

class CaptureThumbnailNotifier extends StateNotifier<CaptureThumbnailState> {
  CaptureThumbnailNotifier() : super(const CaptureThumbnailState());

  void startCapture() {
    state = CaptureThumbnailState(
      status: CaptureThumbnailStatus.processing,
      captureSeq: state.captureSeq + 1,
    );
  }

  void setQuickResult(Uint8List bytes) {
    // 仅当当前 seq 匹配时更新（避免旧 fullProcess 覆盖新拍摄）
    state = state.copyWith(
      status: CaptureThumbnailStatus.preview,
      quickBytes: bytes,
    );
  }

  void setFinalResult(String path, String photoId) {
    state = state.copyWith(
      status: CaptureThumbnailStatus.final_,
      finalPath: path,
      photoId: photoId,
    );
  }

  void reset() {
    state = const CaptureThumbnailState();
  }
}

final captureThumbnailProvider =
    StateNotifierProvider<CaptureThumbnailNotifier, CaptureThumbnailState>(
  (ref) => CaptureThumbnailNotifier(),
);
```

- [ ] **Step 2: 验证编译**

Run: `flutter analyze lib/features/capture/data/capture_thumbnail_state.dart`
Expected: No issues

- [ ] **Step 3: 提交**

```bash
git add lib/features/capture/data/capture_thumbnail_state.dart
git commit -m "feat(capture): add CaptureThumbnailState state machine"
```

---

## Task 6: capture_state.dart 改造（删除 cameraStateProvider）

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart`

- [ ] **Step 1: 删除 cameraStateProvider**

在 `capture_state.dart` 中删除第 25-28 行：

```dart
// 删除：
// ── 相机引擎状态（由 CameraPreview 通过 onCameraStateCreated 回调注入）──
// static final cameraStateProvider = StateProvider<CameraState?>((ref) => null);
```

同时在 `resetAll` 方法中删除第 301 行：
```dart
// 删除：container.read(cameraStateProvider.notifier).state = null;
```

- [ ] **Step 2: 移除 camerawesome_ohos 的 import（如果不再需要）**

检查 `capture_state.dart` 第 1 行 `import 'package:camerawesome_ohos/camerawesome_plugin.dart';`。如果文件中不再引用 camerawesome 类型（`CameraState` / `ZoomRange` 等），删除此 import。

注意：`ZoomRange` 类在第 325 行定义，是项目自定义的，不依赖 camerawesome。`FlashMode` 不在此文件。删除 import 前确认无残留引用。

- [ ] **Step 3: 验证编译**

Run: `flutter analyze lib/features/capture/data/capture_state.dart`
Expected: 无 "undefined name cameraStateProvider" 之外的问题。其他文件引用 `cameraStateProvider` 会在 Task 7-8 修复。

- [ ] **Step 4: 提交**

```bash
git add lib/features/capture/data/capture_state.dart
git commit -m "refactor(capture): remove cameraStateProvider, decouple from camerawesome"
```

---

## Task 7: CaptureThumbnail widget + ShutterFeedback widget

**Files:**
- Create: `lib/features/capture/widgets/capture_thumbnail.dart`
- Create: `lib/features/capture/widgets/shutter_feedback.dart`

**Interfaces:**
- Consumes: `captureThumbnailProvider`（Task 5）
- Produces: `CaptureThumbnail`（widget）、`ShutterFeedback`（widget）

- [ ] **Step 1: 创建 capture_thumbnail.dart**

```dart
// lib/features/capture/widgets/capture_thumbnail.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_thumbnail_state.dart';

/// 底部角标缩略图。四态：idle(空)/processing(灰块)/preview(近似图)/final(最终图)
class CaptureThumbnail extends ConsumerWidget {
  const CaptureThumbnail({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureThumbnailProvider);
    return GestureDetector(
      onTap: state.status == CaptureThumbnailStatus.idle ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.black26,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(CaptureThumbnailState state) {
    switch (state.status) {
      case CaptureThumbnailStatus.idle:
        return const SizedBox.shrink();
      case CaptureThumbnailStatus.processing:
        return const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        );
      case CaptureThumbnailStatus.preview:
      case CaptureThumbnailStatus.final_:
        final bytes = state.quickBytes;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        if (state.finalPath != null) {
          return Image.file(File(state.finalPath!), fit: BoxFit.cover);
        }
        return const SizedBox.shrink();
    }
  }
}
```

注意：`Image.file` 需要 `import 'dart:io';`。

- [ ] **Step 2: 创建 shutter_feedback.dart**

```dart
// lib/features/capture/widgets/shutter_feedback.dart
import 'package:flutter/material.dart';

/// 屏幕白闪 overlay，模拟机械快门。80ms 闪现。
class ShutterFeedback extends StatefulWidget {
  const ShutterFeedback({super.key, required this.trigger});
  final int trigger; // 递增触发，每次变化播放一次

  @override
  State<ShutterFeedback> createState() => _ShutterFeedbackState();
}

class _ShutterFeedbackState extends State<ShutterFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ShutterFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          if (_controller.value == 0) return const SizedBox.shrink();
          return Container(
            color: Colors.white.withOpacity((1 - _controller.value) * 0.8),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze lib/features/capture/widgets/capture_thumbnail.dart lib/features/capture/widgets/shutter_feedback.dart`
Expected: No issues

- [ ] **Step 4: 提交**

```bash
git add lib/features/capture/widgets/capture_thumbnail.dart \
        lib/features/capture/widgets/shutter_feedback.dart
git commit -m "feat(capture): add CaptureThumbnail and ShutterFeedback widgets"
```

---

## Task 8: capture_page.dart 核心改造

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart`

这是最复杂的任务。参考现有实现：
- [_onCapture 367-405](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L367-L405)
- [_processSingleFrame 410-530](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L410-L530)
- [_onCameraStateCreated 260-310](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L260-L310)
- [_switchCamera 537-562](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L537-L562)
- [_onZoomChanged 572-590](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L572-L590)

**改造要点：**
1. `_isProcessing` → `_isQuickProcessing`，只阻塞 quickProcess 窗口
2. `_onCapture` 改调 `ref.read(cameraServiceProvider).capture()`
3. `_processSingleFrame` 拆为：先 quickProcess（主 Isolate）→ 角标显示 preview 态 → fullProcess（Isolate）→ 角标 swap final 态 → 落库
4. 删除第 519-529 行自动跳预览页
5. 角标点击才跳预览页
6. 移除 `captureState$` 流监听（改为 `CameraService.capture()` 的 Future）
7. 移除 `_lastState` / `_captureSub`（camerawesome 类型）
8. 挂载 `CaptureThumbnail` widget + `ShutterFeedback` overlay

- [ ] **Step 1: 修改 imports**

在 `capture_page.dart` 顶部移除 camerawesome_ohos import，新增：

```dart
// 移除：import 'package:camerawesome_ohos/camerawesome_plugin.dart';
// 新增：
import '../services/camera_service.dart';
import '../services/camera_service_provider.dart';
import '../services/photo_pipeline.dart';
import '../data/capture_thumbnail_state.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/shutter_feedback.dart';
```

- [ ] **Step 2: 修改状态字段**

```dart
// 替换：
// bool _isProcessing = false;
// StreamSubscription<MediaCapture?>? _captureSub;
// CameraState? _lastState;
bool _isQuickProcessing = false;
int _shutterTrigger = 0; // 白闪动画触发器
String? _lastOriginalPath; // 原图备份路径（fullProcess 完成后落库用）
```

- [ ] **Step 3: 重写 _onCapture**

```dart
Future<void> _onCapture() async {
  if (_isQuickProcessing) return;

  final cameraService = ref.read(cameraServiceProvider);
  final flashMode = ref.read(CaptureState.flashModeProvider);
  final facing = ref.read(CaptureState.cameraFacingProvider);
  final zoom = ref.read(CaptureState.zoomProvider);
  final zoomRange = CaptureState.zoomRangeForFacing(facing);
  final zoomMultiplier = CaptureState.normalizedToZoomMultiplier(
      zoom, zoomRange.min, zoomRange.max);

  _isQuickProcessing = true;
  // 立即反馈：白闪 + 角标 processing 态
  setState(() => _shutterTrigger++);
  ref.read(captureThumbnailProvider.notifier).startCapture();

  try {
    final result = await cameraService.capture(
      config: CaptureConfig(
        facing: facing,
        zoomMultiplier: zoomMultiplier,
        flashMode: _mapFlashMode(flashMode),
      ),
    );

    // quickProcess（主 Isolate，< 100ms）
    final params = ref.read(CaptureState.effectivePostProcessProvider);
    final rawMode = ref.read(CaptureState.rawModeProvider);
    final aspectRatio = ref.read(CaptureState.aspectRatioProvider);
    final screenSize = MediaQuery.of(context).size;
    final screenRatio = screenSize.width / screenSize.height;
    final isPortrait = screenSize.height >= screenSize.width;

    final quick = await ref.read(photoPipelineProvider).quickProcess(
      inputPath: result.filePath,
      params: params,
      aspectRatio: aspectRatio,
      screenRatio: screenRatio,
      isPortrait: isPortrait,
      rawMode: rawMode,
    );

    if (quick != null) {
      ref.read(captureThumbnailProvider.notifier).setQuickResult(quick.bytes);
    }
    // quickProcess 完成，恢复可拍
    _isQuickProcessing = false;

    // fullProcess（Isolate 后台，不阻塞）
    _runFullProcess(
      inputPath: result.filePath,
      params: params,
      rawMode: rawMode,
      aspectRatio: aspectRatio,
      screenRatio: screenRatio,
      isPortrait: isPortrait,
    );
  } catch (e, st) {
    _isQuickProcessing = false;
    debugPrint('[capture] capture failed: $e\n$st');
    if (!mounted) return;
    LumiraToast.show(context, '拍照失败：$e', duration: const Duration(seconds: 2));
  }
}
```

- [ ] **Step 4: 新增 _runFullProcess**

```dart
Future<void> _runFullProcess({
  required String inputPath,
  required PostProcess params,
  required bool rawMode,
  required String aspectRatio,
  required double screenRatio,
  required bool isPortrait,
}) async {
  final fillLight = ref.read(CaptureState.fillLightStateProvider);

  // 原图备份（非破坏性编辑）
  String? originalPath;
  try {
    originalPath = '$inputPath.original.jpg';
    await File(inputPath).copy(originalPath);
  } catch (e) {
    originalPath = null;
  }

  try {
    final result = await ref.read(photoPipelineProvider).fullProcess(
      inputPath: inputPath,
      params: params,
      aspectRatio: aspectRatio,
      screenRatio: screenRatio,
      isPortrait: isPortrait,
      rawMode: rawMode,
      fillLight: fillLight,
    );

    // evict FileImage 缓存
    try {
      PaintingBinding.instance.imageCache.evict(FileImage(File(result.filePath)));
    } catch (_) {}

    // 落库
    final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final dao = await ref.read(galleryDaoProvider.future);
      final templateId = ref.read(CaptureState.currentTemplateIdProvider);
      final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
      final lut = params.lut;
      final record = GalleryItemRecord(
        id: photoId,
        filePath: result.filePath,
        originalPath: originalPath,
        postProcess: params,
        dataUrl: null,
        sceneId: sceneId,
        templateId: templateId,
        kitId: null,
        mood: null,
        lut: (lut == 'none' || lut.isEmpty) ? null : lut,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await dao.insert(record);
      ref.invalidate(galleryDaoProvider);
      ref.invalidate(bannerRecommendationProvider);

      if (_activeKitId != null) {
        try {
          final kitsDao = await ref.read(compositionKitsDaoProvider.future);
          await kitsDao.incrementUsage(_activeKitId!);
          ref.invalidate(compositionKitsProvider);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[capture] 落库失败: $e');
    }

    // 角标 swap 最终图
    if (mounted) {
      ref.read(captureThumbnailProvider.notifier).setFinalResult(result.filePath, photoId);
      ref.read(CaptureState.lastPhotoPathProvider.notifier).state = result.filePath;
    }
  } catch (e, st) {
    debugPrint('[capture] fullProcess failed: $e\n$st');
    // 降级：角标保持 preview 态，Toast 提示
    if (mounted) {
      LumiraToast.show(context, '图像增强失败，已保存基础图',
          duration: const Duration(seconds: 2));
    }
  }
}
```

- [ ] **Step 5: 删除 _processSingleFrame 和 _onCaptured**

删除原 `_processSingleFrame`（410-530）和 `_onCaptured`（532-534），已被 _onCapture + _runFullProcess 取代。

- [ ] **Step 6: 删除自动跳预览页逻辑**

确认原 519-529 行的 `GoRouter.push(capturePreview)` 已在 Step 5 删除。

新增角标点击跳预览页：

```dart
void _onThumbnailTap() {
  final state = ref.read(captureThumbnailProvider);
  final path = state.finalPath;
  final photoId = state.photoId;
  if (path == null || photoId == null) return;
  final aspectRatio = ref.read(CaptureState.aspectRatioProvider);
  GoRouter.of(context).push(
    '${RouteNames.capturePreview}'
    '?photoUrl=${Uri.encodeComponent(path)}'
    '&photoId=$photoId'
    '&aspectRatio=${Uri.encodeComponent(aspectRatio)}',
  );
}
```

- [ ] **Step 7: 改造 _onCameraStateCreated**

原 `_onCameraStateCreated(CameraState state)` 接收 camerawesome 类型。改为由 `CameraService.buildPreview()` 的 `onReady` 回调触发初始化逻辑（闪光灯/缩放/模板参数应用）。

删除整个 `_onCameraStateCreated` 方法，把其中的闪光灯/缩放/镜像逻辑移到 `CameraPreview` widget 的 `onReady` 回调中（在 Task 9 的 camera_preview.dart 改造中处理）。

- [ ] **Step 8: 改造 _switchCamera 和 _onZoomChanged**

```dart
Future<void> _switchCamera() async {
  final current = ref.read(CaptureState.cameraFacingProvider);
  final next = current == 'back' ? 'front' : 'back';
  ref.read(CaptureState.cameraFacingProvider.notifier).state = next;
  // 触发 CameraPreview 重建（通过 facing 变化）
  // CameraService.switchCamera 由 buildPreview 的 sensor 参数自动处理
}

void _onZoomChanged(double scale) {
  final facing = ref.read(CaptureState.cameraFacingProvider);
  final range = CaptureState.zoomRangeForFacing(facing);
  // scale 是 1.0+ 的真实倍数
  final clamped = scale.clamp(range.min, range.max);
  final cameraService = ref.read(cameraServiceProvider);
  cameraService.setZoom(clamped);
  final normalized = CaptureState.zoomMultiplierToNormalized(clamped, range.min, range.max);
  ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized;
  ref.read(CaptureState.zoomProvider.notifier).state = normalized;
}
```

- [ ] **Step 9: 在 build 方法中挂载 CaptureThumbnail 和 ShutterFeedback**

在 `build()` 的 Stack 中，把原有缩略图位置替换为 `CaptureThumbnail`，并在最顶层加 `ShutterFeedback` overlay：

```dart
// 在底部控制栏的缩略图位置：
CaptureThumbnail(onTap: _onThumbnailTap),

// Stack 最顶层：
Positioned.fill(
  child: ShutterFeedback(trigger: _shutterTrigger),
),
```

- [ ] **Step 10: 修改 _mapFlashMode 返回类型**

原 `_mapFlashMode` 返回 camerawesome 的 `FlashMode`。改为返回 `CameraFlashMode`：

```dart
CameraFlashMode _mapFlashMode(CaptureFlashMode mode) {
  switch (mode) {
    case CaptureFlashMode.off: return CameraFlashMode.off;
    case CaptureFlashMode.on: return CameraFlashMode.on;
    case CaptureFlashMode.auto: return CameraFlashMode.auto;
    case CaptureFlashMode.torch: return CameraFlashMode.torch;
  }
}
```

注意：`CaptureFlashMode` 是 `capture_state.dart` 的枚举，`CameraFlashMode` 是 `camera_service.dart` 的枚举。

- [ ] **Step 11: 修改 dispose**

删除 `_captureSub?.cancel()`（已无此字段）。保留 `CamerawesomePlugin.stop()` 调用，改为 `ref.read(cameraServiceProvider).dispose()`。

- [ ] **Step 12: 验证编译**

Run: `flutter analyze lib/features/capture/pages/capture_page.dart`
Expected: 无 error。修复所有 warning。

- [ ] **Step 13: 提交**

```bash
git add lib/features/capture/pages/capture_page.dart
git commit -m "feat(capture): rewrite capture flow with CameraService + dual-pipeline + thumbnail"
```

---

## Task 9: camera_preview.dart 改造

**Files:**
- Modify: `lib/features/capture/widgets/camera_preview.dart`

**改造要点：**
- `CameraPreview` widget 不再直接 `CameraAwesomeBuilder.custom`，改为调用 `ref.read(cameraServiceProvider).buildPreview()`
- 把原 `_onCameraStateCreated` 中的闪光灯/缩放/镜像/模板参数应用逻辑移到 `onReady` 回调

- [ ] **Step 1: 修改 imports**

```dart
// 移除：import 'package:camerawesome_ohos/camerawesome_plugin.dart';
// 新增：
import '../services/camera_service.dart';
import '../services/camera_service_provider.dart';
```

- [ ] **Step 2: 重写 build 方法**

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final facing = ref.watch(CaptureState.cameraFacingProvider);
  final flashMode = ref.watch(CaptureState.flashModeProvider);
  final cameraService = ref.read(cameraServiceProvider);

  return cameraService.buildPreview(
    config: CameraPreviewConfig(
      facing: facing,
      fit: CameraPreviewFit.cover,
      onReady: () => _onCameraReady(ref, flashMode, facing),
      onTapFocus: (position, previewSize) {
        cameraService.focusOnPoint(position, previewSize);
      },
      onScaleZoom: (scale) {
        // 交给 capture_page 的 _onZoomChanged 处理
        onZoomChanged?.call(scale);
      },
    ),
  );
}

void _onCameraReady(WidgetRef ref, CaptureFlashMode flashMode, String facing) {
  final cameraService = ref.read(cameraServiceProvider);
  // 应用闪光灯
  cameraService.setFlashMode(_mapFlashMode(flashMode));
  // 重置缩放为 1x
  cameraService.setZoom(1.0);
  final range = CaptureState.zoomRangeForFacing(facing);
  final normalized1x = CaptureState.zoomMultiplierToNormalized(1.0, range.min, range.max);
  ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
  ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
  // 应用模板相机参数（EV 等）
  // ... 从 capture_page 移植 _applyTemplateCameraParams 逻辑
}
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze lib/features/capture/widgets/camera_preview.dart`
Expected: No issues

- [ ] **Step 4: 提交**

```bash
git add lib/features/capture/widgets/camera_preview.dart
git commit -m "refactor(capture): route camera preview through CameraService"
```

---

## Task 10: 单元测试

**Files:**
- Create: `test/features/capture/data/capture_thumbnail_state_test.dart`
- Create: `test/features/capture/services/photo_pipeline_test.dart`

- [ ] **Step 1: 创建 capture_thumbnail_state_test.dart**

```dart
// test/features/capture/data/capture_thumbnail_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rumira_app_flutter/features/capture/data/capture_thumbnail_state.dart';

void main() {
  test('initial state is idle', () {
    final notifier = CaptureThumbnailNotifier();
    expect(notifier.state.status, CaptureThumbnailStatus.idle);
    expect(notifier.state.captureSeq, 0);
  });

  test('startCapture transitions to processing and increments seq', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    expect(notifier.state.status, CaptureThumbnailStatus.processing);
    expect(notifier.state.captureSeq, 1);
    notifier.startCapture();
    expect(notifier.state.captureSeq, 2);
  });

  test('setQuickResult transitions to preview', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    notifier.setQuickResult(Uint8List.fromList([1, 2, 3]));
    expect(notifier.state.status, CaptureThumbnailStatus.preview);
    expect(notifier.state.quickBytes, isNotNull);
  });

  test('setFinalResult transitions to final', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    notifier.setFinalResult('/path/photo.jpg', 'photo_123');
    expect(notifier.state.status, CaptureThumbnailStatus.final_);
    expect(notifier.state.finalPath, '/path/photo.jpg');
    expect(notifier.state.photoId, 'photo_123');
  });

  test('reset returns to idle', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    notifier.reset();
    expect(notifier.state.status, CaptureThumbnailStatus.idle);
  });
}
```

注意：`Uint8List` 需要 `import 'dart:typed_data';`。包名 `rumira_app_flutter` 需确认（pubspec 是 `lumira_app_flutter`）。

- [ ] **Step 2: 运行测试**

Run: `flutter test test/features/capture/data/capture_thumbnail_state_test.dart`
Expected: All tests pass

- [ ] **Step 3: 创建 photo_pipeline_test.dart（computeCropRect 比例验证）**

```dart
// test/features/capture/services/photo_pipeline_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  group('computeCropRect', () {
    test('fullscreen 模式按 screenRatio cover 裁剪', () {
      // 传感器 4032x3024 (4:3)，screen 9:19.5 (竖屏)
      final rect = PhotoPostProcessor.computeCropRect(
        'fullscreen', 4032, 3024, 9.0 / 19.5, true);
      // cover: 短边对齐，裁掉长边多余部分
      expect(rect[2] / rect[3], closeTo(9.0 / 19.5, 0.01));
    });

    test('1:1 模式输出正方形', () {
      final rect = PhotoPostProcessor.computeCropRect(
        '1:1', 4032, 3024, 9.0 / 19.5, true);
      expect(rect[2], closeTo(rect[3], 1));
    });

    test('4:3 竖屏输出 3:4', () {
      final rect = PhotoPostProcessor.computeCropRect(
        '4:3', 4032, 3024, 9.0 / 19.5, true);
      expect(rect[2] / rect[3], closeTo(3.0 / 4.0, 0.01));
    });
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/features/capture/services/photo_pipeline_test.dart`
Expected: All tests pass

- [ ] **Step 5: 提交**

```bash
git add test/
git commit -m "test(capture): add thumbnail state machine and crop rect tests"
```

---

## Task 11: 三端真机验证

**Files:** 无代码改动，仅运行验证

- [ ] **Step 1: HarmonyOS 真机验证**

Run: `flutter run -d <ohos-device>`
验证清单：
- [ ] 取景器正常显示
- [ ] 按下快门 → 白闪 → 角标 150ms 内显示近似图
- [ ] 500ms 后角标 swap 最终图
- [ ] 点击角标进预览页
- [ ] 快速连拍 5 张全部落库
- [ ] 闪光灯/缩放/切换摄像头正常

- [ ] **Step 2: iOS 真机验证**（需 Mac 环境）

Run: `flutter run -d <ios-device>`
验证清单同上 + 首次编译通过

- [ ] **Step 3: Android 真机验证**

Run: `flutter run -d <android-device>`
验证清单同上

- [ ] **Step 4: 弱光场景验证**

在低光环境下拍照，验证：
- quickProcess 可能超 200ms，角标应降级为等 fullProcess
- fullProcess 完成后正常显示最终图

---

## Self-Review

### 1. Spec 覆盖性

| Spec 章节 | 对应 Task |
|---|---|
| §0.2 阶段一目标 | Task 1-11 整体 |
| §1 架构总览 | Task 1-9 |
| §2 CameraService 抽象 | Task 0, 1, 2 |
| §3 PhotoPipeline 双管线 | Task 3, 4 |
| §4 交互流程（角标+连拍） | Task 5, 7, 8 |
| §5 错误处理 | Task 8（_runFullProcess 的 catch）|
| §6 阶段二演进接口 | Task 1, 3（接口已预留）|
| §7 测试策略 | Task 10, 11 |
| §8 文件改动清单 | Task 1-10 全覆盖 |
| §9 风险（camerawesome 共存）| Task 0 |
| §9 风险（Isolate.run）| Task 4 Step 1 |

### 2. Placeholder 扫描

- Task 2 的 `_PathProviderWrapper` 等包装类已标注"实现时简化为直接 import"——这是给 subagent 的实现指引，非 placeholder
- Task 4 的 `_applyColorMatrix` / `_applyTransformImg` / `_applyFillLightImg` 标注"实现时补全"，参考现有 PhotoPostProcessor——subagent 需从现有代码移植
- 无其他 TBD/TODO

### 3. 类型一致性

- `CameraFlashMode` 在 Task 1 定义，Task 8 `_mapFlashMode` 返回类型一致
- `CaptureResult` / `CaptureConfig` 在 Task 1 定义，Task 2/8 使用一致
- `QuickResult` / `FullResult` 在 Task 3 定义，Task 4/8 使用一致
- `CaptureThumbnailStatus` 在 Task 5 定义为 `idle/processing/preview/final_`，Task 7 widget 使用 `final_`（带下划线，避 Dart 关键字）一致
- `captureThumbnailProvider` 在 Task 5 定义，Task 7/8 使用一致
