// 决定性诊断：用四象限颜色图验证「后期拉腿后照片是否旋转 90°」。
// 输入：横向传感器 JPEG，四象限不同颜色（红/绿/蓝/黄）。
// 处理：PhotoPostProcessor.processFile(legStretch=100, isPortrait=true)。
// 输出：打印降采样网格，直接目视方向是否正确。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('diag_leg2_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  /// 四象限颜色图：横向传感器 1440x1080。
  /// 左上红 / 右上绿 / 左下蓝 / 右下黄（模拟「场景上下左右」）。
  File makeJpeg() {
    final iw = 1440;
    final ih = 1080;
    final image = img.Image(width: iw, height: ih);
    for (var y = 0; y < ih; y++) {
      for (var x = 0; x < iw; x++) {
        final left = x < iw ~/ 2;
        final top = y < ih ~/ 2;
        final c = left
            ? (top ? img.ColorRgb8(255, 0, 0) : img.ColorRgb8(0, 0, 255))
            : (top ? img.ColorRgb8(0, 255, 0) : img.ColorRgb8(255, 255, 0));
        image.setPixelRgba(x, y, c.r.toInt(), c.g.toInt(), c.b.toInt(), 255);
      }
    }
    final path =
        '${tempDir.path}/quad_${DateTime.now().microsecondsSinceEpoch}.jpg';
    File(path)..writeAsBytesSync(img.encodeJpg(image, quality: 92));
    return File(path);
  }

  /// 打印输出 JPEG 的降采样网格（cols x rows），每个格子显示主色缩写。
  String grid(String path, {int cols = 5, int rows = 7}) {
    final decoded = img.decodeJpg(File(path).readAsBytesSync())!;
    final w = decoded.width;
    final h = decoded.height;
    final sb = StringBuffer();
    sb.writeln('out=${w}x$h');
    for (var gy = 0; gy < rows; gy++) {
      final sy = ((gy + 0.5) * h / rows).clamp(0, h - 1).toInt();
      for (var gx = 0; gx < cols; gx++) {
        final sx = ((gx + 0.5) * w / cols).clamp(0, w - 1).toInt();
        final p = decoded.getPixel(sx, sy);
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        String c;
        if (r > 200 && g < 100 && b < 100) c = 'R';
        else if (r < 100 && g > 200 && b < 100) c = 'G';
        else if (r < 100 && g < 100 && b > 200) c = 'B';
        else if (r > 200 && g > 200 && b < 100) c = 'Y';
        else c = '.';
        sb.write(c);
      }
      sb.writeln();
    }
    return sb.toString();
  }

  Future<void> run({
    required String name,
    required bool isPortrait,
    required int legStretch,
    String aspectRatio = 'fullscreen',
  }) async {
    final input = makeJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: PostProcess(
        color: const PostProcessColor(),
        legStretch: legStretch,
      ),
      aspectRatio: aspectRatio,
      screenRatio: 9.0 / 19.5,
      isPortrait: isPortrait,
    );
    // ignore: avoid_print
    print('[$name]');
    // ignore: avoid_print
    print(grid(output));
  }

  test('diag2: 横向传感器+竖屏+legStretch=100 (全屏)', () async {
    await run(name: 'landscape-portrait-leg100-fullscreen',
        isPortrait: true, legStretch: 100);
  });

  test('diag2: 横向传感器+竖屏+legStretch=0 (全屏)', () async {
    await run(name: 'landscape-portrait-leg0-fullscreen',
        isPortrait: true, legStretch: 0);
  });

  test('diag2: 横向传感器+竖屏+legStretch=100 (4:3)', () async {
    await run(name: 'landscape-portrait-leg100-4x3',
        isPortrait: true, legStretch: 100, aspectRatio: '4:3');
  });

  test('diag2: 竖拍JPEG+竖屏+legStretch=100 (全屏)', () async {
    final image = img.Image(width: 1080, height: 1440);
    for (var y = 0; y < 1440; y++) {
      for (var x = 0; x < 1080; x++) {
        final left = x < 540;
        final top = y < 720;
        final c = left
            ? (top ? img.ColorRgb8(255, 0, 0) : img.ColorRgb8(0, 0, 255))
            : (top ? img.ColorRgb8(0, 255, 0) : img.ColorRgb8(255, 255, 0));
        image.setPixelRgba(x, y, c.r.toInt(), c.g.toInt(), c.b.toInt(), 255);
      }
    }
    final path = '${tempDir.path}/portrait_${DateTime.now().microsecondsSinceEpoch}.jpg';
    File(path)..writeAsBytesSync(img.encodeJpg(image, quality: 92));
    final output = await PhotoPostProcessor.processFile(
      inputPath: path,
      params: PostProcess(
        color: const PostProcessColor(),
        legStretch: 100,
      ),
      aspectRatio: 'fullscreen',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    // ignore: avoid_print
    print('[portrait-jpeg-portrait-leg100-fullscreen]');
    // ignore: avoid_print
    print(grid(output));
  });
}
