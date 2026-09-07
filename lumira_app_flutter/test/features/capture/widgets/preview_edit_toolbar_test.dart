import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_toolbar.dart';

// 相对 plan/brief 逐字迁移版的必要适配（断言意图不变，详见 task-3-report.md）：
// 1. PreviewEditToolbar 为受控组件（activeTool 由页面持有），空回调无法驱动面板展开，
//    故用 _Harness 把 onToolChanged 回灌为新的 activeTool（旧 PreviewEditPanel 自持
//    TabController，无此需求）。
// 2. CropTab 是 ConsumerWidget（watch uiStyleProvider），需 ProviderScope（与旧
//    preview_edit_panel_test.dart 一致）。
// 3. 现 AdjustPanel 为「调节条 chip + 单滑块」结构：选中项文字出现两次（chip + 滑块
//    标签），'亮度' 断言用 findsWidgets；滑块数值文案带正号（'+20'）。
// 4. CropTab 现行文案为 逆时针/顺时针/水平/垂直（旧测试断言的 '旋转'/'翻转' 在 HEAD
//    已失配，preview_edit_panel_test.dart 存在同名预存失败）。
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
    return _Harness(
      initialTool: activeTool,
      postProcess: postProcess,
      bakedPostProcess: bakedPostProcess,
      transform: transform,
      onToolChanged: onToolChanged,
      onPostProcessChanged: onPostProcessChanged,
      onTransformChanged: onTransformChanged,
      onReset: onReset,
      onReadOnlyTap: onReadOnlyTap,
      isReadOnly: isReadOnly,
      previewImagePath: previewImagePath,
      tokens: tokens,
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
    // '亮度' 出现于调节条 chip 与滑块标签两处
    expect(find.text('亮度'), findsWidgets);
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
    expect(find.text('亮度'), findsWidgets);
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
    // CropTab 现行文案：顺时针（旋转）、水平（翻转）、拉直
    expect(find.text('顺时针'), findsOneWidget);
    expect(find.text('水平'), findsOneWidget);
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
    // 面板显示全量 20（baked 基线），而非增量 0；滑块数值文案带正号
    expect(find.text('+20'), findsOneWidget);
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

    // 亮度滑块轨道 = 面板内唯一带 onPanStart 的 GestureDetector
    // （当前 _EditSlider 结构中轨道 GestureDetector 并非 '亮度' 文本的祖先）
    final trackFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onPanStart != null,
    );
    expect(trackFinder, findsOneWidget);
    final trackWidth = tester.getSize(trackFinder).width;
    const min = -100.0;
    const max = 100.0;
    const newFull = 60.0; // 拖到亮度全量 60
    const t = (newFull - min) / (max - min);
    final localDx = trackWidth * t;

    final detector = tester.widget<GestureDetector>(trackFinder);
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

/// 受控组件测试壳：把 onToolChanged 回灌为 activeTool 并重建，
/// 模拟页面持有 activeTool 的真实用法（ProviderScope 供 CropTab 使用）。
class _Harness extends StatefulWidget {
  const _Harness({
    this.initialTool,
    required this.postProcess,
    this.bakedPostProcess,
    required this.transform,
    required this.onToolChanged,
    required this.onPostProcessChanged,
    required this.onTransformChanged,
    this.onReset,
    this.onReadOnlyTap,
    this.isReadOnly = false,
    this.previewImagePath,
    required this.tokens,
  });

  final PreviewEditTool? initialTool;
  final PostProcess postProcess;
  final PostProcess? bakedPostProcess;
  final TransformParams transform;
  final ValueChanged<PreviewEditTool?> onToolChanged;
  final ValueChanged<PostProcess> onPostProcessChanged;
  final ValueChanged<TransformParams> onTransformChanged;
  final VoidCallback? onReset;
  final VoidCallback? onReadOnlyTap;
  final bool isReadOnly;
  final String? previewImagePath;
  final ThemeTokens tokens;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  PreviewEditTool? _tool;

  @override
  void initState() {
    super.initState();
    _tool = widget.initialTool;
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: PreviewEditToolbar(
            activeTool: _tool,
            postProcess: widget.postProcess,
            bakedPostProcess: widget.bakedPostProcess,
            transform: widget.transform,
            onToolChanged: (t) {
              setState(() => _tool = t);
              widget.onToolChanged(t);
            },
            onPostProcessChanged: widget.onPostProcessChanged,
            onTransformChanged: widget.onTransformChanged,
            onReset: widget.onReset ?? () {},
            isReadOnly: widget.isReadOnly,
            onReadOnlyTap: widget.onReadOnlyTap,
            previewImagePath: widget.previewImagePath,
            tokens: widget.tokens,
          ),
        ),
      ),
    );
  }
}
