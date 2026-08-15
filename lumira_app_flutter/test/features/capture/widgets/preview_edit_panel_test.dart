import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_panel.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('renders 4 tabs: 色彩, 细节, 滤镜, 裁剪旋转', (tester) async {
    PostProcess? capturedPost;
    TransformParams? capturedTransform;

    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        postProcess: const PostProcess(color: PostProcessColor()),
        transform: const TransformParams(),
        onPostProcessChanged: (p) => capturedPost = p,
        onTransformChanged: (t) => capturedTransform = t,
      ),
    ));

    expect(find.text('色彩'), findsOneWidget);
    expect(find.text('细节'), findsOneWidget);
    expect(find.text('滤镜'), findsOneWidget);
    expect(find.text('裁剪旋转'), findsOneWidget);
  });

  testWidgets('color tab shows brightness slider', (tester) async {
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        postProcess: const PostProcess(color: PostProcessColor()),
        transform: const TransformParams(),
        onPostProcessChanged: (_) {},
        onTransformChanged: (_) {},
      ),
    ));

    // Color tab is default
    expect(find.text('亮度'), findsOneWidget);
  });

  testWidgets('detail tab shows smoothStrength slider', (tester) async {
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        postProcess: const PostProcess(color: PostProcessColor()),
        transform: const TransformParams(),
        onPostProcessChanged: (_) {},
        onTransformChanged: (_) {},
      ),
    ));

    await tester.tap(find.text('细节'));
    await tester.pumpAndSettle();
    expect(find.text('磨皮'), findsOneWidget);
  });

  testWidgets('crop tab shows rotation buttons', (tester) async {
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        postProcess: const PostProcess(color: PostProcessColor()),
        transform: const TransformParams(),
        onPostProcessChanged: (_) {},
        onTransformChanged: (_) {},
      ),
    ));

    await tester.tap(find.text('裁剪旋转'));
    await tester.pumpAndSettle();
    expect(find.text('旋转'), findsOneWidget);
    expect(find.text('翻转'), findsOneWidget);
    expect(find.text('拉直'), findsOneWidget);
  });

  testWidgets('tapping rotate button calls onTransformChanged', (tester) async {
    TransformParams? captured;
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        postProcess: const PostProcess(color: PostProcessColor()),
        transform: const TransformParams(),
        onPostProcessChanged: (_) {},
        onTransformChanged: (t) => captured = t,
      ),
    ));

    await tester.tap(find.text('裁剪旋转'));
    await tester.pumpAndSettle();

    // Tap rotate right button
    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.rotation, 90);
  });

  testWidgets('with bakedPostProcess: color sliders show full value', (tester) async {
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        // 增量 postProcess：brightness 归一化为 0（用户未额外调整）
        postProcess: const PostProcess(color: PostProcessColor()),
        // 烘焙基线：brightness=20
        bakedPostProcess: const PostProcess(color: PostProcessColor(brightness: 20)),
        transform: const TransformParams(),
        onPostProcessChanged: (_) {},
        onTransformChanged: (_) {},
      ),
    ));

    // 色彩 Tab 是默认页，亮度行应显示全量 20（而非增量 0）
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('with bakedPostProcess: dragging brightness slider emits delta (increment), not full', (tester) async {
    PostProcess? capturedDelta;
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        // 增量 postProcess：brightness 归一化为 0（用户未额外调整）
        postProcess: const PostProcess(color: PostProcessColor()),
        // 烘焙基线：brightness=20
        bakedPostProcess: const PostProcess(color: PostProcessColor(brightness: 20)),
        transform: const TransformParams(),
        onPostProcessChanged: (p) => capturedDelta = p,
        onTransformChanged: (_) {},
      ),
    ));

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
    const t = (newFull - min) / (max - min);
    final localDx = labelWidth + trackWidth * t;

    // 直接触发滑块 onPanStart，等价于把滑块拖到目标位置
    final detector = tester.widget<GestureDetector>(brightnessRow);
    detector.onPanStart!(DragStartDetails(localPosition: Offset(localDx, 0)));

    expect(capturedDelta, isNotNull);
    // 回调收到的是增量 = newFull - baked = 60 - 20 = 40，而非全量 60
    expect(capturedDelta!.color.brightness, closeTo(40, 0.001));
  });

  testWidgets('with bakedPostProcess filter: FilterTab shows baked lut as selected', (tester) async {
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        // 增量 postProcess：未选滤镜（lut='none'）
        postProcess: const PostProcess(color: PostProcessColor()),
        // 烘焙基线：lut='fuji'
        bakedPostProcess: const PostProcess(color: PostProcessColor(), lut: 'fuji'),
        transform: const TransformParams(),
        onPostProcessChanged: (_) {},
        onTransformChanged: (_) {},
      ),
    ));

    await tester.tap(find.text('滤镜'));
    await tester.pumpAndSettle();

    // 缩略图下方标签字号为 10（区别于无图时容器内 9），通过字体粗细判断选中态
    Text labelText(String label) => tester
        .widgetList<Text>(find.text(label))
        .firstWhere((t) => t.style?.fontSize == 10);

    // 烘焙滤镜 'fuji' 应作为选中态显示（而非本地增量的 'none'）
    expect(labelText('富士').style?.fontWeight, FontWeight.w600);
    expect(labelText('原图').style?.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('null-baked: detail tab reset clears detail fields but preserves color delta', (tester) async {
    PostProcess? capturedPost;
    await tester.pumpWidget(wrapWidget(
      PreviewEditPanel(
        // 无烘焙基线（null）时视为全零基线
        postProcess: const PostProcess(
          color: PostProcessColor(brightness: 20),
          smoothStrength: 10,
          sharpen: 5,
        ),
        transform: const TransformParams(),
        onPostProcessChanged: (p) => capturedPost = p,
        onTransformChanged: (_) {},
      ),
    ));

    await tester.tap(find.text('细节'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    // 重置后：color 增量保留（brightness 仍为 20），细节字段清零
    expect(capturedPost, isNotNull);
    expect(capturedPost!.color.brightness, 20);
    expect(capturedPost!.smoothStrength, 0);
    expect(capturedPost!.sharpen, 0);
  });
}
