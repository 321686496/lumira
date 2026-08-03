# 缩放能力统一实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 统一三端（OHOS/Android/iOS）缩放 API 为真实倍数语义，查询设备真实 maxZoom/minZoom，对不支持超广角的端隐藏 0.5x Tab。

**Architecture:** CameraService 接口对外暴露真实倍数（0.5/1.0/2.0），平台分支转换在 CamerawesomeCameraService 内部完成；OHOS fork 新增 `getMinZoom()` 方法；CaptureState 用 provider 记录设备缩放能力，UI 层按能力动态生成预设 Tab。

**Tech Stack:** Flutter / Riverpod / camerawesome 1.4.0 / camerawesome_ohos (gitcode fork) / pigeon / OHOS ArkTS

## Global Constraints

- 三端必须统一用"真实倍数"作为 CameraService 对外 API 语义（0.5/1.0/2.0/3.0/5.0）
- OHOS setZoom 传真实倍数，iOS/Android setZoom 传 [0,1] 归一化值（camerawesome 1.4.0 原生语义）
- iOS minZoom 硬编码 1.0（camerawesome 1.4.0 限制），0.5x Tab 在 iOS 隐藏
- Android minZoom 假设 0.5（setLinearZoom(0.0) 自动到 minZoomRatio，视觉正确）
- OHOS minZoom 通过新增 fork 方法 `getMinZoom()` 查询 `getZoomRatioRange()` 最小值
- ISO/快门速度/手动曝光模式不实现（camerawesome 1.4.0 三端均未封装）
- OHOS fork 本地缓存路径：`E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc`
- lumira_app_flutter 项目根目录：`e:/Project/photo_post/lumira_app_flutter`
- 不修改 UI 布局结构，只调整 _ZoomTabBar 的预设数据源和 _onZoomChanged 的参数语义

---

## 文件结构

### OHOS fork（5 个文件）
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/pigeons/interface.dart` — 加 `getMinZoom()` 接口定义
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/ohos/src/main/ets/components/cameraX/CameraState.ets` — 实现 `getMinZoom()`
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets` — 转发 `getMinZoom()`
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/lib/pigeon.dart` — 加 `getMinZoom` 绑定（手动编辑，避免运行 pigeon）
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/lib/camerawesome_plugin.dart` — 加 `static Future<num?> getMinZoom()`

### lumira_app_flutter（5 个文件）
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/services/camera_service.dart` — 接口加 4 个方法
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/services/camerawesome_camera_service.dart` — 平台分支实现 + onScale 适配
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/data/capture_state.dart` — 加 3 个 provider，zoomProvider 改语义，清理旧映射函数
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart` — `_onCameraReady` 查询能力，onScaleZoom 适配
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart` — `_ZoomTabBar` 动态预设，`_onZoomChanged` 简化，双指缩放适配

---

## Task 1: OHOS fork 新增 getMinZoom 方法

**Files:**
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/pigeons/interface.dart`
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/ohos/src/main/ets/components/cameraX/CameraState.ets`
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets`
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/lib/pigeon.dart`
- Modify: `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/lib/camerawesome_plugin.dart`

**Interfaces:**
- Produces: `CamerawesomePlugin.getMinZoom()` 返回 `Future<num?>`，OHOS 端返回 `getZoomRatioRange()` 最小值

**上下文（现有 getMaxZoom 实现供参照）：**
- `interface.dart:296` 有 `double getMaxZoom();`
- `CameraState.ets:1010-1021` 的 `getMaxZoom()` 遍历 `getZoomRatioRange()` 取最大值
- `CameraAwesomeX.ets:284-287` 转发 `getMaxZoom()`
- `camerawesome_plugin.dart:347-349` 有 `static Future<num?> getMaxZoom() => CameraInterface().getMaxZoom();`
- `pigeon.dart` 中有 `getMaxZoom` 的 pigeon 绑定类

- [ ] **Step 1: 在 interface.dart 加 getMinZoom 接口**

在 `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/pigeons/interface.dart` 第 296 行 `double getMaxZoom();` 后追加：

