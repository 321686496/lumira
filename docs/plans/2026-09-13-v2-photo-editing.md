# Lumira v2 P 图与后期处理开发计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 v2 发布中提供稳定、所见即所得、可持久化的 P 图与后期处理能力，并把现有照片编辑页升级为可扩展的编辑体系。

**Architecture:** 以 Flutter 现有 `PostProcess` 参数模型和 `original_path` 非破坏式编辑链路为基础，先扩展参数化调整能力，再引入编辑图层模型支持素材类功能。实时预览、离屏快照和最终导出必须共享同一套编辑状态解释逻辑，避免预览与成片不一致。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6、flutter_riverpod 2.3.6、`package:image`、`dart:ui` Canvas / FragmentShader / RepaintBoundary、Sqflite 离线持久化。

## Global Constraints

- 目标发布版本：Flutter App `2.0.0+1`；在 v2 全部验收项通过后再更新 `lumira_app_flutter/pubspec.yaml` 的 `version`。
- 当前主项目是 `lumira_app_flutter/`；禁止修改 `lumira-app/` 作为实现目标。
- Dart SDK 兼容范围是 `>=2.19.6 <3.0.0`，Flutter 锁定 `3.7.12`。
- 新增依赖必须支持 Android、iOS 与 HarmonyOS；任何缺少 OHOS 实现的第三方插件不得直接引入。
- 所有颜色、阴影、边框、圆角、透明度必须从 `appThemeProvider` + `uiStyleProvider` 派生，禁止为编辑控件硬编码主题观感。
- 叠在照片上的浮层按当前 UI 风格选择实心表面、半透明表面、风格化玻璃或柔和渐变，禁止跨风格混搭。
- 编辑必须保留原图路径；新能力优先通过可序列化参数表达，禁止只把结果烘焙成文件后丢失参数。
- 同一轮编辑的实时预览、保存预览和导出结果必须一致；不一致时按 bug 处理。

## Current Baseline

- `gallery_edit_page.dart` 已有颜色、细节、滤镜、裁剪四类工具。
- `PostProcess` 已包含磨皮、锐化、暗角、颗粒、拉腿、LUT、系统滤镜和裁剪矩形。
- `PostProcessColor` 已支持亮度、对比度、饱和度、色温、色调、高光、阴影、黑点、清晰度、自然饱和度和质感参数。
- `PhotoPostProcessor.processFile` 已负责按参数读取原图并输出 JPEG。
- `DartPhotoPipeline.fullProcess` 已有 isolate 全量处理兜底路径。
- `DetailEffectsLayer` 已提供磨皮、暗角、颗粒等 GPU 实时预览能力。
- `GalleryItemRecord.originalPath` 已保留原始文件，`post_process` 与 `transform` 已持久化。

## Release Scope

### P0 — v2 必须交付

1. 编辑体验骨架
   - 撤销 / 重做。
   - 编辑会话状态归一，确保返回后再进入不丢失当前参数。
   - 编辑历史以可序列化状态保存，支持崩溃或页面切换后恢复。
2. 参数化 P 图增强
   - 曲线：RGB 曲线与可拖拽控制点。
   - HSL：色相、饱和度、明度分组调整。
   - 局部亮度、局部对比度的参数化表达。
   - 模糊背景与背景虚化强度的基础实现。
3. 素材编辑
   - 文字层：字体、颜色、描边、透明度、位置、旋转、缩放。
   - 贴纸层：位置、旋转、缩放、透明度。
   - 边框 / 相框层：预设相框、颜色与厚度。
4. 导出一致性
   - 导出统一经过新的 `PhotoEditRenderer`。
   - 全量参数从原图重建成片。
   - 保存为当前照片、另存为新照片均保持参数与结果一致。
5. 诊断与测试
   - 4 套 UI 风格 × 当前主题下的控件视觉验证。
   - Android、iOS、HarmonyOS 构建通过。
   - 常见 12MP、48MP 图片导出无崩溃，内存峰值不超过现有后期处理基线的 1.5 倍。

### P1 — v2 可选交付

1. 局部蒙版
   - 手动涂抹或圆形区域遮罩。
   - 遮罩应用到亮度、模糊、饱和度等调整。
2. 一键增强
   - 基于直方图和现有色彩矩阵生成保守调整建议。
