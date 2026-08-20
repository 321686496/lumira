# Task 5: 管理页重做（单列/双列切换 + 持久化 + 真实预览）

**Files:**
- Sample photo already generated: `lumira_app_flutter/assets/images/watermark_sample.jpg`（已完成，勿重复生成）
- Modify: `lumira_app_flutter/lib/features/watermark/widgets/watermark_preview.dart`
- Modify: `lumira_app_flutter/lib/features/watermark/pages/watermark_manage_page.dart`（重写）
- Modify: `lumira_app_flutter/lib/features/watermark/data/watermark_providers.dart`（管理页布局读写辅助）
- Test: `lumira_app_flutter/test/features/watermark/watermark_manage_page_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkSettings.manageLayout`（Task 2）、`WatermarkTemplate`、`scheduleWatermarkPersist`/`watermarkSettingsProvider`/`presetWatermarksProvider`/`customWatermarksProvider`、`watermarkDaoProvider`（均既有）。
- Produces:
  - `WatermarkManagePage` 顶部右上角「单列/双列」切换按钮 +「＋新建」；单列卡片 / 双列网格两种布局；点卡片选中；自定义模板可编辑/复制/删除；预设只读。
  - `WatermarkPreview(template, background)` 基于真实照片（`watermark_sample.jpg`）渲染叠加预览。

## 现有代码结构（重要）

`watermark_manage_page.dart`（已读）：当前是单列 ListView，每项 `_WatermarkCard`（`NeuCard` 内：左侧 `WatermarkPreview(template, width:96, height:124)` + 名称 + `_TypeTag` 类型标签；右侧选中 `_SelectedBadge` 对勾 / 否则 `_EditButton`）。用 `presetWatermarksProvider`（只含 preset），**不合并自定义**。选择逻辑：`ref.read(watermarkSettingsProvider.notifier).state = ...copyWith(activeTemplateId: ...)` → `scheduleWatermarkPersist` → `context.pop()`。编辑：`context.push(RouteNames.profileSettingsWatermarkEdit?...paramTemplateId=...)`。

`watermark_preview.dart`（已读）：`WatermarkPreview({template, width=100, height=130, background, borderRadius=8})`，用深色固定底 `_defaultBackground = Color(0xFF2A2A2A)` + CustomPaint 画元素。**注意：background 参数存在但语义是"纯色背景色"，需改造为"照片底图"。**

`watermark_providers.dart`（已读）：已有 `watermarkSettingsProvider`（StateProvider<WatermarkSettings>）、`watermarkRendererProvider`、`presetWatermarksProvider`、`customWatermarksProvider`、`currentWatermarkTemplateProvider`、`loadWatermarkSettings`、`loadCustomWatermarks`、`scheduleWatermarkPersist`。`watermarkDaoProvider` 从 `../../../core/db/database_provider.dart` 已有。

`watermark_settings.dart`：`WatermarkSettings` 已有 `manageLayout`（Task 2 完成，默认 list）+ `copyWith(manageLayout:)`。

`themeTokensProvider` 在 `../../../core/theme/theme_controller.dart`（管理页已 import）。`uiStyleProvider` 也在 theme_controller。共享组件：`NeuCard`、`LumiraNav`、`LumiraIconButton`、`LumiraButton` 的位置见管理页现有 import。

## Global Constraints（AGENTS.md 铁律）

- **UI 风格随设置 + 主题**：所有颜色/阴影/边框/圆角必须来自 `themeTokensProvider`（`ThemeTokens` 的 `.canvas/.surface/.textPrimary/.textSecondary/.brand/.brandSubtle/.border` 等）+ 必要时 `uiStyleProvider`。禁止硬编码 `Colors.xxx`/`Color(0xFF...)`/写死 BoxShadow/BorderRadius 表达主题观感。
- **复用共享组件**：优先 `NeuCard`、`LumiraButton`、`LumiraIconButton`、`LumiraNav`。
- **叠在照片上的浮层**：新拟态下用实心 `tokens.surface` + 细边，无外阴影、无模糊。
- **Dart 2.19.6**，禁止 records 语法。
- 测试：`flutter test test/features/watermark/watermark_manage_page_test.dart` 定向；提交前全绿。

