# 拍摄预览页编辑体验改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 拍摄预览页编辑区从「三档拖拽抽屉 + 文字 Tab」改为「底部图标工具条 + 滑出面板」（对齐后期修图页），新增照片右上角对比按钮，心情/场景改紧凑 pill 行，非编辑操作收进顶栏/分享 Sheet。

**Architecture:** 新增 3 个独立 widget（ComparePhotoButton / PreviewTagPillRow / PreviewEditToolbar），capture_preview_page 删除抽屉机制（约 500 行）改为 Column 布局（Expanded 照片区 + 底部 dock），PreviewEditPanel 类删除（FilterTab/CropTab 保留共用）。页面保持 `_localPostProcess` 增量模型与保存流程不变。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（**禁止 Dart 3 records 语法**）、flutter_riverpod、photo_view、现有 PostProcess/TransformParams 域模型。

**Spec:** `docs/specs/2026-09-07-capture-preview-edit-redesign-design.md`

## Global Constraints

- Dart 2.19.6：禁止 records（`(a, b)` 元组）、switch 表达式等 Dart 3 语法
- 样式只从 `ThemeTokens` 派生；**唯一例外**：叠照片的半透明黑/白遮罩（`Colors.black/white.withOpacity(...)`）允许硬编码（项目 UI 铁律）
- 叠照片浮层（对比按钮）：半透明底 + 细描边、**无外阴影、无模糊**（禁止借用 glass 风格语法）
- 禁止修改 `lumira-app/`（废弃 uni-app 项目）
- 面板高度固定值：色彩/细节 160、滤镜 264、裁剪 328（与 gallery_edit_page 一致）
- 每个 Task 完成后 `flutter analyze` 无新增告警
- 所有 shell 命令在 `e:\Project\photo_post\lumira_app_flutter` 下执行（Windows PowerShell；git commit 用多个 `-m`，不用 heredoc）
- git 仓库根为 `e:\Project\photo_post`（lumira_app_flutter 与 docs 同仓）；本功能不涉及后端，无需双远程 push

---

### Task 1: ComparePhotoButton 共享对比按钮

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/compare_photo_button.dart`
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart`（L377-386 使用处、L657-710 `_CompareButton` 类删除）
- Test: `lumira_app_flutter/test/features/capture/widgets/compare_photo_button_test.dart`（新建）

**Interfaces:**
- Produces: `ComparePhotoButton({required bool comparing, required ThemeTokens tokens, required VoidCallback onTap, bool overlayOnImage = false})` — 后续 Task 4 页面直接使用

- [ ] **Step 1: 写失败测试**

新建 `test/features/capture/widgets/compare_photo_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/widgets/compare_photo_button.dart';

void main() {
  final tokens = ThemeTokens.of(ThemeKey.warmWhite);

  Widget wrap({required bool comparing, required bool overlayOnImage}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ComparePhotoButton(
            comparing: comparing,
            tokens: tokens,
            onTap: () {},
            overlayOnImage: overlayOnImage,
          ),
        ),
      ),
    );
  }

  testWidgets('tap fires onTap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ComparePhotoButton(
            comparing: false,
            tokens: tokens,
            onTap: () => tapped++,
          ),
        ),
      ),
    ));
    await tester.tap(find.byType(ComparePhotoButton));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('comparing=true shows status dot', (tester) async {
    await tester.pumpWidget(wrap(comparing: true, overlayOnImage: false));
    // 状态点为 8x8 圆形 Container
    final dot = find.byWidgetPredicate((w) =>
        w is Container &&
        w.constraints?.minWidth == 8 &&
        w.constraints?.minHeight == 8);
    expect(dot, findsOneWidget);
  });

  testWidgets('comparing=false hides status dot', (tester) async {
    await tester.pumpWidget(wrap(comparing: false, overlayOnImage: false));
    final dot = find.byWidgetPredicate((w) =>
        w is Container &&
        w.constraints?.minWidth == 8 &&
        w.constraints?.minHeight == 8);
    expect(dot, findsNothing);
  });

  testWidgets('overlayOnImage=true has border and no shadow', (tester) async {
    await tester.pumpWidget(wrap(comparing: false, overlayOnImage: true));
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ComparePhotoButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final deco = container.decoration as BoxDecoration;
    // 叠照片形态：细描边 + 无外阴影（UI 铁律）
    expect(deco.border, isNotNull);
    expect(deco.boxShadow, isNull);
  });

  testWidgets('overlayOnImage=false keeps canvas style (shadow, no border)',
      (tester) async {
    await tester.pumpWidget(wrap(comparing: false, overlayOnImage: false));
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ComparePhotoButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final deco = container.decoration as BoxDecoration;
    // 画布形态（gallery 现有样式）：柔和凸阴影 + 无描边
    expect(deco.boxShadow, isNotNull);
    expect(deco.border, isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/capture/widgets/compare_photo_button_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'lumira_app_flutter' ... compare_photo_button.dart`（文件不存在）

- [ ] **Step 3: 实现 ComparePhotoButton**

新建 `lib/features/capture/widgets/compare_photo_button.dart`：

```dart
import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';

/// 悬浮「对比」按钮（修改前/修改后切换），拍摄预览页与后期修图页共用。
///
/// 两种形态（遵循项目 UI 铁律「叠照片浮层取向」）：
/// - [overlayOnImage] = false：纯色画布上（后期修图页）— surface 底 + 柔和凸阴影
/// - [overlayOnImage] = true：叠在照片上（拍摄预览页）— 半透明深色底 + 细白描边，
///   无外阴影、无模糊（照片无法承接同色双向浮雕阴影）
class ComparePhotoButton extends StatelessWidget {
  const ComparePhotoButton({
    Key? key,
    required this.comparing,
    required this.tokens,
    required this.onTap,
    this.overlayOnImage = false,
  }) : super(key: key);

  final bool comparing;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  /// 是否叠在照片上（决定浮层视觉取向）
  final bool overlayOnImage;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = comparing
        ? tokens.brand
        : (overlayOnImage ? Colors.white : tokens.textSecondary);
    final BoxDecoration decoration = overlayOnImage
        ? BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          )
        : BoxDecoration(
            color: tokens.surface,
            shape: BoxShape.circle,
            boxShadow: tokens.shadowConvexSubtle,
          );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: decoration,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.chrome_reader_mode_outlined,
              size: 20,
              color: iconColor,
            ),
            if (comparing)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/capture/widgets/compare_photo_button_test.dart`
Expected: PASS（5 个用例全过）

- [ ] **Step 5: gallery_edit_page 接入共享组件**

修改 `lib/features/gallery/pages/gallery_edit_page.dart`：

1. 顶部新增 import：
```dart
import 'package:lumira_app_flutter/features/capture/widgets/compare_photo_button.dart';
```
2. L377-386 的 `_CompareButton(...)` 替换为：
```dart
              Positioned(
                top: 12,
                right: 12,
                child: ComparePhotoButton(
                  comparing: _isComparing,
                  tokens: tokens,
                  onTap: () => setState(() => _isComparing = !_isComparing),
                ),
              ),
```
3. 删除 L657-710 的 `_CompareButton` 类（整段 `/// 画布右上角悬浮「对比」按钮` 注释 + 类体）。

- [ ] **Step 6: 验证 gallery 页无回归**

Run: `flutter analyze` → 无新增告警
Run: `flutter test test/features/gallery`
Expected: PASS

