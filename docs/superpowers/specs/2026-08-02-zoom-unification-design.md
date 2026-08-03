# 缩放能力统一实现设计

> 日期：2026-08-02
> 状态：已批准，进入实施
> 范围：lumira_app_flutter 拍摄页缩放功能 + OHOS camerawesome fork

## 1. 目标

统一三端（OHOS / Android / iOS）的缩放 API 语义，使拍摄页缩放功能在三端表现一致；对不支持超广角的端（iOS）隐藏 0.5x 操作项。

## 2. 背景与约束

### 2.1 camerawesome 1.4.0 三端 setZoom 语义差异（源码调研结论）

| 平台 | setZoom 参数语义 | 底层调用 | minZoom | 超广角(0.5x) |
|------|-----------------|---------|---------|-------------|
| OHOS | 真实倍数 (0.5/1.0/2.0) | `session.setZoomRatio(zoom)` | `getZoomRatioRange()[0]`（可 < 1.0） | 原生支持 |
| Android | [0,1] 归一化 | `cameraControl.setLinearZoom(zoom)` | `zoomState.minZoomRatio`（可 < 1.0） | `setZoom(0.0)` 自动到 minZoomRatio |
| iOS | [0,1] 归一化 | `videoZoomFactor = value*(maxZoom-1)+1` | 硬编码 1.0 | 不可用（minZoom 写死 1.0） |

`getMaxZoom()` 三端均返回真实最大倍数。

### 2.2 不可用能力（明确排除）

- ISO 调整：camerawesome 1.4.0 三端均未封装
- 快门速度调整：camerawesome 1.4.0 三端均未封装
- 手动曝光模式：仅支持 EV 补偿（setBrightness），不支持锁定/自定义曝光

### 2.3 OHOS fork 位置

- 仓库：`https://gitcode.com/CPF-Flutter/fluttertpc_camerawesome.git`，分支 `master`，子路径 `ohos`
- 本地缓存：`E:/flutter/pubcache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc`
- fork 当前暴露 `getMaxZoom()` 但未暴露 `getMinZoom()`
- `CameraState.ets:1010` 的 `getMaxZoom()` 通过遍历 `getZoomRatioRange()` 取最大值；minZoom 即该数组最小值

## 3. 架构设计

### 3.1 统一抽象层

CameraService 接口对外暴露**真实倍数**语义（0.5/1.0/2.0/3.0/5.0），平台分支转换在 CamerawesomeCameraService 内部完成。

```dart
abstract class CameraService {
  // 现有方法保持不变...

  /// 设置缩放倍数（真实倍数，如 0.5/1.0/2.0）
  void setZoomMultiplier(double multiplier);

  /// 获取设备最大缩放倍数（真实倍数）
  Future<double> getMaxZoomMultiplier();

  /// 获取设备最小缩放倍数（真实倍数，iOS=1.0，OHOS/Android 可 < 1.0）
  Future<double> getMinZoomMultiplier();

  /// 是否支持超广角（minZoom < 1.0）
  Future<bool> supportsUltraWide();
}
```

### 3.2 平台分支转换

**setZoomMultiplier**：
- OHOS：`CamerawesomePlugin.setZoom(multiplier)` 直接传真实倍数
- iOS/Android：`normalized = (multiplier - minZoom) / (maxZoom - minZoom)`，clamp [0,1]，调用 `sensorConfig.setZoom(normalized)`

**getMinZoomMultiplier**：
- OHOS：调用新增的 `CamerawesomePlugin.getMinZoom()`，失败 fallback 0.5
- iOS：固定返回 1.0（camerawesome 1.4.0 硬编码）
- Android：假设 0.5（camerawesome 未暴露 `getMinZoomRatio()`，但 `setLinearZoom(0.0)` 必然到 minZoomRatio，UI 显示 0.5x 时下发归一化 0.0，视觉正确）

**supportsUltraWide**：`getMinZoomMultiplier() < 1.0`

### 3.3 OHOS fork 改动

在 fork 中新增 `getMinZoom()` 接口，镜像现有 `getMaxZoom()` 实现：

**文件 1：`ohos/pigeons/interface.dart`**（第 296 行后追加）
```dart
double getMinZoom();
```

**文件 2：`ohos/ohos/src/main/ets/components/cameraX/CameraState.ets`**（第 1021 行后追加）
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

**文件 3：`ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets`**（第 286 行后追加）
```typescript
getMinZoom(): number {
  Logger.debug(TAG, `getMinZoom is called`);
  return this.cameraState!!.getMinZoom()
}
```

**文件 4：重新生成 pigeon 绑定**
- `lib/pigeon.dart`：运行 `flutter pub run pigeon --input ohos/pigeons/interface.dart` 重新生成
- `lib/camerawesome_plugin.dart`：手动追加（若 pigeon 未自动生成顶层方法）
```dart
static Future<num?> getMinZoom() {
  return CameraInterface().getMinZoom();
}
```

### 3.4 CaptureState 扩展

新增三个 provider 记录设备缩放能力：

```dart
static final deviceMaxZoomProvider = StateProvider<double?>((ref) => null);
static final deviceMinZoomProvider = StateProvider<double?>((ref) => null);
static final supportsUltraWideProvider = StateProvider<bool>((ref) => false);
```

`zoomProvider` / `apparentZoomProvider` 语义改为**真实倍数**（默认 1.0）。

