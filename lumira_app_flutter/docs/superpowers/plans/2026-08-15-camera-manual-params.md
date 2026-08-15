# 相机手动参数实现计划（白平衡 / 快门速度 / ISO）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在拍摄页实现白平衡（WB）、快门速度（SS）、ISO 三个手动参数的**真实控制与用户可编辑 UI**。当前底层 camerawesome 系 SDK 不支持手动设置这三个参数，需先完成 SDK 原生能力扩展，再回到 Flutter 层落地 UI、状态与持久化。

**当前状态（2026-08-15 已下线 WB 展示）：**
- 拍摄页顶部参数胶囊栏已移除 `WB xxx` 胶囊（见 `lib/features/capture/widgets/param_pill_bar.dart`），仅保留 `EV / ISO` 胶囊
- 参数面板「相机」Tab 目前只有 EV 滑块 + 闪光灯选项，无 WB/ISO/快门编辑控件
- `CameraParams`（`lib/features/capture/domain/photo_template.dart`）已具备 `whiteBalance` / `whiteBalanceK` / `iso` / `isoMode` / `shutterSpeed` 字段，数据模型无需扩展，仅需接入真实驱动
- `capture_page.dart` 注释：`白平衡功能已下线（SDK 不支持手动设置），ISO/快门为推荐参考值`

**Architecture:** 底层 SDK 原生能力扩展（Android Camera2 / iOS AVCaptureDevice / HarmonyOS Camera Kit）→ Dart 桥接 API → `CameraService` 封装 → Riverpod 状态 → 拍摄页 UI（参数胶囊 + 参数面板滑块）→ 拍摄时透传真实参数。后处理层已有 `PostProcessColor.temperature` 色温通道，可作为「等效白平衡」预览/成片方案，与真实硬件控制二者可选其一或叠加。

**Tech Stack:** Flutter 3.7.x (Dart 2.19.6，不支持 Dart 3 records)、camerawesome (packages/camerawesome 打补丁版) + camerawesome_ohos 1.0.2、Riverpod 2.x、Camera2 / AVCaptureDevice / OHOS Camera Kit

## Global Constraints

- 三端必须行为一致：Android (Camera2)、iOS (AVCaptureDevice)、HarmonyOS (Camera Kit)
- SDK 改动只能发生在本地补丁仓库 `packages/camerawesome/` 与 `camerawesome_ohos`（gitcode 依赖），不破坏原库对外 API 兼容性，新增 API 用可选命名参数向后兼容
- Dart 层新增 API 命名遵循既有风格（如 `setFlashMode`/`setZoom`/`setBrightness`）
- 参数范围与真实硬件对齐：
  - WB：类型枚举（auto/daylight/cloudy/shade/tungsten/fluorescent）+ 手动色温 2000~10000K
  - ISO：100~3200（多数设备），`isoMode` auto/manual 切换
  - 快门：1/8000s ~ 1s（步进遵循设备 `SENSOR_INFO_EXPOSURE_TIME_RANGE`）
- 拍摄照片 EXIF 需写入真实 ISO / ExposureTime / 白平衡标记
- 未经用户明确要求，不改变既有 EV、闪光灯、变焦行为
- 所有 UI 遵循项目五级圆角 token 与金色强调色规范

---

## File Structure

### 新增文件（底层原生 + Dart 桥接）

| 文件 | 职责 |
|---|---|
| `packages/camerawesome/lib/src/orchestrator/models/sensor_config.dart`（修改） | SensorConfig 增加 whiteBalance / iso / shutterSpeed 控制 |
| `packages/camerawesome/android/src/main/kotlin/.../CameraAwesomeController.kt`（修改） | Camera2 `CONTROL_AWB_MODE` / `SENSOR_EXPOSURE_TIME` / `SENSOR_SENSITIVITY` |
| `packages/camerawesome/ios/Classes/...`（修改） | `AVCaptureDevice.whiteBalanceMode` / `setExposureModeCustom` / `setISO` |
| `camerawesome_ohos`（gitcode 依赖）| OHOS Camera Kit 白平衡 / 曝光补偿 / 感光度，需 fork 或提 PR |
| `lib/features/capture/services/camera_service.dart`（修改） | 新增 `setWhiteBalance` / `setIso` / `setShutterSpeed` 透传 |
| `lib/features/capture/widgets/param_panel.dart`（修改） | 相机 Tab 增加 WB / ISO / 快门编辑控件 |
| `lib/features/capture/widgets/param_pill_bar.dart`（修改） | 恢复 WB 胶囊、新增 ISO 手动状态胶囊 |

