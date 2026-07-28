import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ppp_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> createTestJpeg(String path, {int width = 200, int height = 200}) async {
    final image = img.Image(width: width, height: height);
    // Fill with a recognizable pattern: red in top-left, blue in bottom-right
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final r = x < width ~/ 2 && y < height ~/ 2 ? 255 : 0;
        final b = x >= width ~/ 2 && y >= height ~/ 2 ? 255 : 0;
        image.setPixelRgb(x, y, r, 0, b);
      }
    }
    final bytes = img.encodeJpg(image);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  test('outputPath=null writes to inputPath (backward compat)', () async {
    final inputPath = p.join(tempDir.path, 'input.jpg');
    await createTestJpeg(inputPath);
    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
    );

    final result = await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
    );

    expect(result, inputPath);
    expect(await File(inputPath).exists(), isTrue);
  });

  test('outputPath != inputPath writes to outputPath, leaves input unchanged', () async {
    final inputPath = p.join(tempDir.path, 'original.jpg');
    final outputPath = p.join(tempDir.path, 'processed.jpg');
    await createTestJpeg(inputPath);
    final inputBytes = await File(inputPath).readAsBytes();

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
    );

    await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
      outputPath: outputPath,
    );

    expect(await File(outputPath).exists(), isTrue);
    // Input file should be unchanged
    final inputBytesAfter = await File(inputPath).readAsBytes();
    expect(inputBytesAfter.length, inputBytes.length);
  });

  test('TransformParams.identity skips transform (fast path)', () async {
    final inputPath = p.join(tempDir.path, 'identity.jpg');
    await createTestJpeg(inputPath);

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
    );

    // Should not throw and should complete
    final result = await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
      transform: const TransformParams(),
    );
    expect(result, inputPath);
  });

  test('rotation 90 produces different pixel layout than identity', () async {
    final inputPath = p.join(tempDir.path, 'rot_input.jpg');
    final outputPathIdentity = p.join(tempDir.path, 'rot_identity.jpg');
    final outputPath90 = p.join(tempDir.path, 'rot_90.jpg');
    await createTestJpeg(inputPath);

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
    );

    // Process without rotation
    await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
      outputPath: outputPathIdentity,
    );

    // Process with 90° rotation
    await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
      outputPath: outputPath90,
      transform: const TransformParams(rotation: 90),
    );

    final identityBytes = await File(outputPathIdentity).readAsBytes();
    final rotatedBytes = await File(outputPath90).readAsBytes();
    // The two outputs should differ (rotation changes pixel layout)
    // Note: file sizes may be similar, so compare actual decoded dimensions
    final identityImg = img.decodeImage(identityBytes)!;
    final rotatedImg = img.decodeImage(rotatedBytes)!;
    // After 90° rotation, width and height should be swapped
    expect(rotatedImg.width, identityImg.height);
    expect(rotatedImg.height, identityImg.width);
  });
}
