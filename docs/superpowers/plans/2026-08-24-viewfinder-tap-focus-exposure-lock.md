# 拍摄页取景器：点击对焦 + 长按锁定曝光（三端）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在拍摄页取景器实现 iPhone 原生相机一致的单击对焦（金色弹性对焦框，1.5s 自动消失）与长按锁定 AE/AF（金色对焦框常驻 + 「AE/AF 锁定」标签），锁定为三端原生硬件级（iOS `AVCaptureExposureModeLocked` / Android `startFocusAndMetering(disableAutoCancel)` / OHOS `ExposureMode.EXPOSURE_MODE_LOCKED`）。

**Architecture:** 手势仲裁上，tap 继续由 camerawesome 的 `TapGestureRecognizer` 承接（树中更深、竞技场胜出），App 层 `_PinchZoomCamera` 仅新增 `onLongPressStart/End`（与既有 pinch 并存）；对焦反馈由新增的 `_FocusOverlay`（Stack 顶层、IgnorePointer、GlobalKey 驱动、自管理状态）渲染。原生锁定通过新增 Pigeon 方法 `setFocusAndExposureLock` 贯通 Flutter → 三端 `CamerawesomePlugin` → 相机硬件，沿用现有 `setWhiteBalance` 的「静态包装 → Pigeon 通道 → 平台原生」模式。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁 Dart 3 records 语法）、camerawesome（iOS/Android fork）、camerawesome_ohos（OHOS fork）、AVFoundation（iOS）、CameraX（Android）、CameraKit（OHOS）、flutter_riverpod。

## Global Constraints

- Dart 版本 2.19.6 / Flutter 3.7.12，**禁止 Dart 3 records 语法**（类型参数、函数式 API 全部用 class/extends）。
- **锁定必须是原生硬件级**：iOS `AVCaptureFocusModeLocked` + `AVCaptureExposureModeLocked`；Android `startFocusAndMetering(...disableAutoCancel())`（解锁 `cancelFocusAndMetering()`）；OHOS `setExposureMode(EXPOSURE_MODE_LOCKED)` + `setFocusMode(FOCUS_MODE_AUTO)` + 触点。
- 手势仲裁铁律：**tap 由 camerawesome 承接，App 层只加 long-press 与既有 pinch**；App 层不得新增 TapGestureRecognizer（避免与 camerawesome 竞争导致对焦框不确定）。
- 对焦框 / 锁定标签 UI 严格跟随 4 UI 风格（neumorphic/flat/glass/female）× 8 主题（warmWhite/ink/retro/fresh/cozy/macaron/morandi/rosegold），从 `appThemeProvider`（`AppThemeData`）+ `uiStyleProvider` 派生；叠照片浮层语义 = 实心/半透明 `tokens.surface` + 细边，**无阴影、无模糊、无玻璃**；金色（amber）高亮视为跨风格通用的叠加视觉，可用 `Colors.amber` 系。
- 长按阈值 500ms（`LongPressGestureRecognizer` 默认）；对焦框 tap 后 ~1.5s 自动消失，锁定态常驻。
- 前置摄像头不支持点对焦 → 原生调用静默失败（catch + debugPrint），对焦框照常反馈。
- 锁定为实时预览行为，不影响拍照成片管线；拍照 / 切换摄像头 / 退出页面自动解除。
- OHOS 原生（ets）改动需重新编译并重装 App，Dart hot reload 不生效。
- `flutter analyze` 全绿；既有测试必须保持通过。

---

## 文件结构

| 文件 | 责任 |
|---|---|
| `lib/features/capture/services/camera_service.dart` | 接口新增 `setFocusAndExposureLock` |
| `lib/features/capture/services/camerawesome_camera_service.dart` | 实现锁定分发 + `initialize()` 兜底解锁 |
| `packages/camerawesome/lib/pigeon.dart`、`packages/camerawesome_ohos/lib/pigeon.dart` | Dart 侧 Pigeon 通道方法 `setFocusAndExposureLock` |
| `packages/camerawesome/lib/camerawesome_plugin.dart`、`packages/camerawesome_ohos/lib/camerawesome_plugin.dart` | 静态包装（含 iOS 归一化坐标变换） |
| `lib/features/capture/widgets/camera_preview.dart` | `_FocusOverlay` 组件 + `_PinchZoomCamera` 长按 + 接线（`onTapPainter: null`） |
| `packages/camerawesome/ios/Classes/Pigeon/Pigeon.h/.m` | iOS Pigeon 注册 + 分发 |
| `packages/camerawesome/ios/Classes/CamerawesomePlugin.m` | iOS 插件入口转发 |
| `packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.h/.m` | iOS 原生锁定/解锁实现 |
| `packages/camerawesome/android/.../cameraX/Pigeon.kt` | Android Pigeon 注册 |
| `packages/camerawesome/android/.../cameraX/CameraAwesomeX.kt` | Android 原生锁定/解锁实现 |
| `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/Pigeon.ets` | OHOS Pigeon 注册 |
| `packages/camerawesome_ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets` | OHOS 插件转发 |
| `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets` | OHOS 原生锁定/解锁实现 |
| `test/features/capture/widgets/camera_preview_test.dart` | 对焦/锁定 widget 测试 |

