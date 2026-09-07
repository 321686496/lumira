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
      moods: const [
        MoodOption(name: '开心', icon: Icons.sentiment_satisfied),
        MoodOption(name: '甜酷', icon: Icons.wb_sunny_outlined),
      ],
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
      moods: const [
        MoodOption(name: '开心', icon: Icons.sentiment_satisfied),
        MoodOption(name: '甜酷', icon: Icons.wb_sunny_outlined),
      ],
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
      moods: const [
        MoodOption(name: '开心', icon: Icons.sentiment_satisfied),
      ],
      selectedSceneId: 'cafe',
      onSelectScene: (id) => got = id,
    ));
    await tester.tap(find.text('不标记'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('active scene pill has gradient decoration', (tester) async {
    await tester.pumpWidget(wrap(
      moods: const [
        MoodOption(name: '开心', icon: Icons.sentiment_satisfied),
      ],
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