---

- [ ] **Step 0: 确认示例照片已就位**

  确认 `lumira_app_flutter/assets/images/watermark_sample.jpg` 存在（已生成）。pubspec 已含 `assets/images/` 通配，无需改。**不要重新生成。**

- [ ] **Step 1: 改造 WatermarkPreview 为"照片底 + 模板叠加"**

  修改 `watermark_preview.dart`：
  - 入参新增 `ImageProvider? background`（可选）。当提供时，背景绘制真实照片；未提供时保持不变（用现有深色底或空白）。
  - 用 `Stack`：底层 `Image(image: background, fit: BoxFit.cover, ...)`，上层 `CustomPaint(painter: _WatermarkPreviewPainter(template))`。外层 `ClipRRect`/`Clip.antiAlias` 裁圆角。
  - painter 需按模板 `space`（photo/frame）正确换算坐标空间：photo 元素相对照片显示矩形（即整个预览尺寸），frame 元素相对白板区域（若 polaroid 且有 bottomPlate）。但预览为小尺寸，可先按"照片铺满预览区"近似（即 space==frame 元素也用同一矩形），保证观察真实观感即可，不做画框缩放。**保持现有绘画算法与最小字号逻辑。**
  - 若改造复杂，可新增一个 `WatermarkPhotoPreview` 专用组件替代管理页中的使用点，旧 `WatermarkPreview` 保留供编辑页复用；但优先扩展 `WatermarkPreview` 使两个页面共用。

- [ ] **Step 2: 实现布局切换持久化辅助**

  在 `watermark_providers.dart` 增加：
  ```dart
  /// 切换管理页布局并持久化（list/grid）。
  void setWatermarkManageLayout(ProviderContainer container, WatermarkManageLayout layout) {
    container.read(watermarkSettingsProvider.notifier).state =
        container.read(watermarkSettingsProvider).copyWith(manageLayout: layout);
    scheduleWatermarkPersist(container);
  }
  ```
  顶部补 import `../models/watermark_settings.dart`（`WatermarkManageLayout`，若尚未导入）。已有 `WatermarkSettings` 导入，`WatermarkManageLayout` 同文件。

- [ ] **Step 3: 重写管理页**

  `watermark_manage_page.dart` 实现要点（遵循 Global Constraints 主题规范，复用 themeTokens）：
  - **顶部导航**：保留 `LumiraNav(title: '水印管理')`。AppBar 右侧 actions：`LumiraIconButton` 布局切换（单列≡ / 双列▦图标，当前布局高亮）+「＋新建」`LumiraButton`。
  - **布局源**：`ref.watch(watermarkSettingsProvider).manageLayout`；切换调 `setWatermarkManageLayout(ProviderScope.containerOf(context, listen: false), layout)`。
  - **数据源**：合并 `presetWatermarksProvider` + `customWatermarksProvider` 展示（预设在前）。选中态来自 `watermarkSettingsProvider.activeTemplateId`。
  - **单列卡片**：横向卡片 = 左侧 `WatermarkPreview` 缩略（传入 `background: AssetImage('assets/images/watermark_sample.jpg')`）+ 名称 + 类型标签（预置/自定义）+ 右侧 选中✓/编辑✎。
  - **双列网格**：`GridView`（2 列）= `WatermarkPreview` 缩略 + 名称 + 选中/编辑标记，选中态用主题色描边（`tokens.brand` 细边）。
  - **交互**：
    - 点卡片 → `setWatermarkActive`（见下方辅助）→ 更新 settings + `scheduleWatermarkPersist` → `context.pop()`。
    - 编辑 → `context.push(RouteNames.profileSettingsWatermarkEdit?...paramTemplateId=template.id)`。
    - 自定义模板：删除（经 `watermarkDaoProvider` delete + 刷新 `customWatermarksProvider`）、复制（以 `_copy` 后缀生成新自定义模板写入 DAO + 刷新）。
    - 预设只读（无删除/复制，仅选中/编辑？——按现行为准：预设可编辑查看，不可删除）。
    - 「＋新建」→ 空模板进编辑器（无 templateId 的编辑路由，见 Task 6；本任务可仅跳转编辑路由不带参数，或新建空白模板走编辑路由，实现以可行为准，Test 仅断言入口存在）。
  - 删除/复制/选中逻辑若既有管理页已部分实现则沿用并套新布局；否则新增 `setWatermarkActive` 辅助到 providers：
    ```dart
    /// 选中水印模板并持久化（preset/custom 均可）。
    void setWatermarkActive(ProviderContainer container, String templateId) {
      container.read(watermarkSettingsProvider.notifier).state =
          container.read(watermarkSettingsProvider).copyWith(activeTemplateId: templateId);
      scheduleWatermarkPersist(container);
    }
    ```
  - 所有卡片、按钮、描边颜色均来自 `themeTokensProvider`。

  `watermark_manage_page.dart` 顶部需 import：`package:flutter/painting.dart`（AssetImage 来自 `package:flutter/widgets.dart`，material 已含）、assets 相对路径字面量字符串。章节标题可加（预置 / 自定义 两组标题）。