- [ ] **Step 7: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/compare_photo_button.dart lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart lumira_app_flutter/test/features/capture/widgets/compare_photo_button_test.dart
git commit -m "feat: 提取 ComparePhotoButton 共享对比按钮（画布/叠照片双形态）"
```

---

### Task 2: PreviewTagPillRow 心情/场景紧凑 pill 行

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/preview_tag_pill_row.dart`
- Test: `lumira_app_flutter/test/features/capture/widgets/preview_tag_pill_row_test.dart`（新建）

**Interfaces:**
- Consumes: `MoodOption`（`capture_preview_mock_data.dart`，字段 `name`/`active`，有 `copyWith`）、`CapturePreviewMockData.sceneOptions`（元素含 `id`/`name`）
- Produces: `PreviewTagPillRow({required List<MoodOption> moods, required String? selectedSceneId, required ValueChanged<MoodOption> onSelectMood, required ValueChanged<String?> onSelectScene, required ThemeTokens tokens})`

- [ ] **Step 1: 写失败测试**

新建 `test/features/capture/widgets/preview_tag_pill_row_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_preview_mock_data.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_tag_pill_row.dart';

void main() {
  final tokens = ThemeTokens.of(ThemeKey.warmWhite);

  Widget wrap({
    required List<MoodOption> moods,
    required String? selectedSceneId,
    ValueChanged<MoodOption>? onSelectMood,
    ValueChanged<String?>? onSelectScene,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: PreviewTagPillRow(
            moods: moods,
            selectedSceneId: selectedSceneId,
            onSelectMood: onSelectMood ?? (_) {},
            onSelectScene: onSelectScene ?? (_) {},
            tokens: tokens,
          ),
        ),
      ),
    );
  }

  testWidgets('renders mood pills and scene pills with 不标记',
      (tester) async {
    await tester.pumpWidget(wrap(
      moods: const [MoodOption(name: '开心'), MoodOption(name: '甜酷')],
      selectedSceneId: null,
    ));
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('甜酷'), findsOneWidget);
    // 第一个场景 + 不标记 pill（示例用 mock 数据第一个场景名）
    expect(find.text(CapturePreviewMockData.sceneOptions.first.name),
        findsOneWidget);
    expect(find.text('不标记'), findsOneWidget);
  });

  testWidgets('tapping mood pill fires onSelectMood with the option',
      (tester) async {
    MoodOption? tapped;
    await tester.pumpWidget(wrap(
      moods: const [MoodOption(name: '开心'), MoodOption(name: '甜酷')],
      selectedSceneId: null,
      onSelectMood: (m) => tapped = m,
    ));
    await tester.tap(find.text('甜酷'));
    await tester.pumpAndSettle();
    expect(tapped, isNotNull);
    expect(tapped!.name, '甜酷');
  });

  testWidgets('tapping 不标记 fires onSelectScene(null)', (tester) async {
    String? got = 'sentinel';
    await tester.pumpWidget(wrap(
      moods: const [MoodOption(name: '开心')],
      selectedSceneId: 'cafe',
      onSelectScene: (id) => got = id,
    ));
    await tester.tap(find.text('不标记'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('active scene pill has gradient decoration', (tester) async {
    await tester.pumpWidget(wrap(
      moods: const [MoodOption(name: '开心')],
      selectedSceneId: CapturePreviewMockData.sceneOptions.first.id,
    ));
    // active pill 的 Container decoration 有 LinearGradient
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.text(CapturePreviewMockData.sceneOptions.first.name),
        matching: find.byType(Container),
      ).first,
    );
    final deco = container.decoration as BoxDecoration;
    expect(deco.gradient, isA<LinearGradient>());
  });
}
```

注意：`MoodOption` 构造是否为 `const MoodOption(name: '开心')` 需现场核对 `capture_preview_mock_data.dart` L6-16（有 `active` 可选参数默认 false 则成立；若不同，按实际构造调整测试，断言不变）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/capture/widgets/preview_tag_pill_row_test.dart`
Expected: FAIL — `preview_tag_pill_row.dart` 不存在

- [ ] **Step 3: 实现 PreviewTagPillRow**

新建 `lib/features/capture/widgets/preview_tag_pill_row.dart`：

```dart
import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_preview_mock_data.dart';

/// 拍摄预览页底部「心情 | 场景」紧凑 pill 行。
///
/// 左半区横向滑动选择心情（点选中项再点一次 = 取消，语义等同旧「跳过」），
/// 右半区横向滑动选择拍摄场景（首项「不标记」= null）。
class PreviewTagPillRow extends StatelessWidget {
  const PreviewTagPillRow({
    Key? key,
    required this.moods,
    required this.selectedSceneId,
    required this.onSelectMood,
    required this.onSelectScene,
    required this.tokens,
  }) : super(key: key);

