# 修复全屏(fullscreen)横拍「所见即所得」（WYSIWYG）

## Context（为什么改）

用户报告 Bug：**全屏档横持手机拍摄，成片仍是 9:16 竖图，而非 16:9 横满屏**。此前两次尝试只改输出 targetRatio、未让取景器跟着旋转，导致"成片横、取景竖"的所见非所得，被用户否定并已回退。

已确认事实（读码核实，`capture_page.dart` 现与 HEAD 逐 token 一致，`M` 仅为 CRLF 换行符差异）：

- **根因精确**：`CaptureState.computeTargetRatio('fullscreen', isPortrait)`（`capture_state.dart` L100-103）对 `fullscreen` **无条件返回 `null`**。于是：
  - `_doCapture`（`capture_page.dart` L1026-1027）落到 `?? screenRatio`，而 `screenRatio = MediaQuery 宽/高`，UI 恒锁竖屏 → **恒竖屏值、从不随物理方向翻转**。
  - 4:3/1:1 正常是因为 `computeTargetRatio('4:3', isPortrait=false)=4/3` 已按传感器方向正确翻转（走 GPU+isolate 旋转管线）。
- 成片仅消费 `params.targetRatio` + `params.isPortrait` 两个数（GPU 变换见 L3230-3259），对 fullscreen 无特殊分支 → 只需让 fullscreen 的 targetRatio 随方向翻转，成片即变横。
- 四个计算点目前都基于 `MediaQuery`/LayoutBuilder constraints，UI 恒竖屏，**全部不含传感器方向**：
  1. `_doCapture` L1015-1027（已用 `_devicePortrait` 判方向，但 fullscreen 落回竖屏 `screenRatio`）
  2. `_buildEarlyFrameInterimJob` L1696-1724（OHOS 早帧，仅竖屏路，含 fullscreen 用 `screenRatio`）
  3. `_ViewfinderArea._Viewfinder` L2553-2569（取景器，`isPortrait` 来自 LayoutBuilder constraints 恒竖屏）
  4. `_FloatingViewfinder` L2693-2699（补光悬浮窗，同恒竖屏）

- 页面层已有完整传感器状态：`_devicePortrait`、`_isLandscape`、`_landscapeQuarterTurns`（L191-192，initState L323-336 由 `LevelSensorService.holdOrientationStream()` 更新，quarterTurns=1/3）。模板信息卡横屏旋转即复用它（`RotatedBox(quarterTurns: _landscapeQuarterTurns)`，见 `template_info_card.dart` L227）。

- **关键几何**：横满屏 19.5:9 旋转 90° 后恰为 9:19.5 竖屏 == 屏幕竖满屏比例 → 把取景器内容用 `RotatedBox` 转 90°，既能铺满整屏竖画布，又相对用户握持方向呈横屏可读（等于"原相机横屏照片效果"）。

**用户已确认的意图（AskUserQuestion）：**
1. 横持全屏档 → **取景整体旋转 90° 成横满屏**，成片与之对应的横满屏（WYSIWYG）。
2. **完全不动 4:3 / 1:1 的逻辑**（它们的现有行为丝毫不变）。

## 目标状态

- 竖持（`isPortrait=true`）：fullscreen 行为与现在完全一致（竖满屏 9:19.5），4:3/1:1 原样。
- 横持（`isPortrait=false`）：fullscreen 取景器整体旋转 `_landscapeQuarterTurns` 成横满屏，成片为对应横满屏（`1/screenRatio` 宽高比），取景与成片一致；4:3/1:1 仍按现有正确逻辑（成片横/竖由 targetRatio 翻转 + GPU 旋转）。

## 实现步骤

### 第 1 步：`capture_state.dart` — 新增 fullscreen 专用比例解析（不动现有逻辑）

在 `CaptureState` 增加一个静态方法，**不改动** `computeTargetRatio`（4:3/1:1 路径必须零变化）：

```dart
/// 计算 fullscreen 目标宽高比（width/height）。
/// 与原生相机一致随设备方向翻转：
/// - 竖持：短边/长边 = screenRatio（屏幕原比，≈9:19.5）
/// - 横持：长边/短边 = 1/screenRatio（≈19.5:9，横满屏）
static double fullscreenRatio(bool isPortrait, double screenRatio) {
  if (!isPortrait) return 1.0 / screenRatio;
  return screenRatio;
}
```

### 第 2 步：`capture_page.dart` — 三个恒竖屏计算点改用传感器方向

**2a. `_doCapture` L1026-1027**：把
```dart
final targetRatio =
    CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
```
改为（fullscreen 专用翻转，4:3/1:1 不受影响）：
```dart
final targetRatio = ratioId == 'fullscreen'
    ? CaptureState.fullscreenRatio(isPortrait, screenRatio)
    : CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
```

