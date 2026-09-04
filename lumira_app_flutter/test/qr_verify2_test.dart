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
import 'package:qr/qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

const _outDir = 'build/qr_verify2';

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

/// 与 scan_qr_page 完全一致的解码管线。
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

/// qr 包生成干净黑白二维码（白底安静区）。
img.Image makeCleanQr(String data, {int scale = 8, int quietZone = 4}) {
  final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
  final qrImage = QrImage(code);
  final n = qrImage.moduleCount;
  final size = (n + quietZone * 2) * scale;
  final out = img.Image(width: size, height: size, numChannels: 3);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final dark = qrImage.isDark(y, x);
      for (var dy = 0; dy < scale; dy++) {
        for (var dx = 0; dx < scale; dx++) {
          out.setPixelRgb(
            (x + quietZone) * scale + dx,
            (y + quietZone) * scale + dy,
            dark ? 0 : 255,
            dark ? 0 : 255,
            dark ? 0 : 255,
          );
        }
      }
    }
  }
  return out;
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
  testWidgets('验证2：真实海报数据在各渲染路径下均可被相册管线识别', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    // ignore: avoid_print
    print('qrData len=${data.length}');

    // 0) 干净黑白二维码（73 模块 @8px/模块）基准
    final clean = makeCleanQr(data, scale: 8);
    final cleanPng = img.encodePng(clean);
    // ignore: avoid_print
    print('0 clean(73mod@8) decode=${decodeScanPage(cleanPng) == null ? 'FAIL' : 'OK'}');

    // 1) QrPainter 高分辨率 260px
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
    );
    final qr260 = await tester.runAsync(() => painter.toImageData(260));
    File('$_outDir/qr_260.png').writeAsBytesSync(qr260!.buffer.asUint8List());
    // ignore: avoid_print
    print('1 QrPainter 260px decode=${decodeScanPage(qr260.buffer.asUint8List()) == null ? 'FAIL' : 'OK'}');

    // 2) PosterQr 组件 54px @3.6（当前修复后的渲染路径）
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
    final qrBytes = await tester.runAsync(() => captureBoundary(qrKey, 3.6));
    File('$_outDir/poster_qr_54_r36.png').writeAsBytesSync(qrBytes!);
    // ignore: avoid_print
    print('2 PosterQr(54) @3.6 decode=${decodeScanPage(qrBytes) == null ? 'FAIL' : 'OK'}');

    // 3) PosterQr 组件 54px 真实导出倍率 3.6，但裁剪出 QR 区域（无 padding）
    final qrImg = img.decodeImage(qrBytes)!;
    // ignore: avoid_print
    print('3 captured size=${qrImg.width}x${qrImg.height}');

    // 4) 干净 QR 缩小到相册截图常见尺寸：73 模块 @2px/模块（=146px）+ 白边
    final small = img.copyResize(clean, width: (73 + 8) * 2);
    final smallPng = img.encodePng(small);
    // ignore: avoid_print
    print('4 clean@2px/module decode=${decodeScanPage(smallPng) == null ? 'FAIL' : 'OK'}');
    // @3px/模块 = 219px
    final mid = img.copyResize(clean, width: (73 + 8) * 3);
    final midPng = img.encodePng(mid);
    // ignore: avoid_print
    print('4 clean@3px/module decode=${decodeScanPage(midPng) == null ? 'FAIL' : 'OK'}');
  });
}