**Pigeon 方法契约（三端一致）：**
```
setFocusAndExposureLock(Boolean locked, Double x, Double y, Double previewWidth, Double previewHeight) → void
```
- 通道名（native 包）：`dev.flutter.pigeon.CameraInterface.setFocusAndExposureLock`
- 通道名（ohos 包）：`dev.flutter.pigeon.camerawesome.CameraInterface.setFocusAndExposureLock`
- 坐标语义：**与 `focusOnPoint` 完全一致** —— iOS 传归一化 `[0,1]`（`dx/size.width, dy/size.height`）；Android/OHOS 传像素坐标（App 层 flutter 空间 == 像素空间，直接透传，native 自行换算）。
- `locked=false` 时 `x/y/previewWidth/Height` 全部传 0（native 忽略坐标，仅恢复自动）。

---

### Task 1: Dart 层锁定链路（接口 + 服务实现 + 静态包装 + Pigeon 通道）

**Files:**
- Modify: `lib/features/capture/services/camera_service.dart:36-37`
- Modify: `lib/features/capture/services/camerawesome_camera_service.dart`
- Modify: `packages/camerawesome/lib/pigeon.dart`（在 `setWhiteBalance` L1069 后）
- Modify: `packages/camerawesome/lib/camerawesome_plugin.dart`（在 `setWhiteBalance` 静态方法 L348 后）
- Modify: `packages/camerawesome_ohos/lib/pigeon.dart`（在 `setWhiteBalance` L918 后）
- Modify: `packages/camerawesome_ohos/lib/camerawesome_plugin.dart`（在 `setWhiteBalance` 静态方法 L408 后）

**Interfaces:**
- Consumes: 现有 `CamerawesomeDelegate.platformTag`（'ohos' / 其他）。
- Produces: `CameraService.setFocusAndExposureLock`；静态 `CamerawesomePlugin.setFocusAndExposureLock`（native + ohos）；Pigeon `CameraInterface().setFocusAndExposureLock(locked, x, y, previewWidth, previewHeight)`。

**Steps:**

- [ ] 1.1 在 `camera_service.dart` 的 `focusOnPoint`（L36）之后新增接口方法：
```dart
  /// 锁定/解锁对焦与曝光（长按锁定 AE/AF）。
  /// locked=true 时必传 position+previewSize；locked=false 时忽略坐标，恢复连续自动对焦/曝光。
  void setFocusAndExposureLock({
    required bool locked,
    Offset? position,
    Size? previewSize,
  });
```

- [ ] 1.2 在 `packages/camerawesome/lib/pigeon.dart`（native）新增通道方法，完全仿照现有 `setWhiteBalance`（L1069-1082）结构：
```dart
  Future<void> setFocusAndExposureLock(bool arg_locked, double arg_x,
      double arg_y, double arg_previewWidth, double arg_previewHeight) async {
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.CameraInterface.setFocusAndExposureLock', codec,
        binaryMessenger: _binaryMessenger);
    final List<Object?>? replyList = await channel.send(
            <Object?>[arg_locked, arg_x, arg_y, arg_previewWidth, arg_previewHeight])
        as List<Object?>?;
    if (replyList == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
        details: null,
      );
    } else if (replyList.length > 1) {
      throw PlatformException(
        code: replyList[0]! as String,
        message: replyList[1] as String?,
        details: replyList[2],
      );
    } else {
      return;
    }
  }
```
  （`_binaryMessenger`、`codec` 与文件内其余方法保持一致；若本文件用 `async` 风格，照抄相邻方法样板。）

- [ ] 1.3 在 `packages/camerawesome/lib/camerawesome_plugin.dart` 新增静态包装（照仿 `setWhiteBalance` L348 结构），坐标变换与 `CameraContext.focusOnPoint`（L180-199）一致：
```dart
  /// 锁定/解锁对焦与曝光（长按锁定 AE/AF）。iOS 传归一化坐标，Android 传像素坐标。
  static Future<void> setFocusAndExposureLock({
    required bool locked,
    Offset? position,
    Size? previewSize,
  }) {
    final w = previewSize?.width ?? 1.0;
    final h = previewSize?.height ?? 1.0;
    double x, y;
    if (Platform.isIOS) {
      x = (position?.dx ?? w / 2) / w;
      y = (position?.dy ?? h / 2) / h;
    } else {
      x = position?.dx ?? w / 2;
      y = position?.dy ?? h / 2;
    }
    return CameraInterface().setFocusAndExposureLock(
        locked, x, y, w, h);
  }
```
  确认 `dart:io` 已 import（`Platform.isIOS` 用）。