**2b. `_buildEarlyFrameInterimJob` L1712-1714**：同样替换（该方法本就有 `isPortrait` 参数）。保持"仅竖屏路"守卫不动（横屏早帧仍回落，不影响 fullscreen 成片——成片走 GPU 管线）。

**2c. `_FloatingViewfinder` L2698-2699**：`windowRatio` 同样用 `fullscreenRatio` 替换 fullscreen 分支。

### 第 3 步：`_Viewfinder` 取景器 — 全屏横持整体旋转（WYSIWYG 核心）

`_ViewfinderArea`、`_Viewfinder`（L2538-2650）目前是独立 `ConsumerWidget`，`isPortrait` 取 LayoutBuilder constraints（恒竖屏）。改造：

1. 给 `_ViewfinderArea` 新增字段 `devicePortrait`（bool）、`landscapeQuarterTurns`（int），由页面 `build`（L2281-2286）传入 `_devicePortrait` 与 `_landscapeQuarterTurns`。`_FloatingViewfinder` 如需也可传入。
2. `_Viewfinder` 里 `final isPortrait = screenSize.height >= screenSize.width;`（L2566）改为：**fullscreen 时才用 `widget.devicePortrait`，非 fullscreen 保持 constraints 判定** —— 这样 4:3/1:1 的取景框逻辑一个字节都不动：
   ```dart
   final isPortrait = ratioId == 'fullscreen' && widget.devicePortrait != null
       ? widget.devicePortrait!
       : screenSize.height >= screenSize.width;
   ```
   （注意 `targetRatio` 计算保持用翻转后的 `isPortrait` 走第 2 步逻辑或直接 `fullscreenRatio`。）

3. **fullscreen 且横持时整体旋转**：`_Viewfinder` 返回的 `AnimatedContainer(width: vfW, height: vfH, child: viewfinder)`（L2627-2633）里，把 `child` 包一层：
   ```dart
   child: isFullscreen && !isPortrait && widget.landscapeQuarterTurns != 0
       ? RotatedBox(
           quarterTurns: widget.landscapeQuarterTurns,
           child: viewfinder,
         )
       : viewfinder,
   ```
   因为 `RotatedBox` 旋转横满屏内容后布局宽高互换，恰可铺满恒竖屏画布，与模板信息卡 L227 同一手法。**仅当 `isFullscreen && !isPortrait`** 才包，4:3/1:1 的 child 原样返回。

> 说明：`CameraPreview` 自身的 Stack（构图线/姿势/水印源，见 `camera_preview.dart` L316-330）都在这层 viewfinder 之内，整体旋转即同步旋转，无需逐个改。

### 第 4 步：水印动画源方向

页面 `build` 处 `_captureShutterViewfinderFrame()`/WatermarkAnimationOverlay 使用 `isPortrait = MediaQuery 高>=宽`（L2048-2049）恒竖屏。全屏横拍水印动画源的 `isPortrait` 应改用 `_devicePortrait`，避免横拍水印定格方向错。仅此一处并把横屏旋转后的取景帧视为"已对齐"（沿用 `sourceAligned` 逻辑）。

## 不改动项（红线）

- `CaptureState.computeTargetRatio` 本体：4:3/1:1 一个字节不动。
- 竖持 fullscreen 行为：不变。
- 4:3/1:1 的取景框尺寸、cover 裁切逻辑：不变。
- 不新增任何 debugPrint 诊断日志。

## 验证

- **静态核对**
  1. 竖持 fullscreen：`fullscreenRatio(true, ~0.46)=0.46`，与现在一致；不包 RotatedBox。
  2. 横持 fullscreen：`fullscreenRatio(false, 0.46)=~2.17`；取景器包 `RotatedBox(quarterTurns:1/3)`；成片 `targetRatio≈2.17, isPortrait=false` → GPU 输出 `outW=maxDim, outH=maxDim/2.17`（L3252-3258）横满屏，与取景一致。
  3. 4:3/1:1：`computeTargetRatio` 未动，横竖都能按现有逻辑翻转 → 行为不变。
- **真机验证（必测）**：`flutter run --dart-define=API_BASE_URL=...` 接手机——
  1. 横持手机选全屏 → 取景器整体转 90° 成横满屏、预览/构图线/姿势可读；
  2. 快门 → 成片为横满屏，水印定格方向正确；
  3. 竖持全屏、4:3、1:1 横竖各拍一张，与改进前结果逐一对齐（无回归）。
- 无法真机时，以第 1-2 条读码核对为准，并请用户真机复核。