  final List<MoodOption> moods;
  final String? selectedSceneId;
  final ValueChanged<MoodOption> onSelectMood;
  final ValueChanged<String?> onSelectScene;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final scenes = CapturePreviewMockData.sceneOptions;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // 左：心情
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(
                child: _TagPill(
                  label: moods[i].name,
                  active: moods[i].active,
                  tokens: tokens,
                  onTap: () => onSelectMood(moods[i]),
                ),
              ),
            ),
          ),
          // 中：细分隔线
          Container(width: 1, height: 20, color: tokens.divider),
          const SizedBox(width: 8),
          // 右：场景（首项「不标记」）
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: scenes.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Center(
                    child: _TagPill(
                      label: '不标记',
                      active: selectedSceneId == null,
                      tokens: tokens,
                      onTap: () => onSelectScene(null),
                    ),
                  );
                }
                final scene = scenes[i - 1];
                return Center(
                  child: _TagPill(
                    label: scene.name,
                    active: selectedSceneId == scene.id,
                    tokens: tokens,
                    onTap: () => onSelectScene(scene.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// 单个标签 pill：选中 = 品牌渐变底 + 反色文字；未选 = surfaceAlt 底 + 次级文字
class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [tokens.brand, tokens.brandDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? tokens.textInverse : tokens.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/capture/widgets/preview_tag_pill_row_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/preview_tag_pill_row.dart lumira_app_flutter/test/features/capture/widgets/preview_tag_pill_row_test.dart
git commit -m "feat: 新增 PreviewTagPillRow 心情/场景紧凑 pill 行"
```

---

### Task 3: PreviewEditToolbar 图标工具条 + 滑出参数面板

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/preview_edit_toolbar.dart`
- Test: `lumira_app_flutter/test/features/capture/widgets/preview_edit_toolbar_test.dart`（新建）

**Interfaces:**
- Consumes（全部已存在）:
  - `PostProcessColorTab({required PostProcess full, required ValueChanged<PostProcess> onChanged, required ThemeTokens tokens})`
  - `PostProcessDetailTab(...)` 同上
  - `FilterTab({required PostProcess postProcess, required ValueChanged<PostProcess> onChanged, String? previewImagePath, required ThemeTokens tokens})`
  - `CropTab({required TransformParams transform, required ValueChanged<TransformParams> onChanged, required PostProcess postProcess, required ValueChanged<PostProcess> onPostProcessChanged, required ThemeTokens tokens, String? previewImagePath})`
  - `fullOf(PostProcess baked, PostProcess local)` / `deltaOf(PostProcess baked, PostProcess full, {PostProcess? current})`
- Produces:
  - `enum PreviewEditTool { color, detail, filter, crop }`
  - `PreviewEditToolbar({required PreviewEditTool? activeTool, required PostProcess postProcess, PostProcess? bakedPostProcess, required TransformParams transform, required ValueChanged<PreviewEditTool?> onToolChanged, required ValueChanged<PostProcess> onPostProcessChanged, required ValueChanged<TransformParams> onTransformChanged, required VoidCallback onReset, String? previewImagePath, bool isReadOnly = false, VoidCallback? onReadOnlyTap, required ThemeTokens tokens})`
  - 约定：`onToolChanged(null)` = 收起面板；裁剪模式 = `activeTool == PreviewEditTool.crop`（由页面据此驱动 `_isCropMode`）

- [ ] **Step 1: 写失败测试**

新建 `test/features/capture/widgets/preview_edit_toolbar_test.dart`（迁移自 preview_edit_panel_test.dart，交互改为「先点工具 Tab 再断言面板」）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_toolbar.dart';

void main() {
  final tokens = ThemeTokens.of(ThemeKey.warmWhite);

  Widget wrapWidget({
    PreviewEditTool? activeTool,
    PostProcess postProcess = const PostProcess(color: PostProcessColor()),
    PostProcess? bakedPostProcess,
    TransformParams transform = const TransformParams(),
    required ValueChanged<PreviewEditTool?> onToolChanged,
    required ValueChanged<PostProcess> onPostProcessChanged,
    required ValueChanged<TransformParams> onTransformChanged,
    VoidCallback? onReset,
    VoidCallback? onReadOnlyTap,
    bool isReadOnly = false,
    String? previewImagePath,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PreviewEditToolbar(
          activeTool: activeTool,
          postProcess: postProcess,
          bakedPostProcess: bakedPostProcess,
          transform: transform,
          onToolChanged: onToolChanged,
          onPostProcessChanged: onPostProcessChanged,
          onTransformChanged: onTransformChanged,
          onReset: onReset ?? () {},
          isReadOnly: isReadOnly,
          onReadOnlyTap: onReadOnlyTap,
          previewImagePath: previewImagePath,
          tokens: tokens,
        ),
      ),
    );
  }

  testWidgets('renders 5 tools: 色彩/细节/滤镜/裁剪/重置, no panel initially',
      (tester) async {
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    expect(find.text('色彩'), findsOneWidget);
    expect(find.text('细节'), findsOneWidget);
    expect(find.text('滤镜'), findsOneWidget);
    expect(find.text('裁剪'), findsOneWidget);
    expect(find.text('重置'), findsOneWidget);
    // 未选工具时无面板
    expect(find.text('亮度'), findsNothing);
  });

  testWidgets('tapping color tool opens panel with brightness slider',
      (tester) async {
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('色彩'));
    await tester.pumpAndSettle();
    expect(find.text('亮度'), findsOneWidget);
  });

  testWidgets('tapping active tool again collapses panel', (tester) async {
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('色彩'));
    await tester.pumpAndSettle();
    expect(find.text('亮度'), findsOneWidget);
    await tester.tap(find.text('色彩'));
    await tester.pumpAndSettle();
    expect(find.text('亮度'), findsNothing);
  });

  testWidgets('detail tool shows smoothStrength slider', (tester) async {
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('细节'));
    await tester.pumpAndSettle();
    expect(find.text('磨皮'), findsOneWidget);
  });

  testWidgets('crop tool shows rotation/flip/straighten and rotate callback fires',
      (tester) async {
    TransformParams? captured;
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (t) => captured = t,
    ));
    await tester.tap(find.text('裁剪'));
    await tester.pumpAndSettle();
    expect(find.text('旋转'), findsOneWidget);
    expect(find.text('翻转'), findsOneWidget);
    expect(find.text('拉直'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.rotation, 90);
  });

  testWidgets('baked brightness shows full value 20', (tester) async {
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      bakedPostProcess:
          const PostProcess(color: PostProcessColor(brightness: 20)),
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('色彩'));
    await tester.pumpAndSettle();
    // 面板显示全量 20（baked 基线），而非增量 0
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('dragging brightness slider emits delta 40 (not full 60)',
      (tester) async {
    PostProcess? capturedDelta;
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      bakedPostProcess:
          const PostProcess(color: PostProcessColor(brightness: 20)),
      onToolChanged: (_) {},
      onPostProcessChanged: (p) => capturedDelta = p,
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('色彩'));
    await tester.pumpAndSettle();

    // 亮度滑块行 = '亮度' 文本的最近祖先 GestureDetector
    final brightnessRow = find.ancestor(
      of: find.text('亮度'),
      matching: find.byType(GestureDetector),
    ).first;
    final rowSize = tester.getSize(brightnessRow);
    const labelWidth = 64.0;
    const valueWidth = 32.0;
    final trackWidth = rowSize.width - labelWidth - valueWidth;
    const min = -100.0;
    const max = 100.0;
    const newFull = 60.0; // 拖到亮度全量 60
    final t = (newFull - min) / (max - min);
    final localDx = labelWidth + trackWidth * t;

    final detector = tester.widget<GestureDetector>(brightnessRow);
    detector.onPanStart!(DragStartDetails(localPosition: Offset(localDx, 0)));

    // 回调收到增量 = 60 - 20 = 40
    expect(capturedDelta, isNotNull);
    expect(capturedDelta!.color.brightness, closeTo(40, 0.001));
  });

  testWidgets('baked filter shows baked lut as selected', (tester) async {
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      bakedPostProcess:
          const PostProcess(color: PostProcessColor(), lut: 'fuji'),
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('滤镜'));
    await tester.pumpAndSettle();

    Text labelText(String label) => tester
        .widgetList<Text>(find.text(label))
        .firstWhere((t) => t.style?.fontSize == 10);

    expect(labelText('富士').style?.fontWeight, FontWeight.w600);
    expect(labelText('原图').style?.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('read-only: tool tap calls onReadOnlyTap, not onToolChanged',
      (tester) async {
    var readOnlyTapped = 0;
    var toolChanged = 0;
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      isReadOnly: true,
      onReadOnlyTap: () => readOnlyTapped++,
      onToolChanged: (_) => toolChanged++,
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('色彩'));
    await tester.pumpAndSettle();
    expect(readOnlyTapped, 1);
    expect(toolChanged, 0);
    expect(find.text('亮度'), findsNothing);
  });

  testWidgets('reset tool calls onReset', (tester) async {
    var reset = 0;
    await tester.pumpWidget(wrapWidget(
      activeTool: null,
      onReset: () => reset++,
      onToolChanged: (_) {},
      onPostProcessChanged: (_) {},
      onTransformChanged: (_) {},
    ));
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(reset, 1);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/capture/widgets/preview_edit_toolbar_test.dart`
Expected: FAIL — `preview_edit_toolbar.dart` 不存在

- [ ] **Step 3: 实现 PreviewEditToolbar**

新建 `lib/features/capture/widgets/preview_edit_toolbar.dart`：

```dart
import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/post_process_delta.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_color_tab.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_detail_tab.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_panel.dart';

/// 拍摄预览页编辑工具（与 gallery_edit_page._EditTool 对齐的公开版本）。
enum PreviewEditTool { color, detail, filter, crop }

/// 底部图标工具条（色彩/细节/滤镜/裁剪/重置）+ 点选滑出的参数面板。
///
/// - 面板内部复用 PostProcessColorTab / PostProcessDetailTab / FilterTab / CropTab
/// - 全量↔增量换算与旧 PreviewEditPanel 一致：fullOf(baked, local) 显示、
///   deltaOf(baked, full, current: local) 回传
/// - 面板高度与后期修图页一致：色彩/细节 160、滤镜 264、裁剪 328
class PreviewEditToolbar extends StatelessWidget {
  const PreviewEditToolbar({
    Key? key,
    required this.activeTool,
    required this.postProcess,
    this.bakedPostProcess,
    required this.transform,
    required this.onToolChanged,
    required this.onPostProcessChanged,
    required this.onTransformChanged,
    required this.onReset,
    this.previewImagePath,
    this.isReadOnly = false,
    this.onReadOnlyTap,
    required this.tokens,
  }) : super(key: key);

  /// 当前激活工具；null = 面板收起
  final PreviewEditTool? activeTool;

  /// 本地增量参数（页面持有）
  final PostProcess postProcess;

  /// 烘焙基线（null 视为全零基线）
  final PostProcess? bakedPostProcess;

  final TransformParams transform;

  /// 工具切换；null 表示收起面板
  final ValueChanged<PreviewEditTool?> onToolChanged;
  final ValueChanged<PostProcess> onPostProcessChanged;
  final ValueChanged<TransformParams> onTransformChanged;
  final VoidCallback onReset;

  /// 滤镜缩略图路径（null = 降级文字 Chip）
  final String? previewImagePath;

  /// 只读模式：点工具/重置 → onReadOnlyTap，不展开面板
  final bool isReadOnly;
  final VoidCallback? onReadOnlyTap;

  final ThemeTokens tokens;

  PostProcess get _baked =>
      bakedPostProcess ?? const PostProcess(color: PostProcessColor());

  PostProcess get _fullForEdit => fullOf(_baked, postProcess);

  void _updatePostFromFull(PostProcess newFull) =>
      onPostProcessChanged(deltaOf(_baked, newFull, current: postProcess));

  void _toggle(PreviewEditTool tool) {
    if (isReadOnly) {
      onReadOnlyTap?.call();
      return;
    }
    onToolChanged(activeTool == tool ? null : tool);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ToolItem(
                icon: Icons.tune,
                label: '色彩',
                selected: activeTool == PreviewEditTool.color,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.color),
              ),
              _ToolItem(
                icon: Icons.auto_fix_high_outlined,
                label: '细节',
                selected: activeTool == PreviewEditTool.detail,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.detail),
              ),
              _ToolItem(
                icon: Icons.filter_vintage_outlined,
                label: '滤镜',
                selected: activeTool == PreviewEditTool.filter,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.filter),
              ),
              _ToolItem(
                icon: Icons.crop_rotate,
                label: '裁剪',
                selected: activeTool == PreviewEditTool.crop,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.crop),
              ),
              _ToolItem(
                icon: Icons.refresh,
                label: '重置',
                selected: false,
                tokens: tokens,
                onTap: () {
                  if (isReadOnly) {
                    onReadOnlyTap?.call();
                    return;
                  }
                  onReset();
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
        ),
        // 参数面板：点选工具后滑出，再次点击收起
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: activeTool == null
              ? const SizedBox.shrink()
              : _buildPanel(),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final Widget panel;
    final double height;
    switch (activeTool!) {
      case PreviewEditTool.color:
        panel = PostProcessColorTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
        height = 160;
        break;
      case PreviewEditTool.detail:
        panel = PostProcessDetailTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
        height = 160;
        break;
      case PreviewEditTool.filter:
        panel = FilterTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
          previewImagePath: previewImagePath,
          tokens: tokens,
        );
        height = 264;
        break;
      case PreviewEditTool.crop:
        panel = CropTab(
          transform: transform,
          onChanged: onTransformChanged,
          postProcess: postProcess,
          onPostProcessChanged: onPostProcessChanged,
          tokens: tokens,
          previewImagePath: previewImagePath,
        );
        height = 328;
        break;
    }
    return SizedBox(height: height, child: panel);
  }
}

