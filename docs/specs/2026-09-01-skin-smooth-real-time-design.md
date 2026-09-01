# 磨皮（皮肤平滑）实时预览 — 设计文档

> 日期：2026-09-01
> 模块：Flutter 客户端（`lumira_app_flutter/`）
> 状态：设计待评审

## 1. 背景与问题

当前磨皮（`PostProcess.smoothStrength`）是 **CPU 逐像素频率分离算法**（[skin_smoother.dart](../../lumira_app_flutter/lib/features/capture/services/skin_smoother.dart)），只在**导出时**经 [photo_post_processor.dart](../../lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart) 应用，预览过程完全看不到效果：

- 相册修图 [gallery_edit_page.dart](../../lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart) 的画布仅用 `ColorFiltered`（GPU 色彩矩阵）预览，无法表达逐像素磨皮。
- 拍摄后修图 [capture_preview_page.dart](../../lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart) 同样只做 `ColorFiltered`。
- 相机实时画面 [camera_preview.dart](../../lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart) 只应用色彩滤镜，未见磨皮。

用户诉求：**磨皮效果实时预览**，覆盖三个入口，且**极致性能、零卡顿**（尤其拍摄实时画面）。

## 2. 约束与可行性

### 2.1 CPU 方案不可用于实时

`SkinSmoother.smooth` 逐像素 + 高斯模糊，全分辨率下耗时高；live 相机 30fps 下逐帧 CPU 处理必然卡顿。历史教训：拉腿（leg stretch）早期用「RepaintBoundary 抓帧 → 后台 isolate 像素拉伸 → 半透明叠加」，在 iOS/OHOS 上因 **GPU 读回打断渲染管线程**导致卡顿和重影，最终改为**双层 GPU 合成**（见 [camera_preview.dart:730-740](../../lumira_app_flutter/lib/features/capture/widgets/camera_preview.dart) 注释）。

**结论**：实时磨皮必须走 GPU 着色器（片元着色器，逐片元并行），杜绝 GPU 读回。

### 2.2 Flutter 着色器支持

- Flutter 内置 `FragmentShader`（`.frag` 编译产物），支持 `setFloat` 传 uniform、`setImageSampler` 采样贴图；三端（OHOS/iOS/Android）底层均为 Skia/Impeller 原生着色器，可用。
- 目前 `pubspec.yaml` 未声明 `shaders:`（仅有引擎自带的 `ink_sparkle.frag`），需新增声明，并将 `.frag` 产物纳入三端构建。

## 3. 目标

1. 相册修图 / 拍摄后修图：拖动磨皮滑块**实时**看到磨皮效果，零卡顿。
2. 相机实时画面：取景器内实时呈现磨皮效果（阶段 C，需验证）。
3. **WYSIWYG**：保存导出结果与滑块所见完全一致；滑块移动、预览、保存三处渲染逻辑统一。

## 4. 架构

### 4.1 核心：单一 `skin_smooth.frag` 片元着色器

在片元着色器内逐片元完成与 CPU 算法**视觉对等**的运算：

| CPU [skin_smoother.dart](../../lumira_app_flutter/lib/features/capture/services/skin_smoother.dart) | GPU 片元等价 |
|---|---|
| 低频底图 `base = gaussianBlur(src, radius 2..5)` | 片元内邻域采样，按 strength 确定采样半径，加权平均得低频 |
| 细节残差 `detail = 原图 − base` | 当前片元采样值 − 邻域低频 |
| `_skinWeight`：YCbCr 肤色概率（soft 区间） | 相同 Cb/Cr/Y 公式，smoothstep |
| 结构门控 `_smoothstep(margin, edgeLow, edgeHigh)` | `edgeLow = 6+6·strength`，`edgeHigh = edgeLow·2.5` |
| `removal = baseRemove·skin·(1−struct)`，`baseRemove = 0.5·strength+0.04` | 同公式 |
| `out = base + detail·(1−removal)` | 同公式，重建输出 |

uniform 主参数：
- `strength`：0..1，映射自 `smoothStrength/100`。
- 图像采样纹理（`setImageSampler`）。

着色器严格使用加法/乘法线性组合，避免分支波浪，兼容多平台编译器。

### 4.2 统一渲染辅助层

新增一个跨页面复用的预览组件（例如 `SkinSmoothPreview`），内部：
- 持有待显示的 `ui.Image`（预解码/降采样）。
- 构建 `FragmentShader`，`setFloat('strength', …)`，`setImageSampler(0, image)`，用 `CustomPaint`/`Canvas.drawRect` 输出。
- `strength=0` 时快速路径：直接画原图（不启 shader）。

