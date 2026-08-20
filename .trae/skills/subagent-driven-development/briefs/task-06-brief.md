# Task 6: 编辑器重做（全屏沉浸 + 底部可收起操作栏 + 三 Tab + 手势 + 双模式）

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart`（完全重写）
- Test: `lumira_app_flutter/test/features/watermark/watermark_editor_page_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkTemplate`/`WatermarkFrame`/`WatermarkElement.space`（Task 2）、渲染器 `WatermarkRenderer().render({sourceImage, template}) → WatermarkRenderResult{rgbaBytes,width,height}`（Task 3）、`watermark_sample.jpg`（Task 5）、`WatermarkDao`、`scheduleWatermarkPersist`、`SaveMode` sheet。
- Produces:
  - `WatermarkEditorPage({String? templateId, String? photoPath})`——`templateId` 空 = 新建空白模板（模板模式）；`photoPath` 非空 = 应用模式（在真实照片上加水印并另存）。
  - 保存行为：模板模式 → 写 `WatermarkDao` + 刷新 `customWatermarksProvider` + 更新 `activeTemplateId`；应用模式 → 解码照片 → `renderer.render` → 编码 JPEG → 复用 `showLumiraSaveModeSheet` 另存/替换新照片 → 刷新画廊列表。

## 现有代码结构（关键）

`watermark_editor_page.dart`（已读，需完全重写）：当前是 `ConsumerStatefulWidget`，`_template` 为副本、全局滑杆控制所有元素。Task 6 完全替代它。

`WatermarkTemplate`：字段 `id/name/type/elements/createdAt/frame`，`WatermarkElement` 有 `id/type/text/x/y/fontSize/color/shadowColor/opacity/rotation/fontFamily/textAlign/bold/italic/letterSpacing/space`，均支持 copyWith。`WatermarkFrame` 有 `type/color/borderRatio/borderRadius/bottomPlate/bottomRatio/shadowColor/shadowOpacity/shadowBlur` + copyWith。

`WatermarkDao`（`watermark_dao.dart`）：`getAll`/`getById`/`insert`/`update`/`delete`。

`watermark_providers.dart`：`watermarkSettingsProvider`/(`StateProvider`)、`presetWatermarksProvider`、`customWatermarksProvider`、`currentWatermarkTemplateProvider`、`watermarkRendererProvider`、`scheduleWatermarkPersist(container)`、`setWatermarkActive(container, id)`（Task 5 已加）、`setWatermarkManageLayout(container, layout)`。

**应用模式保存管线**（参考 `gallery_edit_page.dart` _export + `capture_page.dart` 水印段落）：
- SaveMode sheet：`import 'package:lumira_app_flutter/shared/widgets/lumira/dialog/lumira_save_mode_sheet.dart'`，`final saveMode = await showLumiraSaveModeSheet(context: context);`；`SaveMode.replace` / `SaveMode.duplicate`；取消返回 null。
- 渲染：`final sourceImage = await ui.decodeImageFromList(await File(photoPath).readAsBytes());` → `final r = await ref.read(watermarkRendererProvider).render(sourceImage: sourceImage, template: _template);` → `img.Image.fromBytes(width: r.width, height: r.height, bytes: r.rgbaBytes.buffer, numChannels: 4, order: img.ChannelOrder.rgba)` → `img.encodeJpg(..., quality: 90)` → 写文件。`img` 来自 `package:image/image.dart as img`（capture_page 同款）。
- 另存/替换：参考 gallery_edit_page——duplicate 用 `_makeDuplicatePath` 风格新文件路径 + `GalleryItemRecord(...) + dao.insert` + `ref.invalidate(galleryDaoProvider)`；replace 用原路径覆盖 + `dao.updateEdit...` 或按画廊现有插入逻辑。**应用模式下建议以 duplicate 为主**（"水印另存新照片"语义），replace 如与原图记录映射复杂可省略——应用模式核心交付：读取照片→渲染→写文件→（创建画廊记录）→返回。**若替换原图需维护完整 gallery record 映射过于复杂，可只实现 duplicate（另存新照片），符合设计"保存并应用→另存新照片"。**
- `GalleryItemRecord`/`galleryDaoProvider` 参考 `gallery_edit_page.dart`。

## Global Constraints（AGENTS.md 铁律）

- **样式随主题**：所有颜色/阴影/边框/圆角来自 `themeTokensProvider`（`ThemeTokens.canvas/surface/textPrimary/textSecondary/textTertiary/brand/brandSubtle/brandText/divider/surfaceAlt` 等，见现有编辑页已用 tokens.*）+ `uiStyleProvider`。禁止硬编码主题色。
- **叠在照片上的浮层（底部操作栏）**：新拟态 → 实心 `tokens.surface` + 细边（`tokens.divider`），**无外阴影、无模糊**；glass 允许其自身毛玻璃。不混搭风格。
- **预览区留白合法**：照片 contain 适配时周围留白是"叠照片遮罩"，可用 `Colors.black`（唯一合法例外）。
- **复用共享组件**：`LumiraNav`、`LumiraButton`、`LumiraIconButton`、`NeuCard`。
- **Dart 2.19.6**，禁止 records。
- 测试：`flutter test test/features/watermark/watermark_editor_page_test.dart` 定向；提交前全绿。

---

- [ ] **Step 1: 写关键 widget 测试**

  `test/features/watermark/watermark_editor_page_test.dart`（沿用 `profile_settings_page_test.dart` 的 ProviderScope/wrap/settleOrPump/setLargeViewport 模式，可仅测 neumorphic+warmWhite）：
  ```dart
  // 覆盖点：
  // - 渲染编辑页（模板模式，传入 templateId 为某预设）不崩溃，预览区存在
  // - 底部操作栏默认展开态：存在「元素」「样式」「边框」三个 Tab
  // - 点击「收起」后操作栏折叠为细条（仍可点开恢复）
  // - 元素 Tab：点「＋文本」新增一个元素；选中后可删除
  // - 边框 Tab：切到「拍立得」后模板 frame.type == polaroid（可通过切回模板后读 provider/状态断言，或暴露可选 test hook）
  // - 样式 Tab：切换「照片/白边」后选中元素 space 更新
  ```
  若需断言模板内部状态，可让编辑页在需要时暴露状态（如通过 `find` 拿到后触发 UI 并断言 UI 呈现，而非直接读被裁剪的私有状态）；优先以 UI Finder 断言。模板模式编辑页构造 `WatermarkEditorPage(templateId: <某预设 id>)`。

- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/watermark_editor_page_test.dart`
  Expected: FAIL（新行为不存在）。

