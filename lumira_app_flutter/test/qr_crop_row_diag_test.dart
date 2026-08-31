// 裁剪 fullScreen_cards.png 中各卡片区域并放大保存，用于人工核验二维码外观。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('裁剪卡片行', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFE8E4DC),
          body: RepaintBoundary(
            key: key,
            child: Image.file(
              File('build/qr_card_diag/fullScreen_cards.png'),
              width: 1000,
              height: 352,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/qr_card_crop').createSync(recursive: true);
      File('build/qr_card_crop/cards_row.png').writeAsBytesSync(byteData!.buffer.asUint8List());
      // ignore: avoid_print
      print('saved cards_row.png ${image.width}x${image.height}');
    });
  });
}
