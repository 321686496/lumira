# 拍摄页传感器级白平衡（三端）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在拍摄页提供「预设 + 手动色温」的传感器级白平衡，三端（iOS/Android/OHOS）取景实时生效、拍照直出即带白平衡。

**Architecture:** 沿用 camerawesome 现有「Dart `SensorConfig` 订阅 → `CamerawesomePlugin.setX()` → 平台原生」链路。新增 `setWhiteBalance(mode, k)` 贯通四层；App 层 `CameraService` 新增方法透传；param_panel 相机 Tab 新增 UI。OHOS camerawesome 先本地化进 `packages/`。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁 Dart 3 records）；camerawesome（iOS/Android 本地 patch 1.4.0）+ camerawesome_ohos（本地化）；iOS AVFoundation / Android CameraX / OHOS CameraKit。

## 全局约束（Global Constraints）
- Dart 2.19.6：**禁止 Dart 3 records**，用 class / `Object.hash()`。
- 三端 Dart 侧新方法签名**完全一致**。
- UI 严格遵循「UI 风格 + 主题」（`appThemeProvider` + `uiStyleProvider`），禁止硬编码颜色/阴影，复用 param_panel 现有 pill / slider 组件。
- 白平衡为**仅实时会话调节**，不写入模板 `CameraParams`。
- 手动色温 K 统一 **3000–8000K**，中心 5500K；预设：Auto / 日光 / 阴天 / 荧光 / 白炽。
- OHOS camerawesome 本地化后 **pubspec 不得改回 `git:`**。
- OHOS 原生改动需重新编译安装（无热重载）。
- 每端完成一块 commit；commit 后 `git push origin master`（gitee）+ `git push github master`（遵循 AGENTS.md）。

---

### Task 0: OHOS camerawesome 本地化（前置，无功能）

**Files:**
- Create: `lumira_app_flutter/packages/camerawesome_ohos/`（整体拷贝）
- Modify: `lumira_app_flutter/pubspec.yaml:30-34`

**Interfaces:** Produces 本地 path 依赖 `camerawesome_ohos`；现有 `import 'package:camerawesome_ohos/camerawesome_plugin.dart'` 保持不变。

- [ ] **Step 1: 确认 pubcache 源完整**：`Test-Path 'E:\flutter\pubcache\git\fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc\ohos\pubspec.yaml'` → `True`
- [ ] **Step 2: 拷贝**：
  ```powershell
  Copy-Item -Recurse -Force 'E:\flutter\pubcache\git\fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc\ohos' 'e:\Project\photo_post\lumira_app_flutter\packages\camerawesome_ohos'
  Remove-Item -Recurse -Force 'e:\Project\photo_post\lumira_app_flutter\packages\camerawesome_ohos\.git' -ErrorAction SilentlyContinue
  ```
  Verify `Test-Path '...\packages\camerawesome_ohos\pubspec.yaml'` → `True`
- [ ] **Step 3: 改 pubspec.yaml** 将 `camerawesome_ohos` 一段：
  ```yaml
  camerawesome_ohos:
    path: packages/camerawesome_ohos
  ```
- [ ] **Step 4: 刷新依赖**：`cd lumira_app_flutter; flutter pub get`
  验证：`flutter pub get` 成功无 git fetch 报错；`pubspec.lock` 中 `camerawesome_ohos` 的 source 变本地、出现 `path` 字段。
- [ ] **Step 5: 冒烟**：`flutter analyze` 不新增错误（本地化不改代码，应 0 净变化）。
- [ ] **Step 6: Commit + push**
  ```bash
  git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock lumira_app_flutter/packages/camerawesome_ohos
  git commit -m "chore(camera): 本地化 camerawesome_ohos 依赖以扩展原生白平衡"
  git push origin master ; git push github master
  ```

---

