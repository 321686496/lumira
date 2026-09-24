import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';

PosterStyleData _data({
  String hint = '长按识别 · 查看高清原图',
  PosterKind kind = PosterKind.photo,
  String authorName = '小满',
}) =>
    PosterStyleData(
      ratio: PosterRatio.fullScreen,
      kind: kind,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/photo/1',
      qrHint: hint,
      qrSub: '打开如画 · 保存原图',
      shareText: '测试文案',
      authorName: authorName,
      photoBuilder: (w, h) => SizedBox(width: w, height: h),
    );

void main() {
  test('固定文案按 kind 派生，不再靠落款是否为空推断', () {
    final photo = _data(kind: PosterKind.photo, authorName: '');
    expect(posterKickerOf(photo), posterPhotoKicker);
    expect(posterQrHintOf(photo), posterPhotoQrHint);
    expect(posterQrSubOf(photo), posterPhotoQrSub);

    final template = _data(kind: PosterKind.template, authorName: '');
    expect(posterKickerOf(template), posterTemplateKicker);
    expect(posterQrHintOf(template), posterTemplateQrHint);
    expect(posterQrSubOf(template), posterTemplateQrSub);
  });

  test('posterQrMiniLinesOf 按「·」拆两行', () {
    expect(posterQrMiniLinesOf(_data()), <String>['长按识别', '查看高清原图']);
  });

  test('posterQrMiniLinesOf 主提示无「·」时回退副文案', () {
    expect(
      posterQrMiniLinesOf(_data(hint: '长按识别')),
      <String>['长按识别', '打开如画 · 保存原图'],
    );
  });

  testWidgets('PosterAuthorRow 空 suffix 时不渲染落款', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterAuthorRow(name: '小满', suffix: ''),
        ),
      ),
    );
    expect(find.text('@小满'), findsOneWidget);
    expect(find.textContaining('· 用'), findsNothing);
  });

  testWidgets('PosterAuthorRow 自定义字号生效', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterAuthorRow(name: '小满', whoSize: 10, withSize: 8, avatarSize: 18),
        ),
      ),
    );
    final who = tester.widget<Text>(find.text('@小满'));
    expect(who.style?.fontSize, 10);
  });

  testWidgets('PosterAuthorRow 长名字在窄容器内省略不溢出', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              child: PosterAuthorRow(
                name: '很长很长的昵称名字',
                whoSize: 10,
                withSize: 8,
                avatarSize: 18,
                gap: 6,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('@'), findsOneWidget);
  });

  testWidgets('PosterAuthorRow 空名字不渲染占位', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterAuthorRow(name: ''),
        ),
      ),
    );
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('· 用'), findsNothing);
  });

  testWidgets('PosterVerticalText 逐字渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterVerticalText(text: '如画', style: posterPlain(9)),
        ),
      ),
    );
    expect(find.text('如'), findsOneWidget);
    expect(find.text('画'), findsOneWidget);
  });

  group('满版照片（f1）共享件', () {
    test('PosterFullBleedScrim 四段压暗值/停靠点符合 v12 设计稿', () {
      expect(PosterFullBleedScrim.colors, const [
        Color(0x2E14100A),
        Color(0x0514100A),
        Color(0x9E14100A),
        Color(0xBD14100A),
      ]);
      expect(PosterFullBleedScrim.stops, const [0.0, 0.28, 0.78, 1.0]);
    });

    testWidgets('PosterFullBleedScrim 渲染为自上而下线性渐变', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PosterFullBleedScrim())),
      );
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PosterFullBleedScrim),
          matching: find.byType(DecoratedBox),
        ),
      );
      final grad = (box.decoration as BoxDecoration).gradient as LinearGradient;
      expect(grad.begin, Alignment.topCenter);
      expect(grad.end, Alignment.bottomCenter);
      expect(grad.colors, PosterFullBleedScrim.colors);
    });

    testWidgets('PosterKicker 支持 shadows 透传', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosterKicker(
              text: 'LUMIRA · 如画出品',
              color: PosterPalette.goldSoft,
              shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('LUMIRA · 如画出品'));
      expect(text.style?.shadows?.length, 1);
    });

    testWidgets('PosterKicker 不传 shadows 时保持无阴影（浅色底款不受影响）',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PosterKicker(text: 'LUMIRA · 如画出品')),
        ),
      );
      final text = tester.widget<Text>(find.text('LUMIRA · 如画出品'));
      expect(text.style?.shadows, isNull);
    });

    // 回归锁定：scale 为既有能力，f1 用 0.9 时英文标 11*0.9 = 9.9（设计稿 10px）
    testWidgets('PosterBrandOnPhoto scale 等比缩放英文标字号（既有能力回归）',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosterBrandOnPhoto(scale: 0.9),
          ),
        ),
      );
      final en = tester.widget<Text>(find.text('LUMIRA'));
      final zh = tester.widget<Text>(find.text('如画'));
      expect(en.style?.fontSize, closeTo(9.9, 0.01));
      expect(zh.style?.fontSize, closeTo(9.0, 0.01));
    });
  });
}