- [ ] 1.4 在 `packages/camerawesome_ohos/lib/pigeon.dart` 新增同名通道方法，通道名用 `dev.flutter.pigeon.camerawesome.CameraInterface.setFocusAndExposureLock`（照仿 L918 `setWhiteBalance` 样板，返回 `Future<void>`）。

- [ ] 1.5 在 `packages/camerawesome_ohos/lib/camerawesome_plugin.dart` 新增静态包装：**恒走像素坐标**（OHOS 非 iOS，`Platform.isIOS` 为 false 即像素分支；直接仿照 1.3 但不写 iOS 分支，或保留 `if (Platform.isIOS)` 亦可——OHOS 编译时恒 false）。

- [ ] 1.6 在 `camerawesome_camera_service.dart` 实现接口方法（照仿 `setWhiteBalance` L283-296 的分发模式）：
```dart
  @override
  void setFocusAndExposureLock({
    required bool locked,
    Offset? position,
    Size? previewSize,
  }) {
    try {
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.setFocusAndExposureLock(
            locked: locked, position: position, previewSize: previewSize);
      } else {
        ca.CamerawesomePlugin.setFocusAndExposureLock(
            locked: locked, position: position, previewSize: previewSize);
      }
    } catch (e) {
      debugPrint('[camera] setFocusAndExposureLock failed: $e');
    }
  }
```
  注意：**走静态 Pigeon（不经 `_cameraState`）**，因此 `_cameraState == null` 时也能调用（初始化兜底解锁依赖此点）。

- [ ] 1.7 在 `camerawesome_camera_service.dart` 的 `initialize()`（L44-66）末尾追加一次兜底解锁（幂等、静默）：
```dart
    // 兜底：上一会话若处于锁定态，重置为连续自动对焦/曝光（新会话原生默认即自动，此调用幂等）
    setFocusAndExposureLock(locked: false);
```
  放在 `_cameraState = null;` 等清理之后、`try { stop }` 之外（方法本身已 catch）。

- [ ] 1.8 运行 `flutter analyze`（在 `lumira_app_flutter/` 下），修复所有报错；确认无类型/语法问题。

- [ ] 1.9 运行既有测试 `flutter test test/features/capture/widgets/camera_preview_test.dart`，确认全部通过（本任务无新测试，只验证不破坏既有行为）。

- [ ] 1.10 Commit（建议信息：`feat(camera): add setFocusAndExposureLock pigeon channel + service method`）。注：本项目 Flutter 端改动无强制 push 要求，但若同时涉及后端则按 AGENTS.md push 规则处理（本计划不含后端）。

---

### Task 2: Flutter 对焦反馈层 `_FocusOverlay` + 长按手势接线

**Files:**
- Modify: `lib/features/capture/widgets/camera_preview.dart`（`_PinchZoomCamera` L326-404、`build` L142-251、新增 `_FocusOverlay` 类）
- Modify: `lib/features/capture/services/camerawesome_camera_service.dart`（`_buildOhos` L358-366 / `_buildNative` L386-394 的 `onTapPainter`）
- Test: `test/features/capture/widgets/camera_preview_test.dart`

**Interfaces:**
- Consumes: `CameraService.focusOnPoint` / `CameraService.setFocusAndExposureLock`（Task 1）、`appThemeProvider` / `uiStyleProvider`。
- Produces: `_FocusOverlayState`（`showFocus(Offset)` / `showLock(Offset)` / `isLocked` / `unlockAndRefocus(Offset)`）、`_PinchZoomCamera.onLongPressStart(Offset, Size)` / `onLongPressEnd()`。

**Steps:**

