# 拍摄页取景器：点击对焦 + 长按锁定曝光（三端）

> 日期：2026-08-24
> 状态：设计稿（已实现）
> 范围：`lumira_app_flutter/`（Flutter 拍摄页 + camerawesome 三端原生层 `packages/camerawesome` / `packages/camerawesome_ohos`）

## 1. 背景与目标

拍摄页取景器目前缺少两个 iPhone 原生相机标配交互：

- **点击对焦**：底层虽已通过 camerawesome `onPreviewTapBuilder → focusOnPoint` 接了一版，但仅剩 camerawesome 默认的细白线小方框反馈（白色 1.5px、2s 内缩小消失），无 iPhone 风格金色对焦框动画；且与取景器外层 `_PinchZoomCamera`（`HitTestBehavior.opaque`）的 `GestureDetector` 并存，存在手势竞争隐患。
- **长按锁定曝光（AE/AF Lock）**：**完全没有实现**。camerawesome `OnPreviewTap` 仅支持 `onTap`，无长按；三端原生侧（iOS `ContinuousAutoFocus`、Android `startFocusAndMetering` 自动取消、OHOS `setFocusMode(AUTO)`）均无「锁定曝光/对焦」接口。

目标：在拍摄页取景器实现与 iPhone 原生相机一致的**单击对焦**与**长按锁定 AE/AF**，锁定必须为**原生硬件级锁定**（非纯 UI 模拟），三端一次性完成。

### 关键约束（不可妥协）
- **锁定必须是原生硬件级**：iOS `AVCaptureExposureModeLocked` / Android `startFocusAndMetering(...disableAutoCancel())` / OHOS `ExposureMode.EXPOSURE_MODE_LOCKED`。
- 手势统一收口到 Flutter 层（tap / long-press / pinch 一个 `GestureDetector`），与 camerawesome 内置手势解耦，规避竞争。
- 对焦框 / 锁定标签 UI 严格跟随现有「UI 风格 + 主题」（4 风格 × 8 主题），叠照片浮层语义（实心 `surface` + 细边，无阴影、无模糊）；金色高亮视为跨风格通用的叠加视觉。
- 锁定为实时预览行为，不影响拍照成片管线；切换摄像头 / 退出页面 / 拍照自动解除。

## 2. 现状盘点

| 层 | 位置 | 现状 |
|---|---|---|
| 取景器手势 | `lib/features/capture/widgets/camera_preview.dart#L326` `_PinchZoomCamera` | 仅双指捏合缩放，`GestureDetector` + `HitTestBehavior.opaque` |
| 点击对焦回调 | `lib/features/capture/widgets/camera_preview.dart#L149-L152` | `onTapFocus → cameraService.focusOnPoint`，无自绘反馈 |
| 相机服务接口 | `lib/features/capture/services/camera_service.dart#L36` | 已有 `focusOnPoint`，无锁定接口 |
| camerawesome 手势 | `packages/camerawesome/lib/src/widgets/preview/awesome_camera_gesture_detector.dart` | `OnPreviewTap` 仅 `onTap`；`onTapPainter` 默认白色方框 |
| iOS 原生 | `packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L419` | `focusOnPoint` 仅 `setFocusMode(ContinuousAutoFocus)`，无曝光锁定 |
| Android 原生 | `packages/camerawesome/android/.../CameraAwesomeX.kt#L691` | `focusOnPoint` 走 `startFocusAndMetering`（默认 2500ms 自动取消），无持久锁定 |
| OHOS 原生 | `packages/camerawesome_ohos/ohos/.../CameraAwesomeX.ets#L252` | `focusOnPoint` 仅 `setFocusMode(AUTO)+setFocusPoint`，无曝光锁定 |

## 3. 交互模型（对齐 iPhone 原生相机）

- **单击对焦**：点取景器任意位置 → 显示金色对焦框（弹性缩小动画）→ `focusOnPoint` 对焦+测光到触点，约 1.5s 后对焦框自动消失。
- **长按锁定 AE/AF**：长按触点 → 显示金色对焦框 + 底部小标签「AE/AF 锁定」（锁图标 + 文字）→ 原生锁定曝光与对焦在触点，对焦框**持续显示不消失**。
- **解锁**：
  - 锁定状态下单击其他位置 → 先解除锁定（恢复连续自动对焦/曝光）再对新触点重新对焦（iPhone 行为）。
  - 拍照 / 切换摄像头 / 退出拍摄页 → 自动解除锁定。
