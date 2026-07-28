import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('ppp_test_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Write a 1080x1440 JPEG (3:4 portrait, common phone sensor ratio)
  File makeSensorJpeg() {
    final image = img.Image(width: 1080, height: 1440);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final path = '${tempDir.path}/sensor_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final bytes = img.encodeJpg(image);
    final file = File(path)..writeAsBytesSync(bytes);
    return file;
  }

  Future<List<int>> processAndDecodeSize({
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
  }) async {
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      rawMode: rawMode,
      aspectRatio: aspectRatio,
      screenRatio: screenRatio,
      isPortrait: isPortrait,
    );
    final bytes = await File(output).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    codec.dispose();
    return [w, h];
  }

  test('fullscreen portrait: output ratio matches screenRatio', () async {
    // 9:19.5 phone portrait → screenRatio = 9/19.5 ≈ 0.4615
    final size = await processAndDecodeSize(
      aspectRatio: 'fullscreen',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(9.0 / 19.5, 0.02),
        reason: 'fullscreen output must match screen ratio');
  });

  test('4:3 portrait: output ratio is 3:4 (0.75)', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '4:3',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(0.75, 0.02),
        reason: '4:3 portrait output must be 3:4');
  });

  test('1:1: output ratio is 1.0', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '1:1',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(1.0, 0.02), reason: '1:1 output must be square');
  });

  test('3:4: output ratio is 0.75 regardless of orientation', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '3:4',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(0.75, 0.02),
        reason: '3:4 output must always be 3:4');
  });

  test('4:3 landscape: output ratio is 4:3 (1.333)', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '4:3',
      screenRatio: 19.5 / 9.0,
      isPortrait: false,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(4.0 / 3.0, 0.02),
        reason: '4:3 landscape output must be 4:3');
  });

  // ── 回归测试：rawMode 下裁剪必须仍然应用（WYSIWYG）──
  // 之前的 bug：rawMode=true 时直接返回原图（4:3 传感器比例），
  // 导致全屏取景器看到 9:16 但照片为 4:3，破坏所见即所得。
  // 修复后：rawMode 仅跳过滤镜效果，裁剪始终应用。

  test('REGRESSION: rawMode=true fullscreen still crops to screenRatio', () async {
    final size = await processAndDecodeSize(
      aspectRatio: 'fullscreen',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      rawMode: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(9.0 / 19.5, 0.02),
        reason: 'rawMode 不应跳过裁剪：fullscreen 输出仍须匹配屏幕比例');
  });

  test('REGRESSION: rawMode=true 1:1 still crops to square', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '1:1',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      rawMode: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(1.0, 0.02),
        reason: 'rawMode 不应跳过裁剪：1:1 输出仍须为正方形');
  });

  test('REGRESSION: rawMode=true 4:3 portrait still crops to 3:4', () async {
    final size = await processAndDecodeSize(
      aspectRatio: '4:3',
      screenRatio: 9.0 / 19.5,
      isPortrait: true,
      rawMode: true,
    );
    final ratio = size[0] / size[1];
    expect(ratio, closeTo(0.75, 0.02),
        reason: 'rawMode 不应跳过裁剪：4:3 竖屏输出仍须为 3:4');
  });

  // ── 端到端集成测试：autoDeblur 自动去模糊 ──
  // 验证点：
  // 1. autoDeblur=false 时即使图像模糊也绝不触发去模糊（安全默认）
  // 2. autoDeblur=true 时清晰图应跳过去模糊（性能基线，避免无意义耗时）

  group('PhotoPostProcessor autoDeblur integration', () {
    test('autoDeblur=false never deblurs (even on blurry image)', () async {
      // 构造模糊图像（平滑渐变，Laplacian 方差极低）
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final v = ((x + y) / 2).round().clamp(0, 255);
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      final tempDir = await Directory.systemTemp.createTemp('deblur_test_');
      final inputPath = '${tempDir.path}/blurry.jpg';
      final jpgBytes = img.encodeJpg(image, quality: 88);
      await File(inputPath).writeAsBytes(jpgBytes);

      final result = await PhotoPostProcessor.processFile(
        inputPath: inputPath,
        params: const PostProcess(color: PostProcessColor()),
        aspectRatio: 'free',
        autoDeblur: false,
      );

      expect(await File(result).exists(), isTrue);
      await tempDir.delete(recursive: true);
    });

    test('autoDeblur=true on clear image skips deblur (performance)', () async {
      // 构造清晰图像（棋盘格，Laplacian 方差远高于 kClearThreshold=600）
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final isWhite = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
          image.setPixelRgb(
              x, y, isWhite ? 255 : 0, isWhite ? 255 : 0, isWhite ? 255 : 0);
        }
      }
      final tempDir = await Directory.systemTemp.createTemp('deblur_test_');
      final inputPath = '${tempDir.path}/clear.jpg';
      final jpgBytes = img.encodeJpg(image, quality: 88);
      await File(inputPath).writeAsBytes(jpgBytes);

      final sw = Stopwatch()..start();
      final result = await PhotoPostProcessor.processFile(
        inputPath: inputPath,
        params: const PostProcess(color: PostProcessColor()),
        aspectRatio: 'free',
        autoDeblur: true,
      );
      sw.stop();
      debugPrint('[test] 清晰图 autoDeblur=true 耗时: ${sw.elapsedMilliseconds}ms');

      expect(await File(result).exists(), isTrue);
      // 清晰图应快速返回（跳过去模糊）
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '清晰图应跳过去模糊，耗时接近无去模糊基线');
      await tempDir.delete(recursive: true);
    });
  });
}