### 3.5 相机就绪时查询能力

`camera_preview.dart` 的 `_onCameraReady`：
1. 设置闪光灯、EV（保持现有逻辑）
2. 异步调用 `_queryZoomCapabilities`：查询 maxZoom/minZoom/supportsUltraWide，写入 providers
3. 重置缩放为 1.0x，下发 `setZoomMultiplier(1.0)`

查询失败不阻塞相机就绪，fallback 值：maxZoom=10.0、minZoom=1.0、supportsUltraWide=false。

### 3.6 _ZoomTabBar 动态预设

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

前摄固定 `[1.0, 2.0]`（+ 0.5 若支持超广角）；后摄按 maxZoom 动态扩展。

### 3.7 _onZoomChanged 简化

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

### 3.8 双指缩放手势适配

`CamerawesomeCameraService.buildPreview` 的 onScale 回调按平台转换：

- OHOS：`onScaleZoom?.call(scale)`（scale 已是真实倍数）
- iOS/Android：`multiplier = minZoom + (maxZoom - minZoom) * scale`，`onScaleZoom?.call(multiplier)`

上层 `camera_preview.dart` 的 `onScaleZoom` 回调统一接收真实倍数，直接调 `_onZoomChanged`。

### 3.9 旧映射函数清理

移除 `CaptureState` 中的：
- `displayToCameraMultiplier`（已在上一轮重置中移除）
- `zoomMultiplierToNormalized` / `normalizedToZoomMultiplier`（若已无引用）

保留 `zoomRangeForFacing`（用于 fallback），但改为返回真实倍数范围 `[minZoom, maxZoom]`。

## 4. 数据流

```
相机就绪 → _onCameraReady
            ├─ setFlashMode / setBrightness
            ├─ _queryZoomCapabilities → deviceMaxZoom/Min/SupportsUltraWide providers
            └─ setZoomMultiplier(1.0)

_ZoomTabBar ──读 deviceMaxZoom + supportsUltraWide──→ _getPresets → 动态 Tab
     │ Tab onTap / 水平拖动
     ↓
_onZoomChanged(真实倍数)
     ├─ clamp(minZoom, maxZoom)
     ├─ 写 zoomProvider / apparentZoomProvider
     └─ setZoomMultiplier(真实倍数)
                                    ├─ OHOS: CamerawesomePlugin.setZoom(真实倍数)
                                    └─ iOS/Android: 归一化 → sensorConfig.setZoom([0,1])

双指缩放 → onScale
     ├─ OHOS: 透传真实倍数 → onScaleZoom
     └─ iOS/Android: 归一化 → 真实倍数 → onScaleZoom
                                ↓
                          _onZoomChanged(真实倍数)
```

## 5. 改动文件清单

### 5.1 OHOS fork（gitcode 仓库 master 分支）
1. `ohos/pigeons/interface.dart` — 加 `getMinZoom()` 接口
2. `ohos/ohos/src/main/ets/components/cameraX/CameraState.ets` — 实现 `getMinZoom()`
3. `ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets` — 转发 `getMinZoom()`
4. `lib/pigeon.dart` — 重新生成 pigeon 绑定
5. `lib/camerawesome_plugin.dart` — 加 `static Future<num?> getMinZoom()`

### 5.2 lumira_app_flutter
6. `lib/features/capture/services/camera_service.dart` — 接口加 4 个方法
7. `lib/features/capture/services/camerawesome_camera_service.dart` — 平台分支实现
8. `lib/features/capture/data/capture_state.dart` — 加 3 个 provider，zoomProvider 改语义
9. `lib/features/capture/widgets/camera_preview.dart` — `_onCameraReady` 查询能力，onScaleZoom 适配
10. `lib/features/capture/pages/capture_page.dart` — `_ZoomTabBar` 动态预设，`_onZoomChanged` 简化

## 6. 测试策略

### 6.1 静态验证
- `flutter analyze` 无 error
- 旧映射函数无残留引用

### 6.2 手动验证（需真机）
- OHOS：0.5x Tab 显示，点击后视野变广；5x Tab 显示（若 maxZoom≥5）
- Android：0.5x Tab 显示，`setLinearZoom(0.0)` 到超广角
- iOS：0.5x Tab 隐藏（supportsUltraWide=false），1x/2x 正常

### 6.3 边界场景
- 查询 maxZoom 失败：fallback 10.0，5x Tab 显示
- 查询 minZoom 失败：fallback 1.0，0.5x Tab 隐藏
- 切前后摄：重新查询能力，重置 1x

## 7. 风险与缓解

| 风险 | 缓解 |
|------|------|
| OHOS fork 改动需重新发布到 gitcode 才能被 pub get 拉取 | 修改本地 git cache 路径的文件，pub get 不会覆盖已存在的 git checkout（需验证）；或临时改 pubspec 指向本地 path |
| Android minZoom 假设 0.5 但实际可能 0.6/0.7 | `setLinearZoom(0.0)` 必然到 minZoomRatio，UI 显示 0.5x 视觉正确，差异在 0.5 vs 0.6 不可感知 |
| pigeon 重新生成需 flutter 环境 | 若无法运行 pigeon，手动编辑生成的 `pigeon.dart` 文件 |
| iOS 端 0.5x Tab 隐藏后 UI 间距变化 | `_ZoomTabBar` 用 ListView/Wrap 自适应布局，预设数量变化不影响排版 |