- **手势仲裁**：tap 由 camerawesome 的 `TapGestureRecognizer` 承接（树中更深、竞技场胜出）；App 层手势层注册 `onLongPressStart` / `onScaleStart|Update|End`（长按超阈值 = long-press 胜出并锁定；双指移动 = scale）。三者互不竞争。

## 4. 架构与分层

```
CameraPreview (Flutter)
 ├─ 手势层 _PinchZoomCamera（扩展现有，新增 onLongPressStart/End 回调）
 │     tap（由 camerawesome 承接）→ 走下方 onTapFocus
 │     longPress → setFocusAndExposureLock(true, point, size)  [锁定 AE/AF]
 │     pinch     → setZoomMultiplier（现有逻辑不变）
 ├─ 相机本体 CameraService.buildPreview
 │     onTapPainter 置 null（屏蔽 camerawesome 默认白框）
 │     onTapFocus 保留：tap 由 camerawesome 的 TapGestureRecognizer 承接
 │        （其在树中更深、在手势竞技场中胜出），回调内 focusOnPoint + 驱动对焦框
 └─ 对焦反馈层 _FocusOverlay（Stack 顶层，IgnorePointer）
       金色对焦框 + AE/AF 锁定标签；tap 位置来自 onTapFocus 回调，
       longPress 位置来自手势层回调
```

> 关键手势仲裁决策：camerawesome 的 `AwesomeCameraGestureDetector` 只要 `onPreviewTap` 非 null 就注册 `TapGestureRecognizer`（Dart 兜底为默认对焦行为，因此恒非 null），且其位于树更深层，**快速点击时在竞技场中胜出**。因此 tap 必须继续由 camerawesome 承接（否则我们自己的 tap recognizer 不会稳定触发）；App 层手势层只负责 long-press（长按超过 500ms 后 LongPressGestureRecognizer 胜出、tap 被拒）与 pinch。这样避免两个 TapGestureRecognizer 竞争造成对焦框不确定。

### 4.1 CameraService 接口新增
```dart
/// 锁定/解锁对焦与曝光（长按锁定）。
/// locked=true 时必传 position+previewSize；locked=false 时忽略坐标，恢复连续自动对焦/曝光。
void setFocusAndExposureLock({
  required bool locked,
  Offset? position,
  Size? previewSize,
});
```

### 4.2 三端原生实现
| 平台 | 挂钩点 | 锁定（locked=true） | 解锁（locked=false） |
|---|---|---|---|
| iOS | `CameraPreview.m` | `setExposurePointOfInterest` + `setExposureMode(Locked)`；`setFocusPointOfInterest` + `setFocusModeLocked(lensPosition:)` | `setFocusMode(ContinuousAutoFocus)` + `setExposureMode(ContinuousAutoExposure)` |
| Android | `CameraAwesomeX.kt` | `startFocusAndMetering(FLAG_AF or FLAG_AE).disableAutoCancel()`（持续保持触点测光） | `cancelFocusAndMetering()` |
| OHOS | `CameraState.ets` / `CameraAwesomeX.ets` | `setFocusPoint` + `setFocusMode(AUTO)` + `setExposureMode(EXPOSURE_MODE_LOCKED)` + `setExposurePoint` | `setExposureMode(EXPOSURE_MODE_AUTO)` + 恢复连续对焦 |

三端均需新增 Pigeon 方法注册（Dart `CameraInterface` + 各端实现），沿用现有 `setWhiteBalance` 的「SensorConfig 订阅 → Plugin 方法通道 → 平台原生」模式。

### 4.3 交互状态归属
对焦点 / 锁定态 / 可见性作为 `_FocusOverlay`（`StatefulWidget`）自管理状态，不污染全局 provider；通过 `_FocusGestureLayer` 回调驱动。

### 4.4 对焦框 UI
- 金色（amber）对焦框：四角描边、弹性缩小动画（与 iPhone 接近），叠加 `tokens` 细边/半透明表面。
- 锁定态：对焦框常驻 + 下方居中「AE/AF 锁定」小胶囊标签（锁图标 + 文字）。
- 全部走 `appThemeProvider` / `uiStyleProvider`，叠照片浮层语义（实心 `surface` + 细边，无阴影、无模糊）。

