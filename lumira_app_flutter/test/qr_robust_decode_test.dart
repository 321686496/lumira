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

/// 现行单策略解码。
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

/// 多策略 + 最近邻放大：模拟微信式鲁棒解码。
String? decodeRobust(List<int> bytes) {
  var image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;

  final attempts = <String>[];
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
    final pixels = work
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.rgba);
    final source =
        RGBLuminanceSource(work.width, work.height, pixels.buffer.asInt32List());
    for (final binarizer in [
      HybridBinarizer(source),
      GlobalHistogramBinarizer(source),
    ]) {
      try {
        final result = QRCodeReader().decode(BinaryBitmap(binarizer));
        if (result.text.isNotEmpty) return result.text;
      } catch (_) {
        attempts.add('${work.width}x$scale');
      }
    }
  }
  // ignore: avoid_print
  print('robust attempts failed: ${attempts.join(', ')}');
  return null;
}

void main() {
  test('多策略 + 最近邻放大能否解码失败的海报 QR', () {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());
    final bytes = File('$_outDir/poster_qr_54_r36.png').readAsBytesSync();
    // ignore: avoid_print
    print('single decode=${decodeSingle(bytes) == null ? 'FAIL' : 'OK'}');
    // ignore: avoid_print
    print('robust decode=${decodeRobust(bytes) == null ? 'FAIL' : 'OK'}');
  });
}