三个接入点复用同一组件，替换掉当前的纯 `ColorFiltered` 预览路径：
1. 相册修图 `gallery_edit_page.dart` 的 `_CanvasArea`。
2. 拍摄后修图 `capture_preview_page.dart` 的画布。
3. 相机实时画面（阶段 C）。

### 4.3 导出一致性

`PhotoPostProcessor.processFile` 的磨皮分支改为：加载同一 `skin_smooth.frag`，离线渲染 `finalImage`，替代当前 `SkinSmoother` CPU 实现，保证保存结果 = 滑块所见。

### 4.4 分阶段落地

- **阶段 A**：静态预览（相册 + 拍摄后）用 `FragmentShader` 实时磨皮；写入 shader 声明与构建基础设施。
- **阶段 B**：导出改用同一 shader，实现预览→保存 WYSIWYG。
- **阶段 C（最高风险）**：相机实时画面纹理层叠磨皮。需验证 OHOS 原生侧（[photo_processor.cpp](../../lumira_app_flutter/ohos/entry/src/main/cpp/photo_processor.cpp)）与 camerawesome 纹理注入可行性；若 OHOS 受阻，以「拍摄后修图」覆盖实时场景。

## 5. 组件 / 数据流

```text
磨皮滑块 (strength/100)
      │ setState / provider
      ▼
_SkinSmoothPreview (StatelessWidget)
   ├─ ui.Image (降采样到预览分辨率)
   ├─ FragmentShader(assets/shaders/skin_smooth.frag)
   │     └─ setFloat('strength')
   │     └─ setImageSampler(0, image)
   ├─ strength==0 ? 直接画原图 : 画 shader
   └─ 输出到 canvas / InteractiveViewer 子部件
```

## 6. 错误处理与降级

- 着色器**编译/运行时异常**：`try/catch` 捕获后回退到当前预览行为（ColorFiltered 或原图），并打印日志，不阻塞编辑页。
- `ui.Image` 解码/加载失败：沿用现有 `errorWidget` 逻辑。
- 阶段 C 若 OHOS 无法注入纹理着色器：局部回退为「拍摄后修图」覆盖，不强行 on-device 实时。

## 7. 测试

- 单元：`skin_smooth.frag` 无法做 Dart 单测；将「shader 参数映射 + strength=0 快速路径 + 异常回退」抽出可测的 Dart 逻辑，写单测。
- 集成/手动：
  - 相册修图与拍摄后修图拖动磨皮滑块，确认实时、零卡顿。
  - 保存后与原图对比，确认磨皮 WYSIWYG。
  - 三端（OHOS/iOS/Android）构建通过，实时帧率不降。
- CI：`flutter analyze` 通过；维护 UI 交互测试（若存在对应测试基架）不破坏。

## 阶段 C：相机实时取景磨皮（调研结论）

> 状态：**受限（无现成通道）+ 成本过高 → 采用既定回退（以「拍摄后修图页实时预览」覆盖）**，不纳入本次阶段交付。

### 调研结论（逐条给出证据出处）

结论一句话：**`FragmentProgram`/`skin_smooth.frag` 无法直接作用到「相机实时取景纹理流」上**；在现有 Flutter + camerawesome 插件能力内无可行的片元着色器注入通道，需引擎/插件核心改造才可能，成本与稳定性风险高，判定**不可行/受限**。

依据如下：

1. **`FragmentShader.setImageSampler` 只接受 `ui.Image`，不接受外部纹理**。
   - 既有实现 [skin_smooth_preview.dart](../../lumira_app_flutter/lib/features/capture/widgets/skin_smooth_preview.dart) 里就是 `program.fragmentShader()..setImageSampler(0, image)`，其中 `image` 是 `ui.Image`（解码/降采样后的静态位图）。
   - SDK 签名：本机 SDK `D:\flutter\flutter_harmony\flutter_flutter\bin\cache\pkg\sky_engine\lib\ui\painting.dart:4322` → `void setImageSampler(int index, Image image) { _setImageSampler(index, image._image); }`。参数只能是 `ui.Image` 的 `_image` 句柄。
   - 相机实时取景是**外部 GPU 纹理**（`Texture(id)` 控件），不是 `ui.Image`；无任何 API 能从 `textureId` 免读回地得到 `ui.Image`，也无法把外部纹理当作 sampler 喂给碎片着色器。