- [ ] **Step 3: 实现编辑器**

  `watermark_editor_page.dart` 完全重写为 `ConsumerStatefulWidget`，要点：
  - **构造**：`WatermarkEditorPage({super.key, this.templateId, this.photoPath})`。
  - **状态**：`_template`（可变副本）、`_selectedElementId`（String?）、`_expanded`（bool，默认 true）、`_tab`（`_EditorTab` 枚举：element/style/border）、`_photoBytes`（应用模式）。
  - **initState 加载模板**：
    - 应用模式（photoPath != null）：读取照片字节 `_photoBytes`；模板 = `currentWatermarkTemplateProvider` 命中的模板副本，否则用首个预设副本。
    - 模板模式：`templateId` 命中（preset 或 custom）则 deep-copy 该模板为自定义副本（元素 copyWith 新 id）；`templateId` 为 null → 新建空白模板（1 个默认文本元素，name='新水印'）。
  - **顶部导航**：`LumiraNav`；左侧「取消」返回；标题（模板模式「编辑水印」/应用模式「添加水印」）；右侧「保存」（模板模式）/「保存并应用」（应用模式）。
  - **预览区（铁律）**：
    - `LayoutBuilder` 计算可用高度 = 屏高 − 顶部导航高度 − 底部操作栏高度（随 `_expanded` 动态）。
    - 背景：应用模式 `Image.memory(_photoBytes)`；模板模式 `AssetImage('assets/images/watermark_sample.jpg')`（用 `Image`）。
    - 照片 `BoxFit.contain`（**等比适配，宽高比不变，全貌可见**）；周围 `Colors.black` 留白。
    - 元素叠加层：`Stack` + `Positioned`，按 `space` 换算：photo 元素 → 照片显示矩形；frame 元素 → polaroid 白板矩形（含 bottomPlate 时）；无画框时 frame==photo 矩形。以 `LayoutBuilder` 得到的照片实际显示 rect 计算（用 `AspectRatio` 或手动换算 contain 后 rect）。
    - 元素用 `GestureDetector`：点选（选中高亮边框）、单指 `onPanUpdate` 拖拽（更新 x/y 相对坐标）、双指 `onScaleStart/Update` 缩放（改 fontSize）。实现参考常见可拖拽叠加层。
  - **底部操作栏**（锚定在底部，`AnimatedSize`/`AnimatedContainer` 平滑展开折叠）：
    - 折叠态：细条（约 40px）+「展开操作栏」箭头。
    - 展开态：顶部三 Tab（元素/样式/边框）+ 参数区。
    - 作为叠照片浮层：颜色/圆角/阴影按当前风格从 `tokens` 取（新拟态实心 surface + 细边、无外阴影）。
  - **元素 Tab**：
    - 元素 chip 列表（名称/类型 + 选中态）。
    - 「＋文本」「＋日期」按钮新增元素（追加到 `_template.elements`，新 id）。
    - 选中元素：「复制」「删除」按钮。
  - **样式 Tab**（当 `_selectedElementId != null` 时启用）：
    - 文本输入（text 类型编辑元素.text）。
    - 字号/透明度/旋转（弧度）/字间距滑杆。
    - 颜色色板（主题色 + 白/黑）。
    - 粗体/斜体/对齐 toggle。
    - 「照片/白边」segmented：更新 `selectedElement.space` 为 `photo`/`frame`；frame 选项仅当 template.frame.type==polaroid 且 bottomPlate 时可选，其余禁用（默认 photo）。
  - **边框 Tab**：
    - 画框类型 segmented：无 / 拍立得 / 内描边。
    - 拍立得 → 厚度(borderRatio)、白板开关 + 比例(bottomRatio)、圆角(borderRadius)、投影开关/强度(shadowOpacity/shadowBlur)。
    - 内描边 → 颜色、厚度(borderRatio)、圆角。
  - **模板模式保存**（`_saveTemplate`）：
    - `final dao = await ref.read(watermarkDaoProvider.future); await dao.insert(_template);`
    - `ref.read(customWatermarksProvider.notifier).state = [...ref.read(customWatermarksProvider), _template];`
    - `setWatermarkActive(ProviderScope.containerOf(context, listen:false), _template.id);`（或手动 copyWith+persist）
    - `if (context.canPop()) context.pop();`
  - **应用模式保存**（`_saveApply`）：
    - 弹 `showLumiraSaveModeSheet`；取消则返回。
    - decode `_photoBytes` → `renderer.render(sourceImage, template)` → JPEG 写文件（duplicate 用新路径 `<>_wm.jpg` 风格）→ 创建 `GalleryItemRecord` + `galleryDao.insert` + `ref.invalidate(galleryDaoProvider)`（参考 gallery_edit_page duplicate 分支）→ toast「已另存为新照片」→ 返回相册并刷新。
    - **若 replace 需完整 gallery record 映射过于复杂，只实现 duplicate 即可。**
  - **取消**（模板模式丢弃返回 / 应用模式直接返回）。

