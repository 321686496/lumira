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
