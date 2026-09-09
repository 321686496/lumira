# iOS 取景器与成片统一（WYSIWYG）+ 取景器全效果实时

## 概述（Summary）

用户报告 iOS 拍摄页「实时预览」与「拍摄成片」严重不一致，无论默认值还是调参后都如此。

系统性根因调查确认：**iOS 取景器与成片走两条完全不同的原生相机管线**，导致色彩、效果均对不上。

本次目标（用户已确认会议范围 = 完整）：
1. **统一色彩**：让成片 = 取景器所见（WYSIWYG）。
2. **取景器全效果实时**：磨皮 / 锐化 / 清晰度 / 暗角 / 颗粒 在取景器也实时显示，并与成片一致。
3. 去除 Dart 侧所有「治标不治本」的补色逻辑。

## 现状分析（Current State Analysis）

### 管线拓扑（已逐步核对源码证实）

```
iOS 相机传感器
 ├─ AVCaptureVideoDataOutput ──> _latestPixelBuffer ──(copyPixelBuffer)──> FlutterTexture ──ColorFiltered(色彩矩阵)──> 取景器
 │      （video 管线，色彩中性）                                            仅色彩矩阵实时；空间效果不显示
 └─ AVCapturePhotoOutput ──> takePictureAtPath ──> 成片 JPEG（偏暖）
        （photo 管线，Smart HDR/Deep Fusion，ISP 比 video 偏暖）
             └─ Dart capture_page.dart: 解码 → isDisplayP3Jpeg? applyP3ToSrgbRgba → 
                    _buildAdaptiveWhiteBalanceMatrixFromRgba(灰区自适应WB) →
                    _applyColorMatrixOnGpu(dart:ui ColorFilter.matrix) →
                    worker isolate: applySmoothSkinImg/applyPerPixelEffectsImg/applyVignetteImg
```

### 关键事实（Phase 1 证据）

