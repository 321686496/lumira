# Task 1 简报 — 白平衡共享模型 + camerawesome 插件 Dart 接口

来源计划：`docs/superpowers/plans/2026-08-22-white-balance.md` 的 Task 1。

## 目的
建立传感器级白平衡跨三端的 Dart 侧基础：
- **A. App 级共享模型** `WhiteBalanceSettings`（可单测），供后续 `CameraService` / param_panel 使用。
- **B. 两个 camerawesome 包（`camerawesome` iOS/Android、`camerawesome_ohos`）的 Dart 插件静态方法** `setWhiteBalance(String mode, int? k)`，先接通方法通道（实现体里调各自平台的 `CameraInterface().setWhiteBalance(...)`）。

> 方法通道原生实现的真正落点在 Task 2/3/4；本任务先在两个包的 Dart 层把方法 + 通道调用定下来并保证 analyze 通过。

## 文件
- Create: `lumira_app_flutter/lib/features/capture/services/white_balance.dart`
- Create(test): `lumira_app_flutter/test/features/capture/services/white_balance_test.dart`（**先写测试，TDD**）
- Modify: `lumira_app_flutter/packages/camerawesome/lib/camerawesome_plugin.dart`（iOS/Android 包，加静态方法）
- Modify: `lumira_app_flutter/packages/camerawesome_ohos/lib/camerawesome_plugin.dart`（OHOS 包，加静态方法）

## 关键签名（三端必须一致，禁止 Dart 3 records）

A. `white_balance.dart`:
```dart
enum WhiteBalanceMode { auto, daylight, cloudy, fluorescent, incandescent }

class WhiteBalanceSettings {
  const WhiteBalanceSettings({this.mode = WhiteBalanceMode.auto, this.temperatureK});
  final WhiteBalanceMode mode;
  final int? temperatureK; // 3000..8000，仅非 auto 时生效
  WhiteBalanceSettings copyWith({WhiteBalanceMode? mode, int? temperatureK});
  bool get isAuto => mode == WhiteBalanceMode.auto;
  @override bool operator ==(Object other);
  @override int get hashCode; // 用 Object.hash(mode, temperatureK)
}
```

B. 插件方法（每个包的 `CamerawesomePlugin` 静态方法，签名一致）：
```dart
/// mode ∈ {auto,daylight,cloudy,fluorescent,incandescent}; k 为 3000..8000 或 null
static Future<void> setWhiteBalance(String mode, int? k) {
  return CameraInterface().setWhiteBalance(mode, k);
}
```

## 步骤（TDD）
1. 写测试 `white_balance_test.dart`：
   - 默认是 auto、`temperatureK == null`、`isAuto == true`
   - `copyWith(mode: daylight, temperatureK: 6000)` 后 `isAuto == false`
   - 相等性与 hashCode 一致
2. 运行 `flutter test test/features/capture/services/white_balance_test.dart` → 应先 FAIL（文件/类型不存在）。
3. 实现 `white_balance.dart`，再用 `flutter test` 确认 PASS。
4. **读两个包各自的现有 `setBrightness` 实现，核对真实通道方法名**：
   - `camerawesome`（iOS/Android）：`packages/camerawesome/lib/camerawesome_plugin.dart` 里 `setBrightness` 到底调用 `CameraInterface().setCorrectionBrightness(...)` 还是别的？溯源到其 `CameraInterface`（pigeon 生成）。
   - `camerawesome_ohos`：`packages/camerawesome_ohos/lib/camerawesome_plugin.dart` `setBrightness`(约 L399) 调 `CameraInterface().setCorrection(brightness)`。
   - **据此决定新方法在各自包里的通道方法名**（跟随各自包的命名习惯，OHOS 用 `setCorrection` 风格、native 包用 `setCorrectionBrightness` 风格）。
   - **若某个包的 Pigeon 通道方法尚不存在**，本任务可以先定义一个与原生待实现的调用（如 `CameraInterface().setWhiteBalance(mode, k)`），并**在代码注释里标注**「原生通道由 Task 2/3/4 实现」。
5. 两个包各加静态方法 `setWhiteBalance(String mode, int? k)`，模式映射 `WhiteBalanceMode.name`（`'auto'|'daylight'|'cloudy'|'fluorescent'|'incandescent'`）。
6. `flutter analyze` 无新增错误。若 `CameraInterface().setWhiteBalance` 尚不存在导致 analyze 报"方法未定义"，用兼容写法（如先调 `CameraInterface` 现有通道方法接收 `(mode, k)` 两参数重载）并标注，或按包内实际可用通道写。**以 analyze 通过且签名三端一致为准。**
7. Commit：
   `git add lumira_app_flutter/lib/features/capture/services/white_balance.dart lumira_app_flutter/test/features/capture/services/white_balance_test.dart lumira_app_flutter/packages/camerawesome lumira_app_flutter/packages/camerawesome_ohos`
   `git commit -m "feat(camera): 白平衡共享模型与插件 Dart 接口"`
   push：`git push origin master ; git push github master`

## 注意
- 只提交本任务涉及文件；不要动 `global_search_page.dart`、`templates_page.dart`（游离 WIP）。
- 全程 PowerShell；不要用 Dart 3 records。
- 完成后写报告到 `docs/superpowers/plans/reports/task-1-report.md`（不 commit）。