3. 人像微调
   - 面部亮度、牙齿提亮、背景压暗等保守参数化效果。
4. 模板化 P 图预设
   - 把完整编辑参数导出为可复用预设。

### 不进入 v2

- AI 生成式修图、AI 扩图、背景替换、发型妆容重绘。
- 液化、瘦脸、瘦身以外的复杂 mesh 变形。
- 需要引入大模型推理运行时或多平台原生推理适配的功能。

## Implementation Plan

### Task 1: 冻结现有行为并建立回归基线

**Files:**
- Modify: `lumira_app_flutter/test/`
- Reference: `lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart`
- Reference: `lumira_app_flutter/lib/features/capture/domain/photo_template.dart`

**Interfaces:**
- Consumes: 现有 `PostProcess`、`PostProcessColor`、`TransformParams` 的序列化格式。
- Produces: 编辑模型兼容性测试，确保后续扩展不破坏 v1 记录。

- [ ] 为 `PostProcess`、`PostProcessColor`、`TransformParams` 的 JSON 编解码补齐表驱动测试。
- [ ] 为旧照片记录 `baked + local` 增量合并建立回归用例。
- [ ] 对 v1 已支持的颜色、细节、滤镜、裁剪路径建立 golden test 或数值结果测试。
- [ ] 运行 `cd lumira_app_flutter && flutter test`，确认无既有用例回归。

### Task 2: 定义 v2 编辑会话模型

**Files:**
- Create: `lumira_app_flutter/lib/features/photo_edit/domain/photo_edit_session.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/domain/photo_edit_layer.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/domain/photo_edit_blend.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/photo_edit_session_test.dart`

**Interfaces:**
- Consumes: `PostProcess`、`TransformParams`。
- Produces:
  - `PhotoEditSession.fromPhotoRecord(GalleryItemRecord record)`
  - `PhotoEditSession apply(PhotoEditAction action)`
  - `bool get canUndo`
  - `bool get canRedo`
  - `Map<String, dynamic> toJson()`
  - `PhotoEditSession.fromJson(Map<String, dynamic> json)`

- [ ] 写失败测试：新建会话时正确导入 v1 参数。
- [ ] 写失败测试：每次参数变更生成一条可撤销动作。
- [ ] 写失败测试：undo / redo 后参数与历史索引一致。
- [ ] 实现不可变 `PhotoEditSession` 与动作历史。
- [ ] 实现 `PhotoEditLayer` 的 `adjustment / text / sticker / frame` 类型。
- [ ] 实现参数兼容迁移：v1 单一 `PostProcess` 自动转换为 v2 会话。
- [ ] 运行 `cd lumira_app_flutter && flutter test test/features/photo_edit/photo_edit_session_test.dart`。

### Task 3: 实现统一渲染器接口

**Files:**
- Create: `lumira_app_flutter/lib/features/photo_edit/services/photo_edit_renderer.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/services/photo_edit_canvas_painter.dart`
- Modify: `lumira_app_flutter/lib/features/capture/services/photo_post_processor.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/photo_edit_renderer_test.dart`

**Interfaces:**
- Consumes: `PhotoEditSession`。
- Produces:
  - `Future<ui.Image> renderPreview(ui.Image source, PhotoEditSession session)`
  - `Future<Uint8List> renderExport(Uint8List sourceBytes, PhotoEditSession session)`
  - `bool isRenderable(PhotoEditSession session)`

- [ ] 写失败测试：空会话输出与原图像素等价，忽略 JPEG 编码差异。
- [ ] 写失败测试：调整层顺序不影响颜色矩阵最终合成顺序。
- [ ] 实现 `PhotoEditRenderer` 的抽象接口和参数校验。
- [ ] 实现颜色、细节、滤镜、裁剪的 Canvas / ColorFilter 渲染。
- [ ] 实现 transform 与 crop 的嵌套组合，复用现有裁剪映射语义。
- [ ] 让 `PhotoPostProcessor` 调用统一渲染器，保留 isolate 兜底。
- [ ] 用同一张测试图和同一份 session 对比预览与导出的抽样像素。

### Task 4: 升级编辑页 UI 与工具栏