### Task 1: 共享 Dart 层 — WhiteBalance 模型 + CamerawesomePlugin.setWhiteBalance

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/services/white_balance.dart`（App 级共享模型）
- Modify: `lumira_app_flutter/packages/camerawesome/lib/src/.../`（原生包的 Dart 层，跟随现有 `setBrightness` 放置）
  - `packages/camerawesome/lib/camerawesome_plugin.dart`（新增静态方法）
  - `packages/camerawesome/lib/src/orchestrator/models/sensor_config.dart`（新增字段 + setter + 订阅）

> 说明：Task 1 在本任务先建 **App 级模型** `WhiteBalanceSettings`（供 Task 5/6 用）；camerawesome 原生 Dart 层的 `setWhiteBalance(mode, k)` 方法签名在本任务定稿，其 Dart ↔ 原生通道实现分散在 Task 2/3/4 的三端原生层。

**Interfaces:**
- Produces (App 模型):
  ```dart
  enum WhiteBalanceMode { auto, daylight, cloudy, fluorescent, incandescent }
  class WhiteBalanceSettings {
    const WhiteBalanceSettings({this.mode = WhiteBalanceMode.auto, this.temperatureK});
    final WhiteBalanceMode mode;
    final int? temperatureK; // 3000..8000，仅非 auto 时生效
    WhiteBalanceSettings copyWith({WhiteBalanceMode? mode, int? temperatureK});
    bool get isAuto => mode == WhiteBalanceMode.auto;
    @override bool operator ==(Object other);
    @override int get hashCode; // Object.hash(...)
  }
  ```
- Produces (camerawesome 原生 Dart，三端一致签名):
  ```dart
  // OK 写法（勿用 Dart3 records）
  static Future<void> setWhiteBalance(String mode, int? k) // 在 CamerawesomePlugin
  void setWhiteBalance(WhiteBalanceModeMode mode, int? temperatureK) // 在 SensorConfig → 内部订阅调用 plugin
  ```
- Consumes: 现有 `SensorConfig`（参考 `setBrightness` L79-165 native 包、`sensor_config.dart` L37-77 OHOS 包）。

- [ ] **Step 1: 写 App 模型测试失败**
  创建 `lumira_app_flutter/test/features/capture/services/white_balance_test.dart`：
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:lumira_app/features/capture/services/white_balance.dart';

  void main() {
    test('WhiteBalanceSettings defaults to auto, no temp', () {
      final s = const WhiteBalanceSettings();
      expect(s.mode, WhiteBalanceMode.auto);
      expect(s.temperatureK, isNull);
      expect(s.isAuto, isTrue);
    });
    test('copyWith changes mode and temp', () {
      const s = WhiteBalanceSettings();
      final c = s.copyWith(mode: WhiteBalanceMode.daylight, temperatureK: 6000);
      expect(c.mode, WhiteBalanceMode.daylight);
      expect(c.temperatureK, 6000);
      expect(c.isAuto, isFalse);
    });
    test('equality and hash', () {
      const a = WhiteBalanceSettings(mode: WhiteBalanceMode.cloudy, temperatureK: 5000);
      const b = WhiteBalanceSettings(mode: WhiteBalanceMode.cloudy, temperatureK: 5000);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  }
  ```
- [ ] **Step 2: 运行确认失败**：`flutter test test/features/capture/services/white_balance_test.dart` → FAIL（找不到 white_balance.dart / 类型未定义）
- [ ] **Step 3: 创建 App 模型**
  在 `lumira_app_flutter/lib/features/capture/services/white_balance.dart` 实现 `WhiteBalanceMode` + `WhiteBalanceSettings`（见 Interfaces 签名，用 `Object.hash`，`copyWith` 用 `??` 保留旧值）。**禁止 Dart 3 records。**
- [ ] **Step 4: 运行确认通过**：`flutter test test/features/capture/services/white_balance_test.dart` → PASS
- [ ] **Step 5: 在 camerawesome 原生包定稿 Dart 方法签名**
  在 `packages/camerawesome/lib/camerawesome_plugin.dart`（仿 `setBrightness` L399 附近）加入并在 `sensor_config.dart`（仿现有 `setBrightness` L79-165）加入接口与订阅桩，先留 TODO 体，通道实现在 Task 2/3/4 填。
  ```dart
  // camerawesome_plugin.dart
  /// mode ∈ {auto,daylight,cloudy,fluorescent,incandescent}; k 为 3000..8000 或 null
  static Future<void> setWhiteBalance(String mode, int? k) {
    return CameraInterface().setWhiteBalance(mode, k);
  }
  ```
  > 注：此处假定原生包也用 Pigeon `CameraInterface`（与 OHOS 一致）；Task 2 会核对 iOS/Android 原生包的实际通道名，若不同则同步修正本方法体。
