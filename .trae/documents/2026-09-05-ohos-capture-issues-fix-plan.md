# OHOS 拍摄页五问题修复计划

日期：2026-09-05
模块：`lumira_app_flutter/`（Flutter）+ `lumira_app_flutter/packages/camerawesome_ohos/`（OHOS 原生 .ets）+ `lumira_app_flutter/ohos/entry/.../cpp`（C++）

## Context

真机实测一条快照（`sharpen=0, vignette=100, grain=98`）暴露 5 个问题，需按根因逐一修复：

- `cameraService.capture: 2235ms`（原生 capture，HIGH_QUALITY 主因）
- `isPortrait=false` → 走慢的 Dart GPU+isolate+水印管线（又 ~2.3s，成片被旋/裁成 `1280x960`）
- `_LiveBeautyLayer shader program==null` → 取景器只剩色彩矩阵，细节参数无实时预览
- 水印动画内容 ≠ 取景器（OHOS 动画源=原生 FAST_MODE 早帧，未套取景器色彩矩阵/镜像/裁切）
- 锐化怎么拉成片都一样（叠加 F2 低分辨率放大 + 原生/引擎死区）

用户已确认两个决策：**放宽 HIGH_QUALITY（接受牺牲少量系统降噪细节）**、**OHOS 实时预览优先排查 shader（先确认是否打包/引擎问题）**。

---

## F1 成片速度：放宽 `HIGH_QUALITY`（capture 2235ms → 亚秒）

- **文件**：`lumira_app_flutter/packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets` L300-312
- **改动**：删除三行 `setPhotoQualityPrioritization(camera.PhotoQualityPrioritization.HIGH_QUALITY)` 调用，恢复系统默认（速度优先单段式）。保留 `sdkApiVersion >= 21` 与能力检查骨架（注释掉即可回滚）。
- **清晰度补偿**：capture 仍走 OHOS 8.2MP 档（`MAX_PHOTO_PIXELS`）+ 原生后处理 `maxDim=2560` 全分辨率输出，靠超采样补软。无需其它改动。
- **测量**：在 `takePhoto()` 处加 `[perf-cam] capture start → photoAvailable` 计时，记录改前/改后对比（本 plan 附验收）。
- 注：若某些机型去掉 HIGH_QUALITY 后明显糊，再按设计文档 A1 升级到「更高输出分辨率 + 默认优先级」档位。

## F2 方向误判 → 强制走原生快路径 + 恢复全分辨率 + 锐化可感

**根因**：OHOS `LumiraSensorPlugin.ets` 经 `lumira/level_sensor` EventChannel 推送加速度 `[x,y,z]`，Flutter `LevelSensorService`（`level_sensor_service.dart`）用 `portrait = |y| >= |x|` 判定。真机竖持却判成 `isPortrait=false` → `capture_page.dart` L1036 `fastNative=false` → 慢管线，成片 `1280x960`，且 `_applyColorMatrixOnGpu` 里 `alignRotation=270°` 把竖图旋成横图、锐化被低分辨率掩盖。

**改动**（先诊断、后定点，避免盲翻坐标）：
1. `level_sensor_service.dart` `_holdOrientationTransformer`（L140-170）加**首帧诊断日志**：打印原始 `x/y/z`、归一化重力分量、据此判定的 `portrait`，用于真机确认 OHOS `AccelerometerResponse` 的坐标轴约定。
2. 据诊断结果修正映射。最可能：OHOS 竖持时重力主轴落在传感器 **x** 轴（与 Android/iOS 落在 y 轴相反），此时把 OHOS 判定改为 `portrait = |x| >= |y|`，或等价地对调 x/y。加平台分支 `isOhos`，不影响 iOS/Android。
3. **稳健兜底**：当传感器读数持续不可靠（`[0,0,0]` / 平放无方向感 / 流提前关闭）时，回退用 `MediaQuery` 方向（锁竖屏→portrait=true），保证默认走原生快路径并恢复全分辨率输出 + 锐化可感。

**效果**：竖持拍照回到 `processJpeg` 原生快路径（后处理 ~200ms），成片回到全分辨率，锐化/细节可感知；总耗时从 ~4.6s 降到接近「capture 亚秒 + 后处理 ~0.2s」。

## F3 水印动画内容 = 取景器（WYSIWYG）

**根因**：OHOS 动画源=原生 `requestEarlyFrameForAnimation`（`CameraState.ets` L1116-1146，FAST_MODE 低质量，走相册增强管线），未套取景器的色彩矩阵/前置镜像/比例裁切 → 与取景器观感不一致。

**改动**：
- 新增 OHOS 取景器**快门冻结帧捕获**：在 `_doCapture()` 按下快门瞬间，对已合成取景器（含 `ColorFiltered` 色彩矩阵 + 前置镜像 + 裁切）做一次 `RepaintBoundary.toImage`，作为水印动画源，与 iOS `captureFrameForAnimation` 对齐、符合设计文档 A3。
- 保留原生早帧流作为「取景器帧捕获失败/无可用帧」回退；不再作为主动画源。
- `CameraPreview` 复用现有 `rawCaptureKey` 的 RepaintBoundary 模式，新增一个 `shutterFrameKey` 在快门时刻 `toImage()`（单帧，开销可接受）；`camera_preview.dart` / `camera_service.dart` 相应暴露 OHOS 版获取该帧的能力。