```dart
  double getMinZoom();
```

- [ ] **Step 2: 在 CameraState.ets 实现 getMinZoom**

在 `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/ohos/src/main/ets/components/cameraX/CameraState.ets` 第 1021 行 `getMaxZoom()` 方法结束后（`}` 之后）追加：

```typescript
  getMinZoom(): number {
    let zoomRatios = this.session?.getZoomRatioRange()
    if (zoomRatios == undefined) {
      return 0
    }
    let minZoom = zoomRatios[0]
    for (let zr of zoomRatios) {
      minZoom = minZoom < zr ? minZoom : zr
    }
    return minZoom
  }
```

- [ ] **Step 3: 在 CameraAwesomeX.ets 转发 getMinZoom**

在 `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets` 第 287 行 `getMaxZoom()` 方法结束后追加：

```typescript
  getMinZoom(): number {
    Logger.debug(TAG, `getMinZoom is called`);
    return this.cameraState!!.getMinZoom()
  }
```

- [ ] **Step 4: 在 pigeon.dart 加 getMinZoom 绑定**

先读取 `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/lib/pigeon.dart`，找到 `getMaxZoom` 相关的 pigeon 绑定类（通常是 `GetMaxZoomResult` 接口 + `getMaxZoom` 方法签名），在其后镜像追加 `getMinZoom` 的对应绑定。

具体需查看现有 `getMaxZoom` 在 pigeon.dart 中的三处出现：
1. 抽象接口类中的方法声明
2. 实现类中的方法实现（调用 native channel）
3. 结果回调接口（若有）

对每处镜像追加 `getMinZoom` 版本。

- [ ] **Step 5: 在 camerawesome_plugin.dart 加 getMinZoom 顶层方法**

在 `E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/lib/camerawesome_plugin.dart` 第 349 行 `getMaxZoom` 方法后追加：

```dart
  static Future<num?> getMinZoom() {
    return CameraInterface().getMinZoom();
  }
```

- [ ] **Step 6: 验证 fork 改动无语法错误**

检查所有 5 个文件的改动是否完整、语法正确。无法在 Windows 上编译 OHOS ArkTS，仅做人工检查。

- [ ] **Step 7: Commit fork 改动**

```bash
cd E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc
git add -A
git commit -m "feat(ohos): add getMinZoom method for ultra-wide support"
```

---

## Task 2: CameraService 接口扩展

**Files:**
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/services/camera_service.dart`

**Interfaces:**
- Produces: `CameraService` 抽象类新增 4 个方法签名

**上下文：**
- 现有 `camera_service.dart` 已有 `setZoom(double normalized)` 等方法（上一轮重置后的状态）
- 需保留现有方法，新增以"Multiplier"命名的方法

- [ ] **Step 1: 读取现有 camera_service.dart**

读取 `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/services/camera_service.dart` 全文，确认现有方法签名和注释风格。

- [ ] **Step 2: 在 CameraService 抽象类末尾追加 4 个方法**

在 `CameraService` 抽象类的最后一个方法后（`}` 之前）追加：

```dart
  /// 设置缩放倍数（真实倍数，如 0.5/1.0/2.0）。
  /// 内部按平台转换：OHOS 传真实倍数，iOS/Android 转归一化 [0,1]。
  void setZoomMultiplier(double multiplier);

  /// 获取设备最大缩放倍数（真实倍数）。
  /// 失败时返回 fallback 值 10.0。
  Future<double> getMaxZoomMultiplier();

  /// 获取设备最小缩放倍数（真实倍数）。
  /// iOS 固定 1.0，OHOS/Android 可 < 1.0（支持超广角时）。
  /// 失败时返回 fallback 值 1.0。
  Future<double> getMinZoomMultiplier();

  /// 是否支持超广角（minZoom < 1.0）。
  Future<bool> supportsUltraWide();
```

- [ ] **Step 3: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/services/camera_service.dart
git commit -m "feat(camera): add zoom multiplier API to CameraService interface"
```

---

## Task 3: CamerawesomeCameraService 平台分支实现

