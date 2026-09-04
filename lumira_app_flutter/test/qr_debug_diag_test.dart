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

const _outDir = 'build/qr_debug_diag';

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

/// 与 scan_qr_page.dart 完全一致的解码管线。
String? decodeScanPage(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return 'NOIMAGE';
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    return result.text.isEmpty ? null : result.text;
  } catch (e) {
    return 'ERR:$e';
  }
}

Future<void> waitQrLoaded(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    var allLoaded = true;
    for (final im in images) {
      final stream = im.image.resolve(const ImageConfiguration());
      var done = false;
      late ImageStreamListener l;
      l = ImageStreamListener(
        (_, __) { done = true; stream.removeListener(l); },
        onError: (_, __) { done = true; stream.removeListener(l); },
      );
      stream.addListener(l);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      if (!done) allLoaded = false;
    }
    if (allLoaded && images.isNotEmpty) return;
  }
}

Future<Uint8List> captureBoundary(GlobalKey key, double ratio) async {
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: ratio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  Directory(_outDir).createSync(recursive: true);

  testWidgets('诊断：高分辨率 QrPainter 直渲 vs PosterQr 组件', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    // ignore: avoid_print
    print('qrData len=${data.length}');

    // A) 直接高分辨率 QrPainter 渲染 260px → 保存 + 解码（验证渲染与管线）
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
    );
    final directBytes = await tester.runAsync(() async {
      final data2 = await painter.toImageData(260);
      return data2!.buffer.asUint8List();
    });
    File('$_outDir/direct_260.png').writeAsBytesSync(directBytes!);
    // ignore: avoid_print
    print('A direct260 decode=${decodeScanPage(directBytes)}');

    // B) PosterQr 组件 54px @3.6
    final qrKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF888888),
          body: Center(
            child: RepaintBoundary(key: qrKey, child: PosterQr(data: data, size: 54, padding: 5, radius: 9)),
          ),
        ),
      ),
    );
    await tester.pump();
    await waitQrLoaded(tester);
    final imgCount = tester.widgetList<Image>(find.byType(Image)).length;
    // ignore: avoid_print
    print('B imgCount=$imgCount');
    final qrBytes = await tester.runAsync(() => captureBoundary(qrKey, 3.6));
    File('$_outDir/poster_qr_54_r36.png').writeAsBytesSync(qrBytes!);
    // ignore: avoid_print
    print('B PosterQr(54) @3.6 decode=${decodeScanPage(qrBytes)}');
    final im = img.decodeImage(qrBytes);
    // ignore: avoid_print
    print('B captured size=${im?.width}x${im?.height}');
  });
}
