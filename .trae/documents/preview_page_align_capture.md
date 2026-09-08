# 模板添加表单 · 实时预览页对齐拍摄页

## Context（背景）

「添加/编辑自定义模板」表单中点「预览」进入的实时预览页
`lib/features/capture/pages/capture_preview_template_page.dart` 已严重落后于 App 当前拍摄页功能：
目前只有简化版取景器（`CameraPreview formOverride`）+ 简化的折叠 `_AdjustPanel`（构图透明度 + 相机 3 滑块 +
后期若干滑块 + 白平衡/闪光/对焦/LUT seg-btn），而拍摄页 `capture_page.dart` 已演进为完整的
5 页签参数面板、滤镜抽屉、场景条、缩放轮盘、补光灯、多姿势切换、水平仪、实时成片等。

需求：预览页在**功能、布局、参数调整效果上与拍摄页完全一致**，且参数调整后能**回写到添加模板表单（EditorForm）**。

已与用户对齐的方向（用户跳过澄清，采用推荐项）：
- **全部照搬**拍摄页能力（导航胶囊 / 5 页签参数面板 / 滤镜 / 场景条 / 缩放 / 补光 / 多姿势 / 水平仪 / 拍照）。
- 采用**桥接方案**：预览页把 `EditorForm` 转换为 `PhotoTemplate`，喂给拍摄页公共组件，视觉与参数效果天然一致；**不改拍摄页真实拍摄逻辑**。
- 预览页**拍照仅预览、不入成片库**。

关键事实（已核实）：
- 拍摄页公共组件：`CaptureNav`、`ParamPanel`、`FilterPicker`、`ScenePresetStrip`、`TemplateStrip`、`LevelIndicator`、`DelayTimerButton`、`AspectRatioSelector`、`ParamPillBar`、`CaptureButton`、`ShutterFeedback`（均在 `lib/features/capture/widgets/` 下，已 public）。
- 拍摄页其余控件是 `capture_page.dart` 内**私有类**：`_BottomControlArea`、`_CaptureToolbar`、`_AnimatedToolDrawer`、`_FillLightPanel`、`_ZoomBar`、`_CaptureButtonRow`、`_PoseSwitchButton`。
- 数据双模：预览页用 `EditorForm`（`lib/features/templates/data/templates_editor_mock_data.dart`，有 `copy()`、`meta.style/subStyle/method/images/shortDesc/ambience` 等 EditorForm 独有字段）；拍摄页组件用 `PhotoTemplate` + `CaptureState`（`lib/features/capture/domain/photo_template.dart`、`data/capture_state.dart`）。
- `CameraPreview` 双路径：`formOverride != null` 走 EditorForm；`null` 走 `editableTemplateProvider + effective*Provider`（拍摄页路径）。桥接后预览页传 `null`，与参数面板共享同一状态源。
- 编辑器 `_onPreview`（`templates_editor_page.dart` L989-1027）写 `previewEditorFormProvider` → 跳 `/capture/preview-template?draftId=` → 返回后读回更新 `_form`；`preview_form_provider.dart` 是 `StateProvider<EditorForm?>`。
- `originalTemplateProvider` 是派生 provider（读 `currentTemplateIdProvider`），**无法被直接 write**，ParamPanel 的「重置」直接读它 → 需要新增「预览原始快照」provider 并让 `originalTemplateProvider` 优先返回它。

## 实现方案

### 1. `lib/features/capture/data/capture_state.dart` — 新增桥接源
- 新增 `static final previewTemplateSourceProvider = StateProvider<PhotoTemplate?>((ref) => null);`
- 修改 `originalTemplateProvider`：开头优先判空返回 `previewTemplateSourceProvider`，否则走原逻辑：
  ```dart
  final preview = ref.watch(previewTemplateSourceProvider);
  if (preview != null) return preview;
  // … 原有 currentTemplateId → registry/cache/remote 逻辑不变 …
  ```
- `previewTemplateSourceProvider` 恒 null 时拍摄页行为不变，`editableTemplateProvider / effective*Provider / currentPoseCameraDirectionProvider / appliedProvider` 全部零改动直接生效。
- 同步在 `resetAll` 末尾清空 `previewTemplateSourceProvider`。