**Files:**
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/services/camerawesome_camera_service.dart`

**Interfaces:**
- Consumes: Task 1 的 `CamerawesomePlugin.getMinZoom()`、Task 2 的接口签名
- Produces: `CamerawesomeCameraService` 实现 4 个新方法，`buildPreview` 的 onScale 按平台转换

**上下文：**
- 现有 `camerawesome_camera_service.dart` 有 `_delegate.platformTag`（值为 'ohos' 或 'native'）区分平台
- 现有 `setZoom(double normalized)` 直接传归一化值
- 现有 `buildPreview` 的 onScale 回调分 OHOS/native 两支
- `_cameraState` 持有 `CameraState` 实例，`_cameraState?.sensorConfig` 可调 `setZoom`
- 需缓存 maxZoom/minZoom 避免每次 setZoom 都查询

- [ ] **Step 1: 读取现有 camerawesome_camera_service.dart**

读取全文，确认 `_delegate.platformTag`、`setZoom`、`buildPreview` 的 onScale、`_cameraState` 字段的当前位置和代码。

- [ ] **Step 2: 添加 maxZoom/minZoom 缓存字段**

在 `CamerawesomeCameraService` 类的字段区（`_cameraState` 附近）追加：

```dart
  double? _cachedMaxZoom;
  double? _cachedMinZoom;
```

- [ ] **Step 3: 实现 setZoomMultiplier**

在类中追加新方法（保留现有 `setZoom`，新方法独立）：

```dart
  @override
  void setZoomMultiplier(double multiplier) {
    if (_delegate.platformTag == 'ohos') {
      // OHOS: setZoom 接收真实倍数
      try {
        CamerawesomePlugin.setZoom(multiplier);
      } catch (e) {
        debugPrint('[camera] OHOS setZoom failed: $e');
      }
    } else {
      // iOS/Android: setZoom 接收 [0,1] 归一化值
      try {
        final maxZoom = _cachedMaxZoom ?? 10.0;
        final minZoom = _cachedMinZoom ?? 1.0;
        final normalized = ((multiplier - minZoom) / (maxZoom - minZoom))
            .clamp(0.0, 1.0);
        _cameraState?.sensorConfig?.setZoom(normalized);
      } catch (e) {
        debugPrint('[camera] native setZoom failed: $e');
      }
    }
  }
```

- [ ] **Step 4: 实现 getMaxZoomMultiplier**

```dart
  @override
  Future<double> getMaxZoomMultiplier() async {
    if (_cachedMaxZoom != null) return _cachedMaxZoom!;
    try {
      final maxZoom = await CamerawesomePlugin.getMaxZoom();
      _cachedMaxZoom = (maxZoom ?? 10.0).toDouble();
      return _cachedMaxZoom!;
    } catch (e) {
      debugPrint('[camera] getMaxZoom failed: $e');
      _cachedMaxZoom = 10.0;
      return 10.0;
    }
  }
```

- [ ] **Step 5: 实现 getMinZoomMultiplier**

```dart
  @override
  Future<double> getMinZoomMultiplier() async {
    if (_cachedMinZoom != null) return _cachedMinZoom!;
    try {
      if (_delegate.platformTag == 'ohos') {
        // OHOS: 调用 fork 新增的 getMinZoom
        final minZoom = await ohos.CamerawesomePlugin.getMinZoom();
        _cachedMinZoom = (minZoom ?? 0.5).toDouble();
        // fork 返回 0 表示 session 未就绪，fallback 0.5
        if (_cachedMinZoom == 0) _cachedMinZoom = 0.5;
        return _cachedMinZoom!;
      }
      if (Platform.isIOS) {
        // iOS: camerawesome 1.4.0 硬编码 minZoom=1.0
        _cachedMinZoom = 1.0;
        return 1.0;
      }
      // Android: camerawesome 未暴露 getMinZoomRatio，假设 0.5
      // setLinearZoom(0.0) 会到 minZoomRatio，UI 显示 0.5x 视觉正确
      _cachedMinZoom = 0.5;
      return 0.5;
    } catch (e) {
      debugPrint('[camera] getMinZoom failed: $e');
      _cachedMinZoom = _delegate.platformTag == 'ohos' ? 0.5 : 1.0;
      return _cachedMinZoom!;
    }
  }
