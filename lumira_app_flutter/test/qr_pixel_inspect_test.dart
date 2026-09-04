import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:zxing2/qrcode.dart';

img.Image makeCleanQr(String data, {int scale = 8, int quietZone = 4}) {
  final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
  final qrImage = QrImage(code);
  final n = qrImage.moduleCount;
  final size = (n + quietZone * 2) * scale;
  final out = img.Image(width: size, height: size, numChannels: 3);
  img.fill(out, color: img.ColorRgb8(255, 255, 255)); // 白底安静区
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

String? decodeWith(img.Image image, String pipeline) {
  try {
    final LuminanceSource source;
    if (pipeline == 'luminance') {
      // ImageLuminanceSource 风格：pixel.luminance.round()
      final lum = Int8List(image.width * image.height);
      var i = 0;
      for (final px in image) {
        lum[i++] = px.luminance.round() - 128;
      }
      source = _LumSource(lum, image.width, image.height);
    } else {
      // RGBLuminanceSource 风格：RGBA + asInt32List
      final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    }
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text;
  } catch (e) {
    return 'ERR:$e';
  }
}

class _LumSource extends LuminanceSource {
  _LumSource(this._lum, int w, int h) : super(w, h);
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

void main() {
  test('检查像素数据 + 两种 luminance source', () {
    const data = 'hello world';
    final qr3 = makeCleanQr(data, scale: 8);
    // ignore: avoid_print
    print('qr3 ${qr3.width}x${qr3.height} channels=${qr3.numChannels}');
    // 检查几个像素
    final samples = <List<int>>[
      [0, 0],
      [10, 10],
      [100, 100]
    ];
    for (final s in samples) {
      final px = qr3.getPixel(s[0], s[1]);
      // ignore: avoid_print
      print('pixel(${s[0]},${s[1]}) r=${px.r} g=${px.g} b=${px.b} lum=${px.luminance}');
    }

    // ignore: avoid_print
    print('decode luminance = ${decodeWith(qr3, 'luminance')}');
    // ignore: avoid_print
    print('decode rgbaint32  = ${decodeWith(qr3, 'rgbaint32')}');

    // PNG 往返
    final png = img.encodePng(qr3);
    final back = img.decodeImage(png)!;
    // ignore: avoid_print
    print('png back ${back.width}x${back.height} channels=${back.numChannels}');
    // ignore: avoid_print
    print('decode png luminance = ${decodeWith(back, 'luminance')}');
    // ignore: avoid_print
    print('decode png rgbaint32 = ${decodeWith(back, 'rgbaint32')}');
  });
}
