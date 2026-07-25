import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/compare_image_generator.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('compare_gen_test_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  File makeTestJpeg(int width, int height, int r) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, r, 100, 100);
      }
    }
    final path = '${tempDir.path}/input_$r.jpg';
    File(path).writeAsBytesSync(img.encodeJpg(image));
    return File(path);
  }

  test('generate produces a PNG with correct dimensions for equal inputs',
      () async {
    // 输入 400×600，两张相同 → targetH=600, origW=filtW=400
    // totalW = 400 + 400 + 20*3 = 860
    // totalH = 600 + 40 + 20*2 = 680
    final input = makeTestJpeg(400, 600, 200);
    final outputPath = '${tempDir.path}/compare_out.png';

    final result = await CompareImageGenerator.generate(
      originalPath: input.path,
      filteredPath: input.path, // 用同一张图简化测试
      outputPath: outputPath,
    );

    expect(result, equals(outputPath));
    final outputFile = File(outputPath);
    expect(await outputFile.exists(), isTrue);
    // 文件非空（PNG header + 实际像素数据）
    expect((await outputFile.length()), greaterThan(1024));

    final bytes = await outputFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    // 宽度 = 两张图宽 + 3×padding（左/中/右）
    expect(frame.image.width, equals(860));
    // 高度 = targetH + labelH + 2×padding（顶/底）
    expect(frame.image.height, equals(680));
    codec.dispose();
  });

  test('generate unifies height when inputs have different dimensions',
      () async {
    // orig 400×600, filt 300×450 → targetH = min(600, 450) = 450
    // origW = 400 * 450 / 600 = 300, filtW = 300 * 450 / 450 = 300
    // totalW = 300 + 300 + 60 = 660, totalH = 450 + 40 + 40 = 530
    final orig = makeTestJpeg(400, 600, 200);
    final filt = makeTestJpeg(300, 450, 100);
    final outputPath = '${tempDir.path}/compare_diff.png';

    await CompareImageGenerator.generate(
      originalPath: orig.path,
      filteredPath: filt.path,
      outputPath: outputPath,
    );

    final bytes = await File(outputPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, equals(660));
    expect(frame.image.height, equals(530));
    codec.dispose();
  });
}
