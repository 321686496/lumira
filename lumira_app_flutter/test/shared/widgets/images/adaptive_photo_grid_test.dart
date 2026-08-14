import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/shared/widgets/images/adaptive_photo_grid.dart';

void main() {
  List<String> makeUrls(int n) => List.generate(n, (i) => 'https://example.com/$i.png');

  testWidgets('5 urls renders 3x2 grid with +1 overflow on last cell', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(body: AdaptivePhotoGrid(urls: makeUrls(5))),
    )));
    await tester.pumpAndSettle();
    // 5 张图，最后一格应为 +1 占位
    expect(find.text('+1'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(4));
  });

  testWidgets('7 urls renders 3x3 grid with +1 overflow', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(body: AdaptivePhotoGrid(urls: makeUrls(7))),
    )));
    await tester.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(6));
  });

  testWidgets('9 urls renders 3x3 grid without overflow', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(body: AdaptivePhotoGrid(urls: makeUrls(9))),
    )));
    await tester.pumpAndSettle();
    expect(find.text('+9'), findsNothing);
    expect(find.byType(Image), findsNWidgets(9));
  });

  testWidgets('12 urls renders first 9 with +3 overflow on 9th cell', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(body: AdaptivePhotoGrid(urls: makeUrls(12))),
    )));
    await tester.pumpAndSettle();
    // 第 9 格替换为 +3 占位
    expect(find.text('+3'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(8));
  });

  testWidgets('onTapOverflow callback fires when +N tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(body: AdaptivePhotoGrid(
        urls: makeUrls(12),
        onTapOverflow: () => tapped = true,
      )),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+3'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
