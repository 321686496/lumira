import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:zxing2/qrcode.dart';

/// 用 qr 包生成干净的黑白二维码位图。
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

String? decode(img.Image image) {
  final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
  final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
  try {
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text.isEmpty ? null : result.text;
  } catch (e) {
    return 'ERR';
  }
}

void main() {
  test('zxing2 解码能力随数据长度的变化', () {
    final samples = <String, String>{
      '短': 'hello world',
      'URL短': 'https://lumira.app/tpl?name=portrait',
      'URL中': 'https://lumira.app/tpl?name=portrait&category=portrait&tags=a,b,c&seed=1234567890',
      'lumira短': 'lumira://tpl/abcd1234',
      'base64-50': 'lumira://tpl/' + List.generate(50, (_) => 'A').join(),
      'base64-100': 'lumira://tpl/' + List.generate(100, (_) => 'A').join(),
      'base64-200': 'lumira://tpl/' + List.generate(200, (_) => 'A').join(),
      'base64-300': 'lumira://tpl/' + List.generate(300, (_) => 'A').join(),
      'base64-400': 'lumira://tpl/' + List.generate(400, (_) => 'A').join(),
      'base64-500': 'lumira://tpl/' + List.generate(500, (_) => 'A').join(),
    };
    samples.forEach((label, data) {
      try {
        final clean = makeCleanQr(data, scale: 8);
        final ok = decode(clean);
        // ignore: avoid_print
        print('$label len=${data.length} modules=${((clean.width ~/ 8) - 8)} decode=$ok');
      } catch (e) {
        // ignore: avoid_print
        print('$label len=${data.length} GEN_FAIL:$e');
      }
    });
  });
}
