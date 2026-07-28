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
}