### 修改文件（Flutter 业务层）

| 文件 | 改动 |
|---|---|
| `lib/features/capture/domain/photo_template.dart` | 校验手动参数范围（无需改字段） |
| `lib/features/capture/data/capture_state.dart` | WB/ISO/快门改动监听并下发 `CameraService` |
| `lib/features/capture/pages/capture_page.dart` | 恢复三参数实时下发监听，更新注释 |
| `test/features/capture/param_pill_bar_test.dart` | 新增/更新胶囊与面板测试 |

---

## Task 1: 底层 SDK 能力扩展（三端原生）

**Files:**
- Modify: `packages/camerawesome/lib/src/orchestrator/models/sensor_config.dart`
- Modify: `packages/camerawesome/android/src/main/kotlin/**`
- Modify: `packages/camerawesome/ios/Classes/**`
- Modify: `camerawesome_ohos`（依赖仓库）

- [ ] **Step 1: Dart 侧 SensorConfig 扩展**

在 `SensorConfig` 增加与既有 `setFlashMode` 风格一致的 API：

```dart
// 白平衡
enum WhiteBalanceMode { auto, daylight, cloudy, shade, tungsten, fluorescent, custom }
Future<void> setWhiteBalance(WhiteBalanceMode mode, {int? kelvin}) async {
  await CamerawesomePlugin.setWhiteBalance(mode.name, kelvin: kelvin);
}

// ISO
Future<void> setIso(int iso, {required bool manual}) async { ... }

// 快门速度（秒，如 1/200 → 0.005）
Future<void> setShutterSpeed(double seconds) async { ... }
```

- [ ] **Step 2: Android Camera2 实现**

在 `CameraAwesomeController.kt` / 拍照 Session 中：
- 白平衡：`CaptureRequest.CONTROL_AWB_MODE` 映射枚举（`CONTROL_AWB_MODE_AUTO/DAYLIGHT/CLOUDY_DAYLIGHT/SHADE/TUNGSTEN/FLUORESCENT`），手动色温用 `CONTROL_AWB_LOCK` + `COLOR_CORRECTION_MODE_TRANSFORM`（或 `COLOR_CORRECTION_GAINS`）实现
- ISO：`SENSOR_SENSITIVITY`，需同时设置 `CONTROL_AE_MODE_OFF`（自动模式时切回 `CONTROL_AE_MODE_ON`）
- 快门：`SENSOR_EXPOSURE_TIME`（纳秒），同样依赖 AE 手动模式
- EXIF：写入 `ExifInterface.TAG_ISO_SPEED` / `TAG_EXPOSURE_TIME` / `TAG_WHITE_BALANCE`

- [ ] **Step 3: iOS 实现**

- 白平衡：`AVCaptureDevice.whiteBalanceMode`（locked 时用 `setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains`，通过 `temperatureAndTintValues` 换算 K 值）
- ISO/快门：`setExposureModeCustomWithDuration:ISO:completionHandler:`，自动模式切回 `AVCaptureExposureModeContinuousAutoExposure`
- EXIF：`AVCapturePhotoSettings` 已携带相关元数据

- [ ] **Step 4: HarmonyOS Camera Kit 实现**

- fork `camerawesome_ohos`（gitcode CPF-Flutter/fluttertpc_camerawesome）
- Camera Kit：`CameraInput` / `CaptureSession` 的 `CONTROL_MODE_MANUAL`，`AE_FOCUS_MODE` 等控制白平衡（`WHITE_BALANCE_MODE`）、ISO（`SENSOR_SENSITIVITY`）、曝光时间（`EXPOSURE_TIME`）
- 若无法本地改动 gitcode 依赖，记录 PR 需求并暂时以「等效色温后处理」作为 HarmonyOS 端降级方案

