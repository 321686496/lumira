import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';

PosterStyleData _data({String hint = '长按识别 · 查看高清原图'}) => PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/photo/1',
      qrHint: hint,
      qrSub: '打开如画 · 保存原图',
      shareText: '测试文案',
      authorName: '小满',
      photoBuilder: (w, h) => SizedBox(width: w, height: h),
    );

void main() {
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

  testWidgets('PosterPara 使用衬线 text2 样式', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterPara(text: '九月晴午，光落草尖，见之成卷。'),
        ),
      ),
    );
    final t = tester.widget<Text>(find.text('九月晴午，光落草尖，见之成卷。'));
    expect(t.style?.color, PosterPalette.text2);
    expect(t.style?.fontFamily, 'NotoSerifSC');
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
}
