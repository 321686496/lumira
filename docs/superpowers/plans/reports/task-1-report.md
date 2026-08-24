# Task 1 报告 — 白平衡共享模型 + camerawesome 插件 Dart 接口

状态：**DONE**

## 本任务产物
- 新建 `lumira_app_flutter/lib/features/capture/services/white_balance.dart`
  - `enum WhiteBalanceMode { auto, daylight, cloudy, fluorescent, incandescent }`
  - `class WhiteBalanceSettings`：`mode` / `temperatureK` / `copyWith` / `isAuto` / `operator ==` / `hashCode`（用 `Object.hash(mode, temperatureK)`），无 Dart 3 records。
- 新建（测试）`lumira_app_flutter/test/features/capture/services/white_balance_test.dart`（TDD：先写测试 → 确认 RED → 实现 → 确认 GREEN）。
- 修改 `lumira_app_flutter/packages/camerawesome/lib/camerawesome_plugin.dart`：新增静态方法 `setWhiteBalance(String mode, int? k)`。
- 修改 `lumira_app_flutter/packages/camerawesome_ohos/lib/camerawesome_plugin.dart`：新增同样签名的静态方法。

## 两个包的通道命名惯例（关键发现）
- **`camerawesome`（iOS/Android）**：`setBrightness(double)` 实现体调用 `CameraInterface().setCorrection(brightness)`（`pigeon.dart` 为 `Future<void> setCorrection(double arg_brightness)`）。即该包现有“画面校正”通道方法名是 **`setCorrection`**，并非预想中的 `setCorrectionBrightness`。
- **`camerawesome_ohos`（HarmonyOS）**：同样调用 `CameraInterface().setCorrection(brightness)`（`pigeon.dart` 为 `Future<void> setCorrection(double arg_brightness)`）。
- 两包 Pigeon `CameraInterface` **均无** `setWhiteBalance`（或任何 white/balance 相关）通道方法。

## setWhiteBalance 实现方式（兼容写法）
由于两个包当前 Pigeon 接口都没有接收 `(mode, k)` 的白平衡通道方法，若直接写 `CameraInterface().setWhiteBalance(mode, k)` 会触发 analyze “方法未定义”。因此按简报步骤 6 采用兼容写法：

```dart
// 原生通道由 Task 2/3/4 实现：届时将实现为
// `return CameraInterface().setWhiteBalance(mode, k);`（Pigeon 接口当前尚无该通道方法）。
static Future<void> setWhiteBalance(String mode, int? k) {
  return Future<void>.value();
}
```

`mode`/`k` 参数保留（签名三端一致），实现体为占位，确保 analyze 通过；真调用由 Task 2/3/4 落点。两包签名完全一致。

## 验证
- `flutter test test/features/capture/services/white_balance_test.dart` → **3/3 通过**（默认 auto + temperatureK null + isAuto true；copyWith 后非 auto；相等性与 hashCode 一致）。
- `flutter analyze` → **无新增错误/警告**。全仓 403 条均为既有 `info` 级 lint（`avoid_print`、`unnecessary_import`、`prefer_const` 等，与本次改动无关）；本次新增/修改文件（`white_balance.dart`、测试、两个 plugin.dart）均无 error/warning。

## Commit
- Hash：`930e387`
- 提交信息：`feat(camera): 白平衡共享模型与插件 Dart 接口`
- 已推送：`origin`（gitee）+ `github` 均 `master → 930e387`。
- 未触碰游离 WIP：`global_search_page.dart`、`templates_page.dart`（保持未暂存修改）。

## 关注点
1. **占位实现**：`setWhiteBalance` 当前返回 `Future.value()`，未真正走通道。Task 2/3/4 需回归并替换为真实 `CameraInterface().setWhiteBalance(...)` 调用。
2. **BOM 副作用**：编辑 `camerawesome_ohos/lib/camerawesome_plugin.dart` 时，文件首行原有的 UTF-8 BOM 被去除（diff 显示第 1 行 `import 'dart:async';` 变化）。不影响 Dart 编译/运行，但属计划外字节差异。