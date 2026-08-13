# camerawesome 1.4.0 (lumira vendor 版) 补丁说明

本目录是 pub.dev 的 `camerawesome 1.4.0` 原版拷贝（去掉了 docs/example/test/pigeons），
仅用于修复 iOS/Android 端取景器与成片不一致的问题（OHOS 使用单独的
`camerawesome_ohos` git fork，已包含下述 Dart 侧修复）。

## 1. Dart：取景器 cover 缩放算法（lib/src/widgets/preview/awesome_camera_preview.dart）

原版 `CameraPreviewFit.cover` 始终以取景框**高度**为基准缩放竖屏纹理
（宽 = 高 × 纹理宽高比），当取景框比纹理更宽（如 4:3 / 1:1 框 vs 竖屏 16:9
预览流）时不会裁切而是留黑边，取景器显示比例与成片不一致。

已移植 `camerawesome_ohos` 1.0.2 的正确算法：
按宽度铺满与按高度铺满中取能完整覆盖取景框的那个，超出部分由 ClipRect 居中裁切。
同时按实际可见区域修正 `_croppedPreviewSize`（手势/对焦坐标换算）。

算法抽到 `lib/preview_fit.dart` 的 `computeCoverPreviewSize`，应用侧测试见
`lumira_app_flutter/test/features/capture/services/preview_fit_test.dart`。

## 2. iOS 原生：预览流保持 4:3 全传感器（ios/Classes/CameraPreview/CameraPreview.m）

原版 `setBestPreviewQuality` 会把 session preset 切到 16:9 视频 preset
（3840x2160 / 1920x1080 等），而照片输出是 4:3 全传感器，两者视场不一致：

- 16:9 预览流是传感器中心的横向裁切，无法显示 4:3 成片两侧的内容；
- 即使修好 cover 算法，4:3/1:1 取景器也不可能与成片一致（内容本身缺失）。

改为保持 `AVCaptureSessionPresetPhoto`（4:3 全传感器），预览流与成片同视场，
与 OHOS fork 选择与照片同比例的预览 profile 的策略一致。

> 注意：应用未使用视频录制/图像流分析，本补丁未覆盖这两条路径。
## 3. iOS 原生：成片不再做比例裁剪（ios/Classes/Controllers/Picture/CameraPictureController.m）
上游拍照回调会按 `aspectRatio`（应用侧固定为默认 4:3）对照片再裁一次，
且裁剪矩形混用了“方向校正后的 UIImage size”与“传感器原始 CGImage 坐标”，
导致成片在 Dart 后处理裁剪之前就已经被裁小（双次裁剪 → 成片比取景器放大）。
Android（CameraX）与 OHOS（Camera Kit）均保存全传感器原图，交由 Dart 统一裁剪；
本补丁让 iOS 保持一致：`takePicture` 保存全分辨率原图（含 EXIF 方向），
比例裁剪全部由 `lumira_app_flutter` 的 `PhotoPostProcessor.computeCropRect` 完成。
