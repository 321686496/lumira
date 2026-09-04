# OHOS 拍摄页拍照性能优化设计

日期：2026-09-04
模块：`lumira_app_flutter/packages/camerawesome_ohos/`（原生 ArkTS）+ `lumira_app_flutter/lib/features/capture/`（Flutter）+ `lumira_app_flutter/ohos/entry/.../ImageProcessorPlugin.ets`（原生 C++）

## 背景与动机

OHOS 端按下快门到出成片的完整链路实测 **2–3 秒**，且采用「先快后质量」方式（先出低质量早帧、成片后再升级）。而官方 CustomCamera 示例与系统原相机按下快门即回（约瞬时、拍摄逻辑与原相机一致）。

对官方 CameraKit/CustomCamera 源码与 `camerawesome_ohos` 原生实现逐段对比后，**瓶颈不在项目后处理（已是硬件 C++ 一圈），而在原生 `camerawesome_ohos` 的同步单发拍照实现**。

## 现状瓶颈（根因，按影响排序）

| # | 环节 | 位置 | 影响 |
|---|---|---|---|
| 1 | `setPhotoQualityPrioritization(HIGH_QUALITY)` | `camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets` L300-312 | **主因**。强制「画质优先」，系统等整条高质量增强链路才出片，把快门时延拉满。官方 demo 不切它有默认（速度优先）+ 分段式交付，所以快 |
| 2 | Dart 侧 `takePhoto()` 同步 await 原生全量完成 | `camerawesome_ohos/lib/src/orchestrator/states/photo_camera_state.dart` L66-81，原生 `photoAvailable` 写盘后才 success (`CameraState.ets` L1005-1049) | 高质量管线+JPEG 编码+磁盘写全部串行完成后才回 Flutter，无「先返回后增强」 |
| 3 | 每次拍照 `await getCurrentDeviceDegree()` 重力传感器 | `CameraState.ets` L949 | 每次快门先异步读重力，且与 App 侧 `sensors_plus` 的 `isPortrait` 重复 |
| 4 | 早帧接在慢 capture 之后 | `photoAssetAvailable`(L1051-1071) → `requestEarlyFrameForAnimation`(L1116) | 「先快后质量」的 FAST_MODE 早帧在成片 asset 可用后才发起，实际没快过成片，只是渐进解码占位 |

> 后处理本身已快：`ImageProcessorPlugin.ets` 是「系统硬件解码 + C++ NAPI（矩阵/锐化/暗角/颗粒）+ 硬件编码」，`processJpeg` 毫秒级。所以 2–3s ≈ 原生 capture 上述 1–3 项。

## 目标

- 按下快门 → 水印动画 / 缩略图首帧到达：**≤ 0.3s**
- 动画淡出 → 跳摄影预览页：**≤ 0.7s**
- 高清成片 + 后处理全部完成（后台）：**≤ 2s**
- 不与官方「一致性」诉求冲突：水印动画帧与取景器 WYSIWYG（见下文方案 A3）。

## 非目标（YAGNI）

- 不做取景器实时美颜烘焙（无此产品诉求）。
- 本设计仅针对 OHOS 原生插件；**iOS 侧的镜像/水印一致性问题单列于文末「iOS 侧专项」**，不与本设计混合实现。
- 首次不做真 ZSL（超采样残留），仅在需要时评估。

## 优化方案清单

### A. 拍摄链路（最大收益，集中在原生 `CameraState.ets`）

**A1. 去除 / 放宽 `HIGH_QUALITY` 优先级**
- 做法：改为默认优先级，或做成「设置内 画质优先/速度优先」开关。
- 若怕糊：用「更高输出分辨率 + 默认优先级」替代「低分辨率 + HIGH_QUALITY」，不牺牲速度。
- 预期：capture 从 ~1.9s → 亚秒。**改动面 1 处，数据可得**。

**A2. 原生分段式（deferred）拍照**
- 做法：`capture()` 立即返回，同时请求一个「低质量取景器冻结帧」立刻给 Flutter 做 interim，全质量图异步递达后再升级 final。直接复用 Flutter 已建好的 **interim→final 状态机**（`captureThumbnailProvider`）。
- 依据：官方「分段式拍照」能力（camera-deferred-capture）。正是「原相机一致」的精髓。
- 预期：首帧 50–200ms；拍摄逻辑对齐 CustomCamera。