- [ ] 2.1 新增 `_FocusOverlay`（`StatefulWidget`，放在 `camera_preview.dart` 底部、`_PinchZoomCamera` 之前或之后均可）。自管理状态，`GlobalKey<_FocusOverlayState>` 由外部驱动，不污染 provider：
```dart
class _FocusOverlay extends StatefulWidget {
  const _FocusOverlay({super.key});
  @override
  State<_FocusOverlay> createState() => _FocusOverlayState();
}

class _FocusOverlayState extends State<_FocusOverlay> {
  Offset? _point;
  bool _locked = false;
  bool _visible = false;
  Timer? _hideTimer;

  bool get isLocked => _locked;

  /// 单击对焦：显示金色对焦框，约 1.5s 后自动消失。
  void showFocus(Offset point) {
    _hideTimer?.cancel();
    setState(() {
      _point = point;
      _locked = false;
      _visible = true;
    });
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  /// 长按锁定：显示金色对焦框 + 「AE/AF 锁定」标签，常驻不消失。
  void showLock(Offset point) {
    _hideTimer?.cancel();
    setState(() {
      _point = point;
      _locked = true;
      _visible = true;
    });
  }

  /// 解除锁定并隐藏（用于「锁定后单击其他位置」的解锁阶段）。
  void unlock() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _locked = false;
      _visible = false;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _point == null) return const SizedBox.shrink();
    final theme = context.watch(appThemeProvider);
    final uiStyle = context.watch(uiStyleProvider);
    final tokens = theme.tokens;
    // 金色对焦框：四角描边 + 弹性缩小动画；锁定态下方居中「AE/AF 锁定」胶囊
    return IgnorePointer(
      child: Stack(children: [
        // —— 金色四角对焦框 + 动画 ——
        _FocusFrame(point: _point!, locked: _locked, tokens: tokens, uiStyle: uiStyle),
        if (_locked) _LockBadge(point: _point!, tokens: tokens),
      ]),
    );
  }
}
```
  > 说明：`context.watch` 需在 `ConsumerState` 中可用——`_FocusOverlayState` 需 `extends ConsumerState<_FocusOverlay>` 或改用 `ref.watch`（本项目统一 flutter_riverpod，推荐 `ConsumerState`）。`appThemeProvider` / `uiStyleProvider` 的 import 与页面其余部分一致。

- [ ] 2.2 实现 `_FocusFrame`：金色（`Colors.amber.shade400`，透明度 0.9）四角 L 形描边方框，尺寸约 70×70，中心位于 `point`；用 `AnimationController(duration: ~300ms)` + `Curves.elasticOut` 做 1.6→1.0 弹性缩入 + 轻微淡入。**叠照片浮层语义**：边框用金色描边（跨风格叠加视觉），不外发光、无阴影、无模糊；`ColorFiltered`/构图线等叠层之上渲染不受影响（位于 Stack 顶层）。

- [ ] 2.3 实现 `_LockBadge`：锁定态时对焦框正下方（offset 约 56px）居中显示胶囊：`Icons.lock`（14px）+ 「AE/AF 锁定」小字（12px）；背景 `tokens.surface`（实心，跨风格通用叠照片浮层），细边 `tokens.divider`，文字 `tokens.textPrimary`，圆角胶囊。**不使用** BackdropFilter / 阴影 / 玻璃。

- [ ] 2.4 扩展 `_PinchZoomCamera`（L326-404）：
  - 构造函数新增 `final void Function(Offset localPosition, Size previewSize)? onLongPressStart;` 与 `final VoidCallback? onLongPressEnd;`
  - `build` 中把 `GestureDetector` 包进 `LayoutBuilder` 以获取自身尺寸：
```dart
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.start,
        onLongPressStart: (details) =>
            widget.onLongPressStart?.call(details.localPosition, previewSize),
        onLongPressEnd: (_) => widget.onLongPressEnd?.call(),
        onScaleStart: (_) => _resetGesture(),
        onScaleUpdate: (details) { /* 现有逻辑不变 */ },
        onScaleEnd: (_) => _resetGesture(),
        child: widget.child,
      );
    });
  }
```
  > 关键点：`onLongPressStart` 与 `onScale*` 同在 arena——长按超过 500ms 由 `LongPressGestureRecognizer` 胜出（tap 与 scale 被拒），双指捏合由 `ScaleGestureRecognizer` 胜出；互不干扰，pinch 逻辑零改动。

- [ ] 2.5 在 `CameraPreview` 添加 `final GlobalKey<_FocusOverlayState> _focusKey = GlobalKey<_FocusOverlayState>();` 字段（ConsumerWidget 可持有 final 字段）。

- [ ] 2.6 修改 `buildPreview` 的 `onTapFocus` 回调（L149-152）：
```dart
              onTapFocus: (position, previewSize) {
                final overlay = _focusKey.currentState;
                // 锁定状态下单击其他位置 → 先解除锁定，再对新触点重新对焦（iPhone 行为）
                if (overlay?.isLocked == true) {
                  cameraService.setFocusAndExposureLock(locked: false);
                  overlay?.unlock();
                }
                cameraService.focusOnPoint(position, previewSize);
                overlay?.showFocus(position);
              },
```

- [ ] 2.7 修改 `_PinchZoomCamera` 调用处（L167-174），接入长按回调：
```dart
    final filteredCamera = _PinchZoomCamera(
      onLongPressStart: (localPosition, previewSize) {
        _focusKey.currentState?.showLock(localPosition);
        cameraService.setFocusAndExposureLock(
          locked: true,
          position: localPosition,
          previewSize: previewSize,
        );
      },
      onLongPressEnd: () {
        // 锁定常驻，抬手不隐藏（避免动画闪烁）
      },
      child: applyFilter
          ? ColorFiltered(
              colorFilter: fromPostProcess(effectivePost),
              child: rawCamera,
            )
          : rawCamera,
    );
```

