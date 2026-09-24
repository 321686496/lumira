import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/photo_poster_styles.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';

PosterStyleData _data({
  String authorName = '小满',
  String dateText = '2026.09.24',
}) =>
    PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/photo/1',
      qrHint: '长按识别 · 查看高清原图',
      qrSub: '打开如画 · 保存原图',
      shareText: '测试文案',
      authorName: authorName,
      dateText: dateText,
      photoBuilder: (w, h) =>
          Container(width: w, height: h, color: const Color(0xFFDDDDDD)),
    );

PosterStyle _styleOf(String id) =>
    photoPosterStyles().firstWhere((s) => s.id == id);

Future<void> _pump(WidgetTester tester, String id, PosterStyleData data) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: _styleOf(id).builder(data)))),
  );
}

/// 加载与生产一致的字体度量（详见 `test/poster_diag_render_test.dart` 同款做法）。
///
/// 测试环境未加载真实字体时，所有字形（含 Latin）都回退到内置测试字体
/// FlutterTest（每字形 1em），Latin 宽度约为真机 Roboto 的两倍，会让本就
/// 紧凑的 300px 画布产生**测试环境特有的虚假 RenderFlex 溢出**。
/// 这里按生产字体族加载：
/// - `NotoSerifSC`（App asset）：衬线标题 / 题跋（posterSerif / posterSerifEn）；
/// - `Roboto`（Flutter SDK material_fonts）：默认无衬线正文（posterPlain 未指定族）。
Future<void> _loadPosterFonts() async {
  final noto = FontLoader('NotoSerifSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Bold.otf'));
  await noto.load();

  final root = Platform.environment['FLUTTER_ROOT'];
  final roboto = FontLoader('Roboto');
  var hasRoboto = false;
  for (final name in const ['roboto-regular.ttf', 'roboto-bold.ttf']) {
    final file = File('$root/bin/cache/artifacts/material_fonts/$name');
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    roboto.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    hasRoboto = true;
  }
  if (!hasRoboto) {
    fail('未找到 Flutter SDK 的 Roboto 字体（FLUTTER_ROOT=$root）：'
        '字体度量会退化为测试字体，溢出断言将失去意义。');
  }
  await roboto.load();
}

void main() {
  setUpAll(_loadPosterFonts);

  testWidgets('9:16 三款照片海报均正常渲染且无溢出', (tester) async {
    final styles = photoPosterStyles()
        .where((s) => s.supports(PosterRatio.fullScreen))
        .toList();
    expect(styles.length, 3);
    for (final s in styles) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: s.builder(_data())),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '${s.id} 渲染应无异常');
    }
  });

  testWidgets('满版照片 f1 使用画布默认圆角与金线（预览/导出同款）', (tester) async {
    await _pump(tester, 'f1', _data());
    final canvas = tester.widget<PosterCanvas>(find.byType(PosterCanvas));
    expect(canvas.borderRadius, 20);
    expect(canvas.borderColor, PosterPalette.line);
  });

  testWidgets('竖排刊 m3 长落款时二维码不被挤出画布', (tester) async {
    await _pump(tester, 'm3', _data(authorName: '小满今天也在努力拍照'));
    expect(tester.takeException(), isNull);
    final canvas = tester.getRect(find.byType(PosterCanvas));
    final qr = tester.getRect(find.byType(PosterQrMini));
    expect(qr.right, lessThanOrEqualTo(canvas.right));
    expect(qr.left, greaterThanOrEqualTo(canvas.left));
    expect(qr.width, greaterThan(40));
    expect(qr.height, greaterThan(30));
  });

  testWidgets('竖排刊 m3 刊头使用真实拍摄日期（无 VOL./期号假数据）', (tester) async {
    await _pump(tester, 'm3', _data());
    expect(find.text('2026.09.24'), findsOneWidget);
    expect(find.textContaining('VOL'), findsNothing);
    expect(find.textContaining('期'), findsNothing);
  });

  testWidgets('立轴 j1 地头不含题跋与金印，日期取真实值', (tester) async {
    await _pump(tester, 'j1', _data());
    expect(find.textContaining('九月晴午'), findsNothing);
    expect(find.text('如'), findsNothing);
    expect(find.text('画'), findsNothing);
    expect(find.text('2026.09.24'), findsOneWidget);
  });

  testWidgets('日期为空时三款均不渲染假日期', (tester) async {
    for (final id in const ['f1', 'm3', 'j1']) {
      await _pump(tester, id, _data(dateText: ''));
      expect(find.textContaining('2026'), findsNothing, reason: id);
      expect(find.textContaining('VOL'), findsNothing, reason: id);
    }
  });

  testWidgets('落款为空时不渲染 @ 占位，且 kicker 仍是照片文案', (tester) async {
    await _pump(tester, 'm3', _data(authorName: ''));
    expect(find.textContaining('@'), findsNothing);
    expect(find.text('LUMIRA · 如画出品'), findsOneWidget);
    expect(find.textContaining('TEMPLATE'), findsNothing);
  });
}