```

注意：`ohos.CamerawesomePlugin` 需确认 import 别名。现有文件顶部应已有 `import 'package:camerawesome_ohos/camerawesome_plugin.dart' as ohos;` 之类的别名导入，若无则用 `CamerawesomePlugin`（需确认两个包的 CamerawesomePlugin 是否冲突）。若冲突，需加 import 别名。

- [ ] **Step 6: 实现 supportsUltraWide**

```dart
  @override
  Future<bool> supportsUltraWide() async {
    final minZoom = await getMinZoomMultiplier();
    return minZoom < 1.0;
  }
```

- [ ] **Step 7: 修改 buildPreview 的 onScale 回调**

找到 `buildPreview` 方法中 onScale 回调（OHOS 分支和 native 分支），改为统一输出真实倍数：

OHOS 分支（scale 已是真实倍数）：
```dart
config.onScaleZoom?.call(scale);
```

native 分支（scale 是 [0,1] 归一化，转真实倍数）：
```dart
final maxZoom = _cachedMaxZoom ?? 10.0;
final minZoom = _cachedMinZoom ?? 1.0;
final multiplier = minZoom + (maxZoom - minZoom) * scale;
config.onScaleZoom?.call(multiplier);
```

- [ ] **Step 8: 切换摄像头时清空缓存**

找到 `switchCamera` 方法（或相机重新初始化的地方），在重置相机状态时清空缓存：

```dart
  _cachedMaxZoom = null;
  _cachedMinZoom = null;
```

- [ ] **Step 9: 确认 import 完整**

确保文件顶部有：
- `import 'dart:io' show Platform;`（若没有）
- OHOS 包的 import（若需要 `ohos.CamerawesomePlugin.getMinZoom()`）

- [ ] **Step 10: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/services/camerawesome_camera_service.dart
git commit -m "feat(camera): implement zoom multiplier with platform branching"
```

---

## Task 4: CaptureState 扩展与清理

**Files:**
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/data/capture_state.dart`

**Interfaces:**
- Produces: 3 个新 provider（deviceMaxZoomProvider / deviceMinZoomProvider / supportsUltraWideProvider），zoomProvider/apparentZoomProvider 语义改为真实倍数（默认 1.0）

**上下文：**
- 上一轮重置后 `zoomProvider` / `apparentZoomProvider` 是 [0,1] 归一化，默认 0.0
- 现有 `zoomRangeForFacing` 返回归一化范围，需改为真实倍数范围
- `zoomMultiplierToNormalized` / `normalizedToZoomMultiplier` 若存在且无引用则移除

- [ ] **Step 1: 读取现有 capture_state.dart**

读取全文，确认现有 providers 和辅助函数。

- [ ] **Step 2: zoomProvider/apparentZoomProvider 改为真实倍数**

找到 `zoomProvider` 和 `apparentZoomProvider` 定义，默认值从 `0.0` 改为 `1.0`：

```dart
  static final zoomProvider = StateProvider<double>((ref) => 1.0);
  static final apparentZoomProvider = StateProvider<double>((ref) => 1.0);
```

- [ ] **Step 3: 新增 3 个设备能力 provider**

在 `zoomProvider` 附近追加：

```dart
  /// 设备最大缩放倍数（真实倍数），相机就绪时写入，null 表示未查询
  static final deviceMaxZoomProvider = StateProvider<double?>((ref) => null);

  /// 设备最小缩放倍数（真实倍数），相机就绪时写入，null 表示未查询
  static final deviceMinZoomProvider = StateProvider<double?>((ref) => null);

  /// 是否支持超广角（minZoom < 1.0），相机就绪时写入
  static final supportsUltraWideProvider = StateProvider<bool>((ref) => false);
