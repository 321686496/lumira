import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:zxing2/qrcode.dart';

const _outDir = 'build/qr_fix_verify';

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

/// 用 zxing2 自带 Encoder 生成「像素级完美」的二维码 PNG（每模块 modulePx 像素 + 4 模块静区）。
List<int> encodePixelPerfectPng(String data, {int modulePx = 8}) {
  final qr = Encoder.encode(data, ErrorCorrectionLevel.m);
  final m = qr.matrix!;
  final dim = m.width;
  final quiet = 4;
  final size = (dim + quiet * 2) * modulePx;
  final im = img.Image(width: size, height: size);
  img.fill(im, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < dim; y++) {
    for (var x = 0; x < dim; x++) {
      if (m.get(x, y) == 1) {
        img.fillRect(im,
            x1: (x + quiet) * modulePx,
            y1: (y + quiet) * modulePx,
            x2: (x + quiet + 1) * modulePx - 1,
            y2: (y + quiet + 1) * modulePx - 1,
            color: img.ColorRgb8(0, 0, 0));
      }
    }
  }
  return img.encodePng(im);
}

String? decodeSingle(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

String? decodeRobust(List<int> bytes) {
  var image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  for (var scale = 1; scale <= 4; scale *= 2) {
    var work = image;
    if (scale > 1) {
      final resized = img.copyResize(image,
          width: image.width * scale,
          height: image.height * scale,
          interpolation: img.Interpolation.nearest);
      if (resized == null) return null;
      work = resized;
    }
    final pixels = work.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(work.width, work.height, pixels.buffer.asInt32List());
    for (final binarizer in [
      HybridBinarizer(source),
      GlobalHistogramBinarizer(source),
    ]) {
      try {
        final result = QRCodeReader().decode(BinaryBitmap(binarizer));
        if (result.text.isNotEmpty) return result.text;
      } catch (_) {}
    }
  }
  return null;
}

/// 假设：对模糊小二维码做「线性放大（非最近邻）+ 多二值化 + TRY_HARDER」能否救回。
String? decodeLinearUpscale(List<int> bytes) {
  var image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  for (final interp in [
    img.Interpolation.linear,
    img.Interpolation.cubic,
    img.Interpolation.average,
  ]) {
    for (var scale = 2; scale <= 8; scale *= 2) {
      final resized = img.copyResize(image,
          width: image.width * scale,
          height: image.height * scale,
          interpolation: interp);
      if (resized == null) continue;
      final pixels = resized.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      final source =
          RGBLuminanceSource(resized.width, resized.height, pixels.buffer.asInt32List());
      for (final binarizer in [
        HybridBinarizer(source),
        GlobalHistogramBinarizer(source),
      ]) {
        try {
          final hints = DecodeHints()..put(DecodeHintType.tryHarder);
          final result =
              QRCodeReader().decode(BinaryBitmap(binarizer), hints: hints);
          if (result.text.isNotEmpty) return result.text;
        } catch (_) {}
      }
    }
  }
  return null;
}

/// 逐步探测：精确记录哪个「放大倍率 × 插值 × 二值化」组合能救回，便于确定最小可用配置。
String probeLinear(List<int> bytes) {
  var image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return 'no-image';
  for (final interp in [
    img.Interpolation.linear,
    img.Interpolation.cubic,
    img.Interpolation.average,
  ]) {
    for (var scale = 2; scale <= 8; scale *= 2) {
      final resized = img.copyResize(image,
          width: image.width * scale,
          height: image.height * scale,
          interpolation: interp);
      if (resized == null) continue;
      final pixels = resized.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      final source =
          RGBLuminanceSource(resized.width, resized.height, pixels.buffer.asInt32List());
      for (final global in [false, true]) {
        try {
          final hints = DecodeHints()..put(DecodeHintType.tryHarder);
          final bitmap = BinaryBitmap(global
              ? GlobalHistogramBinarizer(source)
              : HybridBinarizer(source));
          final result = QRCodeReader().decode(bitmap, hints: hints);
          if (result.text.isNotEmpty) {
            return 'OK interp=${interp.index} x$scale ${global ? 'global' : 'hybrid'}';
          }
        } catch (_) {}
      }
    }
  }
  return 'FAIL';
}

void main() {
  Directory(_outDir).createSync(recursive: true);

  test('zxing2 编码→像素渲染→解码 回环诊断', () {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    // ignore: avoid_print
    print('qr data length=${data.length}');

    final qr = Encoder.encode(data, ErrorCorrectionLevel.m);
    // ignore: avoid_print
    print('qr version=${qr.version!.versionNumber}, dim=${qr.matrix!.width}');

    final png = encodePixelPerfectPng(data, modulePx: 8);
    File('$_outDir/zxing_roundtrip_m8.png').writeAsBytesSync(png);
    // ignore: avoid_print
    print('roundtrip single decode=${decodeSingle(png) == null ? "FAIL" : "OK"}');

    // 扫描最小可解码模块尺寸（2~6px/模块）
    for (var m = 2; m <= 6; m++) {
      final p = encodePixelPerfectPng(data, modulePx: m);
      final s = decodeSingle(p);
      final r = decodeRobust(p);
      // ignore: avoid_print
      print('module=${m}px total=${p.length ~/ 1024}KB single=${s == null ? "FAIL" : "OK"} robust=${r == null ? "FAIL" : "OK"}');
    }

    // 解码实际捕获的 PosterQr 图
    final cap = File('$_outDir/poster_qr_54_r36.png').readAsBytesSync();
    // ignore: avoid_print
    print('captured poster_qr single=${decodeSingle(cap) == null ? "FAIL" : "OK"} robust=${decodeRobust(cap) == null ? "FAIL" : "OK"} linearUpscale=${decodeLinearUpscale(cap) == null ? "FAIL" : "OK"}');
    // ignore: avoid_print
    print('probe => ${probeLinear(cap)}');
  });
}