### 2. `lib/features/templates/services/template_mapper.dart` — 新增双向桥接转换
（该文件已用 `editor` 别名 import EditorForm，复用 `normalizeAssetUrl` / Silhouette 处理，不新建文件。）
- `static PhotoTemplate editorFormToPhotoTemplate(editor.EditorForm form, {String? id})`：
  EditorForm 全字段映射到 `PhotoTemplate.meta/composition/poses/camera/sceneGuide/postProcess`。
  默认值补齐（EditorForm 缺失的字段）：
  - `postProcess.legStretch = 0`（EditorForm 无，预览可调但**不回写**，注明）
  - `systemFilter` 原样映射；`customCropRect`/`wbResidual` 置 null
  - `meta.price=0, author='', version=0` 等模板组件的默认值
  - `composition.type` 等空字符串回退
- `static editor.EditorForm photoTemplateToEditorFormMerge(PhotoTemplate edited, editor.EditorForm base)`：
  **不得从零重建 EditorForm**（会丢 `meta.style/subStyle/method/images/shortDesc/ambience`）。采用「`base.copy()` + 用 edited 的 PhotoTemplate 覆盖 composition/poses/camera/postProcess/fillLight 可编辑字段」。
- 私有 helper：`_editorPoseToPose / _poseToEditorPose / _editorColorToDomain / _domainColorToEditor / _editorFillLightToDomain / _domainFillLightToEditor`。可空字段（highlights/shadows/blackPoint/clarity/vibrance/brilliance/systemFilter）双向原样透传。

### 3. `lib/features/capture/widgets/capture_bottom_controls.dart`（新建）
把 `capture_page.dart` 里以下私有类**剪切**过去并去掉下划线改 public，内容不改（纯 move）：
`_ZoomBar→ZoomBar`、`_CaptureToolbar→CaptureToolbar`、`_AnimatedToolDrawer→AnimatedToolDrawer`、`_FillLightPanel→CaptureFillLightPanel`、`_CaptureButtonRow→CaptureButtonRow`、`_PoseSwitchButton→CapturePoseSwitchButton`。
并新增公共组装组件：
```dart
class CaptureBottomBar extends StatelessWidget {
  const CaptureBottomBar({
    required this.isFullscreen,
    required this.isTrialMode,
    required this.onCapture,
    this.onSwitchCamera,
  });
  // 复刻原 _BottomControlArea 的 build：ZoomBar + CaptureToolbar + AnimatedToolDrawer + 拍摄行(CaptureButtonRow)
}
```
依赖注入约束：组件内部通过 `activeToolProvider` 分发 `TemplateStrip / ScenePresetStrip / ParamPanel / FilterPicker / CaptureFillLightPanel`（沿用原逻辑）。
`capture_page.dart` 删除这些私有类，改为 `import '../widgets/capture_bottom_controls.dart'`，把 `_BottomControlArea(...)` 调用替换为 `CaptureBottomBar(...)`（回调照传）。**纯 move，不改逻辑**。

### 4. `lib/features/capture/pages/capture_preview_template_page.dart`（重写）
- 保留：`_template`（EditorForm 源）、从 `previewEditorFormProvider` 读取 + fallback `CapturePreviewMockData`、加载失败 Toast+pop。
- 删除旧私有实现：`_AdjustPanel / _Viewfinder / _ParamPillBar / _SyncButton / _PreviewTemplateNav / _NavCircleButton`。
- `initState` 加载成功后：
  1. `_bridge = TemplateMapper.editorFormToPhotoTemplate(_template!, id: 非空?meta.id:'preview_${ts}')`
  2. `CaptureState.resetAll(ref.container)`（清拍摄残留）
  3. `ref.write(previewTemplateSourceProvider, _bridge)`（original 派生）
  4. `ref.write(currentTemplateIdProvider, _bridge.meta.id)`（CaptureNav 识别「模板拍摄」+ 模板/剪影按钮）
  5. `ref.write(aspectRatioProvider, cropRatio 非空 ? cropRatio : composition.aspectRatio)`
  6. 若 `form.fillLight?.enabled`：写 `fillLightEnabled/Color/Intensity` 三件套；若 pose.cameraDirection=='front'：写 `cameraFacingProvider='front'`。
- `build` 组成（Stack，镜像 capture_page.build 去除非预览项）：
  ```
  AspectRatio 取景器 + CameraPreview(formOverride: null),   // 走 editableTemplate，与参数面板同源
  CaptureNav(onBack: _onSyncBack),                          // 返回即同步
  顶部浮层：DelayTimerButton / AspectRatioSelector / ParamPillBar,
  右侧居中：CapturePoseSwitchButton,
  底部：CaptureBottomBar(onCapture: _onCapture, onSwitchCamera: 可选),
  ParamPanel(),  LevelIndicator(),
  右下角：「完成」浮层胶囊（tokens.surface + 细边，叠照片浮层规范；调用 _onSyncBack）
  ```