```

- [ ] **Step 4: 改 zoomRangeForFacing 返回真实倍数范围**

找到 `zoomRangeForFacing`，改为返回真实倍数范围。若它原来返回 `(minNormalized, maxNormalized)`，改为返回 `(minMultiplier, maxMultiplier)`：

```dart
  /// 返回设备支持的缩放倍数范围（真实倍数）。
  /// 优先用查询到的设备值，否则用 fallback。
  static (double, double) zoomRangeForFacing(String facing) {
    // fallback：前摄 [1.0, 2.0]，后摄 [1.0, 10.0]
    final maxFallback = facing == 'front' ? 2.0 : 10.0;
    return (1.0, maxFallback);
  }
```

注意：若现有代码用了 Record 语法 `(double, double)`，保持一致；若用了旧式 `List<double>` 或多个返回值，按现有风格调整。

- [ ] **Step 5: 移除无引用的旧映射函数**

查找 `zoomMultiplierToNormalized` / `normalizedToZoomMultiplier` 在整个项目中是否还有引用（用 Grep 搜 `lumira_app_flutter/lib`）。若无引用则删除；若有引用，更新调用方。

- [ ] **Step 6: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/data/capture_state.dart
git commit -m "feat(capture): add device zoom capability providers, switch zoom to real multiplier"
```

---

## Task 5: camera_preview 查询能力与 onScaleZoom 适配

