import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

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

Future<Uint8List> renderQrPainter(String data, double size,
    {Color color = const Color(0xFF1A1A1A)}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
    dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square, color: color),
  ).paint(canvas, Size.square(size));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 管线 A：scan_qr_page 现行（RGBA + asInt32List + HybridBinarizer）
String? pipelineScanPage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

/// 管线 B：逐像素算灰度（同 zxing 亮度公式），显式构造 Int32List，避免 getBytes 歧义。
String? pipelineGrayscale(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final w = image.width, h = image.height;
    final pix = Int32List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        pix[y * w + x] = (0xFF000000 | (r << 16) | (g << 8) | b);
      }
    }
    final source = RGBLuminanceSource(w, h, pix);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

/// 管线 C：先用 image 包转灰度图，再手动构造亮度矩阵。
String? pipelineGrayImage(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final gray = img.grayscale(image);
    final lum = Int8List(gray.width * gray.height);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        lum[y * gray.width + x] = gray.getPixel(x, y).r.toInt();
      }
    }
    final source = GrayLuminanceSource(gray.width, gray.height, lum);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

/// 管线 D：管线的简化版 — 直接以 ARGB Int32List 喂给 RGBLuminanceSource（zxing 原生期望）。
String? pipelineArgb(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final w = image.width, h = image.height;
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    // RGBA 字节 → little-endian Int32 = ABGR；zxing 期望 ARGB，这里交换 R/B 修正。
    final pix = Int32List(w * h);
    for (var i = 0; i < w * h; i++) {
      final r = pixels[i * 4], g = pixels[i * 4 + 1], b = pixels[i * 4 + 2], a = pixels[i * 4 + 3];
      pix[i] = (a << 24) | (r << 16) | (g << 8) | b;
    }
    final source = RGBLuminanceSource(w, h, pix);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

void main() {
  testWidgets('诊断：QrPainter 直渲二维码在多种解码管线下的识别结果', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    // ignore: avoid_print
    print('qrData len=${data.length}');

    await tester.runAsync(() async {
      for (final size in [200.0, 400.0, 800.0]) {
        final bytes = await renderQrPainter(data, size);
        // ignore: avoid_print
        print('--- size=$size ---');
        // ignore: avoid_print
        print('  A scanPage(rgba+int32+hybrid): ${pipelineScanPage(bytes) ?? 'FAIL'}');
        // ignore: avoid_print
        print('  B argb-Int32+hybrid        : ${pipelineArgb(bytes) ?? 'FAIL'}');
        // ignore: avoid_print
        print('  C grayscale+hybrid         : ${pipelineGrayscale(bytes) ?? 'FAIL'}');
      }
    });
  });
}

/// zxing2 的 LuminanceSource 子类：直接喂亮度矩阵（等价 RGBLuminanceSource 但避开其构造）。
class GrayLuminanceSource extends LuminanceSource {
  final Int8List _lum;
  GrayLuminanceSource(int width, int height, this._lum) : super(width, height);
  @override
  Int8List getMatrix() => _lum;
  @override
  Int8List getRow(int y, Int8List? row) {
    if (row == null || row.length < width) row = Int8List(width);
    for (var x = 0; x < width; x++) {
      row[x] = _lum[y * width + x];
    }
    return row;
  }
}
