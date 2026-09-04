import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/shared/services/qr_decoder.dart';
import 'package:zxing2/qrcode.dart';

const _outDir = 'build/qr_fix_verify';

int otsuFromHist(List<int> hist, int total) {
  var sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0, wB = 0;
  var maxVariance = -1.0;
  var threshold = 128;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final variance = wB * wF * (mB - mF) * (mB - mF);
    if (variance > maxVariance) {
      maxVariance = variance;
      threshold = t;
    }
  }
  return threshold;
}

/// 快速路径：原图 → RGBA → HybridBinarizer 解码。
String? attempt(img.Image image, {bool tryHarder = false}) {
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final hints = tryHarder ? (DecodeHints()..put(DecodeHintType.tryHarder)) : null;
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)), hints: hints);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

/// 基于 RGBA int32（与 zxing 同公式）算亮度 → 阈值二值化 → 解码。
String? decodeThresholdLum(
  img.Image image, {
  bool tryHarder = false,
  List<int>? thresholds,
}) {
  try {
    final n = image.width * image.height;
    final rgba = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final src = rgba.buffer.asInt32List();
    final lum = Int32List(n);
    final hist = List<int>.filled(256, 0);
    for (var i = 0; i < n; i++) {
      final p = src[i];
      final r = p & 0xff;
      final g = (p >> 8) & 0xff;
      final b = (p >> 16) & 0xff;
      final l = (0.299 * r + 0.587 * g + 0.114 * b).round();
      lum[i] = l;
      hist[l]++;
    }
    final otsu = otsuFromHist(hist, n);
    final ths = thresholds ?? [otsu, 128, otsu + 24, 96, 160];
    for (final th in ths) {
      if (th < 0 || th > 255) continue;
      try {
        final bin = Int32List(n);
        for (var i = 0; i < n; i++) {
          bin[i] = lum[i] > th ? 0xFFFFFFFF : 0xFF000000;
        }
        final source = RGBLuminanceSource(image.width, image.height, bin);
        final hints = tryHarder ? (DecodeHints()..put(DecodeHintType.tryHarder)) : null;
        final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)), hints: hints);
        final text = result.text;
        if (text.isNotEmpty) return text;
      } catch (_) {
        // 该阈值下解码失败，尝试下一个阈值
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

String? decodeLinear2x(img.Image image, {bool tryHarder = false}) {
  try {
    final up = img.copyResize(image,
        width: image.width * 2,
        height: image.height * 2,
        interpolation: img.Interpolation.linear);
    final pixels = up.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(up.width, up.height, pixels.buffer.asInt32List());
    final hints = tryHarder ? (DecodeHints()..put(DecodeHintType.tryHarder)) : null;
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)), hints: hints);
    final text = result.text;
    return text.isNotEmpty ? text : null;
  } catch (_) {
    return null;
  }
}

void main() {
  Directory(_outDir).createSync(recursive: true);

  test('阈值二值化 + linear2x 方案验证', () {
    final cap = File('$_outDir/poster_qr_54_r36.png').readAsBytesSync();
    final pC = File('$_outDir/pC_full_1080.png').readAsBytesSync();

    for (final entry in {'poster_qr(194px)': cap, 'pC_full(1080w)': pC}.entries) {
      final image = img.decodeImage(Uint8List.fromList(entry.value))!;
      print('[${entry.key}] ${image.width}x${image.height}');

      void probe(String label, String? r, int ms) {
        print('  $label: ${r == null ? 'FAIL' : 'OK'} ${ms}ms');
      }

      var sw = Stopwatch()..start();
      final fast = attempt(image);
      sw.stop();
      probe('fast', fast, sw.elapsedMilliseconds);

      sw = Stopwatch()..start();
      final fastTh = attempt(image, tryHarder: true);
      sw.stop();
      probe('fast TH', fastTh, sw.elapsedMilliseconds);

      sw = Stopwatch()..start();
      final tNoTh = decodeThresholdLum(image);
      sw.stop();
      probe('thresholdLum(no TH)', tNoTh, sw.elapsedMilliseconds);

      sw = Stopwatch()..start();
      final tTh = decodeThresholdLum(image, tryHarder: true);
      sw.stop();
      probe('thresholdLum(TH)', tTh, sw.elapsedMilliseconds);

      sw = Stopwatch()..start();
      final l2 = decodeLinear2x(image);
      sw.stop();
      probe('linear2x(no TH)', l2, sw.elapsedMilliseconds);

      sw = Stopwatch()..start();
      final l2Th = decodeLinear2x(image, tryHarder: true);
      sw.stop();
      probe('linear2x(TH)', l2Th, sw.elapsedMilliseconds);

      // 复刻之前成功的手写 setPixel 阈值方案，与 Int32List 方案对比
      final g2 = img.grayscale(image);
      final binImg = img.Image(width: image.width, height: image.height);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final l = img.getLuminance(g2.getPixel(x, y));
          binImg.setPixel(x, y,
              l > 128 ? img.ColorRgb8(255, 255, 255) : img.ColorRgb8(0, 0, 0));
        }
      }
      sw = Stopwatch()..start();
      final rSet = attempt(binImg);
      sw.stop();
      probe('setPixel bin(128)+attempt', rSet, sw.elapsedMilliseconds);

      sw = Stopwatch()..start();
      final pxl = binImg.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      final src2 = RGBLuminanceSource(binImg.width, binImg.height, pxl.buffer.asInt32List());
      String? rDirect;
      try {
        rDirect = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(src2))).text;
      } catch (_) {}
      sw.stop();
      probe('binImg->direct RGBLum',
          (rDirect == null || rDirect.isEmpty) ? null : rDirect, sw.elapsedMilliseconds);

      // 对比我的亮度数组 vs getLuminance(grayscale) 的分类差异（th=128）
      final rgba2 = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      final src3 = rgba2.buffer.asInt32List();
      final g3 = img.grayscale(image);
      var diff = 0;
      var total = 0;
      for (var y = 0; y < image.height; y += 3) {
        for (var x = 0; x < image.width; x += 3) {
          final p = src3[y * image.width + x];
          final lMine = (((p >> 16) & 0xff) + ((p >> 7) & 0x1fe) + (p & 0xff)) >> 2;
          final lRef = img.getLuminance(g3.getPixel(x, y));
          if ((lMine > 128) != (lRef > 128)) diff++;
          total++;
        }
      }
      print('  亮度分类差异(采样): $diff/$total');
    }
  });

  test('共享服务 decodeQrFromBytes 端到端耗时（用户真实体验路径）', () {
    final cap = File('$_outDir/poster_qr_54_r36.png').readAsBytesSync();
    final pC = File('$_outDir/pC_full_1080.png').readAsBytesSync();
    for (final entry in {'poster_qr(194px)': cap, 'pC_full(1080w)': pC}.entries) {
      final sw = Stopwatch()..start();
      final r = decodeQrFromBytes(entry.value);
      sw.stop();
      print('[${entry.key}] decodeQrFromBytes: ${r == null ? 'FAIL' : 'OK'} ${sw.elapsedMilliseconds}ms');
      expect(r, isNotNull, reason: '共享解码服务必须能识别 ${entry.key}');
    }
  });
}