## F4 点击对焦「没有了」— 诊断并恢复

**现状**：Flutter `onTapFocus` 已接通 OHOS `AwesomeCameraPreview.onPreviewTap`，原生 `CameraAwesomeX.focusOnPoint → setFocusMode(AUTO)+setFocusPoint`（`CameraState.ets` L1148-1158）均已实现。链路结构完整，但真机未显示/未生效。

**改动**：
1. 在 `camera_preview.dart` `onTapFocus` 回调加 `[capture] onTapFocus tapped=...` 日志；原生 `setFocusPoint` 已有 `normalized` 日志，`focusStateChange` 监听（`CameraState.ets` L1165-1173）存在。
2. 排查外层 `_PinchZoomCamera`（`camera_preview.dart` L448-489）的 `ScaleGestureRecognizer` 与内层 `AwesomeCameraGestureDetector` 的 `TapGestureRecognizer` 手势竞争是否吞掉 tap；若命中，将外层单指分支改为不参与（仅双指触发 `onScale*`）。
3. 确认 `photo_camera_state.dart` `focusOnPoint` 正确透传 OHOS 的 pigeon `PreviewSize` 与 `AndroidFocusSettings`，且 focus 后不立即被切回 `CONTINUOUS_AUTO` 取消（锁定时机见 `registerFocusStateListener` 注释，L1160-1173）。
- 该项为**真机诊断驱动**：先加日志观察 tap 是否到达、原生是否上报聚焦，再定点修。

## F5 取景器实时细节预览：优先排查 shader 加载

**根因**：`PreviewBeautyShader.program == null`（`preview_beauty_shader.dart` L31-38 捕获异常置 null）→ `_LiveBeautyLayer` 降级纯色彩矩阵（`camera_preview.dart` L883-888）。

**改动**（优先排查，不改架构）：
1. 确认 OHOS Flutter 工具链是否把 `pubspec.yaml` 的 `shaders: [preview_beauty.frag, skin_smooth.frag]` 编译/打包为引擎可加载的 runtime-effect。检查 `pubspec.yaml` L196-198 与 OHOS 构建产物（`build/hap` 内 assets 是否含 shader blob）。
2. 若仅打包问题 → 修正构建/资产声明后重编即可恢复实时预览。
3. 若 OHOS 引擎确不支持 `ui.FragmentProgram`（非打包问题）→ **如实报告**，保持现有「色彩矩阵+成片后才见空间效果」降级（符合设计文档 B3=P3 可选），并在计划中给出可选的原生 GPU 预览方案（仿 iOS `PreviewEffectProcessor`，工作量最大、需真机）供后续立项。

---

## 验证

- **静态**：改完跑 `flutter analyze`（项目根 `lumira_app_flutter/`）。
- **真机（必须）**：
  1. 竖持拍照：`[perf-cam] capture` 应降到亚秒；`[perf] OHOS原生 processJpeg 快速路径` 出现（不再走 `_applyColorMatrixOnGpu`/`CaptureWorker`）；成片尺寸回到全分辨率（≥ 2000px 长边）而非 `1280x960`。
  2. 拉锐化 0→100：成片清晰度肉眼可见变化；同时抓 F2 的传感器首帧诊断日志确认竖持 `portrait=true`。
  3. 开/关水印：水印动画内容与取景器所见一致（含前置自拍镜像方向）。
  4. 点击取景器任一点：金色对焦框出现 + `focusStateChange` 上报聚焦（确认 F4 是否只缺链路/竞争）。
  5. 磨皮/锐化/暗角/颗粒在取景器实时可见（若 F5 判定为打包问题则改后生效）。
- **回归**：连拍/切镜头/试用模式/各比例不回退。

## 涉及文件

- `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets`：F1（去 HIGH_QUALITY）、F3（早帧保持回退）
- `lumira_app_flutter/lib/features/capture/services/level_sensor_service.dart`：F2（OHOS 轴映射 + 首帧诊断）
- `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`：F2（用修正后 isPortrait）、F3（快门冻结帧动画源）、F4（tap 日志）
- `lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart`：F3（shutterFrameKey/冻结帧）、F4（手势/日志）
- `lumira_app_flutter/lib/features/capture/services/camerawesome_camera_service.dart`：F3/F4（OHOS 冻结帧与 focus 接线）
- `lumira_app_flutter/pubspec.yaml` + OHOS 构建产物：F5（shader 打包排查）

## 待真机决策（不在本次硬性范围内）

- F5 若确认 OHOS 引擎不支持 FragmentProgram → 是否立项原生化（仿 iOS PreviewEffectProcessor）。