import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/services/poster_generator.dart';

void main() {
  testWidgets('PosterGenerator.showPoster displays sheet with three buttons',
      (tester) async {
    final posterKey = GlobalKey();
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => PosterGenerator.showPoster(
                  context: context,
                  tokens: tokens,
                  title: '测试海报',
                  content: Container(
                    width: 100,
                    height: 100,
                    color: tokens.brand,
                  ),
                  posterKey: posterKey,
                  shareSubject: '测试主题',
                  shareText: '测试文本',
                  fileNamePrefix: 'test_poster',
                ),
                child: const Text('打开海报'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开海报'));
    await tester.pumpAndSettle();

    // 验证底部 Sheet 出现
    expect(find.text('测试海报'), findsOneWidget);
    // 验证三个按钮都出现
    expect(find.text('生成海报'), findsOneWidget);
    expect(find.text('导出海报'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
