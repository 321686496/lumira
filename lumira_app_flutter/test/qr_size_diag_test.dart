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

const _outDir = 'build/qr_size_diag';

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

String? decodeScanPage(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

/// 用高分辨率 QrPainter 预渲染成 ui.Image，再以 RawImage 显示在指定逻辑尺寸。
Future<Uint8List> renderHighRes(WidgetTester tester, String data, double displaySize,
    double renderSize, double ratio) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF888888),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: displaySize + 10,
              height: displaySize + 10,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F1E8),
                borderRadius: BorderRadius.circular(9),
              ),
              child: FutureBuilder<ui.Image>(
                future: QrPainter(
                  data: data,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A1A)),
                ).toImage(renderSize),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return RawImage(
                    image: snap.data,
                    width: displaySize,
                    height: displaySize,
                    fit: BoxFit.fill,
                  );
                },
              ),
            ),
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
  });
  return out!;
}

/// 现行 PosterQr（QrImageView）不同逻辑尺寸。
Future<Uint8List> renderPosterQr(
    WidgetTester tester, String data, double logicalSize, double ratio) async {
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
  });
  return out!;
}

void main() {
  testWidgets('不同逻辑尺寸 PosterQr @ratio3.6 的解码结果 + 高分辨率预渲染对比',
      (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());

    // 1) 现行 PosterQr 不同逻辑尺寸 @3.6（真实导出倍率）
    for (final size in [54.0, 60.0, 70.0, 80.0, 90.0, 110.0]) {
      final bytes = await renderPosterQr(tester, data, size, 3.6);
      final ok = decodeScanPage(bytes);
      // ignore: avoid_print
      print('PosterQr size=$size @3.6 decode=${ok == null ? 'FAIL' : 'OK'}');
    }

    // 2) 高分辨率预渲染：显示 54px，渲染 216/312/468px，@3.6 捕获
    for (final renderSize in [216.0, 312.0, 468.0]) {
      final bytes =
          await renderHighRes(tester, data, 54, renderSize, 3.6);
      final ok = decodeScanPage(bytes);
      // ignore: avoid_print
      print('HighRes render=${renderSize.toInt()}px display=54 @3.6 '
          'decode=${ok == null ? 'FAIL' : 'OK'}');
    }
  });
}
