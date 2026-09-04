# 极致性能 + 照片高质量：OHOS/iOS 美肤后期统一管线改造

日期：2026-09-04
目标目录：`d:\app\projects\photo_post\lumira_app_flutter\`（+ `packages\camerawesome_ohos\`、`packages\camerawesome\`）

## Context（为什么要做）

四个美颜效果（磨皮/暗角/颗粒/锐化）在三端（OHOS/iOS 取景器、双端成片）质量差、性能差、且预览与成片割裂：

| 问题 | 根因（已核实） |
|---|---|
| 锐化预览无效果 | OHOS 取景器只有 `ColorFiltered(4x5 色彩矩阵)`，无法做空域卷积；面板还标"导出后生效"（`camera_preview.dart` L218-226 注释明言"无零读回真实现，暂不伪造预览"） |
| 颗粒效果差 + 预览卡顿 | 成片/Dart 用±24 均匀 CPU 噪声（观感差）；iOS 预览逐帧 `CIRandomGenerator` 合成（30fps 卡顿） |
| 暗角预览≠成片 | iOS 预览 `CIVignette`（radius/intensity 旧参数）与成片解析式不同一套 |
| 磨皮整屏糊/成片塑料 | 曾实时做法=整图高斯糊；iOS 预览是整图模糊；成片虽频率分离但参数/实现各端漂移 |

产出目标：**四个效果统一为一套公式，同时跑在「取景器 30fps GPU」与「成片离线烘焙」两条路上、视觉近一致**；OHOS 取景器做真逐帧处理（FragmentShader 覆盖于 Flutter Texture）；**硬约束：取景器不得卡顿/掉帧**。

用户已拍板：两端并行；OHOS 要真视图层逐帧处理；预览与成片同算法、交互近一致；颗粒预览不得逐帧生成噪声。

## 核心方案

### 统一算法规格（一条公式，四处实现：OHOS 预览 shader / OHOS bake C++ / iOS 预览 CoreImage / iOS bake Dart）

**磨皮（频率分离 + YCbCr 肤色掩膜 + 结构门控）**——沿用现在 C++ `smoothSkin` 数学，四处参数钉死：
```
base = lowPass(color, σ)                       # 唯一允许 预览/成片 不同的步骤
detail = color - base
skin = ss(y,0.24,0.25)*(1-ss(y,0.98,1)) * ss(cb,0.27,0.33)*(1-ss(cb,0.47,0.52)) * ss(cr,0.50,0.55)*(1-ss(cr,0.67,0.73))
structure = ss(edgeLow, edgeHigh, max|detail|), edgeLow=0.06+0.06s, edgeHigh=edgeLow*2.5
removal = clamp(baseRemove*(1-structure)*skin, 0,1), baseRemove=0.50s+0.04
out = base + detail*(1-removal)                # 保低频、削高频，保留五官/轮廓/非肤
```
- bake：base = 降采样块平均 + 高斯(σ=radius/2, radius=2+3s) + 升采样。
- preview 廉价：base = 单 pass 内 9-tap 十字高斯近似（同公式，仅换低通求取）。

**锐化（仅亮度域死区 Unsharp）**——修复"预览无效果 + 逐通道彩色噪点"：
```
luma = dot(rgb, LUM); lumaBlur = 3x3 邻域均值（预览 4-tap）
diff = luma - lumaBlur; edge = ss(1.0/255, 2.5/255, |diff|)
amnt = a*(diff>thr? diff-thr : (diff<-thr? diff+thr : 0)), a=clamp(sharpen/100,0,1.2)
out.rgb = rgb + amnt*edge                      # 亮度方向，平坦区不放大
```

**暗角（单一解析函数，预览逐像素==成片）**：
```
dn = length((2x-w)/w,(2y-h)/h)/sqrt(2); s=vignette/100
factor = 1 - s*smoothstep(0.45,1.0,dn); out = color*factor
```
与 C++ `applyVignette`（`photo_processor.cpp` L243，e0=0.45,e1=1.0）**现已是此公式**；iOS 预览废弃 `CIVignette` 改此函数 → 修预览≠成片。

**颗粒（预计算 tile + 幅度随亮度）**——修"效果差 + 预览卡顿"：
- 每端**启动生成一次** 128×128 单通道白噪声 tile（固定 LCG，与 C++ 现 LCG 同种子族），双线性采样，`grainOffset` 每会话**固定**。
- `amp = (grain/100)*kFilm * mix(0.35,1.0, smoothstep(0.05,0.85, luma))`，`out = rgb + g*amp`（亮度驱动胶片感）。
- 消除：C++/Dart 原±24 平噪（改亮度缩放）；iOS 逐帧 `CIRandomGenerator`（改一次建 tile → 灭卡顿）。

### 预览 30fps 保帧策略（硬约束）
- **单 pass**：一个 `preview_beauty.frag` 内顺序 矩阵→暗角→锐化→磨皮→颗粒；磨皮 base 用 9-tap 十字内联，无多 pass。
- 采样源：`RepaintBoundary.toImage(pixelRatio: kPreviewScale)`，`kPreviewScale` 默认 **0.30**（~360×640），复用 `camera_preview.dart` 已有 `rawCaptureKey` 范式。
- 颗粒 tile 建一次缓存为 `ui.Image`，作第二采样器 `setImageSampler(1, tile)`，每帧只换 uniforms。
- **即时反馈 + 自适应保帧**：参数变化时立即用本地上一捕获帧+新 uniforms 重绘（零读回）；相机帧由 Ticker 按 30fps 周期捕获；实测单次捕获+渲染 >33ms 自动降 `kPreviewScale`（0.30→0.20）或先关磨皮预览（bake 保留全量）——绝不阻塞、绝不丢帧。
- 仅色彩矩阵无空间效果时维持廉价 `ColorFiltered`；任一空间效果>0 走 shader 路径。

### iOS 成片决策
**iOS 成片保留在 Dart，重写 `skin_smooth.frag` 与逐像素 grain/sharpen 到统一规格；iOS 原生预览 `PreviewEffectProcessor` 同步到同一规格**。理由：iOS 预览已原生、改动小；成片 400ms 预算内，搬 Metal 收益有限且双主机风险高；"近一致起见式一致"靠公式统一即可达成。

## 分步实施

**阶段 1 — 统一算法落到 bake（先行，保证成片先正确）**
- `ohos/entry/src/main/cpp/photo_processor.cpp`：`ProcessRgba` 锐化 pass 改亮度死区（A.2）；`applyGrain`（L265）改预置 tile + 亮度缩放（新增静态 `g_grainTile[128*128]`）；`applyVignette`/`smoothSkin` 对齐 A.1/A.3 常量。入口签名不变。
- `packages/camerawesome/ios/Classes/CameraPreview/PreviewEffectProcessor.m`：`applyParams` 四分支替换为 A.1-A.4；新增 `buildGrainTile` 一次建 tile（替换 L195-208 每帧 `CIRandomGenerator`）。`.h` `PreviewEffectsParams` 不变（channel 复用）。
- iOS/Dart bake：`lib/features/capture/services/photo_post_processor.dart` `_applyPerPixelEffects` sharp 改 A.2、grain 改 tile+亮度；`assets/shaders/skin_smooth.frag` 参数归一 A.1；`dart_photo_pipeline.dart` 同步。
- 回归：逐平台、逐强度验成片。

**阶段 2 — 新预览 shader + OHOS 预览管线**
- 新增 `assets/shaders/preview_beauty.frag`（矩阵+暗角+锐化+磨皮+颗粒单 pass，`uNoise` 第二采样器）；`pubspec.yaml` `shaders:` 登记。
- 新增 wrapper `lib/features/capture/services/preview_beauty_shader.dart`：启动缓存颗粒 tile 为 `ui.Image`，暴露 `setParams(PostProcess, ui.Image frame)`。
- `lib/features/capture/widgets/camera_preview.dart`：`filteredCamera` 三元（L208-226）加 OHOS 分支——空间效果>0 时用新 `_LiveBeautyLayer`（RepaintBoundary 捕获→shader 覆盖，内嵌 Ticker+自适应保帧）替换 `ColorFiltered`。
- iOS 原生预览只需换算法+tile（阶段 1 已含）。

**阶段 3 — 一致性面板**
- `lib/features/capture/widgets/post_process_adjust_panel.dart`：删 `锐化`(L130)、`磨皮`(L139) 的 `hint:'导出后生效'`；保留 `拉腿`(L164)。

**阶段 4 — 水印/一致性收尾**
- 水印冻结帧=取景器：iOS 冻结帧取 `PreviewEffectProcessor` 后缓冲；OHOS 水印源帧=经 `_LiveBeautyLayer` 的帧（同一 RepaintBoundary 源）；颗粒 offset 固定保证 预览↔冻结帧↔成片 一致。

## 关键文件
- 新增：`assets/shaders/preview_beauty.frag`、`lib/features/capture/services/preview_beauty_shader.dart`
- 改：`ohos/entry/src/main/cpp/photo_processor.cpp`、`packages/camerawesome/ios/Classes/CameraPreview/PreviewEffectProcessor.m`(+`.h`)、`lib/features/capture/widgets/camera_preview.dart`、`lib/features/capture/services/photo_post_processor.dart`、`assets/shaders/skin_smooth.frag`、`dart_photo_pipeline.dart`、`lib/features/capture/widgets/post_process_adjust_panel.dart`、`pubspec.yaml`
- 复用：`ImageProcessorPlugin.ets` 通道、`updatePreviewEffects` 通道、`PostProcess` 模型（`post_process_delta.dart`）、`rawCaptureKey` RepaintBoundary 范式

## 验证
- `flutter analyze` 零告警。
- 复用/扩展测试：`test/features/capture/services/` 下 skin_smoother、skin_smooth_shader、photo_post_processor_smoothing/crop、`widgets/camera_preview_test.dart`（分支/参数断言）、`domain/post_process_delta_test.dart`（回归）。
- 真机（OHOS/iOS 并行）：逐个开启 锐化/磨皮/暗角/颗粒，取景器实时呈现且 30fps 不丢帧（Ticker 耗时观测）；磨皮=美颜级非整图糊、锐化咬边无 halo、颗粒=亮度驱动胶片感、暗角中心不变边缘渐变；预览==成片（近一致），暗角逐像素一致；水印动画帧==取景器；低配机自适应降采样仍不卡。

## 风险与对策
- 预览磨皮近一致而非像素级：符合"交互近一致"决策，bake 全量为权威。
- shader 采样 `ui.Image` 有 RepaintBoundary 捕获开销：kPreviewScale=0.30 + 自适应降档兜底。
- 两端并行工作量大：按阶段顺序，阶段 1 成片先交付可独立验证。