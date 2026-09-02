import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../lib/features/capture/services/skin_smoother.dart';

double _std(img.Image im, int x0, int y0, int x1, int y1) {
  var sum = 0.0, n = 0.0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final p = im.getPixel(x, y);
      sum += (p.r + p.g + p.b) / 3.0;
      n += 1;
    }
  }
  final mean = n == 0 ? 0 : sum / n;
  var s = 0.0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final p = im.getPixel(x, y);
      final d = (p.r + p.g + p.b) / 3.0 - mean;
      s += d * d;
    }
  }
  return n == 0 ? 0 : math.sqrt(s / n);
}

void main() {
  const w = 1536, h = 1536;
  final rnd = math.Random(11);
  final src = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inSkin = (x - w ~/ 2).abs() < 260 && (y - h ~/ 2).abs() < 260;
      if (inSkin) {
        src.setPixelRgb(x, y,
          210 + rnd.nextInt(21) - 10, 168 + rnd.nextInt(21) - 10, 150 + rnd.nextInt(21) - 10);
      } else {
        final v = 120 + rnd.nextInt(96);
        src.setPixelRgb(x, y, v, v, v);
      }
    }
  }
  final reference = src.clone(); // 平滑前快照（不受 in-place 污染）

  final sw = Stopwatch()..start();
  final out = SkinSmoother.smooth(src, 80);
  sw.stop();

  final skinStdBefore = _std(reference, w ~/ 2 - 200, h ~/ 2 - 200, w ~/ 2 + 200, h ~/ 2 + 200);
  final skinStdAfter = _std(out, w ~/ 2 - 200, h ~/ 2 - 200, w ~/ 2 + 200, h ~/ 2 + 200);
  final bgStdBefore = _std(reference, 40, 40, 340, 340);
  final bgStdAfter = _std(out, 40, 40, 340, 340);

  // 背景区域像素与参考逐点比对（应 0 处不同）。
  var bgDiffPixels = 0;
  for (var y = 40; y < 340; y++) {
    for (var x = 40; x < 340; x++) {
      final a = reference.getPixel(x, y);
      final b = out.getPixel(x, y);
      if (a.r != b.r || a.g != b.g || a.b != b.b) bgDiffPixels++;
    }
  }

  print('皮肤std(毛孔噪声): ${skinStdBefore.toStringAsFixed(2)} -> '
      '${skinStdAfter.toStringAsFixed(2)} (磨掉 ${(100 * (1 - skinStdAfter / skinStdBefore)).toStringAsFixed(0)}%)');
  print('背景std: ${bgStdBefore.toStringAsFixed(2)} -> ${bgStdAfter.toStringAsFixed(2)}  背景差异像素=$bgDiffPixels (应=0)');
  print('smooth 总耗时=${sw.elapsedMilliseconds}ms');
}