2. **OHOS 取景是 Flutter 外部纹理（非平台视图），但引擎无 per-texture shader 注入扩展点**。
   - OHOS 原生注册纹理：[cameraX/CameraState.ets:120-121](../../lumira_app_flutter/packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets) `this.textureEntry = textureRegistry!!.registerTexture(textureId); this.surfaceId = this.textureEntry.getSurfaceId()`；[CameraState.ets:409](../../lumira_app_flutter/packages/camerawesome_ohos/ohos/src/main/ets/components/cameraX/CameraState.ets) `createPreviewOutput(profile, surfaceId.toString())` → 相机预览直接写进 Flutter 引擎的外部纹理表面。
   - Dart 侧显示：`widgets/preview/awesome_camera_preview.dart:408` `_buildTexture()` 返回 `Texture(textureId: _textureId!)`。即 OHOS 取景就靠这一张引擎纹理渲染。
   - SDK `_Texture` widget 说明（SDK `D:\flutter\flutter_harmony\flutter_flutter\packages\flutter\lib\src\widgets\texture.dart:35` `class Texture`）：后端纹理由平台纹理注册表按整数 ID 管理、由引擎图层树独立重绘，与 Dart 片段着色器无 bridge。**SDK Dart UI API 中未发现「per-texture shader 注入」扩展点**（`painting.dart` 里 `FragmentShader` 只能采样 `ui.Image`）。→ 该条可判「引擎能力内不支持」；若将来走引擎底层定制，属于源码级改造，需真机重编重装验证（待实测）。

3. **camerawesome / camerawesome_ohos 无「在相机纹理之上挂自定义 shader」的扩展点**。
   - 唯一滤镜挂钩是 Dart 侧对 `Texture` 控件包 `ColorFiltered`：`widgets/preview/awesome_camera_preview.dart:294-299`（`snapshot.data != AwesomeFilter.None` 时 `ColorFiltered(colorFilter: snapshot.data!.preview, child: previewTexture)`）。`ColorFiltered` 是**色彩矩阵 + 混合**，不是用户自定义 GLSL 片元着色器采样纹理，无法表达逐像素磨皮。
   - 拉腿「双层 GPU 合成」（[awesome_camera_preview.dart:407-447](../../lumira_app_flutter/packages/camerawesome_ohos/lib/src/widgets/preview/awesome_camera_preview.dart)）能用 `ClipRect + Transform` 复用同一 `Texture` 两次，属于**几何变换**，不改变片元颜色；**无法通过它做频率分离磨皮**。
   - 插件暴露的 `PreviewController`/pigeon 接口仅有相机控制与 `getPreviewTextureId` 等（`cameraX/Pigeon.ets:718`），无「texture buffer 回调 / 自定义渲染 pass」注入通道。

### 为何不能像「拍摄后修图」那样预览

拍摄后修图 / 相册修图画布是**静态 `ui.Image`**，可直接 `setImageSampler` 喂给 `skin_smooth.frag`。而相机取景是**连续的引擎外部纹理流**；要喂给现有 shader 必须每帧 `Texture→ui.Image`（等价 GPU 读回 / 抓帧编码），违背「实时磨皮必须 GPU 零读回」的根因（见 §2.1 拉腿卡顿教训），且引入逐帧读回+重码，帧率与稳定性风险大。

### 时间 / 性能预期与后续登记

- 若要真正 on-device 实时，唯一正路是在 **Flutter 引擎 / camerawesome 插件底层**把「取景纹理 + 自定义 fragment pass」做成双层 GPU 合成（在引擎纹理渲染前插入 shader）。这属于跨引擎/插件源码级改造 + 三端分别适配 + OHOS 真机重编验证，远超阶段 B 已实现的静态预览成本，且一旦翻车直接打崩相机模块。
- 性能预期：即使做成，也要保证 30fps 级 GPU 调度与零读回，受设备 GPU 与着色器复杂度（当前 9 次采样 + 肤色概率）约束，需要在真机逐端验证（**待真机验证**）。
- **回退**：按设计文档既定方案（§4.4 阶段 C 说明 与 §6），以「拍摄后修图页实时预览」覆盖实时打磨需求（阶段 A/B 已实现静态预览 + 导出 WYSIWYG），**不强行 on-device 实时**。
- 后续如要推进，可在 `docs/future-optimizations.md` 登记「相机取景实时磨皮（引擎/插件层双层合成）设计，# 高成本项」；当前不新增条目。

## 8. 待评审确认

- 阶段 A→B→C 的推进顺序是否认可。
- 当前 CPU `SkinSmoother` 保留为降级后端（shader 不可用时回退到导出 CPU 结果），建议保留。
- shader 资产命名与目录（`assets/shaders/skin_smooth.frag`）是否审批。