**Files:**
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/photo_edit_toolbar.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/photo_edit_history_bar.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/photo_edit_layer_list.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/photo_edit_toolbar_test.dart`

**Interfaces:**
- Consumes: `PhotoEditSession`、`PhotoEditRenderer`。
- Produces: 统一编辑工具入口和当前激活工具状态。

- [ ] 把 `_EditTool` 迁移为 photo edit 模块的公共枚举或工具描述模型。
- [ ] 接入 undo / redo 按钮，禁用态跟随 `canUndo` / `canRedo`。
- [ ] 接入图层列表，展示调整、文字、贴纸、边框层。
- [ ] 新增曲线、HSL、模糊背景工具入口。
- [ ] 所有控件改用 `ConsumerWidget` 并从 `appThemeProvider` 读取样式。
- [ ] 在 neumorphic、flat、glass、female 四种风格下人工检查面板与浮层。
- [ ] 运行 `cd lumira_app_flutter && flutter analyze` 与工具栏测试。

### Task 5: 实现曲线与 HSL

**Files:**
- Create: `lumira_app_flutter/lib/features/photo_edit/domain/rgb_curve.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/domain/hsl_adjustment.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/rgb_curve_editor.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/hsl_adjustment_tab.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/rgb_curve_test.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/hsl_adjustment_test.dart`

**Interfaces:**
- Consumes: `PhotoEditAdjustmentLayer`。
- Produces:
  - `List<double> rgbCurveToMatrix(List<Offset> controlPoints)`
  - `List<double> hslAdjustmentToMatrix(HslAdjustment adjustment)`
  - `double sampleCurve(double input, List<Offset> controlPoints)`

- [ ] 写失败测试：恒等曲线返回恒等颜色矩阵。
- [ ] 写失败测试：0、0.5、1 三个采样点符合 Catmull-Rom 插值结果。
- [ ] 实现单调 RGB 曲线和 0-1 输入采样。
- [ ] 实现色相分段、饱和度、明度参数到矩阵的映射。
- [ ] 在曲线编辑器中支持拖拽、重置和最多 8 个控制点。
- [ ] 在 HSL 面板中按红、橙、黄、绿、青、蓝、紫分组。
- [ ] 对预览与导出抽样像素做一致性断言。

### Task 6: 实现文字、贴纸与边框层

**Files:**
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/text_layer_editor.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/sticker_picker.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/widgets/frame_picker.dart`
- Modify: `lumira_app_flutter/lib/features/photo_edit/services/photo_edit_canvas_painter.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/photo_edit_canvas_painter_test.dart`

**Interfaces:**
- Consumes: `PhotoEditTextLayer`、`PhotoEditStickerLayer`、`PhotoEditFrameLayer`。
- Produces: 按图层顺序绘制到导出画布的 painter。

- [ ] 写失败测试：图层顺序决定绘制顺序。
- [ ] 写失败测试：文字层的位置、旋转、缩放、透明度映射到 Canvas 变换。
- [ ] 实现文字输入、颜色、描边和透明度编辑。
- [ ] 实现贴纸选择、拖拽、双指缩放和旋转。
- [ ] 实现预设边框、颜色和厚度。
- [ ] 交互层使用 `InteractiveViewer` / `GestureDetector`，导出层使用同一坐标模型。
- [ ] 验证贴纸缩放不会放大导出时的位图锯齿。

### Task 7: 实现背景模糊基础能力

**Files:**
- Modify: `lumira_app_flutter/lib/features/photo_edit/services/photo_edit_renderer.dart`
- Create: `lumira_app_flutter/lib/features/photo_edit/services/background_blur_service.dart`
- Test: `lumira_app_flutter/test/features/photo_edit/background_blur_service_test.dart`

**Interfaces:**
- Consumes: `PhotoEditAdjustmentLayer`。
- Produces: `Future<ui.Image> applyBackgroundBlur(ui.Image source, double radius, Rect? subjectRect)`。

- [ ] 写失败测试：`radius == 0` 返回原图。
- [ ] 写失败测试：`subjectRect == null` 对整图应用模糊。
- [ ] 实现 CPU 高斯模糊路径和 GPU `ImageFilter.blur` 路径。
- [ ] 预览层优先 GPU，导出层按分辨率选择 GPU 或 isolate CPU。
- [ ] 第一版使用用户选择的矩形主体区域，不依赖人像分割模型。
- [ ] 记录 12MP 与 48MP 测试图的耗时和内存峰值。

