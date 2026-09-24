import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/photo_poster_styles.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

PosterStyleData _data() => PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/photo/1',
      qrHint: '长按识别 · 查看高清原图',
      qrSub: '打开如画 · 保存原图',
      shareText: '测试文案',
      authorName: '小满',
      photoBuilder: (w, h) =>
          Container(width: w, height: h, color: const Color(0xFFDDDDDD)),
    );

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

  testWidgets('9:16 九款照片海报均正常渲染且无溢出', (tester) async {
    final styles = photoPosterStyles()
        .where((s) => s.supports(PosterRatio.fullScreen))
        .toList();
    expect(styles.length, 9);
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
}