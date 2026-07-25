import 'dart:io';
import 'dart:ui' as ui;

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
  }) async {
    final input = makeSensorJpeg();
    final output = await PhotoPostProcessor.processFile(
      inputPath: input.path,
      params: const PostProcess(color: PostProcessColor()),
      rawMode: false,
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
}
