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

const _outDir = 'build/qr_path_diag';

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

/// 用 zxing 的 MultiFormatReader + 多尝试（含 TryHarder）解码。
String? decodeMulti(List<int> bytes, {bool tryHarder = true}) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final hints = <DecodeHintType, Object>{
      DecodeHintType.tryHarder: tryHarder,
      DecodeHintType.pureBarcode: false,
      DecodeHintType.possibleFormats: [BarcodeFormat.qrCode],
    };
    final result = MultiFormatReader().decode(bitmap, hints);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

/// 手动 Detector：只探测，看 finder pattern 是否被找到。
String? detectOnly(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final detector = Detector(bitmap.blackMatrix);
    final det = detector.detect();
    return 'FOUND ${det.bottomLeft} ${det.topLeft} ${det.topRight}';
  } catch (e) {
    return 'NOT-FOUND: $e';
  }
}

/// PosterQr 组件（小逻辑尺寸 → RepaintBoundary upscale）。
Future<Uint8List> renderPosterQr(
  WidgetTester tester,
  String data,
  double logicalSize,
  double ratio,
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
  });
  return out!;
}

void main() {
  testWidgets('zxing 多路径 vs 手动 Detector：up_54_r4 能否被任何路径解码', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    final bytes = await renderPosterQr(tester, data, 54, 4.0);
    // ignore: avoid_print
    print('scanPage(QRCodeReader) : ${decodeScanPage(bytes) ?? 'FAIL'}');
    // ignore: avoid_print
    print('multi(tryHarder=false) : ${decodeMulti(bytes, tryHarder: false) ?? 'FAIL'}');
    // ignore: avoid_print
    print('multi(tryHarder=true)  : ${decodeMulti(bytes, tryHarder: true) ?? 'FAIL'}');
    // ignore: avoid_print
    print('detector-only          : ${detectOnly(bytes)}');
  });
}
