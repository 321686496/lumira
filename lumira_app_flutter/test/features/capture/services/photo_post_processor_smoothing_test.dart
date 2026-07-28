import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ppp_smooth_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> createTestJpeg(String path, {int width = 200, int height = 200}) async {
    final image = img.Image(width: width, height: height);
    final random = DateTime.now().millisecondsSinceEpoch;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final v = ((x + y + random) % 256);
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    final bytes = img.encodeJpg(image);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  test('smoothStrength=0 skips smoothing (no change)', () async {
    final inputPath = p.join(tempDir.path, 'no_smooth.jpg');
    await createTestJpeg(inputPath);

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
      smoothStrength: 0,
    );

    final result = await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
    );

    expect(result, inputPath);
    expect(await File(inputPath).exists(), isTrue);
  });

  test('smoothStrength=50 processes without error', () async {
    final inputPath = p.join(tempDir.path, 'with_smooth.jpg');
    await createTestJpeg(inputPath);

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
      smoothStrength: 50,
    );

    final result = await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
    );

    expect(result, inputPath);
    // Verify output is a valid JPEG
    final bytes = await File(inputPath).readAsBytes();
    expect(img.decodeImage(bytes), isNotNull);
  });

  test('smoothStrength=100 processes without error', () async {
    final inputPath = p.join(tempDir.path, 'max_smooth.jpg');
    await createTestJpeg(inputPath);

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
      smoothStrength: 100,
    );

    await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
    );

    final bytes = await File(inputPath).readAsBytes();
    expect(img.decodeImage(bytes), isNotNull);
  });
}
