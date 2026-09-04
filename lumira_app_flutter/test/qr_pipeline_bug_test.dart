import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:qr/qr.dart';
import 'package:zxing2/qrcode.dart';
import 'package:zxing2/src/luminance_source.dart';

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

/// 用 qr 包生成干净的黑白二维码位图（scale=8 像素/模块，无抗锯齿）。
img.Image makeCleanQr(String data, {int scale = 8, int quietZone = 4}) {
  final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
  final qrImage = QrImage(code);
  final n = qrImage.moduleCount;
  final size = (n + quietZone * 2) * scale;
  final out = img.Image(width: size, height: size, numChannels: 1);
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

/// 直接灰度 LuminanceSource（最干净路径）。
class _GraySource extends LuminanceSource {
  _GraySource(this._lum, int w, int h) : super(w, h);
  final Int8List _lum;
  @override
  Int8List getMatrix() => _lum;
  @override
  Int8List getRow(int y, Int8List? row) {
    final r = row ?? Int8List(width);
    for (var x = 0; x < width; x++) {
      r[x] = _lum[y * width + x];
    }
    return r;
  }
}

/// 解码管线 A：现行 scan_qr_page（RGBA + asInt32List + HybridBinarizer）
String? pipeA(img.Image image) {
  final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
  final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
  try {
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text.isEmpty ? null : result.text;
  } catch (e) {
    return 'ERR:$e';
  }
}

/// 解码管线 B：直接灰度 → 自定义 LuminanceSource
String? pipeB(img.Image image) {
  final g = image.convert(numChannels: 1);
  final lum = Int8List(image.width * image.height);
  final bytes = g.getBytes(order: img.ChannelOrder.rgb);
  for (var i = 0; i < lum.length; i++) {
    lum[i] = bytes[i] - 128;
  }
  final source = _GraySource(lum, image.width, image.height);
  try {
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text.isEmpty ? null : result.text;
  } catch (e) {
    return 'ERR:$e';
  }
}

/// 解码管线 C：管线 A 但 GlobalHistogramBinarizer
String? pipeC(img.Image image) {
  final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
  final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
  try {
    final result = QRCodeReader().decode(BinaryBitmap(GlobalHistogramBinarizer(source)));
    return result.text.isEmpty ? null : result.text;
  } catch (e) {
    return 'ERR:$e';
  }
}

void main() {
  test('解码管线诊断：干净黑白二维码', () {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    // ignore: avoid_print
    print('qrData len=${data.length}');
    final clean = makeCleanQr(data, scale: 8);
    // ignore: avoid_print
    print('clean ${clean.width}x${clean.height}');
    // ignore: avoid_print
    print('pipeA(rgba+int32+hybrid) = ${pipeA(clean)}');
    // ignore: avoid_print
    print('pipeB(gray+planar+hybrid) = ${pipeB(clean)}');
    // ignore: avoid_print
    print('pipeC(rgba+int32+global)  = ${pipeC(clean)}');

    final pngBytes = img.encodePng(clean);
    final decoded = img.decodeImage(pngBytes)!;
    // ignore: avoid_print
    print('pipeA(png roundtrip) = ${pipeA(decoded)}');
    // ignore: avoid_print
    print('pipeB(png roundtrip) = ${pipeB(decoded)}');
    // ignore: avoid_print
    print('pipeC(png roundtrip) = ${pipeC(decoded)}');

    expect(pipeB(clean), data);
  });
}