- `build` 补相机副作用监听（对齐拍摄页，否则取景器不随控件实时变）：
  `flashModeProvider→cameraService.setFlashMode`、`effectiveCameraProvider.exposureCompensation→setBrightness`、`fillLightEnabledProvider→屏幕亮度`（dispose 恢复）。
- `_onCapture`：轻量 `cameraService.capture(config…)`（沿用现 Bug12 实现），本地 `ShutterFeedback` 白闪 + Toast，**不写 gallery/watermark/thumbnail**。
- `_onSyncBack`：
  ```dart
  final bridge = ref.read(CaptureState.editableTemplateProvider);
  if (bridge != null && _template != null) {
    ref.write(previewEditorFormProvider,
        TemplateMapper.photoTemplateToEditorFormMerge(bridge, _template!));
  }
  ref.write(previewTemplateSourceProvider, null);   // 清理预览源
  pop（canPop->pop : GoRouter.go(templates)）
  ```
- `_back`（非同步的直接返回）也显式清 `previewTemplateSourceProvider`；dispose 兜底。

> 剪影：桥接后 `CameraPreview` 按 `editableTemplate.poses[currentPoseIndex]` 渲染（与拍摄页同款），`CapturePoseSwitchButton` 调 `CaptureState.nextPose`。删除原可拖动剪影层（与拍摄页一致的固定剪影）。

### 5. 测试适配
- `test/features/capture/capture_preview_template_page_test.dart`：旧断言（「参数调整」「实时调整模板参数」、11 slider、seg-btn 白平衡/闪光/对焦/LUT、剪影拖动）改为基于共享组件的等价断言：`find.byType(ParamPanel)`、5 Tab 文案（相机/色彩/细节/构图/场景）、`CaptureNav`/`CapturePoseSwitchButton`/`FilterPicker`/`ScenePresetStrip` 存在性；删除剪影拖动测试；新增「同步写回 previewEditorFormProvider 且 meta 不变」单测。
- 运行全量 capture 相关测试（尤其 `capture_page_test.dart`、`capture_nav_test.dart`、`param_panel_test.dart`、`route_observers` 相关）确认**抽取私有控件 + originalTemplateProvider 优先分支**未破坏真实拍摄页。

## 不会改动的文件
`camera_preview.dart`（预览页传 `formOverride:null` 即可）、`router.dart`、`param_panel.dart`、`filter_picker.dart`、`scene_preset_strip.dart`、`capture_nav.dart` 及其它公共组件。

> 说明：AGENTS.md 的「改动后端/后台后 commit+push 双仓」规则仅针对 `lumira-server/`；本次为纯 Flutter 改动，不需推送。

## 风险
1. **抽取私有控件回归**：纯 move 保 AST，风险低；用既有 capture 测试兜底。
2. **originalTemplateProvider 优先分支**：previewSource 恒 null 时拍摄行为不变；补 1 行单测。
3. **金色 CTA 与 UI 规范冲突**：预览页「完成」按钮不用原 `_SyncButton` 硬编码金色渐变，改为半透明 `tokens.surface` + 细边（叠照片浮层规范），避免跨风格混搭。
4. **相机副作用缺失**：需在预览页手动补 flash/EV/fillLight 监听（见上），否则实时预览不随控件变。
5. **预览页测试环境**：测试已用 `cameraPreviewOverrideProvider` 注入占位，`resetAll`/bridge 写入在 initState 发生，需确保 override 下共享组件可渲染（现有测试已覆盖大半）。

## 验证
1. `flutter analyze` 全绿。
2. `flutter test test/features/capture/capture_preview_template_page_test.dart test/features/capture/capture_page_test.dart test/features/capture/widgets/`（适配/全量回归）。
3. 真机/截图人工核对：
   - 编辑器点「预览」→ 预览页导航胶囊、5 页签参数面板、滤镜抽屉、场景条、缩放轮盘、补光（前置）、多姿势切换、水平仪、拍照按钮均与拍摄页一致。
   - 调整 EV/色彩/滤镜/补光/姿势后点「完成」→ 编辑器 `_form` 同步（meta 不变、可调字段更新）。
   - 前后置切换、比例跟随 cropRatio、剪影随姿势切换、拍照白闪/Toast 但不进图库。
   - 退出预览后进真实拍摄页，无残留（自由模式、非本模板）。