1. **成片走 photo 管线**：[CameraPreview.m takePictureAtPath](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L734-L740) → `captureWithPhotoOutputAtPath`。注释原文：「photoOutput 的照片 ISP（Smart HDR/Deep Fusion）产出比 video 管线偏暖的内容……锁白平衡 / P3→sRGB 色域转换 / 灰区自适应白平衡均无法消除」。
2. **取景器走 video 管线**：[didOutputSampleBuffer](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L908-L933) 存 `_latestPixelBuffer`；[copyPixelBuffer](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L945-L958) 供 FlutterTexture 消费。取景器就是这一帧。
3. **项目已有 video 帧直出**：[captureVideoFrameToJpegAtPath](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L637-L717)，注释明确「成片与取景器同源同色、100% 所见即所得」，且 exifOrientation 恒为 1（video 帧已物理竖屏）。但**目前仅用于水印动画源**，成片仍走偏暖的 photoOutput。
4. **Dart 侧补色**：[capture_page.dart _applyColorMatrixOnGpu](file:///e:/Project/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L4291-L4315) 内做 P3→sRGB + 自适应 WB，并写色彩诊断 IO `_writeColorDiagnostics`（L4259）。
5. **取景器仅色彩矩阵实时**：[camera_preview.dart filteredCamera](file:///e:/Project/photo_post/lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart#L205-L211) 用 `ColorFiltered(fromPostProcess(effectivePost))`；空间效果（磨皮/锐化/暗角/颗粒）只在成片 worker 出现。
6. **原生无 GPU 效果管线**：iOS 侧仅有 `setFilterMatrix:`（TODO 未实现，[CamerawesomePlugin.m L437-439](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CamerawesomePlugin.m#L437-L439)）。无 Metal/CoreImage 效果链。

### 根因结论
- 不一致 = 双管线（video 取景 vs photo 成片）。
- 取景器不显示空间效果 = 空间效果只在成片 CPU worker 里做。

## 方案（Proposed Changes）

### 核心思路（决定一次做对）
把**效果链上移到 iOS 原生 video 帧阶段**（`didOutputSampleBuffer` → 存 `_latestPixelBuffer` 之前），用 **CoreImage（自动 Metal GPU 加速）** 对每个取景器帧施加全部效果：
- 取景器看到 = 处理后的 video 帧 = **实时全效果**。
- 成片改为默认走 **video 帧直出**（已有 `captureVideoFrameToJpegAtPath`）＝ **同源同色同效果**。
- 闪光模式（捕捉不到瞬时闪光）回退 photoOutput（保留原直出通道）。

效果顺序（与成片 worker 保持一致）：色彩矩阵 → 磨皮 → 清晰度 → 锐化 → 颗粒 → 暗角。

### 逐文件改动

#### A. 新增原生效果管线（新文件）
- **`packages/camerawesome/ios/Classes/Rendering/EffectPipeline.h/.m`**（新建）
  - 维护 `CIContext`（Metal 支持）、`CIFilter` 链状态。
  - 输入 BGRA `CVPixelBufferRef` → `CIImage` → 链式滤镜 → `context.render` 输出到目标 BGRA buffer。
  - 参数 setter（来自 Dart）：色彩矩阵(20 系数)、磨皮强度、锐化、清晰度、颗粒、暗角。
  - 磨皮用 `CIPortraitSkinMatte`（受支持设备）或自定义 `CIKernel`（肤色掩膜 + 边缘保留平滑，镜像 Dart `SkinSmoother` 算法）。
  - 明确性能预算：单帧 GPU 处理目标 ≤ 8ms，保证 30fps 取景流畅。

#### B. iOS 原生取景器
- **`packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m`**
  1. 在 [didOutputSampleBuffer](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L908-L933) 中，对 `_captureVideoOutput` 分支：将 `newBuffer` 经 `EffectPipeline` 处理后得到 `processedBuffer`，再做原子换出存入 `_latestPixelBuffer`；原 buffer 释放。
     - 需新建目标 pixel buffer pool（BGRA），避免每帧分配。
  2. [captureVideoFrameToJpegAtPath](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m#L637-L717) 已取处理后的 `_latestPixelBuffer`，自带 WYSIWYG，无需改。
  3. 新增 `applyEffectParameters:...` 透传方法。
- **`packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.h`**：声明新方法。

#### C. iOS 插件/通道
- **`packages/camerawesome/ios/Classes/CamerawesomePlugin.m`**：实现 [setFilterMatrix](file:///e:/Project/photo_post/lumira_app_flutter/packages/camerawesome/ios/Classes/CamerawesomePlugin.m#L437-L439)，扩展为 `applyPostProcess` 通道，把色彩矩阵 + 各空间效果参数传给 `EffectPipeline`。
- **`packages/camerawesome/ios/Classes/Pigeon/Pigeon.m/.h`**：如需要，为效果参数新增 Pigeon message（优先用现有 channel 传 Map 减少改动）。

#### D. Dart 拍摄服务（参数透传）
- **`lib/features/capture/services/camerawesome_camera_service.dart`**：
  - 新增 `applyPostProcess(PostProcess)` 方法，把 `filter_recipe.composePostProcessMatrix`（色彩矩阵）与 smoothStrength/sharpen/clarity/grain/vignette/legStretch 序列化为原生参数并调用插件通道。
- **`lib/features/capture/services/camera_service.dart`**：接口增加 `applyPostProcess`（三端：iOS 走原生通道；OHOS/Android 暂空实现，后续对齐）。

#### E. 取景器去掉冗余叠层
- **`lib/features/capture/widgets/camera_preview.dart`**：
  - 效果已由原生视频帧承载，移除 `ColorFiltered` 包裹（[filteredCamera L205-211](file:///e:/Project/photo_post/lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart#L205-L211)），改为直接渲染原始相机流（空间效果已在原生帧内）。拉腿 `legStretch` 仍走 camerawesome 双层 GPU 合成（未被取代，保留）。

#### F. 成片路径切直出 + 清理补色
- **`lib/features/capture/services/camerawesome_camera_service.dart` capture()**：iOS 且非闪光模式时，用 `captureFrameForAnimation`（即 video 帧直出，已实现）作为成片源，替代 `photoState.takePhoto`；闪光模式保持 photoOutput。
- **`lib/features/capture/pages/capture_page.dart`**：
  - `_onCapture`：iOS 非闪光时，成片 = 取景器帧直出路径。
  - 移除/停用：`isDisplayP3Jpeg` + `applyP3ToSrgbRgba`、`_buildAdaptiveWhiteBalanceMatrixFromRgba`、`_writeColorDiagnostics` 的偏黄诊断分支。
  - `_applyColorMatrixOnGpu`：色彩矩阵上移到原生后，Dart 侧不再重复叠加补色（保留方向对齐/裁切/缩放/拉腿几何处理）。
- **`lib/features/capture/services/dart_photo_pipeline.dart`**：`_isDisplayP3Jpeg`/`_applyP3ToSrgb` 逻辑保留但不再在 iOS 直出路径启用（video 帧已是 sRGB 语境）。`_processInIsolate` 的效果仍作为「后期编辑/非 iOS 平台」兜底保留。

#### G. 快速效果预览组件
- 现有 `SkinSmoothPreview`（GPU shader，供**编辑页静态图**用）**保留不动**——它服务于静态图片，本次仅取景器实时流交给原生。避免该组件被误删。

### 关键决策（Assumptions & Decisions）
1. **统一基准 = video 帧（sRGB 语境）**，而非 photo。取景器就是 video，直出成片即一致。与 OHOS「原始帧直出」一致。
2. **实时效果在原生 CoreImage 做**，不在 Flutter FragmentShader（取景器是 FlutterTexture 实时流，无静态 `ui.Image` 可喂 FragmentProgram）。已有 `skin_smooth.frag` 仅用于静态编辑页。
3. **闪光模式回退 photoOutput**：video 帧捕捉不到瞬时闪光（现有 `captureFrameForAnimation` 注释已声明），保留原直出通道。色彩不足由原生 WB 锁定缓解（保留 `lockWhiteBalanceToCurrentPreview`）。
4. **效果顺序统一**为：色彩矩阵 → 磨皮 → 清晰度 → 锐化 → 颗粒 → 暗角，原生与成片 worker 保持一致。
5. 拉腿仍走 camerawesome 双层 GPU 合成（未包含在本次色彩/空间效果重构内）。

## 验证（Verification）

1. **色彩一致性**：iOS 真机，默认参数连拍，取对比灰度卡 / 肤色参考，取景器截帧 vs 成片平均 RGB 差 ≤ 3/255。
2. **全效果实时**：调整磨皮/锐化/暗角/颗粒滑块，取景器秒级实时变化，无卡顿（帧率 ≥ 25fps，Instrument Time Profiler 单帧 GPU ≤ 8ms）。
3. **参数变化 WYSIWYG**：任意参数组合下，成片与取景器最后一帧视觉一致。
4. **闪光模式**：开闪光拍摄，成片正常曝光（走 photoOutput 直出），不黑屏、不缺失。
5. **iOS 分析/编译**：`flutter analyze` + iOS build 通过；OHOS/Android 回归不受影响（新通道为空实现 + 原管线兜底）。
6. **成片质量**：直出分辨率 = 取景器 resolution（预览档），与需求「成片 800ms 内」目标兼容（直出省去 photo 管线延迟）。

## 风险
- CoreImage 全分辨率实时磨皮性能：若超预算，磨皮在预览档降采样上做，成片直出用同帧（预览档，语义一致）。
- 色彩矩阵被原生接管后，需在 iOS 端用与 `filter_recipe.composePostProcessMatrix` 相同 20 系数，避免算错。
- 成片从 12MP 降为预览档分辨率：属天然权衡（换取 WYSIWYG 与速度），已在决策 1 声明，需用户知悉。