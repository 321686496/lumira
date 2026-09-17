# 扫一扫优化计划

## Context（背景）

首页 `扫一扫` 使用本地化 `packages/qr_code_scanner`（fork 了 juliuscanute/qr_code_scanner，并合并了 OHOS 适配）。用户反馈三个问题：

1. **识别二维码速度太慢**（影响 iOS / OHOS）
2. **OHOS 首次打开有时黑屏、取景器取不到景**
3. **iOS 越靠近二维码画面越模糊**

经系统排查，三个问题的根因分别定位如下，均已确认到具体文件与代码行。

## 根因分析

### A. 识别慢
- **iOS**：Dart 侧 `QRViewController.updateDimensions` 对 iOS 内置了 `300ms` 延迟（保证 renderbox 就绪），而 `_startScan` 是 **串行 `await`** 它之后再 `invokeMethod('startScan')`。也就是说相机真实开始出流被延后 300ms+，是「识别慢」的感知起点。
  - 位置：[qr_code_scanner.dart](file:///e:/Project/photo_post/lumira_app_flutter/packages/qr_code_scanner/lib/src/qr_code_scanner.dart) `_startScan`（L240-L250）与 `updateDimensions`（L348-L367）。
- **OHOS**：识别回调被 `MyDebounceSingletonUtil.isDebounced(..., 800)` 以 **800ms 防抖**拦住，`detectBarcode.decodeImage` 平均约 1 次/0.8s，且是全 1920x1080 JPEG 帧解码。
  - 位置：[CameraService.ets](file:///e:/Project/photo_post/lumira_app_flutter/packages/qr_code_scanner/ohos/src/main/ets/components/plugin/libs/CameraService.ets) `decodeImageBuffer`（L402-L404）。

### B. OHOS 首次打开黑屏
- 现有代码已做大量加固（空 surfaceId 跳过、initCamera 串行化去重、失败 teardown 清理），但**缺少失败后的恢复/重试**。若 `onLoad→scan()` 的 `initCamera` 偶发失败（设备忙、时序竞争），`canStart` 后没有兜底重试，取景器会一直黑。
- 位置：[OhosQrCodeView.ets](file:///e:/Project/photo_post/lumira_app_flutter/packages/qr_code_scanner/ohos/src/main/ets/components/plugin/OhosQrCodeView.ets) `scan()`（L224-L229）、`onLoad`（L315-L318）。

### C. iOS 越近越模糊
- 现有 `configureHighQualityScanning` 已在会话启动后把 preset 提到 1080p 并设置连续对焦/近距优先，但每次 `didStartScanningBlock` 都无条件执行一次 session 配置：重复变更 `sessionPreset` 会触发 AVFoundation 会话异步重建，把刚设好的连续自动对焦/近距限制冲掉，导致近距反复重新拉焦、画面发虚。缺少「只重建一次」的守卫，且对焦恢复只靠 2 个固定延时（0.2s/0.8s），覆盖不全。
- 位置：[QRView.swift](file:///e:/Project/photo_post/lumira_app_flutter/packages/qr_code_scanner/ios/Classes/QRView.swift) `configureHighQualityScanning`（L253-L301）。

## 改动方案

### 1. Dart：并行化 startScan，消除 iOS 300ms 启动延迟
文件：`packages/qr_code_scanner/lib/src/qr_code_scanner.dart` 的 `_startScan`

- 将「`await updateDimensions()` 之后再 `startScan`」改为并行：
  - `startScan` 立即发起；
  - `updateDimensions` 用 `unawaited(...)` 并发执行（iOS 的 300ms 与扫描互不阻塞，扫描区域随后下发）。
- 复用现有 `unawaited`（文件已 `import 'dart:async'`）。此改动对 Android/OHOS 同样更早出流，无副作用。

### 2. iOS：为 session 重建加守卫 + 强化近距连续对焦
文件：`packages/qr_code_scanner/ios/Classes/QRView.swift`

- 新增 `private var didConfigureHighQuality = false`：
  - `configureHighQualityScanning` 仅在 `!didConfigureHighQuality` 时执行 preset 变更（`beginConfiguration…commit`）一次，之后置位；
  - 每次 `didStartScanningBlock` 仍调用它，用于**重复补对焦**（近期条目逻辑），但不再反复触发会话重建。
- 把对焦恢复从「2 个固定 dispatch」改为「立即 + 短周期重复补（约 1.5s 内 3~4 次）」，确保 preset 重建导致的连续对焦/近距限制回退被可靠恢复，直击「越近越模糊」。
- 保留现有：1060/1080 preset 提升、`applyBestFocus`（中央+continuous AF/AE+`.near`）、点击对焦 `handleTapToFocus`。

### 3. OHOS：降低识别防抖 + 失败重试兜底
文件：
- `packages/qr_code_scanner/ohos/src/main/ets/components/plugin/libs/CameraService.ets`
  - `decodeImageBuffer` 的防抖窗口 `800 → 200`（约 4× 识别频率；ScanKit `decodeImage` 为异步 Worker 解码，200ms 节流在流畅度与实时性之间取平衡）。
- `packages/qr_code_scanner/ohos/src/main/ets/components/plugin/OhosQrCodeView.ets`
  - `scan()`（onLoad 回调）：`initCamera` 后增加**一次性失败重试**——若 `cameraService` 的会话未成功启动，延时 ~300ms 重试一次（幂等，由 `initCamera` 的去重/串行逻辑兜底），避免首次打开偶发黑屏后无恢复。
  - `onPageShow` 已跳过空 surfaceId，保持不变。

> 说明：更进一步的 OHOS 提速（把 ScanKit 识别流降到 720p 以减少每帧解码量）会涉及 preview profile 匹配与 imageReceiver 尺寸联动，风险较高且需真机验证；本计划不展开，作为「后续优化」候选登记。

## 验证

均为原生/HAR 改动，无法在本机跑自动测试，需真机验证：

1. **构建**：iOS 侧 `pod install` 后 `flutter build ios`（或直接跑真机）；OHOS 侧照常构建 App 的 ohos 工程（qr_code_scanner 为其中的 ohos 模块）。
2. **iOS 识别速度 + 近距清晰度**：连开多次扫码页，观察相机出流与识别耗时；把二维码从 30cm 缓慢靠近到约 10cm，确认画面保持清晰不拉风箱。
3. **OHOS 黑屏 + 速度**：冷启动连续进出扫码页 ≥10 次，确认不再黑屏；同一二维码对准后记录识别到结果的耗时（应显著短于此前约 0.8s 间隔）。
4. 若在真机仍有异常，通过各端日志核对：
   - iOS：`[QRView] high-quality configured` / focus 相关 NSLog；
   - OHOS：`[CameraService]` / `[OhosView]` console 输出。