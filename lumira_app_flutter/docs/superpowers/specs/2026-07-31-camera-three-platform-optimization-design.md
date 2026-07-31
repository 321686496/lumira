# 拍摄功能三端适配 + 性能极限调优设计

> 日期：2026-07-31
> 范围：Flutter 拍摄功能（HarmonyOS / iOS / Android 三端适配 + 拍照性能两阶段调优）
> 状态：已确认架构方向，待实现

---

## 0. 背景与目标

### 0.1 现状

- 相机依赖 `camerawesome_ohos` 1.0.2（gitcode fork），其 pubspec 仅声明 `ohos` 平台（[ohos/pubspec.yaml:43-46](file:///d:/app/flutter/flutter_pub_cache/git/fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc/ohos/pubspec.yaml#L43-L46)），iOS / Android 编译会抛 `MissingPluginException`。
- 拍照后处理全在主 Isolate 串行执行（[photo_post_processor.dart:33-242](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart#L33-L242)），UI 冻结 200-500ms。
- 无 ZSL / 预捕获 / Isolate / 硬件编码，按下快门到出片 550-1300ms+。
- 拍照后强制跳预览页（[capture_page.dart:519-529](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L519-L529)），无法连拍。
- `CaptureState` 直接持有 camerawesome 的 `CameraState` 类型（[capture_state.dart:28](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/data/capture_state.dart#L28)），业务层与相机库耦合。

### 0.2 目标（两阶段）

| 阶段 | 硬指标 | 工作量 | 范围 |
|---|---|---|---|
| 阶段一 | 体感延迟 < 200ms（按下到近似最终图） | 2-3 周 | 三端共享 `CameraService` 抽象 + `PhotoPipeline` 双管线 Isolate 化 + 原生相机交互模式（缩略图角标 + 连拍） |
| 阶段二 | 物理延迟 < 100ms（按下到最终图） | 1-2 个月 | 各端原生相机层下沉（OHOS Camera Kit / AVFoundation / Camera2 + ZSL + 硬件 ISP/编码） |

阶段一接口在阶段二零改动，仅替换实现。

### 0.3 非目标

- 阶段一不实现真 ZSL（环形缓冲 / YUV 预捕获），留给阶段二。
- 阶段一不替换 JPEG 软编码为硬件编码，留给阶段二。
- 不重构非拍摄页面的代码。

---

## 1. 架构总览

### 1.1 目标分层架构

```
                        ┌──────────────────────────────────────┐
                        │     CameraService 抽象接口            │
                        │  (Dart 层, 三端共享)                  │
                        │  - initialize() / dispose()          │
                        │  - capture() : Future<CaptureResult> │
                        │  - focusOnPoint() / setZoom() / ...  │
                        │  - buildPreview() : Widget           │
                        └──────────────────────────────────────┘
                              ▲           ▲           ▲
            阶段一实现         │           │           │
        ┌──────────────┐  ┌──────────┐  ┌──────────────┐
        │OhosCamSrv    │  │IOSCamSrv │  │AndroidCamSrv │
        │camerawesome  │  │camerawesome│ │camerawesome  │
        │_ohos fork    │  │原版 1.4.0 │  │原版 1.4.0    │
        └──────────────┘  └──────────┘  └──────────────┘
            阶段二演进         │           │           │
        ┌──────────────┐  ┌──────────┐  ┌──────────────┐
        │OhosNative    │  │IOSNative │  │AndroidNative │
        │Camera Kit    │  │AVFound+  │  │Camera2 +     │
        │+ ZSL         │  │PhotoKit  │  │YUV + Vulkan  │
        └──────────────┘  └──────────┘  └──────────────┘

                        ┌──────────────────────────────────────┐
                        │     PhotoPipeline 抽象接口            │
                        │  (Dart 层, 三端共享)                  │
                        │  - quickProcess(): QuickResult 同步  │
                        │  - fullProcess(): Future<Final> 异步 │
                        └──────────────────────────────────────┘
                                       │
                                       ▼
                        ┌──────────────────────────────────────┐
                        │  DartPhotoPipeline (阶段一唯一实现)   │
                        │  quick: 解码+裁剪+ColorMatrix+Vignette│
                        │         (Canvas GPU, 主Isolate <100ms)│
                        │  full:  皮肤平滑+Sharpen+Grain+补光   │
                        │         +JPEG软编码 (Isolate 300-800ms)│
                        └──────────────────────────────────────┘
                                       │
                         阶段二演进     ▼
                        ┌──────────────────────────────────────┐
                        │  各端原生 PhotoPipeline (阶段二)      │
                        │  iOS: Metal MPS / Android: Vulkan    │
                        │  / OHOS: 原生 PixelMap               │
                        └──────────────────────────────────────┘
```

### 1.2 拍摄流程时序（阶段一目标）

```
T=0      用户按下快门
T+10ms   CaptureButton 动画启动
T+30ms   CameraService.capture() 调用
         UI 立即响应：快门音效 + 屏幕白闪 + 角标缩略图占位（灰色圆角）
T+50ms   JPEG 文件就绪（camerawesome 回调）
T+150ms  quickProcess 完成 → 角标缩略图替换为"近似最终图"
         ── 用户感知：按下 150ms 看到调好色的图，可立即按下一次 ──
T+150ms  fullProcess 在 Isolate 后台启动
         CaptureButton 已恢复可用 → 支持连拍
T+500ms  fullProcess 完成 → 角标缩略图无缝 swap 为最终图
         → 落库（SQLite）
         → 不再自动跳预览页
T+??     用户点击角标缩略图 → 才跳预览页
```

### 1.3 阶段一 / 阶段二分工

| 项 | 阶段一（本次实现） | 阶段二（后续演进） |
|---|---|---|
| 相机层 | `CameraService` + 三端 camerawesome 实现 | 替换为各端原生 Camera Kit/AVFoundation/Camera2 |
| ZSL | 无（按下才曝光，quickProcess < 100ms 掩盖） | 原生环形缓冲真 ZSL |
| 后处理 | `DartPhotoPipeline`（Canvas GPU + image 包 CPU，Isolate 化） | 原生 Metal/Vulkan/PixelMap 管线 |
| JPEG 编码 | `img.encodeJpg` 软编码（在 Isolate 中） | 原生硬件编码器 |
| 延迟 | 体感 < 200ms（按下到近似图） | 物理 < 100ms（按下到最终图） |
| 接口稳定性 | `CameraService` / `PhotoPipeline` 接口冻结 | 接口零改动，只换实现 |

---

## 2. CameraService 抽象层

### 2.1 问题

`CaptureState.cameraStateProvider` 直接持有 camerawesome 的 `CameraState`，业务层（capture_page）直接调用 `state.when(onPhotoMode: (p) => p.takePhoto())`，类型耦合散布三处。要支持三端，必须把 camerawesome 类型驱逐出业务层。

### 2.2 抽象接口

新增 `lib/features/capture/services/camera_service.dart`：

```dart
/// 平台无关的相机服务接口。
/// 阶段一：三端实现各自封装 camerawesome（ohos fork / 原版 1.4.0）
/// 阶段二：替换为各端原生相机层，本接口零改动
abstract interface class CameraService {
  /// 初始化相机。facing = 'front' | 'back'
  Future<void> initialize({required String facing});

  /// 释放相机资源
  Future<void> dispose();

  /// 拍照。返回原始 JPEG 文件路径（传感器直出，未做任何后处理）。
  /// 调用方负责后续 quickProcess / fullProcess。
  Future<CaptureResult> capture({required CaptureConfig config});

  /// 切换前后摄像头
  Future<void> switchCamera(String facing);

  /// 设置缩放（真实倍数，1.0 = 1x，0.5 = 0.5x）
  void setZoom(double multiplier);

  /// 设置闪光灯模式
  void setFlashMode(CameraFlashMode mode);

  /// 点击对焦
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize);

  /// 取景器 widget（平台实现负责构建原生预览）
  Widget buildPreview({required CameraPreviewConfig config});

  /// 相机就绪状态流（用于 UI 显示"正在初始化"提示）
  Stream<bool> get readyStream;
}

/// 拍照结果（平台无关，不携带 camerawesome 的 MediaCapture）
class CaptureResult {
  final String filePath;                  // 原始 JPEG 路径
  final int sensorWidth;                  // 传感器原始宽
  final int sensorHeight;                 // 传感器原始高
  final SensorOrientation orientation;    // 拍摄时传感器方向
  final int? timestampMs;                 // 传感器曝光时间戳（阶段二 ZSL 用）
}

/// 拍照配置快照（按下快门时的状态）
class CaptureConfig {
  final String facing;
  final double zoomMultiplier;
  final CameraFlashMode flashMode;
  final double? evCompensation;           // 阶段二：扩展 ISO / shutter / wb
}

enum CameraFlashMode { off, on, auto, torch }
enum SensorOrientation { portrait, landscape, portraitUpsideDown, landscapeLeft }

/// 取景器配置
class CameraPreviewConfig {
  final String facing;
  final CameraPreviewFit fit;             // cover / contain
  final VoidCallback? onReady;
  final void Function(Offset, Size)? onTapFocus;
  final void Function(double)? onScaleZoom;
}

enum CameraPreviewFit { cover, contain }
```

### 2.3 三端实现（阶段一）

| 平台 | 实现类 | 包裹的库 | pubspec 改动 |
|---|---|---|---|
| HarmonyOS | `CamerawesomeCameraService` + `CamerawesomeDelegate.ohos()` | `camerawesome_ohos`（已有 gitcode fork） | 不变 |
| iOS | `CamerawesomeCameraService` + `CamerawesomeDelegate.ios()` | `camerawesome` 1.4.0（pub.dev 原版） | 新增依赖 |
| Android | `CamerawesomeCameraService` + `CamerawesomeDelegate.android()` | `camerawesome` 1.4.0（pub.dev 原版） | 同 iOS |

原版 `camerawesome` 和 `camerawesome_ohos` 的 Dart API 几乎一致（ohos fork 从 1.4.0 fork），三端实现 95% 重复。为避免维护三份重复代码，引入 `CamerawesomeDelegate`：

```dart
/// camerawesome 系列库的统一委托层。
/// 三端 CamerawesomeCameraService 共用一份业务代码，
/// 仅 delegate 负责处理 import 差异和平台特定行为（如 OHOS 的 setZoom 倍数 vs 归一化差异）。
class CamerawesomeDelegate {
  final String platformTag;  // 'ohos' | 'ios' | 'android'
  final bool zoomIsMultiplier;  // ohos: true（原生期望倍数）；ios/android: false（setZoom 归一化）
  // ...
}

class CamerawesomeCameraService implements CameraService {
  CamerawesomeCameraService(this._delegate);
  // capture / switchCamera / setZoom 等 95% 逻辑共用
}
```

**平台差异处理**：OHOS 的 `CamerawesomePlugin.setZoom(multiplier)` 期望真实倍数（[capture_page.dart:564-589](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L564-L589) 注释说明），而原版 camerawesome 的 `SensorConfig.setZoom` 归一化到 [0,1]。`CamerawesomeDelegate.zoomIsMultiplier` 标记此差异，共用代码按标记分支。

### 2.4 Provider 注册

```dart
// lib/features/capture/services/camera_service_provider.dart
final cameraServiceProvider = Provider<CameraService>((ref) {
  if (Platform.isIOS) return CamerawesomeCameraService(CamerawesomeDelegate.ios());
  if (Platform.isAndroid) return CamerawesomeCameraService(CamerawesomeDelegate.android());
  // HarmonyOS — ohos fork
  return CamerawesomeCameraService(CamerawesomeDelegate.ohos());
});
```

### 2.5 CaptureState 改造

删除 `cameraStateProvider`（camerawesome 类型泄漏），改为通过 `cameraServiceProvider` 调用。其他 provider（`flashModeProvider` / `zoomProvider` / `aspectRatioProvider` / `effectivePostProcessProvider` / `lastPhotoPathProvider` 等）全部保留，它们是平台无关的纯 Dart 状态。

`capture_page.dart` 的 `_onCapture` / `_onCameraStateCreated` / `_switchCamera` / `_onZoomChanged` 改为通过 `ref.read(cameraServiceProvider)` 调用。

### 2.6 Dart SDK 约束

- pubspec 当前 `sdk: '>=2.19.6 <3.0.0'`（Dart 2.19）
- 原版 `camerawesome` 1.4.0 要求 `sdk: '>=2.17.3 <3.0.0'` — 兼容
- `abstract interface class` 需 Dart 2.17+ 的 `interface` 修饰符 — 2.19 支持
- 无 SDK 阻塞

---

## 3. PhotoPipeline 双管线

### 3.1 问题

当前 `PhotoPostProcessor.processFile` 单管线串行（[photo_post_processor.dart:33-242](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart#L33-L242)）：

```
JPEG解码(50ms) → 变换 → 裁剪计算 → Canvas合并(降采样+裁剪+ColorMatrix+Vignette)
→ 皮肤平滑(80ms, image包CPU) → 逐像素(Sharpen/Clarity/Grain, 200-500ms CPU)
→ 补光(20ms) → img.encodeJpg软编码(80-150ms) → 写文件
```

全程主 Isolate 阻塞，UI 冻结。

### 3.2 双管线拆分

按"能否在 Canvas GPU 上完成"拆分：

| 步骤 | 管线 | 实现 | 耗时 |
|---|---|---|---|
| JPEG 解码 | quick | `dart:ui` instantiateImageCodec | ~50ms |
| 变换（旋转/翻转/拉直） | quick | Canvas GPU | ~10ms |
| 裁剪计算 | quick | `_computeCropRect`（纯数学） | <1ms |
| 降采样 + 裁剪 + ColorMatrix + Vignette | quick | 单次 Canvas GPU 合并 | ~20ms |
| 输出近似最终图（PNG/JPEG 到内存） | quick | `PictureRecorder → toImage → readBytes` | ~20ms |
| **小计 quickProcess** | | | **~100ms** |
| 皮肤平滑 | full | `SkinSmoother`（image 包 CPU） | ~80ms |
| Sharpen / Clarity / Grain | full | `image` 包逐像素 | ~200-500ms |
| 补光叠加 | full | BlendMode.multiply | ~20ms |
| JPEG 软编码 | full | `img.encodeJpg(quality:88)` | ~80-150ms |
| 写文件 | full | `File.writeAsBytes` | ~30ms |
| **小计 fullProcess** | | | **~400-800ms** |

### 3.3 抽象接口

新增 `lib/features/capture/services/photo_pipeline.dart`：

```dart
/// 照片后处理管线接口。
/// 阶段一：唯一实现 DartPhotoPipeline（Canvas GPU quick + image CPU full，full 在 Isolate）
/// 阶段二：各端原生实现（Metal/Vulkan/PixelMap），接口零改动
abstract interface class PhotoPipeline {
  /// 同步快速处理（主 Isolate）。
  /// 输入：原始 JPEG 文件路径 + 后处理参数快照。
  /// 输出：近似最终图的内存字节（已调色，无皮肤平滑/Sharpen/Grain）。
  /// 目标 < 100ms。失败时返回 null，调用方降级为等待 fullProcess。
  Future<QuickResult?> quickProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
  });

  /// 异步完整处理（Isolate）。
  /// 输入同 quickProcess。
  /// 输出：最终图文件路径 + 落库所需元数据。
  Future<FullResult> fullProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    FillLightState? fillLight,
    String? outputPath,
  });
}

/// quickProcess 结果：近似最终图的内存字节 + 尺寸
class QuickResult {
  final Uint8List bytes;       // PNG 或低质量 JPEG
  final int width;
  final int height;
}

/// fullProcess 结果：最终图文件路径
class FullResult {
  final String filePath;
  final int width;
  final int height;
}
```

### 3.4 DartPhotoPipeline 实现

新增 `lib/features/capture/services/dart_photo_pipeline.dart`：

- `quickProcess`：在主 Isolate 执行。复用现有 `PhotoPostProcessor` 的解码 + 变换 + 裁剪计算 + Canvas 合并逻辑，但停在"Canvas 合并后"——用 `PictureRecorder` 录制 Canvas，`toImage` 得到 `ui.Image`，`readBytes` 导出 PNG 字节。跳过皮肤平滑/逐像素/补光/编码。
- `fullProcess`：在 Isolate 中执行。通过 `Isolate.run()`（Dart 2.19 支持）把完整处理（含 quickProcess 的所有步骤 + 皮肤平滑 + 逐像素 + 补光 + `img.encodeJpg`）丢到 worker。输入参数通过闭包传递，输出文件路径回传。

**关键约束**：`dart:ui` 的 `Canvas` / `PictureRecorder` / `instantiateImageCodec` **只能在主 Isolate 使用**（Platform-Finalizer 限制）。因此：
- `quickProcess` 必须在主 Isolate（本就是同步快速路径）
- `fullProcess` 在 Isolate 中只能用 `image` 包（纯 Dart，无 dart:ui 依赖）。现有 `PhotoPostProcessor` 的 Canvas 合并部分依赖 dart:ui，不能直接搬进 Isolate。

**解决方案**：`fullProcess` 在 Isolate 中**重新用 image 包实现一遍 Canvas 合并的逻辑**（降采样 + 裁剪 + ColorMatrix + Vignette）。代码有重复，但保证 Isolate 隔离。ColorMatrix 在 image 包上用 `ImageMapping` 逐像素应用，比 Canvas 慢但可在后台跑。

**Isolate 数据传递**：原始 JPEG bytes + 参数对象（需可序列化）通过 `Isolate.run` 闭包传入，处理后的 JPEG bytes 回传，主 Isolate 负责写文件。

### 3.5 现有 PhotoPostProcessor 的处置

- 保留 `PhotoPostProcessor` 类作为 `DartPhotoPipeline.fullProcess` Isolate 内部的实现细节（image 包路径）。
- `quickProcess` 的 Canvas GPU 路径从 `PhotoPostProcessor` 抽取到 `DartPhotoPipeline`。
- `capture_page.dart` 不再直接调用 `PhotoPostProcessor.processFile`，改调 `PhotoPipeline`。

---

## 4. 交互流程（缩略图角标 + 连拍）

### 4.1 取消"自动跳预览页"

删除 [capture_page.dart:519-529](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L519-L529) 的 `GoRouter.push(capturePreview)` 自动导航。预览页改为通过点击角标缩略图进入。

### 4.2 角标缩略图状态机

新增 `lib/features/capture/data/capture_thumbnail_state.dart`，用 Riverpod StateNotifier 管理角标缩略图的三态：

```
idle ──按下快门──> processing(占位灰块) ──quickProcess完成──> preview(近似图)
                                                              │
                              fullProcess完成(后台) ──────────┘
                                                              │
                                                              ▼
                                                         final(最终图)
                                                         │
                                          用户点击角标 ────┘
                                                         │
                                                         ▼
                                              跳预览页（参数：最终图路径 + photoId）
```

```dart
class CaptureThumbnailState {
  final CaptureThumbnailStatus status;  // idle / processing / preview / final
  final Uint8List? quickBytes;          // preview 态的近似图字节
  final String? finalPath;              // final 态的最终图路径
  final String? photoId;                // 落库后的 ID
  final int? captureSeq;                // 拍摄序号（连拍递增）
}

enum CaptureThumbnailStatus { idle, processing, preview, final_ }
```

**连拍支持**：每次按下快门递增 `captureSeq`。若上一次仍在 fullProcess，不阻塞本次拍摄——本次拍摄走完整流程，前一次 fullProcess 在后台继续。角标缩略图始终显示**最近一次**拍摄的结果（preview 或 final）。历史拍摄结果按序落库，用户可在相册查看。

### 4.3 CaptureButton 改造

- 移除 `_isProcessing` 全局阻塞（[capture_page.dart:69](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L69)）。
- 改为 `_isQuickProcessing`：只阻塞 quickProcess 这 ~100ms 窗口（防止 JPEG 解码并发冲突）。quickProcess 完成后立即允许下一次拍摄。
- 连拍间隔下限：quickProcess 耗时（~100ms），即理论 ~10fps。实际受相机传感器曝光限制（~300-500ms/帧），约 2-3fps。

### 4.4 快门反馈

按下快门时立即（T+10ms 内）：
1. 播放快门音效（系统音效或 assets 音频）
2. 屏幕白闪动画（80ms 全屏白色 overlay 闪现，模拟机械快门）
3. 角标缩略图切换为 `processing` 态（灰色圆角占位）

### 4.5 角标缩略图点击

点击角标 → 跳预览页，URL 参数：
- `photoUrl` = 当前角标的 `finalPath`（若 fullProcess 未完成，传 `quickBytes` 临时文件路径，预览页 fullProcess 完成后 swap）
- `photoId` = 落库 ID
- `aspectRatio` = 拍摄时比例

---

## 5. 错误处理 + 性能边界

### 5.1 错误处理

| 失败点 | 处理 |
|---|---|
| `CameraService.capture()` 抛异常 | Toast 提示"拍照失败"，`_isQuickProcessing` 复位，不阻塞后续拍摄 |
| `quickProcess` 失败 | 返回 null，角标保持 `processing` 态，直接等 `fullProcess` 完成显示 `final` 态 |
| `quickProcess` 成功但 `fullProcess` 失败 | 角标显示 `preview` 态（近似图），Toast 提示"图像增强失败，已保存基础图"；落库 `filePath` 指向 quickProcess 的临时文件；原图备份仍保留 |
| `fullProcess` Isolate 崩溃 | 同上，主 Isolate catch Isolate 异常，降级为 quickProcess 结果 |
| 落库失败 | Toast 提示"保存失败"，但照片文件已存在临时目录，下次启动可恢复 |
| 原图备份失败 | 不阻塞（现有逻辑，[capture_page.dart:432-435](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/capture/pages/capture_page.dart#L432-L435) 已处理） |

### 5.2 性能边界

- **quickProcess 超时**：设 200ms 软上限。若实际超过（弱光/大图），降级为不显示近似图，直接等 fullProcess。监控 `Stopwatch`，超时 debugPrint 警告。
- **fullProcess 队列**：连拍时多个 fullProcess 在 Isolate 队列中串行执行（避免内存爆掉）。最多排队 3 个，超出丢弃最旧的 fullProcess（保留 quickProcess 结果落库）。
- **内存**：每张原图 JPEG ~3-8MB，quickProcess 的 ui.Image ~20-50MB（1536² × 4 bytes）。连拍时最多同时存在 1 个 quickProcess（主 Isolate）+ 3 个排队 fullProcess（Isolate 闭包持有原图 bytes）。峰值内存 ~200MB，可接受。
- **Isolate 复用**：不创建长期 Isolate（Dart 2.19 的 `Isolate.run` 每次新建，开销 ~5ms，相对 400ms 处理时间可忽略）。阶段二考虑 `IsolateNameServer` + 长期 worker。

---

## 6. 阶段二演进接口

阶段一接口设计预留阶段二替换点，阶段二零改动 Dart 业务层：

### 6.1 CameraService 阶段二扩展

```dart
abstract interface class CameraService {
  // 阶段一方法（不变）...

  /// 阶段二新增：注册预捕获帧回调（ZSL）。
  /// 开启后，相机持续捕获帧到环形缓冲，capture() 从缓冲取最近帧。
  /// 阶段一默认空实现（返回不支持）。
  Future<void> enablePreCaptureBuffer({int bufferSize = 3});

  /// 阶段二新增：手动传感器控制。
  /// 阶段一 CaptureConfig.evCompensation 已预留，阶段二扩展 ISO/shutter/wb。
  Future<void> setManualControl(ManualControlParams params);
}

class ManualControlParams {
  final double? iso;
  final double? shutterSpeedMs;
  final double? whiteBalanceKelvin;
  final bool lockAutoExposure;
  final bool lockAutoFocus;
}
```

### 6.2 PhotoPipeline 阶段二扩展

```dart
abstract interface class PhotoPipeline {
  // 阶段一方法（不变）...

  /// 阶段二新增：处理原生 YUV 平面（ZSL 帧格式）。
  /// 阶段一 CameraService 只产出 JPEG，此方法不被调用。
  Future<FullResult> processYuvPlanes({
    required YuvPlanes planes,
    required PostProcess params,
    // ...
  });
}
```

### 6.3 阶段二替换路径

| 层 | 阶段一 | 阶段二替换 |
|---|---|---|
| `cameraServiceProvider` | `CamerawesomeCameraService` 三端 | `OhosNativeCameraService` / `IosNativeCameraService` / `AndroidNativeCameraService` |
| `photoPipelineProvider` | `DartPhotoPipeline` | `OhosNativePipeline` / `IosMetalPipeline` / `AndroidVulkanPipeline` |
| `capture_page.dart` | **不改** | **不改** |
| `CaptureState` | **不改** | **不改** |

---

## 7. 测试策略

### 7.1 单元测试

项目当前无测试文件（`test/` 目录为空）。本次新增：

- `test/features/capture/services/photo_pipeline_test.dart`
  - `quickProcess` 返回非空字节 + 正确尺寸
  - `quickProcess` 在 rawMode=true 时跳过 ColorMatrix 但仍裁剪
  - `fullProcess` 返回文件路径存在 + 可读
  - `fullProcess` 在 Isolate 中不阻塞主 Isolate（用 `Future.delayed` 探针验证主 Isolate 响应）
  - `_computeCropRect` 比例正确性（4:3 / 1:1 / 3:4 / fullscreen / 任意 W:H）
- `test/features/capture/services/camera_service_test.dart`
  - `CamerawesomeDelegate` 三端 zoomIsMultiplier 标记正确
  - `CaptureConfig` / `CaptureResult` 序列化
- `test/features/capture/data/capture_thumbnail_state_test.dart`
  - 状态机转换：idle → processing → preview → final
  - 连拍时序：seq 递增，旧 fullProcess 完成不覆盖新角标
  - fullProcess 失败降级到 preview

### 7.2 集成测试（手动，三端真机）

- HarmonyOS：拍照 → 角标 150ms 内显示近似图 → 500ms 后 swap 最终图 → 点击角标进预览页
- iOS：首次编译通过 + 相机能开 + 拍照流程同上
- Android：同 iOS
- 连拍：快速按 5 次快门，5 张全部落库，角标显示最后一张
- 弱光：quickProcess 可能超时，验证降级到直接等 fullProcess

### 7.3 性能基准

- 在 `photo_pipeline_test.dart` 中用 `Stopwatch` 断言：
  - `quickProcess` < 200ms（中端机，1536² 图）
  - `fullProcess` < 1000ms（中端机，含逐像素）
- 超时不 fail，仅 debugPrint 警告（避免 CI 环境波动误报）

---

## 8. 文件改动清单

### 8.1 新增文件

```
lib/features/capture/services/
  camera_service.dart                    # CameraService 抽象接口 + 值对象
  camera_service_provider.dart           # 三端 Provider 注册
  camerawesome_camera_service.dart       # camerawesome 系列三端共用实现
  camerawesome_delegate.dart             # 三端差异委托
  photo_pipeline.dart                    # PhotoPipeline 抽象接口
  dart_photo_pipeline.dart               # Dart 实现（quick 主Isolate + full Isolate）
lib/features/capture/data/
  capture_thumbnail_state.dart           # 角标缩略图状态机
lib/features/capture/widgets/
  capture_thumbnail.dart                 # 角标缩略图 widget
  shutter_feedback.dart                  # 快门音效 + 白闪动画
test/features/capture/
  services/photo_pipeline_test.dart
  services/camera_service_test.dart
  data/capture_thumbnail_state_test.dart
docs/superpowers/specs/
  2026-07-31-camera-three-platform-optimization-design.md  # 本文档
```

### 8.2 修改文件

```
pubspec.yaml
  - 新增 camerawesome: ^1.4.0（原版，iOS/Android 用）
  - 保留 camerawesome_ohos（gitcode fork，OHOS 用）
  - 条件依赖：用 dependency_overrides 或平台条件导入

lib/features/capture/data/capture_state.dart
  - 删除 cameraStateProvider（camerawesome CameraState 泄漏）
  - 其他 provider 保留

lib/features/capture/pages/capture_page.dart
  - _onCapture：改调 CameraService.capture()
  - captureState$ 监听器：改为 CameraService.capture() 的 Future 链
  - _processSingleFrame：拆为 quickProcess（主）+ fullProcess（Isolate）
  - 删除自动跳预览页逻辑（519-529）
  - _onCameraStateCreated / _switchCamera / _onZoomChanged：改调 CameraService
  - _isProcessing → _isQuickProcessing
  - 新增角标缩略图 widget 挂载

lib/features/capture/widgets/camera_preview.dart
  - 内部 CameraAwesomeBuilder 封装到 CamerawesomeCameraService.buildPreview()

lib/features/capture/widgets/capture_button.dart
  - onTap 行为不变，但允许连拍（移除外部 _isProcessing 阻塞）

lib/features/capture/services/photo_post_processor.dart
  - 保留为 DartPhotoPipeline.fullProcess 的 Isolate 内部实现
  - 不再被 capture_page 直接调用
```

---

## 9. 风险与缓解

| 风险 | 缓解 |
|---|---|
| `camerawesome` 原版 1.4.0 与 `camerawesome_ohos` 同时存在于 pubspec 导致符号冲突 | 用 `dependency_overrides` + 条件导入（`import 'package:camerawesome/camerawesome_plugin.dart' if dart.library.io 'package:camerawesome_ohos/camerawesome_plugin.dart'`）。需在实施阶段验证 pub 解析。若冲突无法解决，回退到三端各写独立 Service（放弃 CamerawesomeDelegate 共用） |
| `image` 包在 Isolate 中的性能比预期差 | 性能基准测试先行；若 fullProcess Isolate > 1500ms，降级 maxDimension 1536 → 1080 |
| 连拍时内存峰值超 200MB | fullProcess 队列上限 3，超出丢弃最旧 fullProcess；监控 `Process.currentRss` |
| Dart 2.19 的 `Isolate.run` 在 OHOS Flutter 3.7 上不支持 | 实施前先写最小 Isolate.run 验证 demo；若不支持，回退到 `compute()`（Dart 2.19 支持，内部 Isolate.run 封装） |
| quickProcess 与 fullProcess 色彩不一致（Canvas ColorMatrix vs image 包逐像素） | 两处共用同一 `FilterRecipe.fromPostProcess(params)` 生成的 ColorMatrix；quickProcess 用 Canvas ColorFilter，fullProcess 用 image 包 ImageMapping 应用同一矩阵。理论上结果一致，但需视觉对比验证 |

---

## 10. 实施顺序（供 writing-plans 参考）

1. **pubspec 依赖**：新增 `camerawesome: ^1.4.0`，验证三端 pub 解析无冲突
2. **CameraService 抽象层**：接口 + CamerawesomeDelegate + CamerawesomeCameraService + Provider
3. **PhotoPipeline 抽象层**：接口 + DartPhotoPipeline（quickProcess + fullProcess Isolate）
4. **capture_state.dart 改造**：删除 cameraStateProvider，其他保留
5. **capture_page.dart 改造**：CameraService 调用 + quick/full 拆分 + 删除自动跳预览页
6. **角标缩略图状态机**：CaptureThumbnailState + widget
7. **快门反馈**：白闪动画 + 音效
8. **连拍支持**：_isQuickProcessing 替换 _isProcessing
9. **camera_preview.dart 改造**：封装到 CamerawesomeCameraService.buildPreview()
10. **单元测试**：photo_pipeline / camera_service / capture_thumbnail_state
11. **三端真机验证**：OHOS / iOS / Android