/// 单个工具项：图标 + 文字，选中时品牌色高亮 + 圆角底（与 gallery _ToolItem 同款）
class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.brand : tokens.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/capture/widgets/preview_edit_toolbar_test.dart`
Expected: PASS（10 个用例）

- [ ] **Step 5: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/preview_edit_toolbar.dart lumira_app_flutter/test/features/capture/widgets/preview_edit_toolbar_test.dart
git commit -m "feat: 新增 PreviewEditToolbar 图标工具条+滑出参数面板"
```

---

### Task 4: capture_preview_page 布局重构（删抽屉 + 顶栏改造 + 对比按钮 + 分享 Sheet）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart`
- Rewrite: `lumira_app_flutter/test/features/capture/capture_preview_page_test.dart`（整文件替换）
- Rewrite: `lumira_app_flutter/test/features/capture/capture_preview_scene_test.dart`（整文件替换）
- Modify: `lumira_app_flutter/test/features/capture/capture_preview_share_test.dart`（加一条断言）

**Interfaces:**
- Consumes: Task 1 `ComparePhotoButton`、Task 2 `PreviewTagPillRow`、Task 3 `PreviewEditToolbar`/`PreviewEditTool`
- 保留不变的页面 API：`CapturePreviewPage({this.photoUrl, this.photoId, this.aspectRatio, this.challengeId, this.pendingFinal})`；`_updateLocalPostProcess`/`_updateLocalTransform`/`_onSave`/`_onSaveToAlbum`/`_onDelete`/`_onShare`/`_onShareSystem`/`_onCompareCard`/`_onExifPoster`/`_back`/`_selectMood`/`_selectScene`/`_guardPendingFinal`/`_showReadOnlyToast`/`_initLocalCropRatio`

- [ ] **Step 1: 重写页面测试（先失败）**