- [ ] **Step 4: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_editor_page_test.dart`
  Expected: PASS。

- [ ] **Step 5: analyze + Commit**

  Run: `flutter analyze`（或 focus 相关文件）
  Expected: 无 error。

  提交（**只精确暂存编辑页 + 其测试**，先 `git status`，绝不 `git add -A`）：
  ```bash
  git add lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart lumira_app_flutter/test/features/watermark/watermark_editor_page_test.dart
  git commit -m "feat(watermark): immersive editor with collapsible bottom panel and gestures"
  ```

  **IMPORTANT（并行会话）**：另一会话在并行提交（共享工作区文件正在被反复回滚）。只暂存上述 2 文件。若编译时报共享组件（LumiraButton/LumiraIconButton/NeuCard）API 不符，读取这些文件了解当前 API 后适配，但**不提交、不修改**这些共享组件文件。
  **注意**：应用模式用到的 `gallery_edit_page.dart`、`gallery_dao.dart` 如需作为参考或 import helper，仅读取参考，不修改。

## 参考实现锚点（已核对的真实签名）

```dart
// 渲染器
final r = await WatermarkRenderer().render(sourceImage: sourceImage, template: tpl);
// r.width / r.height / r.rgbaBytes（Uint8List）

// image 包编码（capture_page 同款）
import 'package:image/image.dart' as img;
final outputImage = img.Image.fromBytes(width: r.width, height: r.height,
  bytes: r.rgbaBytes.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
final jpegBytes = img.encodeJpg(outputImage, quality: 90);

// decode
import 'dart:ui' as ui;
final sourceImage = await ui.decodeImageFromList(await File(photoPath).readAsBytes());

// SaveMode
import 'package:lumira_app_flutter/shared/widgets/lumira/dialog/lumira_save_mode_sheet.dart';
final saveMode = await showLumiraSaveModeSheet(context: context);
// enum SaveMode { replace, duplicate }
```

**注意**：`ui.decodeImageFromList` 在 Flutter 3.7.12 是否可用需核实（若不可用，用 `ui.instantiateImageCodec` + `getNextFrame` 模式，与 capture_page 创建的 descriptor 方式类似）。以实际编译为准。