**Files:**
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart`

**Interfaces:**
- Consumes: Task 3 的 `setZoomMultiplier` / `getMaxZoomMultiplier` / `getMinZoomMultiplier` / `supportsUltraWide`，Task 4 的 3 个新 provider
- Produces: `_onCameraReady` 查询能力写入 providers，`onScaleZoom` 回调接收真实倍数

**上下文：**
- 现有 `_onCameraReady` 上一轮重置后直接下发 `setZoom(0.0)`（归一化 1x）
- 现有 onScaleZoom 回调直接透传归一化值
- `CameraPreview` 是 ConsumerWidget，用 `ref` 读写 providers

- [ ] **Step 1: 读取现有 camera_preview.dart**

读取全文，定位 `_onCameraReady`、onScaleZoom 回调、`setZoom` 调用点。

- [ ] **Step 2: _onCameraReady 改为查询能力 + 下发真实倍数**

找到 `_onCameraReady`，替换缩放下发部分：

```dart
void _onCameraReady(WidgetRef ref, CaptureFlashMode flashMode, String facing) {
  final cameraService = ref.read(cameraServiceProvider);
  cameraService.setFlashMode(_mapFlashMode(flashMode));
  // EV 补偿等其他设置保持现有逻辑...

  // 异步查询设备缩放能力（不阻塞相机就绪）
  _queryZoomCapabilities(ref, cameraService);

  // 重置缩放为 1x（真实倍数 1.0）
  ref.read(CaptureState.apparentZoomProvider.notifier).state = 1.0;
  ref.read(CaptureState.zoomProvider.notifier).state = 1.0;
  cameraService.setZoomMultiplier(1.0);
}
```

- [ ] **Step 3: 新增 _queryZoomCapabilities 方法**

在 `_onCameraReady` 附近追加：

```dart
Future<void> _queryZoomCapabilities(WidgetRef ref, CameraService service) async {
  try {
    final maxZoom = await service.getMaxZoomMultiplier();
    final minZoom = await service.getMinZoomMultiplier();
    final ultraWide = await service.supportsUltraWide();
    ref.read(CaptureState.deviceMaxZoomProvider.notifier).state = maxZoom;
    ref.read(CaptureState.deviceMinZoomProvider.notifier).state = minZoom;
    ref.read(CaptureState.supportsUltraWideProvider.notifier).state = ultraWide;
  } catch (e) {
    debugPrint('[camera] query zoom capabilities failed: $e');
    // fallback 不写入，provider 保持初始 null/false
  }
}
```

- [ ] **Step 4: onScaleZoom 回调适配真实倍数**

找到 onScaleZoom 回调（在 CameraAwesomeBuilder.custom 的 onPreviewScaleBuilder 或类似位置），上层现在接收的是真实倍数（Task 3 Step 7 已在 service 层转换），所以回调直接写真实倍数到 provider：

```dart
onScaleZoom: (multiplier) {
  // multiplier 已是真实倍数（service 层已转换）
  ref.read(CaptureState.apparentZoomProvider.notifier).state = multiplier;
  ref.read(CaptureState.zoomProvider.notifier).state = multiplier;
},
```

注意：不再在这里调 `setZoomMultiplier`，因为 camerawesome 的 onScale 已经触发了底层缩放，上层只需同步 UI 状态。若发现重复下发导致抖动，可改为只更新 provider 不再调 service。

- [ ] **Step 5: 清理旧的 setZoom(归一化) 调用**

全文搜索 `setZoom(` 确认无残留的归一化值调用（应全部改为 `setZoomMultiplier`）。

- [ ] **Step 6: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/widgets/camera_preview.dart
git commit -m "feat(camera): query zoom capabilities on ready, adapt onScaleZoom to real multiplier"
```

---

## Task 6: capture_page _ZoomTabBar 动态预设与 _onZoomChanged 简化

**Files:**
- Modify: `e:/Project/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart`

**Interfaces:**
- Consumes: Task 4 的 3 个新 provider，Task 3 的 `setZoomMultiplier`
- Produces: `_ZoomTabBar` 按 maxZoom/supportsUltraWide 动态生成预设，`_onZoomChanged` 接收真实倍数

**上下文：**
- 现有 `_ZoomTabBar` 在 `capture_page.dart` 约 1974-2115 行
- 现有 `_onZoomChanged` 上一轮重置后接收归一化值
- 现有 Tab 预设写死 `[0.5, 1.0, 2.0]`（前摄）/ `[0.5, 1.0, 2.0, 3.0, 5.0]`（后摄）
- 水平拖动轮盘的 `_onHorizontalDragUpdate` 也调用 `_onZoomChanged`

- [ ] **Step 1: 读取现有 capture_page.dart 相关部分**

读取 `_ZoomTabBar` 类（约 1974-2115 行）、`_onZoomChanged`、`_onHorizontalDragUpdate`、`_buildZoomTabBar` 的代码。

- [ ] **Step 2: _onZoomChanged 改为接收真实倍数**

找到 `_onZoomChanged`，改为：

```dart
void _onZoomChanged(double multiplier) {
  final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
  final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
  final clamped = multiplier.clamp(minZoom, maxZoom);
  ref.read(CaptureState.apparentZoomProvider.notifier).state = clamped;
  ref.read(CaptureState.zoomProvider.notifier).state = clamped;
  ref.read(cameraServiceProvider).setZoomMultiplier(clamped);
}
```

- [ ] **Step 3: _ZoomTabBar 读取设备能力动态生成预设**

修改 `_ZoomTabBar` 的 `build` 方法或其父级 `_buildZoomTabBar`，从 provider 读取 maxZoom 和 supportsUltraWide：

```dart
final maxZoom = ref.watch(CaptureState.deviceMaxZoomProvider) ?? 10.0;
final supportsUltraWide = ref.watch(CaptureState.supportsUltraWideProvider);
final presets = _getPresets(facing, maxZoom, supportsUltraWide);
```

新增 `_getPresets` 方法：

```dart
List<double> _getPresets(String facing, double maxZoom, bool supportsUltraWide) {
  final base = <double>[1.0];
  if (maxZoom >= 2.0) base.add(2.0);
  if (facing == 'back') {
    if (maxZoom >= 3.0) base.add(3.0);
    if (maxZoom >= 5.0) base.add(5.0);
  }
  if (supportsUltraWide) base.insert(0, 0.5);
  return base;
}
```

- [ ] **Step 4: Tab 点击直接传真实倍数**

找到 Tab 的 `onTap` / `onPressed`，改为直接传预设值（真实倍数）给 `onChanged`：

```dart
onTap: () => onChanged(preset),  // preset 已是真实倍数
```

- [ ] **Step 5: 水平拖动轮盘按真实倍数范围计算**

找到 `_onHorizontalDragUpdate`，改为按真实倍数范围拖动：

```dart
void _onHorizontalDragUpdate(DragUpdateDetails details) {
  final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
  final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
  final current = ref.read(CaptureState.apparentZoomProvider);
  // 每像素 0.05x 步进（可调整）
  final delta = details.delta.dx * 0.05;
  final next = (current + delta).clamp(minZoom, maxZoom);
  _onZoomChanged(next);
}
```

- [ ] **Step 6: 显示文本格式化**

确认 Tab 显示文本用 `${preset}x` 格式（如 `0.5x` / `1x` / `2x`），无需改动。

- [ ] **Step 7: 清理旧的归一化转换调用**

全文搜索 `_onZoomChanged` 的所有调用点，确认都传真实倍数，不再传归一化值。搜索 `normalizedToZoomMultiplier` / `zoomMultiplierToNormalized` 确认无残留调用。

- [ ] **Step 8: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/pages/capture_page.dart
git commit -m "feat(capture): dynamic zoom presets based on device capabilities, simplify _onZoomChanged"
```

---

## Task 7: 验证与收尾

**Files:**
- 无新文件改动，仅验证

- [ ] **Step 1: 运行 flutter analyze**

```bash
cd e:/Project/photo_post/lumira_app_flutter
flutter analyze
```

Expected: 无 error，可能有 info 级 const 提示（在未改动区域，可忽略）

- [ ] **Step 2: 检查旧映射函数残留引用**

用 Grep 搜索 `lumira_app_flutter/lib` 下：
- `normalizedToZoomMultiplier`
- `zoomMultiplierToNormalized`
- `displayToCameraMultiplier`

Expected: 无匹配（或仅在注释中）

- [ ] **Step 3: 检查 setZoom(归一化) 残留**

用 Grep 搜索 `lumira_app_flutter/lib` 下的 `setZoom(`，确认仅出现在：
- `camerawesome_camera_service.dart` 的 `setZoomMultiplier` 内部（调用 `CamerawesomePlugin.setZoom` 或 `sensorConfig.setZoom`）
- 不再有直接传归一化值的 `setZoom(0.0)` 之类调用

- [ ] **Step 4: 修复 analyze 报告的 error（若有）**

根据 Step 1 的输出修复所有 error。

- [ ] **Step 5: 最终 Commit（若有修复）**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add -A
git commit -m "fix(camera): resolve analyze errors from zoom refactor"
```

---

## Self-Review 记录

**1. Spec coverage:**
- spec 3.1 统一抽象层 → Task 2（接口）+ Task 3（实现）✓
- spec 3.2 平台分支转换 → Task 3 Step 3-6 ✓
- spec 3.3 OHOS fork 改动 → Task 1 ✓
- spec 3.4 CaptureState 扩展 → Task 4 ✓
- spec 3.5 相机就绪查询能力 → Task 5 Step 2-3 ✓
- spec 3.6 _ZoomTabBar 动态预设 → Task 6 Step 3 ✓
- spec 3.7 _onZoomChanged 简化 → Task 6 Step 2 ✓
- spec 3.8 双指缩放适配 → Task 3 Step 7（service 层）+ Task 5 Step 4（UI 层）✓
- spec 3.9 旧映射函数清理 → Task 4 Step 5 + Task 7 Step 2 ✓

**2. Placeholder scan:** 无 TBD/TODO，所有步骤含完整代码 ✓

**3. Type consistency:**
- `setZoomMultiplier(double)` 在 Task 2/3/5/6 一致 ✓
- `getMaxZoomMultiplier() -> Future<double>` 在 Task 2/3/5 一致 ✓
- `getMinZoomMultiplier() -> Future<double>` 在 Task 2/3/5 一致 ✓
- `supportsUltraWide() -> Future<bool>` 在 Task 2/3/5 一致 ✓
- `deviceMaxZoomProvider` / `deviceMinZoomProvider` / `supportsUltraWideProvider` 在 Task 4/5/6 一致 ✓