**A3. 保证水印动画与取景器一致**
- 做法：动画源用 A2 的「快门时刻冻结取景器帧」（WYSIWYG）；保存成片仍走独立水印合成（`capture_page.dart` L1103-1199，原生解码+编码）。水印位置/文字是确定元数据，两处视觉一致。
- 注：iOS 分支现已是「取景器帧直出（WYSIWYG）」（capture_page L802），本优化是把 OHOS 对齐到 iOS 既有成立路径。
- 关键：冻结帧必须在「快门时刻」发，而非等慢成片。

**A4. 去关键路径重力传感器**
- 做法：`takePhoto` 不再 `await getCurrentDeviceDegree()`，改用 App 侧 `isPortrait` 或独立监听器预计算 rotation。
- 预期：去掉每次快门的一次串行传感器等待。

**A5. Dart 侧提前放行**
- 做法：`MediaCapture.success` 从「整图写盘后」提前到 `captureStart/frameShutter` 或原始 buffer 就绪；解码/后处理与写盘解耦。

### B. 图像后处理（集中在 `ImageProcessorPlugin.ets`）

**B1. 帧级 RGBA/YUV 直处理，替代 JPEG 两遍编解码**
- 现状：`processJpeg` JPEG in → 解码 → 处理 → 编码，两趟 JPEG。
- 做法：分段式 early/photo 直接给 `RGBA_8888` buffer（官方 Image Kit `readPixelsBuffer` + 相机 YUV 拍照），C++ 直算 → **一次编码**；用 fd/共享内存传帧少拷贝。
- 预期：再次降低后处理几百 ms。

**B2. 磨皮/暗角/颗粒沉进原生 GPU 渲染**
- 现状：磨皮等一旦开启会回退 Flutter GPU+isolate（实测 4.5s 慢源，见 capture_page L968）。
- 做法：在 `ImageProcessorPlugin` 原生侧用 **OpenGL ES 片元着色器** 离线渲染磨皮（双边/保边、去噪可分离）。
- 预期：把会拖到秒级的档位压回毫秒级硬件管线，消灭慢回退线。

**B3.（可选）XComponent 原生渲染取景器实时美颜**
- 仅为「要取景器实时看到磨皮」场景；当前无该诉求，优先级最低。

## 建议实施优先级

| 优先级 | 项 | 收益 / 风险 |
|---|---|---|
| P0 | A1 去 HIGH_QUALITY（改 1 处 + 加计时） | 高收益/低风险，先验证 capture 降幅 |
| P0 | A3 水印冻结帧保一致（靠 A2 提供帧源） | 保证产品一致性，低风险 |
| P1 | A2 原生分段式拍照 | 高收益/改动面中等（原生 takePhoto/photoOutputCallBack 两处，Dart `CameraService` 接口零改动） |
| P1 | A4 去重力传感器 / A5 Dart 提前放行 | 低风险小优化 |
| P2 | B1 帧级 RGBA/YUV 直处理 | 高收益/中风险（管线改动） |
| P2 | B2 原生 GPU 磨皮 | 中收益/中风险（新增着色器渲染路径） |
| P3 | B3 取景器实时美颜 | 可选加分项 |

## 预期指标与验收

- 各段加毫秒计时（沿用现有 `[perf]` 日志习惯）：capture、processJpeg、水印渲染、落库。
- 验收标准：
  - 快门→首帧 ≤ 0.3s
  - 快门→跳预览 ≤ 0.7s
  - 后台成片完成 ≤ 2s（含水印）
  - 关闭/开启 HIGH_QUALITY 的 capture 耗时对比记录留存
- 回归：`flutter analyze` 通过；各档位水印动画 / 连拍 / 切镜头 / 试用模式不回退。

## 涉及文件（预估）

- `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets`：A1/A2/A4。
- `packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/Constants.ets`：`MAX_PHOTO_PIXELS` 分辨率档位（A1 配套）。
- `packages/camerawesome_ohos/lib/src/orchestrator/states/photo_camera_state.dart`：A5 提前放行。
- `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`：A3 动画源调整（LoW）；interim→final 复用。
- `lumira_app_flutter/ohos/entry/src/main/ets/plugins/ImageProcessorPlugin.ets`：B1/B2。

> 注：`camerawesome_ohos` 为 path 依赖（`packages/camerawesome_ohos`），原生源码在仓库内，可自由修改，无需第三方发布。

## 官方依据

