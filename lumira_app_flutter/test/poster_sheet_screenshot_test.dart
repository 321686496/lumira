import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/services/poster_generator.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

/// 截图诊断：验证重新设计后的「样式选择弹窗」布局
/// （FittedBox 整卡预览 + 双按钮操作条 + 紧凑样式条）。
/// 运行：flutter test test/poster_sheet_screenshot_test.dart --update-goldens
void main() {
  testWidgets('分享模板弹窗整卡截图（默认 pA 样式）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    final data = PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晨光人像',
      category: '人像写真 · 摄影模板',
      qrData: 'lumira://tpl/简化数据占位',
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
      shareText: '分享文案占位',
      authorName: '',
      photoBuilder: (w, h) =>
          Container(width: w, height: h, color: const Color(0xFFCCCCCC)),
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
                    shareSubject: '模板 · 晨光人像',
                    shareText: '分享文案占位',
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

    // 布局断言：新操作条 + FittedBox 预览
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
    expect(find.text('生成海报'), findsNothing);
    expect(tester.takeException(), isNull, reason: '预览区不应出现溢出异常');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('poster_sheet_screenshot.png'),
    );
  });

  testWidgets('切换到 pC 相纸卡片后整卡截图', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    final data = PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晨光人像',
      category: '人像写真 · 摄影模板',
      qrData: 'lumira://tpl/简化数据占位',
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
      shareText: '分享文案占位',
      authorName: '',
      photoBuilder: (w, h) =>
          Container(width: w, height: h, color: const Color(0xFFCCCCCC)),
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
                    shareSubject: '模板 · 晨光人像',
                    shareText: '分享文案占位',
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
    await tester.tap(find.text('相纸卡片'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '切换 pC 后不应出现溢出异常');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('poster_sheet_screenshot_pC.png'),
    );
  });
}
