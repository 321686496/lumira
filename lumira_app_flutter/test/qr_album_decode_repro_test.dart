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
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:zxing2/qrcode.dart';

const _outDir = 'build/qr_album_decode_repro';

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

/// 与 scan_qr_page.dart 的 _decodeQrFromBytes 完全一致的解码管线。
String? decodeWithScanPagePipeline(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  try {
    final pixels = image
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.rgba);
    final source =
        RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    final text = result.text;
    return text.isNotEmpty ? text : null;
  } catch (_) {
    return null;
  }
}

/// 渲染 PosterQr 并落盘 PNG，返回字节。
Future<Uint8List> renderPosterQr(
  WidgetTester tester,
  String data,
  double qrSize, {
  double pixelRatio = 3.6,
  String name = 'qr',
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF888888),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: PosterQr(data: data, size: qrSize, padding: 5, radius: 9),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  Uint8List? out;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    out = byteData!.buffer.asUint8List();
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(out!);
    // ignore: avoid_print
    print('saved $_outDir/$name.png ${image.width}x${image.height} '
        '(qrSize=$qrSize, ratio=$pixelRatio)');
  });
  return out!;
}

void main() {
  testWidgets('复现：海报导出配置渲染二维码 → 相册解码管线', (tester) async {
    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);
    // ignore: avoid_print
    print('qrData len=${data.length}');

    // 真实导出配置：qrSize≈54.5（60*k），pixelRatio=3.6（1080/300）
    for (final qrSize in [54.0, 60.0, 78.0]) {
      for (final ratio in [2.0, 3.0, 3.6, 4.0]) {
        final bytes = await renderPosterQr(
            tester, data, qrSize, pixelRatio: ratio, name: 's${qrSize.toInt()}_r$ratio');
        final text = decodeWithScanPagePipeline(bytes);
        // ignore: avoid_print
        print('>>> qrSize=$qrSize ratio=$ratio decode=${text ?? 'FAIL'}');
      }
    }
  });

  testWidgets('整卡海报 pC 全图导出 → 相册解码管线', (tester) async {
    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);
    final posterData = PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: record.name,
      category: '人像写真 · 摄影模板',
      qrData: data,
      qrHint: 'hint',
      qrSub: 'sub',
      shareText: 'share',
      authorName: '',
      photoBuilder: (w, h) => Container(
        width: w,
        height: h,
        color: const Color(0xFFCCCCCC),
        child: const Center(
          child: Text('PHOTO', style: TextStyle(color: Colors.black38, fontSize: 20)),
        ),
      ),
    );
    final pC = PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)
        .firstWhere((s) => s.id == 'pC');
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF888888),
          body: Center(child: RepaintBoundary(key: key, child: pC.builder(posterData))),
        ),
      ),
    );
    await tester.pump();
    Uint8List? out;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final size = boundary.size;
      final ratio = (1080.0 / size.width).clamp(2.0, 4.0);
      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      out = byteData!.buffer.asUint8List();
      final file = File('$_outDir/pC_full.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(out!);
      // ignore: avoid_print
      print('saved $_outDir/pC_full.png ${image.width}x${image.height} ratio=$ratio');
    });
    final text = decodeWithScanPagePipeline(out!);
    // ignore: avoid_print
    print('>>> pC full decode=${text ?? 'FAIL'}');
  });
}