整文件替换 `test/features/capture/capture_preview_page_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';
import 'package:lumira_app_flutter/features/capture/widgets/compare_photo_button.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// 拍摄预览页改版后测试：底部工具条 + 滑出面板 + 右上角对比按钮 + pill 行。
void main() {
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
  }) {
    final goRouter = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
        ),
        GoRoute(
          path: RouteNames.capturePreview,
          name: 'capturePreview',
          builder: (context, state) {
            final photoUrl = state.queryParams['photoUrl'];
            return CapturePreviewPage(photoUrl: photoUrl);
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        CaptureState.aspectRatioProvider.overrideWith((ref) => '1:1'),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> openPreview(WidgetTester tester,
      {UIStyle style = UIStyle.neumorphic}) async {
    await tester.pumpWidget(
        wrap(themeKey: ThemeKey.warmWhite, uiStyle: style));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('HOME_PAGE')))
        .push(RouteNames.capturePreview);
    await tester.pumpAndSettle();
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  // ============================================================
  // 分类 1: 基本渲染（无抽屉，工具条/pill 行直接可见）
  // ============================================================
  group('CapturePreviewPage — basic rendering', () {
    testWidgets('renders nav with title and new action icons', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      // 顶栏新增：删除、保存到系统相册；保留：分享
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    });

    testWidgets('renders 5 tool bar items', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.text('色彩'), findsOneWidget);
      expect(find.text('细节'), findsOneWidget);
      expect(find.text('滤镜'), findsOneWidget);
      expect(find.text('裁剪'), findsOneWidget);
      expect(find.text('重置'), findsOneWidget);
    });

    testWidgets('renders mood and scene pills immediately (no drawer)',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      // 心情 pill
      expect(find.text('开心'), findsOneWidget);
      expect(find.text('甜酷'), findsOneWidget);
      // 场景 pill + 不标记
      expect(find.text('不标记'), findsOneWidget);
      expect(find.text('咖啡馆'), findsOneWidget);
    });

    testWidgets('renders compare button on photo (top-right)', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.byType(ComparePhotoButton), findsOneWidget);
    });

    testWidgets('no floating button group / no drawer handle', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      // 旧悬浮组「编辑」按钮与抽屉拖拽条已删除
      expect(find.text('编辑'), findsNothing);
      expect(find.byKey(const ValueKey('sheet_handle')), findsNothing);
      expect(find.text('保存到相册'), findsNothing); // 顶栏用图标替代
    });
  });

  // ============================================================
  // 分类 2: 交互
  // ============================================================
  group('CapturePreviewPage — interactions', () {
    testWidgets('tapping mood pill activates it, tapping again deactivates',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      BoxDecoration pillDecorationOf(String name) {
        final container = tester.widget<Container>(
          find.ancestor(of: find.text(name), matching: find.byType(Container))
              .first,
        );
        return container.decoration as BoxDecoration;
      }

      await tester.tap(find.text('甜酷'));
      await tester.pumpAndSettle();
      expect(pillDecorationOf('甜酷').gradient, isA<LinearGradient>());

      // 再点一次 = 取消（等同旧「跳过」）
      await tester.tap(find.text('甜酷'));
      await tester.pumpAndSettle();
      expect(pillDecorationOf('甜酷').gradient, isNull);
    });

    testWidgets('tapping scene pill activates it', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      BoxDecoration pillDecorationOf(String name) {
        final container = tester.widget<Container>(
          find.ancestor(of: find.text(name), matching: find.byType(Container))
              .first,
        );
        return container.decoration as BoxDecoration;
      }

      await tester.tap(find.text('咖啡馆'));
      await tester.pumpAndSettle();
      expect(pillDecorationOf('咖啡馆').gradient, isA<LinearGradient>());
      expect(pillDecorationOf('不标记').gradient, isNull);
    });

    testWidgets('compare button toggles ColorFilter on/off', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      // 初始：非透明滤镜（应用后期参数）
      final colorFilteredBefore =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered).first);
      expect(colorFilteredBefore.colorFilter,
          isNot(const ColorFilter.mode(Colors.transparent, BlendMode.dst)));

      // 点击对比按钮 → 显示修改前（透明滤镜 = 无后期）
      await tester.tap(find.byType(ComparePhotoButton));
      await tester.pumpAndSettle();
      final colorFilteredDuring =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered).first);
      expect(colorFilteredDuring.colorFilter,
          const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          reason: '对比模式应显示修改前（无滤镜）');
      // 对比状态徽标短暂显示
      expect(find.text('查看修改前'), findsOneWidget);

      // 再点一次 → 恢复修改后
      await tester.tap(find.byType(ComparePhotoButton));
      await tester.pumpAndSettle();
      final colorFilteredAfter =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered).first);
      expect(colorFilteredAfter.colorFilter,
          isNot(const ColorFilter.mode(Colors.transparent, BlendMode.dst)));
    });

    testWidgets('tool tap opens panel, photo tap closes it', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      await tester.tap(find.text('色彩'));
      await tester.pumpAndSettle();
      expect(find.text('亮度'), findsOneWidget);

      // 点击照片区（PhotoView 中下部，避开顶栏/对比按钮/dock）
      final photoRect = tester.getRect(find.byType(PhotoView).first);
      await tester.tapAt(Offset(photoRect.center.dx, photoRect.center.dy + 200));
      await tester.pumpAndSettle();
      expect(find.text('亮度'), findsNothing);
    });

    testWidgets('photo tap toggles pure mode (hides nav and dock)',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);

      final photoRect = tester.getRect(find.byType(PhotoView).first);
      await tester
          .tapAt(Offset(photoRect.center.dx, photoRect.center.dy + 200));
      await tester.pumpAndSettle();
      // 纯净模式：导航、工具条、pill 行、对比按钮全部隐藏
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsNothing);
      expect(find.text('色彩'), findsNothing);
      expect(find.text('不标记'), findsNothing);
      expect(find.byType(ComparePhotoButton), findsNothing);

      await tester
          .tapAt(Offset(photoRect.center.dx, photoRect.center.dy + 200));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
    });

    testWidgets('share sheet contains 生成对比图 and EXIF 海报',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      await tester.tap(find.byIcon(Icons.ios_share_outlined));
      await tester.pumpAndSettle();
      expect(find.text('分享到系统'), findsOneWidget);
      expect(find.text('生成对比图'), findsOneWidget);
      expect(find.text('生成 EXIF 海报'), findsOneWidget);
      expect(find.text('保存到相册'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: smoke（8 主题 × 4 风格，无需展开抽屉）
  // ============================================================
  group('CapturePreviewPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
      final combinations = <_ThemeStyleCombo>[
        for (final t in ThemeKey.values)
          _ThemeStyleCombo(theme: t, style: UIStyle.neumorphic),
        for (final s in UIStyle.values)
          if (s != UIStyle.neumorphic)
            _ThemeStyleCombo(theme: ThemeKey.warmWhite, style: s),
      ];

      for (final combo in combinations) {
        setLargeViewport(tester);
        await tester.pumpWidget(wrap(
          themeKey: combo.theme,
          uiStyle: combo.style,
        ));
        await tester.pumpAndSettle();
        if (combo.style == UIStyle.female) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        GoRouter.of(tester.element(find.text('HOME_PAGE')))
            .push(RouteNames.capturePreview);
        await tester.pumpAndSettle();
        if (combo.style == UIStyle.female) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('色彩'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('不标记'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

/// 主题 × 风格组合（Dart 2.19 兼容：不用 record 类型）
class _ThemeStyleCombo {
  const _ThemeStyleCombo({required this.theme, required this.style});
  final ThemeKey theme;
  final UIStyle style;
}

/// 占位页（用于测试 push/pop 行为）
class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
```

- [ ] **Step 2: 运行页面测试确认失败**

Run: `flutter test test/features/capture/capture_preview_page_test.dart`
Expected: FAIL（多处：找不到 ComparePhotoButton、`编辑` 文本仍在、sheet_handle 仍存在等）

- [ ] **Step 3: 重构 capture_preview_page.dart — 状态与方法层**

对 `lib/features/capture/pages/capture_preview_page.dart` 依次修改：

**3a. 新增 import**（顶部 import 区）：
```dart
import 'dart:async';
import 'package:lumira_app_flutter/features/capture/widgets/compare_photo_button.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_toolbar.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_tag_pill_row.dart';
```
并删除 `import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_panel.dart';`（页面不再直接用 PreviewEditPanel；FilterTab/CropTab 移入 toolbar 内部使用）。

**3b. 删除抽屉状态，新增工具状态**：
- 删除 L42 `const double _kClosedHeight = 120;`
- 删除状态字段：`_sheetHeightNotifier`（L153）、`_SheetMode _sheetMode`（L165）、`_dragStartHeight`/`_dragStartGlobalY`（L150 附近，与拖拽相关两个字段）
- 删除 `_SheetMode` 枚举定义（`_sheetMode` 声明附近）
- 删除静态方法 `_quarterHeight`/`_threeQuarterHeight`（L206-211）
- 新增状态字段（放在 `_isCropMode` 声明附近）：
```dart
  /// 当前激活编辑工具；null = 面板收起（裁剪模式 = activeTool == crop）
  PreviewEditTool? _activeTool;

  /// 对比按钮开启后的短暂状态徽标
  bool _showCompareBadge = false;
  Timer? _compareBadgeTimer;
```

**3c. initState**：删除 L235 `_sheetHeightNotifier = ValueNotifier<double>(_kClosedHeight);`

**3d. dispose**：删除 `_sheetHeightNotifier.dispose();`，新增：
```dart
    _compareBadgeTimer?.cancel();
```

