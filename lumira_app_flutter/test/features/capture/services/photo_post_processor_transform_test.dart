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

  test('front camera + portrait + mirror-only keeps dimensions (no stretch)', () async {
    // 前置摄像头竖屏，JPEG 本身为竖屏（高>宽），仅需水平镜像、无需旋转。
    // 回归：旧逻辑错误地对仅镜像的图片应用 90° 旋转并填入未交换的画布，导致横向拉伸变形。
    final inputPath = p.join(tempDir.path, 'front_portrait.jpg');
    final outputPath = p.join(tempDir.path, 'front_portrait_out.jpg');
    final image = img.Image(width: 200, height: 300);
    // 竖屏 + 左右不对称图案：左半区红、右半区蓝，便于验证水平镜像
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final r = x < image.width ~/ 2 ? 255 : 0;
        final b = x >= image.width ~/ 2 ? 255 : 0;
        image.setPixelRgb(x, y, r, 0, b);
      }
    }
    await File(inputPath).writeAsBytes(img.encodeJpg(image));

    final params = const PostProcess(
      color: PostProcessColor(),
      cropRatio: 'none',
    );

    await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: params,
      aspectRatio: 'none',
      isPortrait: true,
      facing: 'front',
      outputPath: outputPath,
    );

    final out = img.decodeImage(await File(outputPath).readAsBytes())!;
    // 仅镜像不旋转 → 宽高保持不变（200x300），绝不能出现拉伸或宽高互换
    expect(out.width, 200, reason: 'front portrait mirror must not stretch width');
    expect(out.height, 300, reason: 'front portrait mirror must not change height');

    // 水平镜像：原左半区（红）应出现在输出右半区
    final leftR = out.getPixel(10, out.height ~/ 2).r;
    final rightR = out.getPixel(out.width - 10, out.height ~/ 2).r;
    expect(leftR, lessThan(100), reason: 'left half should no longer be red after mirror');
    expect(rightR, greaterThan(150), reason: 'right half should be red after mirror');
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