- Camera Kit 开发指导：https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/camera-dev-arkts
- 分段式拍照：camera-deferred-capture（其低质量+全质量双交付即「原相机一致」来源）
- YUV 拍照（帧级处理依据）：camera-yuv-shooting
- Image Kit 像素直操 / Worker 线程：`PixelMap.readPixelsBuffer(RGBA_8888)`、camera-worker
- 图像后处理无官方「磨皮/暗角/颗粒/锐化」现成接口；依赖 PixelMap 逐像素 + ArkGraphics2D colorFilter/imageFilter + 自研着色器

## 风险

- A2 分段式若设备不支持或递延超时，需回退 A1 快速单发，保持可用。
- B1/B2 涉及原生管线改造，需真机（含常见机型）验证编解码耗时与内存峰值。
- 去 HIGH_QUALITY 后清晰度需肉眼回归，必要时提高输出分辨率补足。

---

# iOS 侧专项：镜像一致性 + 水印动画一致性

> 独立于上文 OHOS 优化。iOS 用另一套插件 `camerawesome`（`packages/camerawesome`，含「预览 cover 算法」补丁）。
> 排查对象：`packages/camerawesome/ios/Classes/CameraPreview/CameraPreview.m`、`packages/camerawesome/ios/Classes/Controllers/Picture/CameraPictureController.m`、`packages/camerawesome/lib/camerawesome_plugin.dart`、`capture_page.dart`。

## 现状与两个 Bug

| 位置 | 事实 |
|---|---|
| `CameraPreview.m` L163-171 | 预览镜像 `videoMirrored` 仅在 `Front` 时开启；`videoOrientation` 固定 Portrait |
| `CameraPreview.m` L744-755 | 视频帧直出 EXIF 恒返回 `1`（避免 dart:ui 再旋 180°） |
| `CameraPreview.m` L757-801 | **非闪光下成片 = 取景器 video 帧直出**；`captureFrameForAnimation` 复用它，是早期/动画帧与成片差异入口 |
| `CameraPreview.m` L805-843 | 闪光 / 高分辨率回退 `AVCapturePhotoOutput` 传统拍照路径 |
| `CameraPictureController.m` L184-219 | 前置 + mirror → `LeftMirrored`，落盘覆盖 EXIF 方向 |
| `camerawesome_plugin.dart` L244-250 | `captureFrameForAnimation` 是 iOS 专用「抓取取景器当前帧直出 JPEG」，即水印定格动画内容源 |

### Bug1：拍摄成片水平镜像
预览镜像/旋转是**视图层属性**（`videoMirrored`），而写盘的水印动画帧与成片都来自**未镜像原始 buffer + EXIF=1**。前置自拍预览镜像、成片不镜像 → 保存后与取景器左右相反，被感知为"镜像了"。且 App 浮层已按 `isFront` 做镜像补偿，**浮层与成片在 front 下互相矛盾**。

### Bug2：水印动画内容 ≠ 取景器
`captureFrameForAnimation` 走与成片**同一条未镜像原始 buffer 路径**，未经过"预览镜像 + 方向"预处理 → 前置下动画内容 = 未镜像原图，与镜像取景器不一致；且 `isWysiwyg` 仅 flash off 生效，flash on 动画源回退成片。

## 修复取向（都改 iOS 原生，Dart 零改动）

给「冻结动画帧」与「成片」应用**与预览一致的镜像（仅 front）+ 方向**，统一「取景器 / 动画帧 / 成片」三层策略，一次解两个 Bug。

## iOS 其余优化空间

| # | 项 | 说明 |
|---|---|---|
| I1 | 镜像一致性（正确性，最高优先） | 统一三层镜像/方向策略，解 Bug1+Bug2 |
| I2 | 闪光路径慢 | `isWysiwyg` 仅 flash off；flash on 走 `AVCapturePhotoOutput` 全分辨率慢路径且动画源退回成片。可对该路径也预支一帧 |
| I3 | 方向烘焙 | 预览锁 Portrait、EXIF 恒 1，设备旋转时成片依赖 dart:ui 再旋。可在原生按重力烘焙正确方向（对齐 OHOS processJpeg 已有 transform） |
| I4 | 动画/即时缩略图少吃 dart:ui 软解码 | 冻结帧经 JPEG+dart:ui 解码；可像 OHOS B1 喂 RGBA buffer，减一层解码 |

## iOS 优先级

| 优先级 | 项 |
|---|---|
| P0 | I1 镜像一致性（解双 Bug） |
| P1 | I2 闪光路径预支帧 |
| P2 | I3 方向烘焙 / I4 RGBA 直喂 |