**3e. 删除拖拽/吸附方法**：`_onSheetDragStart`/`_onSheetDragUpdate`/`_onSheetDragEnd`/`_snapToNearest`（L524-571 整段）。

**3f. 改造 `_onCompareToggle`**（L584，加徽标计时）：
```dart
  /// 右上角对比按钮：在「修改后」与「修改前（烘焙基线）」之间切换；
  /// 开启时短暂显示状态徽标（1s 后淡出），帮助用户理解当前看到的版本。
  void _onCompareToggle() {
    if (!mounted) return;
    setState(() {
      _isComparing = !_isComparing;
      _showCompareBadge = true;
    });
    _compareBadgeTimer?.cancel();
    _compareBadgeTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showCompareBadge = false);
    });
  }
```

**3g. 改造 `_onPhotoTap`**（L592，抽屉判断改为面板判断）：
```dart
  void _onPhotoTap(
    BuildContext context,
    TapUpDetails details,
    PhotoViewControllerValue _,
  ) {
    if (!mounted) return;
    setState(() {
      if (_activeTool != null) {
        // 面板展开时：点照片先收面板（不进纯净模式）
        _activeTool = null;
        _isCropMode = false;
      } else {
        _uiVisible = !_uiVisible;
      }
    });
  }
```

**3h. 新增工具切换 / 一键重置方法**（放在 `_updateLocalTransform` 之后）：
```dart
  /// 编辑工具切换（null = 收起面板）；进入裁剪工具受先快后真门控。
  void _onToolChanged(PreviewEditTool? next) {
    if (next == PreviewEditTool.crop && _guardPendingFinal()) return;
    setState(() {
      _activeTool = next;
      _isCropMode = next == PreviewEditTool.crop;
    });
  }

  /// 一键重置全部本地编辑：增量归零 + 变换归零 + 裁剪选区清空
  /// （cropRatio 保留照片实际比例基线 = 满幅选框，无操作 = 无裁剪）。
  void _resetAllLocal() {
    if (!mounted) return;
    if (_guardPendingFinal()) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localPostProcess = PostProcess(
        color: const PostProcessColor(),
        cropRatio: _localPostProcess.cropRatio,
      );
      _localTransform = const TransformParams();
      _isEdited = false;
    });
  }
```

**3i. 改造 `_selectMood`**（L914，支持再点取消 = 旧「跳过」语义）：
```dart
  void _selectMood(MoodOption selected) {
    // 再点选中项 = 取消全部（等同旧「跳过」）
    final bool deselect = selected.active;
    setState(() {
      for (var i = 0; i < _moods.length; i++) {
        _moods[i] = _moods[i]
            .copyWith(active: deselect ? false : _moods[i].name == selected.name);
      }
    });
    // 同步更新数据库中的心情标记（与 _selectScene 一致，让相册详情页能读到）
    final photoId = _currentPhotoId ?? widget.photoId;
    if (photoId != null) {
      ref.read(galleryDaoProvider.future).then((dao) async {
        try {
          await dao.updateMood(photoId, _activeMoodName());
          ref.invalidate(galleryDaoProvider);
        } catch (e) {
          debugPrint('[preview] 更新心情失败: $e');
        }
      });
    }
  }
```
删除 `_onSkip` 方法（L701）。

- [ ] **Step 4: 重构 build() 与 UI 层**

**4a. 整体替换 build 方法**（L1333-1650 区间：Stack 布局 → Column 布局；保留场景预选 postFrameCallback 与只读横幅代码）。新 build：

```dart
  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    // 预选当前场景（修复 Issue 8：拍摄后自动选择该场景）
    // 仅在首次构建且用户未手动改过时设置；通过 postFrameCallback 避免在 build 中调用 setState
    final activeSceneId = ref.watch(CaptureState.activeScenePresetIdProvider);
    if (_selectedSceneId == null && activeSceneId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSceneId == null) {
          setState(() => _selectedSceneId = activeSceneId);
        }
      });
    }

    return Scaffold(
      // 照片全屏显示，背景纯黑
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 1. 照片区：占满剩余空间（面板展开时由 Column 自动收缩）
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 照片本体（裁剪模式 → PhotoCropLayer；否则 PhotoView/历史滑动）
                _buildPhotoStage(tokens),
                // 顶部导航 + 只读横幅（仅 _uiVisible 时显示）
                if (_uiVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PreviewNav(
                            tokens: tokens,
                            onBack: _back,
                            onShare: _onShare,
                            onSave: _onSave,
                            showSave: _isEdited,
                            onDelete: _onDelete,
                            onSaveToAlbum: _onSaveToAlbum,
                          ),
                          // 只读模式横幅：原图未保留时显示（位于导航栏下方）
                          if (_isReadOnly)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: tokens.dangerSubtle,
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline,
                                      size: 16, color: tokens.danger),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '此照片未保留原图，仅可查看，无法编辑',
                                      style: TextStyle(
                                          fontSize: 12, color: tokens.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                // 右上角对比按钮（导航栏下方，叠照片浮层取向：半透明+细边无阴影）
                if (_uiVisible)
                  Positioned(
                    top: 64,
                    right: 12,
                    child: ComparePhotoButton(
                      comparing: _isComparing,
                      tokens: tokens,
                      onTap: _onCompareToggle,
                      overlayOnImage: true,
                    ),
                  ),
                // 对比状态徽标（开启后 1s 内显示，说明当前看到的版本）
                if (_uiVisible && _showCompareBadge)
                  Positioned(
                    top: 112,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(1000),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Text(
                        _isComparing ? '查看修改前' : '已回到修改后',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 2. 底部编辑 dock：心情/场景 pill 行 + 工具条 + 滑出面板
          if (_uiVisible) _buildEditDock(tokens),
        ],
      ),
    );
  }

  /// 照片区：裁剪模式 → PhotoCropLayer；否则单张 PhotoView / 历史滑动 Gallery。
  /// （内容与旧版一致，仅去掉底部 sheet inset 包装）
  Widget _buildPhotoStage(ThemeTokens tokens) {
    return _isCropMode
        // 裁剪模式：把裁剪框直接叠加在照片本体上（iPhone 风格）
        ? PhotoCropLayer(
            photoUrl: _photoUrl,
            initialCrop: _localPostProcess.customCropRect != null
                ? Rect.fromLTWH(
                    _localPostProcess.customCropRect!.x,
                    _localPostProcess.customCropRect!.y,
                    _localPostProcess.customCropRect!.w,
                    _localPostProcess.customCropRect!.h,
                  )
                : null,
            aspectRatio: _parseCropAspectRatio(
                _localPostProcess.cropRatio,
                MediaQuery.of(context).size.aspectRatio),
            transform: _localTransform,
            onChanged: (rect) => setState(() {
              _localPostProcess = _localPostProcess.copyWith(
                customCropRect: CropRect(
                  x: rect.left,
                  y: rect.top,
                  w: rect.width,
                  h: rect.height,
                ),
              );
              _isEdited = true;
            }),
            tokens: tokens,
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final outer = constraints.biggest;
              final childSize = Size(outer.width * 2, outer.height * 2);

              // 无历史照片：单张预览
              if (_historyPhotos.isEmpty) {
                return PhotoView.customChild(
                  child: _buildPhotoContent(
                    _photoUrl,
                    _isComparing,
                    _localPostProcess,
                    _localTransform,
                  ),
                  childSize: childSize,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: 6.0,
                  scaleStateCycle: _previewScaleCycle,
                  onTapUp: _onPhotoTap,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.black),
                );
              }

              // 有历史照片：PhotoViewGallery 边界感知横向切换
              return PhotoViewGallery.builder(
                itemCount: _historyPhotos.length,
                pageController: _pageController,
                onPageChanged: _onPageChanged,
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.black),
                builder: (context, index) {
                  final record = _historyPhotos[index];
                  final url = record.filePath ?? record.dataUrl ?? '';
                  final bool isCurrent = index == _currentIndex;
                  return PhotoViewGalleryPageOptions.customChild(
                    child: isCurrent
                        ? _buildPhotoContent(
                            _photoUrl,
                            _isComparing,
                            _localPostProcess,
                            _localTransform,
                          )
                        : _buildPhotoContent(
                            url,
                            false,
                            const PostProcess(color: PostProcessColor()),
                            record.transform ?? const TransformParams(),
                          ),
                    childSize: childSize,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: 6.0,
                    scaleStateCycle: _previewScaleCycle,
                    onTapUp: _onPhotoTap,
                  );
                },
              );
            },
          );
  }

  /// 底部编辑 dock：单卡片承载 pill 行 + 工具条 + 滑出面板
  Widget _buildEditDock(ThemeTokens tokens) {
    // 滤镜缩略图：仅本地文件路径可用（网络图/空路径 → null 降级文字 Chip）
    final bool isNetwork = _photoUrl.startsWith('http');
    final String? previewImagePath =
        (_photoUrl.isNotEmpty && !isNetwork) ? _photoUrl : null;
    return LumiraSurface(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      radius: 20,
      clip: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PreviewTagPillRow(
            moods: _moods,
            selectedSceneId: _selectedSceneId,
            onSelectMood: _selectMood,
            onSelectScene: _selectScene,
            tokens: tokens,
          ),
          Container(width: double.infinity, height: 1, color: tokens.divider),
          PreviewEditToolbar(
            activeTool: _activeTool,
            postProcess: _localPostProcess,
            bakedPostProcess: _bakedPostProcess,
            transform: _localTransform,
            onToolChanged: _onToolChanged,
            onPostProcessChanged: _updateLocalPostProcess,
            onTransformChanged: _updateLocalTransform,
            onReset: _resetAllLocal,
            previewImagePath: previewImagePath,
            isReadOnly: _isReadOnly,
            onReadOnlyTap: _showReadOnlyToast,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
```

