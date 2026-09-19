import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/checkin/widgets/checkin_poster_styles.dart';
import 'package:lumira_app_flutter/features/profile/widgets/collection_poster_styles.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/photo_poster_styles.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/template_poster_styles.dart';

/// 高清单张海报渲染诊断：加载真实衬线字体，逐款渲染 24 张海报大图，
/// 用于肉眼确认「底部文字下方黄色线条」的形态与数量。
/// 运行：flutter test test/poster_diag_render_test.dart --update-goldens
void main() {
  setUpAll(() async {
    // 加载 NotoSerifSC 真实字体，避免 Ahem 方块
    final loader = FontLoader('NotoSerifSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Bold.otf'));
    await loader.load();
  });

  PosterStyleData dataFor(PosterStyle s) => PosterStyleData(
        ratio: s.ratios.first,
        title: '晨光人像',
        category: '人像写真 · 摄影模板',
        qrData: 'lumira://tpl/诊断占位',
        qrHint: '长按识别 · 查看完整模板',
        qrSub: '打开如画，拍出同款',
        shareText: '分享文案占位',
        authorName: '小满',
        photoBuilder: (w, h) =>
            Container(width: w, height: h, color: const Color(0xFFCCCCCC)),
      );

  final cases = <String, List<PosterStyle>>{
    'tpl': templatePosterStyles(),
    'photo': photoPosterStyles(),
    'ck': checkinPosterStyles(),
    'col': collectionPosterStyles(),
  };

  // 根因验证：无 Material/DefaultTextStyle 上下文渲染（模拟离屏导出路径），
  // 若文字下方出现两条琥珀色调试线，即确认「Text 缺 Material 上下文」为根因。
  testWidgets('render raw_noMaterial (pA 无 Material 上下文)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    final pA = templatePosterStyles().firstWhere((s) => s.id == 'pA');
    final data = dataFor(pA);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: pA.builder(data)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'raw 渲染不应有异常');
    await expectLater(
      find.byType(Directionality),
      matchesGoldenFile('diag_raw_noMaterial.png'),
    );
  });

  // 生产离屏捕获路径复现：与 _capturePosterImage 完全一致——海报插入根 Overlay，
  // 无任何 Material/DefaultTextStyle 祖先。若文字下方出现琥珀双线即确认根因。
  testWidgets('render capture_path_repro (生产 Overlay 捕获路径)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 920));
    late OverlayState rootOverlay;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (ctx) {
            rootOverlay = Overlay.maybeOf(ctx, rootOverlay: true)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final pA = templatePosterStyles().firstWhere((s) => s.id == 'pA');
    final data = dataFor(pA);
    final key = GlobalKey();
    rootOverlay.insert(
      OverlayEntry(
        builder: (_) => Positioned(
          left: 30000, // 移到屏幕外，与生产一致
          top: 0,
          child: RepaintBoundary(key: key, child: pA.builder(data)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '捕获路径渲染不应有异常');
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('diag_capture_repro.png'),
    );
  });

  for (final entry in cases.entries) {
    for (final s in entry.value) {
      final id = '${entry.key}_${s.id}';
      testWidgets('render $id', (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 920));
        final data = dataFor(s);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFE8E8E8),
              body: Center(
                child: s.builder(data),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$id 渲染不应有异常');
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('diag_$id.png'),
        );
      });
    }
  }
}