- [ ] 2.8 在 Stack（L244-251）顶层追加 `_FocusOverlay`，并用 facing 作为 key 以便切换摄像头时重置锁定态：
```dart
    return Stack(
      fit: StackFit.expand,
      children: [
        filteredCamera,
        compositionOverlay,
        silhouetteOverlay,
        KeyedSubtree(
          key: ValueKey('focus_overlay_$facing'), // facing 变化时重建，锁定态复位
          child: _FocusOverlay(key: _focusKey),
        ),
      ],
    );
```
  > 说明：Flutter `GlobalKey` 不能同时充当 `ValueKey`，因此用 `KeyedSubtree` 包一层——`_FocusOverlay` 用 `_focusKey`（GlobalKey，供 `currentState` 驱动），外层 `KeyedSubtree` 用 `ValueKey(facing)`，切换前后摄像头时整棵子树重建、锁定态与对焦框复位。

- [ ] 2.9 在 `camerawesome_camera_service.dart` 的 `_buildOhos`（L358-366）与 `_buildNative`（L386-394）两处 `OnPreviewTap` 中新增 `onTapPainter: null`，屏蔽 camerawesome 默认白色对焦框：
```dart
        onTap: (position, flutterPreviewSize, pixelPreviewSize) {
          config.onTapFocus?.call(
            position,
            Size(flutterPreviewSize.width, flutterPreviewSize.height),
          );
        },
        onTapPainter: null,
```

- [ ] 2.10 扩展 `test/features/capture/widgets/camera_preview_test.dart`，新增 group（沿用现有 `cameraPreviewOverrideProvider` 注入占位预览 + 真实 `_PinchZoomCamera` / `_FocusOverlay` 渲染路径）：
  - 测试 A「tap 触发 focusOnPoint + 对焦框显示后自动消失」：用 `tester.tap` 在占位预览位置点击 → 断言金色对焦框出现（`find.byType(_FocusFrame)` 或加 `Key('focus_frame')` 便于查找）→ `tester.pump(Duration(milliseconds: 1600))` → 断言消失。
    > 因 tap 由 camerawesome 承接、测试中无真实 camerawesome，可在测试内直接调用 `_focusKey.currentState.showFocus` 等价驱动，或对 `onTapFocus` 路径单测；具体以「不引入真实相机」为原则设计。
  - 测试 B「长按触发 setFocusAndExposureLock(true) + 锁定标签显示」：`tester.startGesture` 按住 600ms → 断言 `cameraService.setFocusAndExposureLock(locked: true, ...)` 被调用（注入 spy 服务或覆写 provider）→ 断言「AE/AF 锁定」标签出现且持续。
  - 测试 C「锁定后 tap → 先解锁再重新对焦」：模拟锁定态后 tap → 断言先 `setFocusAndExposureLock(false)` 再 `focusOnPoint`。
  - 测试 D「pinch 回归」：双指捏合 → 断言 `setZoomMultiplier` 仍被调用（既有缩放逻辑不破坏）。
  - 若需注入 spy：`cameraServiceProvider.overrideWith` 提供实现 `CameraService` 的 fake，记录方法调用。

- [ ] 2.11 运行 `flutter test test/features/capture/widgets/camera_preview_test.dart`，全部通过；再运行 `flutter analyze` 全绿。

- [ ] 2.12 Commit（建议信息：`feat(capture): golden focus frame + AE/AF long-press lock UI`）。

---

### Task 3: iOS 原生锁定/解锁

**Files:**
- Modify: `packages/camerawesome/ios/Classes/Pigeon/Pigeon.h`
- Modify: `packages/camerawesome/ios/Classes/Pigeon/Pigeon.m`（注册 `setWhiteBalance` L944 附近追加）
- Modify: `packages/camerawesome/ios/Classes/CamerawesomePlugin.m`（`setWhiteBalanceMode` L196 附近追加）
- Modify: `packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.h`（`focusOnPoint` L90 附近追加声明）
- Modify: `packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m`（`focusOnPoint` L419-434 后追加实现）

**Interfaces:**
- Consumes: Task 1 的 Dart Pigeon 通道名 `dev.flutter.pigeon.CameraInterface.setFocusAndExposureLock`。
- Produces: `CameraInterface` 协议方法 `setFocusAndExposureLockLocked:x:y:previewWidth:previewHeight:error:`（Pigeon 命名风格，参照 `setWhiteBalanceMode:temperatureK:error:`）；`CameraPreview` 的 `setFocusAndExposureLock:(BOOL)locked position:(CGPoint)position preview:(CGSize)preview error:`。

**Steps:**