注意：`LumiraSurface` 的 import 若页面尚无则补（路径以实际位置为准，用 `rg -l "class LumiraSurface" lib` 确认）。

**4b. 改造 `_PreviewNav`**（L1685，新增删除/保存到相册图标，顺序：返回 | 标题 | 删除 | 保存到相册 | 分享 | 保存 pill）：

构造与字段改为：
```dart
class _PreviewNav extends StatelessWidget {
  const _PreviewNav({
    required this.tokens,
    required this.onBack,
    required this.onShare,
    this.onSave,
    this.showSave = false,
    this.onDelete,
    this.onSaveToAlbum,
  });

  final ThemeTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onShare;

  /// 编辑态右上角保存按钮：仅当 showSave 为 true 时显示
  final VoidCallback? onSave;
  final bool showSave;

  /// 删除当前照片（原底部悬浮组操作，收进顶栏）
  final VoidCallback? onDelete;

  /// 保存到系统相册（原底部悬浮组操作，收进顶栏）
  final VoidCallback? onSaveToAlbum;
```

`actions:` 列表改为（保存 pill 保留原样式在最前，其后依次为删除、保存到相册、分享）：
```dart
        actions: [
          if (showSave && onSave != null)
            // …（原保存 pill GestureDetector 代码原样保留）…
          if (onDelete != null)
            _NavIcon(icon: Icons.delete_outline, onTap: onDelete!),
          if (onSaveToAlbum != null)
            _NavIcon(icon: Icons.save_alt, onTap: onSaveToAlbum!),
          GestureDetector(
            onTap: onShare,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.ios_share_outlined,
                size: 22,
                color: tokens.textInverse,
              ),
            ),
          ),
        ],
```
并在 `_NavBackButton` 类旁新增（图标色与返回按钮统一用 `tokens.textInverse`）：
```dart
/// 顶栏动作图标（叠照片浮层）
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: tokens.textInverse),
      ),
    );
  }
}
```
（`_NavIcon` 需接收 `tokens` 或改为 `ConsumerWidget`；实现时给 `_NavIcon` 增加 `required this.tokens` 字段并在使用处传入 `tokens`，保持与其他顶栏元素一致。）

**4c. 分享 Sheet 加「生成对比图」**（`_onShare`，L792）：在「分享到系统」与「生成 EXIF 海报」之间插入：
```dart
          _ShareOption(
            icon: Icons.compare_outlined,
            text: '生成对比图',
            tokens: tokens,
            onTap: () {
              Navigator.of(ctx).pop();
              _onCompareCard();
            },
          ),
```

**4d. 删除全部抽屉/悬浮组相关私有 widget 与残余引用**（文件底部私有 widget 区）：
- `_BottomSheet`（含 `_SheetHandle` 若为独立类）
- `_QuarterPeek`
- `_MoodSection`、`_SceneSection`、`_SectionTitleRow`、`_SectionTitle`
- `_ActionRow`、`_ActionButton`
- `_CollapsedActionButton`（含 State 类）
- `_FloatingActionButton`（含 State 类）
- `_Pill`（样式已移入 PreviewTagPillRow）
- `_BackgroundDecoration`（L1657，死代码，已确认无实例化）
- `_PhotoFrame`（L1801，死代码）与 `_PhotoEmptyState`（L1885，仅 _PhotoFrame 使用）
- 保留：`_PreviewNav`（已改造）、`_NavBackButton`、`_ShareOption`

**4e. 清理残余引用**：`rg -n "_sheetMode|_kClosedHeight|_sheetHeightNotifier|_onSheetDrag|_snapToNearest|PreviewEditPanel|_BottomSheet|_QuarterPeek|_MoodSection|_SceneSection|_ActionRow|_CollapsedActionButton|_FloatingActionButton|_PhotoFrame|_BackgroundDecoration" lib/features/capture/pages/capture_preview_page.dart` 应输出为空（0 匹配）。保存流程（`_onSave`）内若有 `_sheetMode = _SheetMode.hidden` 类复位语句，替换为 `_activeTool = null; _isCropMode = false;`。

**4f. 清理 import**：`flutter analyze` 后删除报告的未使用 import（预计：`preview_edit_panel.dart`、SmoothImageLayer/skin_smooth_shader 相关、`LumiraTabBar` 若有）。

- [ ] **Step 5: 运行页面测试**

Run: `flutter test test/features/capture/capture_preview_page_test.dart`
Expected: PASS（全部用例）。若 PhotoView 点击 tap 测试 flaky（网络图加载中手势区域未挂载），先 `await tester.pump(const Duration(seconds: 2));` 等图片错误分支落地再点击。

- [ ] **Step 6: 重写场景预选测试**

