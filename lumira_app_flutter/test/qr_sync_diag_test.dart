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

const _outDir = 'build/qr_sync_diag';

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

/// 同步高分辨率 QR：260px 逻辑的 CustomPaint(QrPainter) → FittedBox 缩到显示尺寸。
/// 矢量绘制 + 同步渲染，导出时 RepaintBoundary 以高倍率重采样，模块保持锐利。
Widget syncHighResQr(String data, double displaySize, {double renderSize = 260}) {
  return SizedBox(
    width: displaySize,
    height: displaySize,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: renderSize,
        height: renderSize,
        child: CustomPaint(
          painter: QrPainter(
            data: data,
            version: QrVersions.auto,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
          ),
        ),
      ),
    ),
  );
}

Future<Uint8List> captureBoundary(GlobalKey key, double ratio) async {
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: ratio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  Directory(_outDir).createSync(recursive: true);
  testWidgets('同步高分辨率 QR：FittedBox+CustomPaint 不同倍率下的解码', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    // ignore: avoid_print
    print('qrData len=${data.length}');

    // 只 pump 一次（同步渲染，无需等待异步加载）
    for (final renderSize in [260.0, 390.0, 468.0]) {
      for (final ratio in [3.0, 3.6, 4.0]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF888888),
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F1E8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: syncHighResQr(data, 54, renderSize: renderSize),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final bytes = await tester.runAsync(() => captureBoundary(key, ratio));
        File('$_outDir/qr_r${renderSize.toInt()}_x$ratio.png').writeAsBytesSync(bytes!);
        final ok = decodeScanPage(bytes);
        // ignore: avoid_print
        print('render=${renderSize.toInt()}px ratio=$ratio decode=${ok == null ? 'FAIL' : 'OK'}');
      }
    }
  });
}
