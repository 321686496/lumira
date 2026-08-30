import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/services/poster_generator.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

void main() {
  testWidgets('PosterGenerator.showPoster displays sheet with three buttons',
      (tester) async {
    final posterKey = GlobalKey();
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
      ),
    );

    await tester.tap(find.text('打开海报'));
    await tester.pumpAndSettle();

    // 验证底部 Sheet 出现
    expect(find.text('测试海报'), findsOneWidget);
    // 验证两个操作按钮都出现
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });

  testWidgets(
      'showPoster wraps content in RepaintBoundary when plainContentKey provided',
      (tester) async {
    final posterKey = GlobalKey();
    final plainContentKey = GlobalKey();
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => PosterGenerator.showPoster(
                    context: context,
                    tokens: tokens,
                    title: '测试卡片',
                    content: Container(
                      width: 300,
                      height: 400,
                      color: tokens.brand,
                    ),
                    posterKey: posterKey,
                    plainContentKey: plainContentKey,
                    shareSubject: '测试主题',
                    shareText: '测试文本',
                    fileNamePrefix: 'test_card',
                  ),
                  child: const Text('打开卡片'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开卡片'));
    await tester.pumpAndSettle();

    // plainContentKey 解析为一个紧包内容的 RepaintBoundary（卡片级捕获管道已启用）
    expect(find.byKey(plainContentKey), findsOneWidget);
    final renderObject = tester.renderObject(find.byKey(plainContentKey));
    expect(renderObject, isA<RenderRepaintBoundary>());
    // 外层 posterKey 仍是独立的另一个 RepaintBoundary（两键不同实例）
    expect(
      renderObject,
      isNot(same(tester.renderObject(find.byKey(posterKey)))),
    );
  });

  testWidgets(
      'PosterGenerator.showPosterWithStylePicker shows style bar and preview',
      (tester) async {
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    final data = PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '测试模板',
      category: '人像写真 · 摄影模板',
      qrData: 'https://example.com/tpl/test',
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
      shareText: '测试文案',
      authorName: '',
      photoBuilder: (w, h) =>
          Container(width: w, height: h, color: tokens.brand),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => PosterGenerator.showPosterWithStylePicker(
                    context: context,
                    tokens: tokens,
                    title: '分享模板',
                    kind: PosterKind.template,
                    ratio: PosterRatio.fullScreen,
                    data: data,
                    shareSubject: '模板 · 测试模板',
                    shareText: '测试文案',
                    fileNamePrefix: 'test_poster',
                  ),
                  child: const Text('打开样式海报'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开样式海报'));
    await tester.pumpAndSettle();

    // 样式切换条出现（9:16 模板样式含「经典面板」等）
    expect(find.text('选择版式'), findsOneWidget);
    expect(find.text('经典面板'), findsOneWidget);
    expect(find.text('相纸卡片'), findsOneWidget);
    expect(find.text('全出血浮层'), findsOneWidget);
    // 两个操作按钮仍在
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