- [ ] **Step 4: 写管理页 widget 测试**

  `test/features/watermark/watermark_manage_page_test.dart`（沿用 `profile_settings_page_test.dart` 的模式：`ProviderScope` + overrides `themeKeyProvider.uiStyleProvider` + 用 `wrap()` 构建 `MaterialApp.router`）：
  ```dart
  // 覆盖点：
  // - 默认显示单列卡片（find 到「简约日期」「拍立得」等预设卡片文本）
  // - 点击 ▦ 切换后显示双列网格卡片
  // - 切换后 watermarkSettings.manageLayout == grid（读 provider 断言）
  // - 点击卡片后 activeTemplateId 更新（可断言 settings provider 值）
  ```
  测试构建参考 `profile_settings_page_test.dart` 的 `wrap()`（`ProviderScope` + overrides）、`settleOrPump`（female 风格 pump 500ms 其余 pumpAndSettle）、`setLargeViewport`（设置窗口 800x2400 物理尺寸）。可只测 neumorphic 风格 + warmWhite 主题以简化；如遇 female 动画问题，用 settleOrPump 兜底。
  若 `WatermarkPreview` 加载 `AssetImage`，测试中需 `tester.runAsync` 或容忍 `Image` 加载——可用 `tester.pumpAndSettle()` 配合 HttpOverrides 屏蔽网络（参考现测试的 `TestHttpOverrides`、`NetworkImageLoadException` 忽略 handler）。如预览图片导致测试不稳定，可将 preview 背景做成可注入的 `ImageProvider`，测试 override 为纯色 provider 或参数关闭图片，保证测试聚焦布局逻辑。

- [ ] **Step 5: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_manage_page_test.dart`
  Expected: PASS。

- [ ] **Step 6: analyze + Commit**

  Run: `flutter analyze`（或 `flutter analyze lib/features/watermark test/features/watermark`）
  Expected: 无 error。

  提交：`git add lumira_app_flutter/lib/features/watermark lumira_app_flutter/assets/images/watermark_sample.jpg lumira_app_flutter/test/features/watermark` 前先 `git status` 确认只暂存 watermark 相关文件（示例图、模块、测试）。commit 信息：
  ```
  feat(watermark): redesign manage page with list/grid toggle and photo preview
  ```

  **IMPORTANT（并行会话）**：本仓库有另一会话在并行提交（usage/scenes/theme 等共享组件改动在工作区未暂存）。**只精确暂存 watermark 模块 + 示例图 + watermark 测试文件**，绝不 `git add -A`，不提交并行会话的改动。若该示例照片文件已被并行会话无关改动影响，先确认其内容为本任务的 sample。