- [ ] **Step 6: 编译检查**：`flutter analyze` 无因新方法新增的错误（原生通道方法未实现会暂以 TODO 占位，analyze 可通过）。
- [ ] **Step 7: Commit + push**
  ```bash
  git add -A
  git commit -m "feat(camera): 白平衡共享模型与插件 Dart 接口"
  git push origin master ; git push github master
  ```

---

### Task 2: iOS 原生白平衡（AVFoundation）

**Files:**
- Modify: `packages/camerawesome/lib/pigeon.dart`（新增 `setWhiteBalance` 通道方法声明）— 或遵循本仓库实际 Pigeon 定义文件
- Modify: `packages/camerawesome/ios/Classes/Pigeon/Pigeon.h` / `Pigeon.m`（注册通道 + 转发到 `_camera`）
- Modify: `packages/camerawesome/ios/Classes/CamerawesomePlugin.m`（实现接口方法，调用 `_camera`）
- Modify: `packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m`（新增 `setWhiteBalance:` 原生实现）

**Interfaces:**
- Consumes: Task 1 的 Dart `CamerawesomePlugin.setWhiteBalance(String mode, int? k)`
- Produces: iOS 原生 `CameraPreview setWhiteBalance:mode k:temperatureK`（含 AVCaptureDevice 锁定 + 色温 + 恢复自动）

- [ ] **Step 1: 读现状**：读 `CameraPreview.m` L290-309（`setBrightness:`）作为模板；读 `CamerawesomePlugin.m` L193-267（Pigeon 转发）与 `Pigeon.m` L864-939（通道注册）。
- [ ] **Step 2: 在 iOS Pigeon 层加方法**（仿 `setCorrectionBrightness`/`setBrightness`），把 Dart `setWhiteBalance(mode, k)` 连到原生 `CameraPreview setWhiteBalance:mode k:temperatureK:`。
  需要同时改生成的 Pigeon.h/m 定义与注册；若本仓库无 Pigeon 再生成工具链，**手动**在 Pigeon.h 接口声明、Pigeon.m 的 registered 通道与 handler 各加一段，签名与 Dart 一致。
- [ ] **Step 3: 在 CameraPreview.m 实现**
  在 `setBrightness:` 之后新增，逻辑为：
  ```objc
  - (void)setWhiteBalance:(NSString *)mode k:(NSNumber *_Nullable)k
                    error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
    NSError *e = nil;
    if (![_captureDevice lockForConfiguration:&e]) {
      *error = [FlutterError errorWithCode:@"WB_LOCK_ERR" message:[e localizedDescription] details:nil];
      return;
    }
    if ([mode isEqualToString:@"auto"]) {
      if ([_captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
        _captureDevice.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
      }
    } else if (k) {
      AVCaptureWhiteBalanceTemperatureAndTintValues tempTint =
          [_captureDevice deviceWhiteBalanceGainsForTemperatureAndTintValues:
              AVCaptureWhiteBalanceTemperatureAndTintValuesMake([k floatValue], 0.0f)];
      if ([_captureDevice setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:tempTint.redGain
                                                                      greenGain:tempTint.greenGain
                                                                        blueGain:tempTint.blueGain
                                                                 completionHandler:nil]) {
        // 锁定完成，保持手动色温；无需额外动作
      }
    } else {
      // preset mode（非 auto 且无 k）：映射到对应 AVCaptureWhiteBalanceMode
      AVCaptureWhiteBalanceMode wbMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
      if ([mode isEqualToString:@"daylight"])   wbMode = AVCaptureWhiteBalanceModeLocked; // daylight→锁在 ~5500K
      // ... 按 preset 设默认 K 或映射支持的模式
      if ([_captureDevice isWhiteBalanceModeSupported:wbMode]) _captureDevice.whiteBalanceMode = wbMode;
    }
    [_captureDevice unlockForConfiguration];
  }
  ```
  > 细化：手动/预设模式统一走「先算某目标 K 的 gains → `setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains`」；预设 K 建议 daylight 5500 / cloudy 6500 / fluorescent 4200 / incandescent 3000。
