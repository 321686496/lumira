import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';

PosterStyleData _tplData() => PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/tpl/1',
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
      shareText: '测试文案',
      authorName: '',
      photoBuilder: (w, h) => Container(width: w, height: h, color: const Color(0xFFD8D8D8)),
    );

void main() {
  test('posterFixedHeight(fullScreen) = 画布宽 × 16/9（9:16，≈533.33）', () {
    expect(posterFixedHeight(PosterRatio.fullScreen), closeTo(300 * 16 / 9, 0.001));
    expect(
      posterCanvasWidth(PosterRatio.fullScreen) / posterFixedHeight(PosterRatio.fullScreen),
      closeTo(9 / 16, 0.001),
    );
  });

  test('其余比例固定高度沿用 760 × 缩放系数（不变）', () {
    for (final r in const [
      PosterRatio.ratio34,
      PosterRatio.square,
      PosterRatio.ratio43,
      PosterRatio.ratio169,
    ]) {
      expect(posterFixedHeight(r), 760 * posterScale(r));
    }
  });

  testWidgets('模板 fullScreen 三款在新画布高度（≈533.33）下无渲染溢出', (tester) async {
    for (final style in PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)) {
      await tester.pumpWidget(
        MaterialApp(
          // 与 exif_poster_card_test 一致：海报固有总高可超测试默认视口 800x600
          // （如 pA ≈737），外层滚动视图仅放开视口高度约束；画布自身固定高度
          // （s3 ≈533.33）与内部布局不变，渲染异常仍由 takeException 捕获。
          home: Scaffold(
            body: SingleChildScrollView(child: Center(child: style.builder(_tplData()))),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '${style.id} 不应在 533.33 高度下溢出');
    }
  });
}
