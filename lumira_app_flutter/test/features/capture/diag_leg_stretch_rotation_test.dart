// 诊断测试：定位「后期拉腿后照片旋转」根因。
// 复现真实拍摄场景：传感器 JPEG 为横向（landscape），设备竖屏持机（isPortrait=true）。
// 检查 processFile(legStretch>0) 输出是否仍是竖屏且内容方向正确。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('diag_leg_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  /// 生成「横向传感器 JPEG」：上 1/4 全红，下 3/4 全蓝，模拟人物场景的上下分布。
  /// [landscape] 为 true 时宽>高（真实传感器）；false 时宽<高（竖拍 JPEG）。
  File makeJpeg({required bool landscape, int w = 1440, int h = 1080}) {
    final iw = landscape ? w : h;
    final ih = landscape ? h : w;
    final image = img.Image(width: iw, height: ih);
    for (var y = 0; y < ih; y++) {
      final color = y < ih ~/ 4
          ? img.ColorRgb8(255, 0, 0) // 顶部红色
          : img.ColorRgb8(0, 0, 255); // 底部蓝色
      for (var x = 0; x < iw; x++) {
        image.setPixelRgba(x, y, color.r.toInt(), color.g.toInt(),
            color.b.toInt(), 255);
      }
    }
    final path =
        '${tempDir.path}/sensor_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final bytes = img.encodeJpg(image, quality: 92);
    File(path)..writeAsBytesSync(bytes);
    return File(path);
  }

  /// 解码输出 JPEG，返回 [width, height, 顶部颜色, 底部颜色]。
  Future<List<Object>> decodeInfo(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeJpg(bytes)!;
    final topColor = decoded.getPixel(decoded.width ~/ 2, 2);
    final bottomColor =
        decoded.getPixel(decoded.width ~/ 2, decoded.height - 2);
    return [
      decoded.width,
      decoded.height,
      [topColor.r.toInt(), topColor.g.toInt(), topColor.b.toInt()],
      [bottomColor.r.toInt(), bottomColor.g.toInt(), bottomColor.b.toInt()],
    ];
  }

  Future<void> run({
    required String name,
    required bool landscape,
    required bool isPortrait,
    required int legStretch,
    String aspectRatio = '4:3',
  }) async {
    final input = makeJpeg(landscape: landscape);
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
    final info = await decodeInfo(output);
    final w = info[0] as int;
    final h = info[1] as int;
    final top = info[2] as List<int>;
    final bottom = info[3] as List<int>;
    // ignore: avoid_print
    print('[$name] out=${w}x$h '
        '(${w > h ? "横向" : (h > w ? "竖屏" : "方形")}) '
        'top=$top bottom=$bottom');
  }

  test('diag: 横向传感器 + 竖屏 + legStretch=0', () async {
    await run(name: 'landscape-sensor-portrait-leg0', landscape: true, isPortrait: true, legStretch: 0);
  });

  test('diag: 横向传感器 + 竖屏 + legStretch=100', () async {
    await run(name: 'landscape-sensor-portrait-leg100', landscape: true, isPortrait: true, legStretch: 100);
  });

  test('diag: 竖拍JPEG + 竖屏 + legStretch=100', () async {
    await run(name: 'portrait-jpeg-portrait-leg100', landscape: false, isPortrait: true, legStretch: 100);
  });

  test('diag: 竖拍JPEG + 竖屏 + legStretch=0', () async {
    await run(name: 'portrait-jpeg-portrait-leg0', landscape: false, isPortrait: true, legStretch: 0);
  });
}