- [ ] **Step 4: CamerawesomePlugin.m 转发**：实现接口方法，调用 `[_camera setWhiteBalance:mode k:k error:&err]`。
- [ ] **Step 5: 编译验证（iOS）**：`cd lumira_app_flutter; flutter build ios --no-codesign`（或 `--debug`）无编译错误。
- [ ] **Step 6: Commit + push**
  ```bash
  git add packages/camerawesome
  git commit -m "feat(camera): iOS 传感器级白平衡 (AVFoundation temp+tint)"
  git push origin master ; git push github master
  ```

---

### Task 3: Android 原生白平衡（CameraX）

**Files:**
- Modify: `packages/camerawesome/android/.../cameraX/CameraAwesomeX.kt`（新增 `override fun setWhiteBalance(...)`）
- Modify: `packages/camerawesome/android/.../cameraX/Pigeon.kt` 及 Dart `pigeon.dart`（新增通道方法，保持 iOS/Android Dart 签名一致）

**Interfaces:**
- Consumes: Task 1 Dart `CamerawesomePlugin.setWhiteBalance(String mode, int? k)`
- Produces: Android `CameraAwesomeX.setWhiteBalance(mode, k)` → `cameraControl.setWhiteBalanceMode(...)` + `setWhiteBalanceOffset(...)`

- [ ] **Step 1: 读现状**：读 `CameraAwesomeX.kt` L557-566（`setCorrection`，用 `cameraState.previewCamera?.cameraControl`）作为模板。
- [ ] **Step 2: Pigeon 层加方法**：在 Android `Pigeon.kt` 与 Dart `pigeon.dart` 加 `setWhiteBalance` 通道，签名 `(String mode, Integer k)`，接线到 `CameraAwesomeX.setWhiteBalance`。
- [ ] **Step 3: 实现 `setWhiteBalance`**
  ```kotlin
  @SuppressLint("RestrictedApi")
  override fun setWhiteBalance(mode: String, k: Int?) {
    val cc = cameraState.previewCamera?.cameraControl ?: return
    val wb = when (mode) {
      "auto" -> WhiteBalanceState.RANGE_WHITE_BALANCE_AUTO
      "daylight" -> WhiteBalanceState.RANGE_WHITE_BALANCE_DAYLIGHT
      "cloudy" -> WhiteBalanceState.RANGE_WHITE_BALANCE_CLOUDY_DAYLIGHT
      "fluorescent" -> WhiteBalanceState.RANGE_WHITE_BALANCE_FLUORESCENT
      "incandescent" -> WhiteBalanceState.RANGE_WHITE_BALANCE_INCANDESCENT
      else -> WhiteBalanceState.RANGE_WHITE_BALANCE_AUTO
    }
    cc.setWhiteBalanceMode(wb) // throws if unsupported → wrap try/catch CameraAccessException
    if (mode != "auto" && k != null) {
      // CameraX 仅支持 offset；k==5500 为中性 0，其它按比例映射
      val offset = ((k - 5500) / 1000f *.coerceIn(...)).coerceIn(WhiteBalanceState.OFFSET_INCREMENT /* ±... */)
      cc.setWhiteBalanceOffsetLinear(offset)  // 或 setWhiteBalanceOffset(wb, offset)，按 CameraX 版本 API
    }
  }
  ```
  > 细化：CameraX 无任意 K，`offset` 映射需按设备 offset 范围归一；实现时核对 CameraX 1.4.0 的 `setWhiteBalanceOffsetLinear` 是否存在，若无则用 `setWhiteBalanceOffset(WhiteBalanceState, Float)`，并 try/catch `CameraAccessException`。
- [ ] **Step 4: 编译验证（Android）**：`cd lumira_app_flutter; flutter build apk --debug` 无编译错误。
- [ ] **Step 5: Commit + push**
  ```bash
  git add packages/camerawesome
  git commit -m "feat(camera): Android 传感器级白平衡 (CameraX mode+offset)"
  git push origin master ; git push github master
  ```

---

### Task 4: OHOS 原生白平衡（CameraKit，本地化包内）

**Files:**
- Modify: `packages/camerawesome_ohos/lib/camerawesome_plugin.dart`（新增 `static Future<void> setWhiteBalance(String mode, int? k)` 调 `CameraInterface()`）
- Modify: `packages/camerawesome_ohos/ohos/src/main/ets/.../Pigeon*`（通道定义，若为生成物则手动补段）
- Modify: `packages/camerawesome_ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets`（新增 `setWhiteBalance(mode, k)` 调 `this.cameraState.setWhiteBalance(...)`）
- Modify: `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets`（新增 `camera.Input.setWhiteBalanceMode` / 色温控制）— 参阅 OHOS CameraKit `@hms.camera` / `@kit.CameraKit` API