## 5. 边界与错误处理
- 前置摄像头不支持点对焦 → `focusOnPoint` / 锁定调用静默失败（catch + debugPrint），对焦框正常反馈。
- 锁定期间切换摄像头 / 退出 → `CameraService.initialize()` 重置时调用一次 `setFocusAndExposureLock(false)` 兜底。
- 锁定为实时预览行为，不影响拍照成片管线。
- OHOS 原生改动需重新编译并重装 App（Dart hot reload 不生效）。

## 6. 测试
- Flutter widget 测试（`test/features/capture/widgets/camera_preview_test.dart`）：
  - tap → 触发 `focusOnPoint`、对焦框显示后自动消失。
  - longPress → 触发 `setFocusAndExposureLock(true)`、锁定标签显示。
  - 锁定后再 tap → 触发 `setFocusAndExposureLock(false)` + `focusOnPoint` 重新对焦。
  - pinch 逻辑回归（现有测试保持通过）。
- 三端原生：在对应平台验证锁定/解锁、对焦生效、锁定常驻不消失。
- `flutter analyze` 全绿。

## 7. 实现与验证记录

> 状态：已实现（2026-08-24 起）。

### 7.1 实现提交

| Commit | 内容 |
|---|---|
| `c71f84e` | feat(camera): 新增 `setFocusAndExposureLock` Pigeon 通道 + CameraService 方法 |
| `efd44e5` | feat(capture): 金色对焦框 + AE/AF 长按锁定 UI |
| `d89facd` | feat(camerawesome/ios): 原生 AE/AF 锁定支持 |
| `f0a4e81` | feat(camerawesome/android): 原生 AE/AF 锁定支持 |
| `0d776bb` | feat(camerawesome_ohos): 原生 AE/AF 锁定支持 |

### 7.2 验证状态

- **Dart 静态分析**：`flutter analyze` 全量 **0 error**。存在 1 条与本次功能无关的**既有 warning**（`test/core/auth/auth_controller_test.dart:109` `unnecessary_non_null_assertion`，auth 测试历史遗留，非本功能引入，未在本计划修复）+ 425 条 info 级 lint。
- **Flutter 测试**：本次功能相关测试全部通过——`test/features/capture/widgets/camera_preview_test.dart`（10 项，覆盖 tap 对焦/长按锁定/锁定后重对焦/pinch 回归）+ `test/features/capture/services/camerawesome_camera_service_test.dart`（1 项，readyStream 切换防重入）。
- **全量 `flutter test` 说明**：当前工作区全量运行存在 210 条失败，经排查**全部与本计划无关**，根因是仓库中**未提交的其它 WIP**（如 `gallery_items` 表缺少 `hidden` 列导致的 schema fixture 不匹配、`router_test` 期望 73 条路由而实际 79 条、filter_picker/scene_preset_strip 等 WIP 改动未同步测试等），不在本计划修复范围，已按任务约定记录不阻塞。
- **iOS / OHOS 原生编译**：本机为 Windows，无 Xcode / DevEco 工具链，iOS 与 OHOS 原生层**无法在本机编译验证**；Android 原生与 Dart 层经 analyze / 单测覆盖。
- **三端真机手测**：brief 6.3 清单（单击对焦框动画与消失、长按锁定常驻 + 「AE/AF 锁定」标签、锁定后单击重对焦、拍照/切摄/退出自动解锁、捏合缩放回归、前置点对焦静默失败、4 风格 × 主题下浮层配色）**仍未在 iOS / Android / OHOS 真机逐项核验**，需真机到位后补测。

### 7.3 已知限制（来自任务评审，均需真机核验）

- **iOS 对焦锁定时机**：锁定采用 fire-and-forget 自动对焦后立即锁定 `lensPosition`，锁定的镜头位置可能不是最终合焦位置（真机清晰度核验中确认）。
- **OHOS 旋转后 AF 锁定回退**：锁定调用 `setFocusPoint` 会注册一次性方向传感器监听（既有行为）；设备旋转一次后 AF 锁定静默回退为 `CONTINUOUS_AUTO`，而 AE 仍保持 `LOCKED`（AF/AE 不一致）。建议后续修复：绕过方向监听，或在 `setFocusAndExposureLockFn` 中加锁定状态守卫。
- **坐标参考系边界**：非全屏比例下长按坐标与 tap 坐标参考系存在差异的边界情况（brief 6.4 提及，真机场景确认）。