- [ ] 3.1 `Pigeon.h` 在 `@protocol CameraInterface`（含 `setWhiteBalanceMode:temperatureK:error:` L213）追加：
```objc
/// 锁定/解锁对焦与曝光（长按锁定 AE/AF）。
- (void)setFocusAndExposureLockLocked:(NSNumber *)locked x:(NSNumber *)x y:(NSNumber *)y previewWidth:(NSNumber *)previewWidth previewHeight:(NSNumber *)previewHeight error:(FlutterError *_Nullable *_Nonnull)error;
```

- [ ] 3.2 `Pigeon.m` 在 `setWhiteBalance` 注册块（L944-954）后追加注册（照抄样板）：
```objc
  [channel setMessageHandler:^(id _Nullable message, FlutterReply callback) {
    ...
    if ([api respondsToSelector:@selector(setFocusAndExposureLockLocked:x:y:previewWidth:previewHeight:error:)]) {
      [api setFocusAndExposureLockLocked:arg_locked x:arg_x y:arg_y previewWidth:arg_previewWidth previewHeight:arg_previewHeight error:&error];
    }
    ...
  }];
```
  参数解码：`arg_locked = ((NSNumber *)args[0]).boolValue`、`x/y/previewWidth/previewHeight` 为 `NSNumber`。

- [ ] 3.3 `CamerawesomePlugin.m` 实现协议方法并转发到 `CameraPreview`（照仿 `setWhiteBalanceMode` L196-197）：
```objc
- (void)setFocusAndExposureLockLocked:(NSNumber *)locked x:(NSNumber *)x y:(NSNumber *)y previewWidth:(NSNumber *)previewWidth previewHeight:(NSNumber *)previewHeight error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
  [_camera setFocusAndExposureLock:[locked boolValue]
                          position:CGPointMake([x floatValue], [y floatValue])
                            preview:CGSizeMake([previewWidth floatValue], [previewHeight floatValue])
                              error:error];
}
```

- [ ] 3.4 `CameraPreview.h` 在 `focusOnPoint`（L90）附近追加声明：
```objc
- (void)setFocusAndExposureLock:(BOOL)locked position:(CGPoint)position preview:(CGSize)preview error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error;
```

- [ ] 3.5 `CameraPreview.m` 在 `focusOnPoint`（L419-434）后追加实现（**核心硬件锁定**）：
```objc
/// 长按锁定 AE/AF：position 为归一化 [0,1] 坐标（与 focusOnPoint 一致）。
/// locked=YES：曝光与对焦均锁定在触点；locked=NO：恢复连续自动对焦/曝光。
- (void)setFocusAndExposureLock:(BOOL)locked position:(CGPoint)position preview:(CGSize)preview error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
  NSError *lockError;
  if (locked) {
    // —— 曝光锁定 ——
    if ([_captureDevice isExposurePointOfInterestSupported]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setExposurePointOfInterest:position];
        [_captureDevice setExposureMode:AVCaptureExposureModeLocked];
        [_captureDevice unlockForConfiguration];
      }
    }
    // —— 对焦锁定：先触发一次自动对焦到触点，再锁定到当前镜头位置 ——
    if ([_captureDevice isFocusPointOfInterestSupported] &&
        [_captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setFocusPointOfInterest:position];
        [_captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        [_captureDevice unlockForConfiguration];
      }
      if ([_captureDevice isFocusModeSupported:AVCaptureFocusModeLocked]) {
        CGFloat currentLens = _captureDevice.lensPosition;
        [_captureDevice setFocusModeLockedWithLensPosition:currentLens completionHandler:nil];
      }
    }
  } else {
    // —— 解锁：恢复连续自动 ——
    if ([_captureDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        [_captureDevice unlockForConfiguration];
      }
    }
    if ([_captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
      if ([_captureDevice lockForConfiguration:&lockError]) {
        [_captureDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        [_captureDevice unlockForConfiguration];
      }
    }
  }
}
```
  > 注意：`setFocusModeLockedWithLensPosition:completionHandler:` 为异步 API，**不可**在 `lockForConfiguration` 块内调用（先 unlock 再调用）。`AVCaptureExposureModeLocked` 需 `isExposureModeSupported:` 守卫（部分设备不支持则跳过曝光锁定，仅锁对焦）。

- [ ] 3.6 验证：iOS 需在真机验证（模拟器无相机）。检查项：长按出现金色框 + 「AE/AF 锁定」，画面曝光不再随亮度变化；单击其他位置解锁并重新对焦；拍照后解锁。若无法真机，至少 `flutter build ios --no-codesign` 编译通过。

- [ ] 3.7 Commit（建议信息：`feat(camerawesome/ios): native AE/AF lock support`）。

---

### Task 4: Android 原生锁定/解锁