**Interfaces:**
- Consumes: Task 1 Dart `CamerawesomePlugin.setWhiteBalance`
- Produces: OHOS `CameraMax`(CameraState) 白平衡模式 + 手动色温（保留 auto 时 `setLimitPose`/AWB 自动）

- [ ] **Step 1: 读现状**：读 `CameraAwesomeX.ets` L239-282（`setFlashMode`/`setCorrection`）与 `CameraState.ets` 中 `setExposureBias`/`setFlashFn` 下 Camera Kit 调用方式；确认所用 `import`（`@kit.CameraKit` 或旧 triggers）。
- [ ] **Step 2: OHOS Dart 插件加方法**：在 `packages/camerawesome_ohos/lib/camerawesome_plugin.dart` 仿 `setBrightness`(L399) 加 `setWhiteBalance(String mode, int? k)`。
- [ ] **Step 3: Pigeon/ets 通道**：手动在 OHOS Pigeon 通道定义与 `CameraAwesomeX.ets` 加 `setWhiteBalance(mode: string, k?: number)`，转发 `this.cameraState?.setWhiteBalanceFn(mode, k)`。
- [ ] **Step 4: CameraState 实现**
  在 `CameraState.ets` 新增：
  ```typescript
  setWhiteBalanceFn(mode: string, k: number | undefined): void {
    // auto → 恢复自动白平衡
    if (mode === 'auto' || k === undefined) {
      this.videoInput?.setWhiteBalanceMode(WhiteBalanceModeType.COLOR_TEMPERATURE_KELVIN, ...autoVal); // 按设备支持
      return;
    }
    // 手动色温：CameraOutput 的 WhiteBalanceModeType + 色温 K
    this.videoInput?.setWhiteBalanceMode(WhiteBalanceModeType.COLOR_TEMPERATURE_KELVIN, k);
  }
  ```
  > 细化：OHOS CameraKit 白平衡 API 为 `CameraInput.setWhiteBalanceMode(_mode, _value)`，需在 `createCamera` 成功后可用；手动色温模式值即开尔文。实现时在 `CameraState.ets` 内核对实际 `camera.Input`/`Camera` 实例与 `WhiteBalanceModeType` 枚举名（可能为 `WHITE_BALANCE_AUTO`、`WHITE_BALANCE_MANUAL` 或按 `livePhoto`/`photo` 输入不同）并适配。
- [ ] **Step 5: 编译验证（OHOS）**：在本机 HarmonyOS 工程中对 `packages/camerawesome_ohos/ohos` 执行相应 `hvigor`/DevEco 构建（或 `flutter build` 对应 Harmony target），确认 ets 无编译错。
- [ ] **Step 6: Commit + push**
  ```bash
  git add packages/camerawesome_ohos
  git commit -m "feat(camera): OHOS 传感器级白平衡 (CameraKit)"
  git push origin master ; git push github master
  ```

---

