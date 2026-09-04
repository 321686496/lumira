import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

const _outDir = 'build/qr_pixel_diag';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '晨光人像',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: const {'type': '人像', 'style': '清新', 'method': '平拍'},
    tags: const ['人像'],
    tagIds: const [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: const {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: const {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: const {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: const {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: const {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

/// 直接以目标像素尺寸栅格化 QrPainter（无任何 upscale）。
Future<Uint8List> renderDirect(String data, double px) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, px, px), Paint()..color = Colors.white);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
  ).paint(canvas, Size.square(px));
  final picture = recorder.endRecording();
  final image = await picture.toImage(px.toInt(), px.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// PosterQr 组件（小逻辑尺寸 → RepaintBoundary upscale）。
Future<Uint8List> renderPosterQr(
  WidgetTester tester,
  String data,
  double logicalSize,
  double ratio,
  String name,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF888888),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: PosterQr(data: data, size: logicalSize, padding: 5, radius: 9),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  Uint8List? out;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    out = byteData!.buffer.asUint8List();
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(out!);
  });
  return out!;
}

/// 直接渲染并保存 QrPainter。
Future<Uint8List> renderDirectSave(String data, double px, String name) async {
  final bytes = await renderDirect(data, px);
  final file = File('$_outDir/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  return bytes;
}

/// 沿某行打印灰度值，检测模块边界/对齐。
void dumpRow(Uint8List bytes, String label, int y) {
  final image = img.decodeImage(bytes);
  if (image == null) return;
  final w = image.width;
  final vals = <int>[];
  for (var x = 0; x < w; x++) {
    final p = image.getPixel(x, y);
    vals.add((p.r.toInt() + p.g.toInt() + p.b.toInt()) ~/ 3);
  }
  // 压缩打印：连续相同值缩写
  final sb = StringBuffer();
  var run = 0, prev = vals[0];
  for (var i = 1; i < vals.length; i++) {
    if (vals[i] == prev) {
      run++;
    } else {
      sb.write('${prev}x${run + 1} ');
      prev = vals[i];
      run = 0;
    }
  }
  sb.write('${prev}x${run + 1}');
  // ignore: avoid_print
  print('  [$label] y=$y (w=$w): ${sb.toString()}');
}

/// 统计亮度直方图（暗<64, 灰64-191, 亮>191）。
void histogram(Uint8List bytes, String label) {
  final image = img.decodeImage(bytes);
  if (image == null) return;
  var dark = 0, gray = 0, bright = 0;
  for (final p in image) {
    final v = (p.r.toInt() + p.g.toInt() + p.b.toInt()) ~/ 3;
    if (v < 64) {
      dark++;
    } else if (v > 191) {
      bright++;
    } else {
      gray++;
    }
  }
  // ignore: avoid_print
  print('  [$label] dark=$dark gray=$gray bright=$bright '
      '(tot=${image.width * image.height})');
}

/// 探测一个 finder pattern 的中心行长度（黑色 run 的长度分布）。
void finderRuns(Uint8List bytes, String label) {
  final image = img.decodeImage(bytes);
  if (image == null) return;
  final w = image.width, h = image.height;
  // 从左上角往内扫描，找第一段黑-白-黑-白-黑结构（finder 的 1:1:3:1:1）
  // 简化：打印左上角区域 (0..min(w,h)/2) 第一行的黑 run 长度
  for (var y = 0; y < h ~/ 2; y++) {
    final row = <int>[];
    var run = 0;
    var lastDark = false;
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final v = (p.r.toInt() + p.g.toInt() + p.b.toInt()) ~/ 3;
      final dark = v < 128;
      if (dark != lastDark) {
        if (run > 0) row.add(run);
        run = 1;
        lastDark = dark;
      } else {
        run++;
      }
    }
    if (run > 0) row.add(run);
    // finder 特征：run 序列近似 1:1:3:1:1（或 1:1:3:1:1:1:3:1:1 双 finder）
    final joined = row.join(',');
    if (joined.contains('1,1,3,1,1')) {
      // ignore: avoid_print
      print('  [$label] y=$y finderRunPattern=[$joined]');
      return;
    }
  }
  // ignore: avoid_print
  print('  [$label] 未找到 1,1,3,1,1 特征行');
}

void main() {
  testWidgets('像素级对比：direct 216px(OK) vs upscale 54@4x(FAIL)', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());

    await tester.runAsync(() async {
      final direct = await renderDirectSave(data, 216, 'direct_216');
      histogram(direct, 'direct_216');
      finderRuns(direct, 'direct_216');
      dumpRow(direct, 'direct_216', 50);
    });

    final up = await renderPosterQr(tester, data, 54, 4.0, 'up_54_r4');
    await tester.runAsync(() {
      histogram(up, 'up_54_r4(216px out)');
      finderRuns(up, 'up_54_r4');
      dumpRow(up, 'up_54_r4', 50);
      dumpRow(up, 'up_54_r4', 108);
      // finder 图案区（左上角）：白静区后第一行
      dumpRow(up, 'up_54_r4', 22);
      dumpRow(up, 'up_54_r4', 28);
      dumpRow(up, 'up_54_r4', 36);
      dumpRow(up, 'up_54_r4', 40);
      dumpRow(up, 'up_54_r4', 44);
      dumpRow(up, 'up_54_r4', 48);
      return Future.value();
    });
  });
}
