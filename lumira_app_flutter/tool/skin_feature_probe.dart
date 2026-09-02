// 磨皮"抖音式"验证探针：用一张合成的"人脸"验证——
//   A. 皮肤区域的细毛孔被真正磨掉（肤色方差下降）
//   B. 五官/高对比结构几乎不被破坏（五官区域与原图差异极小）
//   C. 背景（非肤色）100% 保留
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../lib/features/capture/services/skin_smoother.dart';

double _stdOf(img.Image im, List<(int, int)> pts) {
  double sum = 0; int n = 0;
  for (final (x, y) in pts) { sum += (im.getPixel(x, y).r + im.getPixel(x, y).g + im.getPixel(x, y).b) / 3.0; n++; }
  final mean = sum / n;
  double s = 0;
  for (final (x, y) in pts) { final d = (im.getPixel(x, y).r + im.getPixel(x, y).g + im.getPixel(x, y).b) / 3.0 - mean; s += d * d; }
  return math.sqrt(s / n);
}

void main() {
  const w = 512, h = 512;
  final rnd = math.Random(7);
  final src = img.Image(width: w, height: h);
  // 整张为肤色底 + 细毛孔噪声
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final r = (205 + rnd.nextInt(17) - 8).clamp(0, 255);
      final g = (160 + rnd.nextInt(17) - 8).clamp(0, 255);
      final b = (140 + rnd.nextInt(17) - 8).clamp(0, 255);
      src.setPixelRgb(x, y, r, g, b);
    }
  }
  // 五官/结构：深色"眼睛"椭圆 + 深色"眉毛"横条 + 深色"唇线"（均非肤色，应原样保留）
  bool inFeature(int x, int y) {
    final dx = x - 256.0, dy = y - 260.0;
    // 眼睛：以(240,240)为中心的深色椭圆
    final ex = x - 200.0, ey = y - 210.0;
    final inEye = (ex * ex) / (34 * 34) + (ey * ey) / (26 * 26) <= 1.0;
    final inEye2 = (	(x - 308.0) * (x - 308.0)) / (34 * 34) + ((y - 210.0) * (y - 210.0)) / (26 * 26) <= 1.0;
    // 眉毛宽条
    final inBrow = (y > 140 && y < 158 && x > 170 && x < 340);
    // 唇
    final inLip = (math.sqrt(((x - 255) * (x - 255)) / (36 * 36) + ((y - 348) * (y - 348)) / (14 * 14)) <= 1.0);
    return inEye || inEye2 || inBrow || inLip;
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (inFeature(x, y)) src.setPixelRgb(x, y, 55, 42, 34); // 深色五官
    }
  }
  // 右下角灰色背景块（非肤色）
  for (var y = h - 150; y < h; y++) {
    for (var x = w - 150; x < w; x++) {
      if (!inFeature(x, y)) src.setPixelRgb(x, y, 128, 128, 128);
    }
  }

  final skinPts = <(int, int)>[];
  final rnd2 = math.Random(99);
  for (var i = 0; i < 4000; i++) {
    final x = rnd2.nextInt(240) + 20, y = rnd2.nextInt(100) + 20; // 左上空旷肤色区，避开五官
    if (!inFeature(x, y)) {
      skinPts.add((x, y));
    }
  }
  // 五官采样点
  var featChanged = 0, featCount = 0;
  double featMaxDiff = 0;

  final sw = Stopwatch()..start();
  final out = SkinSmoother.smooth(src, 70);
  sw.stop();

  for (var y = 140; y < 370; y++) {
    for (var x = 120; x < 390; x++) {
      if (inFeature(x, y)) {
        final a = src.getPixel(x, y);
        final b = out.getPixel(x, y);
        final d = (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
        featCount++;
        if (d > 30) featChanged++;
        if (d > featMaxDiff) featMaxDiff = d;
      }
    }
  }
  // 背景差异
  var bgDiff = 0;
  for (var y = h - 120; y < h - 20; y++) {
    for (var x = w - 120; x < w - 20; x++) {
      final a = src.getPixel(x, y);
      final b = out.getPixel(x, y);
      if (a.r != b.r || a.g != b.g || a.b != b.b) bgDiff++;
    }
  }

  print('皮肤std(毛孔噪声): ${_stdOf(src, skinPts).toStringAsFixed(2)} -> '
      '${_stdOf(out, skinPts).toStringAsFixed(2)} '
      '(磨掉 ${(100 * (1 - _stdOf(out, skinPts) / _stdOf(src, skinPts))).toStringAsFixed(0)}%)');
  print('五官破坏: ${featChanged}/$featCount 个像素位移>30 (理想≈0)  最大位移=${featMaxDiff.toStringAsFixed(0)}');
  print('背景差异像素=$bgDiff (应=0)  smooth 总耗时=${sw.elapsedMilliseconds}ms');
}