### Task 8: 持久化、迁移与另存

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/dao/gallery_dao.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`
- Create: `lumira_app_flutter/test/core/db/migration_v58_photo_edit_session_test.dart`

**Interfaces:**
- Consumes: `PhotoEditSession.toJson()`。
- Produces: `GalleryItemRecord.photoEditSession` 与 v58 数据库迁移。

- [ ] 写失败测试：v57 到 v58 新增 `photo_edit_session` 列且旧数据可读。
- [ ] 将 `_kDbVersion` 从 57 升级到 58。
- [ ] 旧记录首次进入 v2 编辑页时生成并保存兼容 session。
- [ ] 更新当前照片与另存为新照片的写入逻辑。
- [ ] 另存记录必须独立持有自己的 `photoEditSession`，避免引用原记录后被联动修改。
- [ ] 验证 v1 数据库记录升级后仍能打开、编辑和导出。

### Task 9: 性能与平台验收

**Files:**
- Create: `lumira_app_flutter/test/features/photo_edit/photo_edit_performance_test.dart`
- Modify: `docs/plans/2026-09-13-v2-photo-editing.md`

**Interfaces:**
- Consumes: `PhotoEditRenderer.renderExport`。
- Produces: 发布前性能与兼容性验收记录。

- [ ] 使用固定测试图建立 12MP 和 48MP 渲染耗时基线。
- [ ] 每新增导出能力后重复运行性能测试。
- [ ] Android 真机验证预览流畅度、导出成功率和相册保存。
- [ ] iOS 真机验证 P3 / sRGB 颜色观感、权限和相册保存。
- [ ] HarmonyOS 真机或 DevEco 构建验证 Shader、Canvas、文件访问和保存能力。
- [ ] 在弱网 / 完全离线状态下验证全部编辑功能可用。

### Task 10: v2 发布检查

**Files:**
- Modify: `lumira_app_flutter/pubspec.yaml`
- Modify: `docs/plans/2026-09-13-v2-photo-editing.md`

**Interfaces:**
- Consumes: 前九项任务的验收结果。
- Produces: v2 发布候选版本。

- [ ] 确认 P0 全部勾选，且没有未修复的阻断缺陷。
- [ ] 确认所有新增依赖支持 Android、iOS、HarmonyOS。
- [ ] 运行 `cd lumira_app_flutter && flutter analyze`。
- [ ] 运行 `cd lumira_app_flutter && flutter test`。
- [ ] 运行 `.github/workflows/flutter-ci.yml` 对应 CI，并确认通过。
- [ ] 更新 `pubspec.yaml` 版本为 `2.0.0+1`。
- [ ] 补录实际验收结果、已知限制和后续优化项。

## Acceptance Criteria

- v1 已有照片无需迁移操作即可在 v2 编辑页打开。
- 任意编辑参数组合后撤销、重做、重置、保存、另存结果正确。
- 同一份 session 的预览与导出抽样像素一致，颜色差异不超过人工可感知阈值。
- 文字、贴纸、边框和调整层按用户看到的顺序合成。
- 12MP 图片导出 P50 不超过 v1 当前后期处理导出耗时的 2 倍。
- Android、iOS、HarmonyOS 均能完成编辑并保存到本地或相册。
- Flutter analyze 与 Flutter test 全部通过。

## Risks and Decisions

1. **预览与导出不一致**
   - 决策：所有最终成片必须通过 `PhotoEditRenderer` 渲染，禁止编辑页临时叠加逻辑直接决定导出语义。
2. **复杂参数撑爆现有模型**
   - 决策：v2 引入 `PhotoEditSession` 与 `PhotoEditLayer`，`PostProcess` 只作为 v1 兼容视图。
3. **大图内存压力**
   - 决策：交互预览使用低分辨率缓存，导出时才从原图重建高分辨率结果。
4. **HarmonyOS 插件缺口**
   - 决策：优先使用 Flutter / Dart 实现；第三方能力必须同时验证 OHOS 路径，否则不进入 v2。
5. **高级 AI 能力范围蔓延**
   - 决策：AI 抠图、AI 修图、背景替换不进入 v2，待 v2 发布后单独立项。

