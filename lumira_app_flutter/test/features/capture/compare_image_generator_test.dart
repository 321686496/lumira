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

  test('generate produces a PNG wider than the input', () async {
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

    final bytes = await outputFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(400));
    codec.dispose();
  });
}