**Files:**
- Modify: `packages/camerawesome/android/src/main/kotlin/com/apparence/camerawesome/cameraX/Pigeon.kt`（`CameraInterface` 接口 + 注册，`setWhiteBalance` 注册 L994 附近）
- Modify: `packages/camerawesome/android/src/main/kotlin/com/apparence/camerawesome/cameraX/CameraAwesomeX.kt`（`setWhiteBalance` L587 附近实现；`focusOnPoint` L691 附近）

**Interfaces:**
- Consumes: Task 1 的 Dart 通道名。
- Produces: `CameraInterface.setFocusAndExposureLock(locked, x, y, previewWidth, previewHeight)`；`CameraAwesomeX` 的 `override fun setFocusAndExposureLock(...)`。

**Steps:**

- [ ] 4.1 `Pigeon.kt` 在 `interface CameraInterface`（L548 附近，`setWhiteBalance` 声明后）追加接口方法：
```kotlin
  fun setFocusAndExposureLock(locked: Boolean, x: Double, y: Double, previewWidth: Double, previewHeight: Double)
```
  并在 `CameraInterface.setUp` 注册块中（照抄 `setWhiteBalance` L994 附近的样板）新增通道注册，channel 名 `dev.flutter.pigeon.CameraInterface.setFocusAndExposureLock`，参数解码与类型强转保持一致。

- [ ] 4.2 `CameraAwesomeX.kt` 实现：
```kotlin
  override fun setFocusAndExposureLock(locked: Boolean, x: Double, y: Double, previewWidth: Double, previewHeight: Double) {
    val previewSize = PreviewSize(previewWidth.toFloat(), previewHeight.toFloat())
    if (locked) {
      val factory: MeteringPointFactory = SurfaceOrientedMeteringPointFactory(
        previewSize.width, previewSize.height,
      )
      val point = factory.createPoint(x.toFloat(), y.toFloat())
      try {
        cameraState.previewCamera!!.cameraControl.startFocusAndMetering(
          FocusMeteringAction.Builder(
            point,
            FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE or FocusMeteringAction.FLAG_AWB
          ).apply {
            disableAutoCancel() // 持久锁定，不自动回到被动对焦
          }.build()
        )
      } catch (e: CameraInfoUnavailableException) {
        Log.e(TAG, "setFocusAndExposureLock lock failed", e)
      }
    } else {
      try {
        cameraState.previewCamera!!.cameraControl.cancelFocusAndMetering()
      } catch (e: CameraInfoUnavailableException) {
        Log.e(TAG, "setFocusAndExposureLock unlock failed", e)
      }
    }
  }
```
  > 复用现有 `focusOnPoint`（L691-720）的 `SurfaceOrientedMeteringPointFactory` 坐标换算（x/y 为像素坐标，factory 内部归一化）。`previewWidth/Height` 即 App 层传入的预览尺寸。

- [ ] 4.3 验证：`cd lumira_app_flutter && flutter build apk --debug` 编译通过（无需真机也能确认 Kotlin 编译）。真机检查长按锁定、单击解锁、拍照解锁。

- [ ] 4.4 Commit（建议信息：`feat(camerawesome/android): native AE/AF lock support`）。

---

### Task 5: OHOS 原生锁定/解锁

**Files:**
- Modify: `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/Pigeon.ets`（`setWhiteBalance` 抽象 L742 附近 + 注册 L1195 附近）
- Modify: `packages/camerawesome_ohos/ohos/src/main/ets/components/plugin/CameraAwesomeX.ets`（`focusOnPoint` L252 附近 / `setWhiteBalance` L292 附近）
- Modify: `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets`（`setFocusMode` L781 附近 / `setFocusPoint` L1057 附近 / `setExposureBias` L1073 附近）

**Interfaces:**
- Consumes: Task 1 的 ohos 通道名 `dev.flutter.pigeon.camerawesome.CameraInterface.setFocusAndExposureLock`。
- Produces: `CameraInterface.setFocusAndExposureLock(...)`（ets 抽象 + 注册）、`CameraAwesomeX.setFocusAndExposureLock(...)`、`CameraState.setFocusAndExposureLockFn(...)`。

**Steps:**

- [ ] 5.1 `Pigeon.ets` 在 `CameraInterface` 接口（`setWhiteBalance` 抽象 L742 后）追加抽象方法：
```typescript
  abstract setFocusAndExposureLock(locked: boolean, x: number, y: number, previewWidth: number, previewHeight: number): void;
```
  在 `setUpCameraInterface` 注册区（`setWhiteBalance` 注册 L1195 附近）追加通道 handler（channel 名 `dev.flutter.pigeon.camerawesome.CameraInterface.setFocusAndExposureLock`），照抄 `setWhiteBalance` 的 `binaryMessenger` / codec 样板。

