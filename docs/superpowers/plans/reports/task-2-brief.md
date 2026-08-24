# Task 2 简报 — iOS 原生传感器级白平衡（AVFoundation）

来源计划：`docs/superpowers/plans/2026-08-22-white-balance.md` 的 Task 2。

## 目的
在本地 `packages/camerawesome`（iOS/Android 共用包）的 **iOS 原生层** AFP 真实白平衡：把 Task 1 里 `setWhiteBalance` 的 Dart 占位改为真正走通道，并在 ObjC 端用 AVFoundation 实现「预设 + 手动色温」。

## 前置事实（Task 1 已核实）
- 该包 Dart `CamerawesomePlugin.setBrightness` → `CameraInterface().setCorrection(double brightness)`（Pigeon 通道，iOS/Android 同名）。
- 该包当前 Pigeon `CameraInterface` **无** `setWhiteBalance` 通道；Task 1 已留 `static Future<void> setWhiteBalance(String mode, int? k)` 占位在 `packages/camerawesome/lib/camerawesome_plugin.dart`（当前 `return Future<void>.value();`）。**本任务要把它改写为真实通道调用。**

## 需要你先读并照抄的「调用链模板」
iOS 侧 `setBrightness` 的完整调用链（逐文件照抄这个结构新增 `setWhiteBalance`）：
1. Dart 层：`packages/camerawesome/lib/camerawesome_plugin.dart` → `setBrightness` 调的 `CameraInterface().setCorrection(...)`。
2. Pigeon 定义：`packages/camerawesome/lib/pigeon.dart`（或实际生成的 pigeon 文件）里 `setCorrection` 的声明与其在 iOS/Android 的注册方法名。
3. iOS 生成实现：`packages/camerawesome/ios/Classes/Pigeon/Pigeon.h` + `Pigeon.m`（`setCorrection`/`setCorrectionBrightness` 的协议方法、通道注册、handler）。
4. 转发实现：`packages/camerawesome/ios/Classes/CamerawesomePlugin.m`（实现接口方法 → 调 `[_camera setBrightness:]`）。
5. 最终原生：`packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m` 的 `- (void)setBrightness:`（约 L290）。

**务必先读这 5 处，完全摸清 `setBrightness` 从 Dart 到 ObjC 的参数名、类名、selector、通道 key 的写法，再镜像新增 `setWhiteBalance`。**

## 目标签名（保持与 Dart 一致）
- Dart（改写后）：`static Future<void> setWhiteBalance(String mode, int? k)`，body 调 `CameraInterface().setWhiteBalance(mode, k)`（新 Pigeon 方法）。
- Pigeon 新方法（iOS+Android 共享，Task 3 也会用）：
  - 需同时给 Dart pigeon 定义 + iOS(ObjC) + Android(Pigeon.kt，可先在 Task 3 补) —— 若本仓 Pigeon 为生成物，**手动**在各侧补段，保持一致。
  - 命名建议 `setWhiteBalance`，参数 `(String mode, int? temperatureK)`。
- ObjC CameraAwesomePlugin 实现方法：`setWhiteBalance:(NSString*)mode temperatureK:(NSNumber* _Nullable)k error:(FlutterError**)err` → `[_camera setWhiteBalance:mode temperatureK:k error:err]`。
- CameraPreview.m 新增：
  ```objc
  - (void)setWhiteBalance:(NSString *)mode temperatureK:(NSNumber *_Nullable)k
                    error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
    NSError *e = nil;
    if (![_captureDevice lockForConfiguration:&e]) {
      *error = [FlutterError errorWithCode:@"WB_LOCK_ERR" message:[e localizedDescription] details:nil];
      return;
    }
    if (k != nil) {
      // 手动色温：用目标 K 得到 gains，锁定
      AVCaptureWhiteBalanceTemperatureAndTintValues t =
          [_captureDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:
              AVCaptureWhiteBalanceTemperatureAndTintValuesMake([k floatValue], 0.0f)];
      if (![_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:t.redGain
                                                                      greenGain:t.greenGain
                                                                        blueGain:t.blueGain
                                                           completionHandler:nil]) {
        *error = [FlutterError errorWithCode:@"WB_SET_ERR" message:@"lock wb gains failed" details:nil];
      }
    } else if ([mode isEqualToString:@"auto"]) {
      // 恢复自动（连续自动白平衡）
      AVCaptureWhiteBalanceMode m = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
      if ([_captureDevice isWhiteBalanceModeSupported:m]) _captureDevice.whiteBalanceMode = m;
    } else {
      // 模式预设：映射到目标 K 再锁定
      float presetK = 5500.0f;
      if      ([mode isEqualToString:@"daylight"])     presetK = 5500.0f;
      else if ([mode isEqualToString:@"cloudy"])       presetK = 6500.0f;
      else if ([mode isEqualToString:@"fluorescent"])  presetK = 4200.0f;
      else if ([mode isEqualToString:@"incandescent"]) presetK = 3000.0f;
      AVCaptureWhiteBalanceTemperatureAndTintValues t =
          [_captureDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:
              AVCaptureWhiteBalanceTemperatureAndTintValuesMake(presetK, 0.0f)];
      [_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:t.redGain
                                                                greenGain:t.greenGain
                                                                  blueGain:t.blueGain
                                                     completionHandler:nil];
    }
    [_captureDevice unlockForConfiguration];
  }
  ```

## 步骤
1. 读上面 5 处模板，确认 iOS Pigeon 通道命名与接线细节。
2. 在 Pigeon 层与 Dart 层新增 `setWhiteBalance(String mode, int? temperatureK)` 通道（iOS 侧 ObjC 实现 + 注册；`packages/camerawesome/lib/camerawesome_plugin.dart` 的 `setWhiteBalance` 改为真实调用；`lib/pigeon.dart` 相应新增）。Android 侧 Pigeon 通道留给 Task 3，但 Dart 侧 `CameraInterface().setWhiteBalance` 必须能在 analyze 通过。
3. CameraAwesomePlugin.m 与 CameraPreview.m 加入上述实现。
4. 验证：`flutter analyze` 无新增错误。**本机无 iOS 工具链，无法真编译**；请自行 Read 核对 API：`deviceWhiteBalanceGainsForTemperatureAndTintValues:`、`setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:greenGain:blueGain:completionHandler:`、`isWhiteBalanceModeSupported:` 名称拼写与 AVFoundation 一致。
5. Commit：
   `git add packages/camerawesome`
   `git commit -m "feat(camera): iOS 传感器级白平衡 (AVFoundation temp+tint)"`
   `git push origin master ; git push github master`

## 注意
- 只改 `packages/camerawesome`；不要动 `camerawesome_ohos`、App 业务、游离 WIP。
- Android（Pigeon.kt）的实现与回调由 Task 3 负责；**你只需保证 iOS 侧 + Dart 共享层自洽且 analyze 通过**。若 Android 侧缺通道导致 analyze 报错，在 Dart 侧用与 Task 1 一致的相容写法并在注释标注「Android 通道由 Task 3 实现」。
- 完成后写报告 `docs/superpowers/plans/reports/task-2-report.md`（不 commit）。