### Task 5: App 层 CameraService 接口 + 实现透传

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/services/camera_service.dart`（新增抽象方法）
- Modify: `lumira_app_flutter/lib/features/capture/services/camerawesome_camera_service.dart`（实现透传）

**Interfaces:**
- Consumes: Task 1 `WhiteBalanceSettings`；camerawesome 原生包 `setWhiteBalance`
- Produces: `CameraService.setWhiteBalance(WhiteBalanceSettings)` 抽象方法；`CamerawesomeCameraService` 实现（按平台调 `ca.CamerawesomePlugin.setWhiteBalance` 或 `ohos.CamerawesomePlugin.setWhiteBalance`）

- [ ] **Step 1: 接口新增**（`camera_service.dart`，放 `setBrightness` 之后）：
  ```dart
  /// 设置传感器级白平衡（预设 + 手动色温 K）。取景实时生效，直出即带。
  void setWhiteBalance(WhiteBalanceSettings settings);
  ```
  file 内顶部 import `white_balance.dart`。
- [ ] **Step 2: 实现透传**（`camerawesome_camera_service.dart`，仿 `setFlashMode`/`setBrightness`）：
  ```dart
  @override
  void setWhiteBalance(WhiteBalanceSettings settings) {
    final mode = settings.mode.name; // 'auto'|'daylight'|...
    try {
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
      } else {
        ca.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
      }
    } catch (e) {
      debugPrint('[camera] setWhiteBalance failed: $e');
    }
  }
  ```
- [ ] **Step 3: 编译/静态检查**：`flutter analyze` 无错误。
- [ ] **Step 4: Commit + push**
  ```bash
  git add lumira_app_flutter/lib/features/capture/services
  git commit -m "feat(camera): CameraService 暴露白平衡 setter 并透传三端"
  git push origin master ; git push github master
  ```

---

### Task 6: 拍摄页 param_panel 相机 Tab 白平衡 UI

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/param_panel.dart`（相机 Tab，L333-398 附近）
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart` 或持有 `CameraService` 的控制器（接线 `setWhiteBalance` 调用）

**Interfaces:**
- Consumes: Task 5 `CameraService.setWhiteBalance`；Task 1 `WhiteBalanceSettings`
- Produces: 相机 Tab 新增「白平衡」预设选择（pill）+ 色温滑块（3000–8000K、非 Auto 可用）

- [ ] **Step 1: 读现状**：读 `param_panel.dart` 相机 Tab（L333-398）与曝光 EV slider 的组件/接线方式，确定状态如何存（StatefulWidget / Riverpod provider）。
- [ ] **Step 2: 接入状态**：加本地状态保存当前 `WhiteBalanceSettings`（默认 auto）。调用 `cameraService.setWhiteBalance(settings)` 于：预设/滑块变化时。
- [ ] **Step 3: UI 新增**
  - 预设行：复用一个现有 pill/segmented 组件，给出 `Auto / 日光 / 阴天 / 荧光 / 白炽`（映射 `WhiteBalanceMode`）。
  - 手动色温行：一个 slider（min 3000, max 8000, 步进 100），仅在选中非 Auto 预设时展示/可调；值显示为 `XXXX K`。
  - 全部颜色/圆角/阴影从 `appThemeProvider` + `uiStyleProvider` 取，**禁止硬编码**；叠在照片上的浮层按当前风格取向。
  - 若 param_panel 面板不是你选的纯色画布而是叠照片浮层，遵循 AGENTS.md「叠照片取向」表（neumorphic 实心+细边 等）。
- [ ] **Step 4: 联调**：对主平台真机/模拟器，切换预设/拖滑块，**取景实时变色**；拍照后**直出图**白平衡符合预期；切回 Auto 恢复。
- [ ] **Step 5: Commit + push**
  ```bash
  git add lumira_app_flutter/lib/features/capture
  git commit -m "feat(camera): 拍摄页白平衡预设+色温滑块 UI"
  git push origin master ; git push github master
  ```

---

### Task 7: 三端交叉回归与收尾

**Files:**（无代码改动，仅验证）
- [ ] **Step 1:** iOS：验证预设与手动色温、切 Auto 恢复、拍照直出。
- [ ] **Step 2:** Android：验证预设生效；手动色温为 offset 近似，极端值可接受；拍照直出。
- [ ] **Step 3:** OHOS：重新编译安装后验证取景实时变色 + 直出图。
- [ ] **Step 4:** 回归既有相机功能不受影响：变焦、闪光、曝光 EV、对焦、前后切换、连拍。
- [ ] **Step 5:** 若实现中出现「当前先这样、后续再优化」项，按规则追加到 `docs/future-optimizations.md`（如 Android 手动色温精度）。

---

## Self-Review（已核对）

- **Spec 覆盖**：OHOS 本地化(Task0)、共享 Dart(Task1)、三端原生(Task2/3/4)、App 接口(Task5)、UI(Task6)、三端验证(Task7)。✓
- **占位符扫描**：Task2/3/4 原生代码因需核实当库实际 API/通道名，标注了「细化」说明供实现者核对；无 TBD/TODO 作为可跳过项。✓
- **类型一致性**：`WhiteBalanceSettings`（App）+ `setWhiteBalance(String mode, int? k)`（插件/原生）在三端签名一致；`CameraService.setWhiteBalance(WhiteBalanceSettings)`。✓