- [ ] 5.2 `CameraAwesomeX.ets` 实现转发（照仿 `focusOnPoint` L252-256）：
```typescript
  setFocusAndExposureLock(locked: boolean, x: number, y: number, previewWidth: number, previewHeight: number): void {
    Logger.info(TAG, `setFocusAndExposureLock is called, locked: ${locked}`);
    const previewSize = new PreviewSize(previewWidth, previewHeight);
    this.cameraState?.setFocusAndExposureLockFn(locked, previewSize, x, y);
  }
```

- [ ] 5.3 `CameraState.ets` 实现核心逻辑（新增方法，放在 `setExposureBias` L1073 附近）：
```typescript
  /**
   * 长按锁定 AE/AF：x/y 为像素坐标（相对 previewSize），与 focusOnPoint 一致。
   * locked=true：对焦 AFA 到触点 + 曝光锁定到触点；locked=false：恢复连续自动。
   */
  setFocusAndExposureLockFn(locked: boolean, previewSize: PreviewSize, x: number, y: number): void {
    if (locked) {
      // 对焦：自动对焦到触点
      this.setFocusMode(camera.FocusMode.FOCUS_MODE_AUTO)
      this.setFocusPoint(previewSize, x, y)
      // 曝光：锁定模式 + 曝光点
      if (this.session?.isExposureModeSupported(camera.ExposureMode.EXPOSURE_MODE_LOCKED)) {
        this.session?.setExposurePoint({ x: y / previewSize.getHeight(), y: 1 - x / previewSize.getWidth() })
        this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_LOCKED)
      }
    } else {
      if (this.session?.isExposureModeSupported(camera.ExposureMode.EXPOSURE_MODE_AUTO)) {
        this.session?.setExposureMode(camera.ExposureMode.EXPOSURE_MODE_AUTO)
      }
      this.setFocusMode(camera.FocusMode.FOCUS_MODE_CONTINUOUS_AUTO)
    }
  }
```
  > 坐标换算与 `setFocusPoint`（L1057-1058）保持一致：`{ x: y / height, y: 1 - x / width }`。若编译期 `camera.ExposureMode` 枚举名或 `setExposurePoint` 签名与当前 OHOS SDK 版本不符，以 SDK 实际 API 为准调整（`@kit.CameraKit` 的 `camera.ExposureMode` 含 `EXPOSURE_MODE_AUTO` / `EXPOSURE_MODE_LOCKED`）。

- [ ] 5.4 验证：**必须重新编译并重装 App**（ets 改动 hot reload 不生效）。`hvigor`/DevEco 构建 OHOS 工程通过后，真机检查：长按金色框 + 「AE/AF 锁定」常驻、单击解锁并重新对焦、拍照后解锁、曝光锁定生效（画面亮度不再自动变化）。

- [ ] 5.5 Commit（建议信息：`feat(camerawesome_ohos): native AE/AF lock support`）。

---

### Task 6: 收尾验证与文档

**Files:**
- Verify: 全仓 Flutter 测试 + analyze
- Modify: `docs/superpowers/specs/2026-08-24-viewfinder-tap-focus-exposure-lock-design.md`（状态「待评审」→「已实现」）

**Steps:**

- [ ] 6.1 在 `lumira_app_flutter/` 运行 `flutter analyze`，修复所有 warning/error（0 error、0 warning）。

- [ ] 6.2 运行 `flutter test`（全量），确认所有既有 + 新增测试通过；若出现与本计划无关的既有失败（如 schema fixture），记录但不阻塞，确认为历史遗留。

- [ ] 6.3 三端真机手测清单（逐项核对）：
  - iOS / Android / OHOS：单击取景器 → 金色弹性对焦框出现，~1.5s 消失；对焦生效。
  - 长按取景器 → 金色对焦框常驻 + 「AE/AF 锁定」胶囊标签；曝光/对焦被原生锁定（移动手机或改变光源，画面不重新对焦/不重新测光）。
  - 锁定后单击其他位置 → 锁定解除 + 新触点重新对焦（iPhone 行为）。
  - 拍照 / 切换前后摄 / 退出拍摄页 → 锁定自动解除。
  - 双指捏合缩放回归正常；前置摄像头点对焦不崩溃（静默失败）。
  - 4 种 UI 风格 × 主题切换下对焦框/标签颜色正确（叠照片浮层：无阴影、无模糊）。

- [ ] 6.4 更新设计文档状态为「已实现」，并简要记录真机验证结果与已知限制（如非全屏比例下长按坐标与 tap 坐标参考系差异的边界情况）。

- [ ] 6.5 若存在「当前先这样、后续再优化」的内容，按规则追加到 `docs/future-optimizations.md`。

- [ ] 6.6 Commit（建议信息：`docs(capture): mark tap-focus + AE/AF lock design as implemented`）。