- [ ] **Step 5: 三端真机验证**

分别在三端真机验证：设置 WB/ISO/快门后，取景器画面亮度/色温实时变化，成片 EXIF 参数正确。

---

## Task 2: 业务层接入（CameraService + 状态）

**Files:**
- Modify: `lib/features/capture/services/camera_service.dart`
- Modify: `lib/features/capture/data/capture_state.dart`
- Modify: `lib/features/capture/pages/capture_page.dart`

- [ ] **Step 1: CameraService 新增透传方法**

```dart
Future<void> setWhiteBalance(WhiteBalanceMode mode, {int? kelvin});
Future<void> setIso(int iso);
Future<void> setShutterSpeed(double seconds);
```

内部调用底层 `sensorConfig` 新 API，并在不可用平台降级为 no-op + debugPrint。

- [ ] **Step 2: 状态监听与下发**

在 `capture_page.dart` 增加与 EV 一致的三组 `ref.listen`，参数变化时调用 `CameraService` 对应方法；模板/自由模式切换时按 `CameraParams` 初始值下发。

- [ ] **Step 3: 手动模式联动**

`isoMode`/`shutterSpeed`/`whiteBalance` 切换「手动」时自动关闭 AE/AWB 自动，切回「自动」时恢复，避免三者互相覆盖。

---

## Task 3: 拍摄页 UI（胶囊 + 参数面板）

**Files:**
- Modify: `lib/features/capture/widgets/param_pill_bar.dart`
- Modify: `lib/features/capture/widgets/param_panel.dart`

- [ ] **Step 1: 恢复/新增胶囊**

- 恢复 `WB xxx` 胶囊（复用已删除的 `_wbDisplay` 文案映射）
- ISO 胶囊在 `isoMode == manual` 时显示具体值，否则显示 `Auto`
- 新增快门胶囊 `SS 1/200`

- [ ] **Step 2: 参数面板相机 Tab 增加编辑控件**

- WB：类型分段选择（复用 `_PopupRow` 或 seg-btn，选项 auto/daylight/cloudy/shade/tungsten/fluorescent）+ 色温 K 滑块（2000~10000，step 50）
- ISO：`_SliderRow`（100~3200，自动/手动开关）
- 快门：`_SliderRow` 或步进选择（1/8000 ~ 1s）
- 文案标注「实时生效」（WB/ISO/快门在 SDK 支持时实时改变取景器）

- [ ] **Step 3: 面板底部重置/完成逻辑覆盖新参数**

自由模式 `resetFreeModeParams` 与模板重置均需复位 WB/ISO/快门为默认值。

---

## Task 4: 可选增强 — 等效白平衡（后处理兜底）

**Files:**
- Modify: `lib/features/capture/widgets/camera_preview.dart`
- Modify: `lib/features/capture/data/capture_state.dart`

- [ ] **Step 1: K 值 → temperature 映射**

对不支持真实硬件的平台（如 HarmonyOS 未完成原生接入前），将 `whiteBalanceK` 映射到 `PostProcessColor.temperature`（已有色温通道，`camera_preview.dart` 已应用），实现「等效白平衡」预览与成片。

- [ ] **Step 2: 记录 EXIF/元数据**

照片元数据/DB 中写入 `whiteBalance` / `whiteBalanceK` / `iso` / `shutterSpeed`，供相册与后续编辑复用（字段已存在于 `CameraParams` 序列化）。

---

## 验收清单

- [ ] 三端（Android/iOS/HarmonyOS）均可设置 WB/ISO/快门，取景器实时变化
- [ ] 成片 EXIF 包含真实 ISO / ExposureTime / 白平衡标记
- [ ] 拍摄页胶囊正确展示三参数当前值，点击进入对应编辑控件
- [ ] 自动/手动模式切换正确联动 AE/AWB，不互相覆盖
- [ ] 模板加载、自由模式重置后参数正确复位
- [ ] 未改动既有 EV / 闪光灯 / 变焦 / 滤镜功能
- [ ] 新增/更新单元测试通过（`flutter test`）
- [ ] HarmonyOS 模拟器 + 真机通过（项目 CI 锁 Flutter 3.7.12）