整文件替换 `test/features/capture/capture_preview_scene_test.dart`（去掉 expandSheetToThreeQuarter 依赖，pill 行直接可见）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Widget wrap({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/preview',
          routes: [
            GoRoute(
              path: '/preview',
              builder: (_, __) => const CapturePreviewPage(
                photoUrl: '',
                photoId: 'p1',
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration pillDecorationOf(WidgetTester tester, String name) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(name), matching: find.byType(Container))
          .first,
    );
    return container.decoration as BoxDecoration;
  }

  testWidgets('preview page pre-selects active scene from capture state',
      (tester) async {
    setLargeViewport(tester);
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      CaptureState.activeScenePresetIdProvider.overrideWith((ref) => 'cafe'),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container: container));
    await tester.pumpAndSettle();

    expect(container.read(CaptureState.activeScenePresetIdProvider), 'cafe');
    // pill 行直接可见（无需展开抽屉）
    expect(find.text('咖啡馆'), findsOneWidget);
    expect(pillDecorationOf(tester, '咖啡馆').gradient, isA<LinearGradient>(),
        reason: 'active 场景 pill 应为渐变 active 态');
    expect(pillDecorationOf(tester, '街头').gradient, isNull,
        reason: 'inactive 场景 pill 应为非渐变');
  });

  testWidgets(
      'preview page defaults to 不标记 when no active scene is set',
      (tester) async {
    setLargeViewport(tester);
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container: container));
    await tester.pumpAndSettle();

    expect(find.text('不标记'), findsOneWidget);
    expect(pillDecorationOf(tester, '不标记').gradient, isA<LinearGradient>());
    expect(pillDecorationOf(tester, '咖啡馆').gradient, isNull);
  });
}
```

- [ ] **Step 7: 更新分享测试**

`test/features/capture/capture_preview_share_test.dart`：在现有断言（`expect(find.text('生成 EXIF 海报'), findsOneWidget);`）之后新增一行：
```dart
    expect(find.text('生成对比图'), findsOneWidget);
```

- [ ] **Step 8: 运行全部相关测试**

Run: `flutter analyze`
Expected: 无新增告警
Run: `flutter test test/features/capture`
Expected: PASS（注意 `preview_edit_panel_test.dart` 此时仍测试旧 PreviewEditPanel 类，页面已不使用——该测试文件在 Task 5 删除；若此步因页面改动导致该文件编译失败，将删除动作提前到本步：删除 `test/features/capture/widgets/preview_edit_panel_test.dart` 并在 Task 5 仅删类）

- [ ] **Step 9: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart lumira_app_flutter/test/features/capture/capture_preview_page_test.dart lumira_app_flutter/test/features/capture/capture_preview_scene_test.dart lumira_app_flutter/test/features/capture/capture_preview_share_test.dart
git commit -m "feat: 拍摄预览页编辑区改版（工具条+滑出面板+右上角对比按钮）" -m "删除三档抽屉与悬浮按钮组，心情/场景改紧凑 pill 行，删除/保存到相册收进顶栏，生成对比图收进分享 Sheet"
```

---

### Task 5: 删除旧 PreviewEditPanel 类

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/preview_edit_panel.dart`
- Delete: `lumira_app_flutter/test/features/capture/widgets/preview_edit_panel_test.dart`（若 Task 4 Step 8 已删则跳过）

**Interfaces:**
- 保留：`FilterTab`、`CropTab`、`FilterThumbnail`、`editLutLabels`、`unifiedFilters`（gallery_edit_page.dart 与 PreviewEditToolbar 共用）
- 删除：`PreviewEditPanel` 类（已确认仅 capture_preview_page 使用，Task 4 后无引用）

- [ ] **Step 1: 确认无引用**

Run: `rg -n "PreviewEditPanel" lib test`
Expected: 仅 `preview_edit_panel.dart` 自身定义 + 注释提及（post_process_slider_row/color_tab/detail_tab 的文档注释），无代码引用

- [ ] **Step 2: 删除 PreviewEditPanel 类与无用依赖**

删除 `preview_edit_panel.dart` 中 `PreviewEditPanel` 整个类（含 `_EditPanelHeader` 若仅其使用）；删除随之未用的 import（`TabController`/`LumiraTabBar`/`post_process_delta.dart` 等，以 `flutter analyze` 报告为准）。将其他文件文档注释中的 `PreviewEditPanel` 字样更新为 `PreviewEditToolbar`（post_process_slider_row.dart L8、post_process_color_tab.dart L9、post_process_detail_tab.dart L9）。

删除测试文件（若仍存在）：
```powershell
git rm lumira_app_flutter/test/features/capture/widgets/preview_edit_panel_test.dart
```

- [ ] **Step 3: 验证**

Run: `flutter analyze` → 无新增告警
Run: `flutter test test/features/capture test/features/gallery`
Expected: PASS

- [ ] **Step 4: Commit**

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/preview_edit_panel.dart lumira_app_flutter/lib/features/capture/widgets/post_process_slider_row.dart lumira_app_flutter/lib/features/capture/widgets/post_process_color_tab.dart lumira_app_flutter/lib/features/capture/widgets/post_process_detail_tab.dart
git commit -m "refactor: 删除旧 PreviewEditPanel（由 PreviewEditToolbar 取代）"
```

---

### Task 6: 全量验证与收尾

**Files:**
- Commit: `docs/specs/2026-09-07-capture-preview-edit-redesign-design.md`
- Commit: `docs/superpowers/plans/2026-09-07-capture-preview-edit-redesign.md`

- [ ] **Step 1: 全量静态检查**

Run: `flutter analyze`
Expected: `No issues found!`（或不多于改版前的既有告警数）

- [ ] **Step 2: 全量相关测试**

Run: `flutter test test/features/capture test/features/gallery test/shared`
Expected: PASS

- [ ] **Step 3: 手动验收清单（真机/模拟器，用户执行）**

1. 拍摄 → 预览页：底部见 pill 行 + 工具条，无抽屉、无悬浮组
2. 点色彩/细节/滤镜/裁剪：面板滑出、实时预览流畅；滤镜显示真实照片缩略图
3. 编辑中途点右上角对比按钮：照片切回修改前，再点恢复修改后
4. 重置一键还原全部本地编辑（增量/变换/裁剪选区）
5. 编辑态顶栏出现保存 pill；保存（替换/另存）结果与改版前一致
6. 顶栏删除、保存到系统相册；分享 Sheet 含生成对比图/EXIF 海报
7. 心情/场景标记写库正常；历史滑动切换时状态恢复
8. 只读（原图未保留）与先快后真门控正常拦截
9. 设置里切换 4 风格 × 8 主题抽检无样式混搭

- [ ] **Step 4: 提交文档**

```powershell
git add docs/specs/2026-09-07-capture-preview-edit-redesign-design.md docs/superpowers/plans/2026-09-07-capture-preview-edit-redesign.md
git commit -m "docs: 拍摄预览页编辑改版设计文档与实现计划"
```

（纯文档提交，是否 push 由用户决定——项目规则仅后端/后台改动强制双远程推送。）

---

## Self-Review 记录

- **Spec 覆盖**：§3 布局（Task 4 build）、§4.1 顶栏（Task 4b）、§4.2 对比按钮（Task 1+4a）、§4.3 pill 行（Task 2+4a）、§4.4 工具条/面板（Task 3）、§4.5 分享 Sheet（Task 4c）、§4.6 保持不变（Task 4 保留清单）、§5 代码结构（Task 1-5）、§8 验收标准（各测试 + Task 6 清单）——全覆盖
- **占位符扫描**：无 TBD/TODO；所有代码块完整
- **类型一致性**：`PreviewEditTool` 枚举、`onToolChanged(null)` 收起语义、`deltaOf(baked, full, current: postProcess)` 与 Task 3 测试一致；`ComparePhotoButton.overlayOnImage` 在 Task 1 定义、Task 4 使用
- **已知风险**：PhotoView 网络图加载中点击测试可能 flaky（Task 4 Step 5 已给 fallback）；`MoodOption` 构造签名需现场核对（Task 2 Step 1 已注）
