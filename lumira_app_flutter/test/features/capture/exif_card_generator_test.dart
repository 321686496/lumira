import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/exif_card_generator.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('exif_card_test_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  test('generate produces a PNG file', () async {
    final image = img.Image(width: 600, height: 800);
    for (var y = 0; y < 800; y++) {
      for (var x = 0; x < 600; x++) {
        image.setPixelRgb(x, y, 150, 150, 150);
      }
    }
    final inputPath = '${tempDir.path}/input.jpg';
    File(inputPath).writeAsBytesSync(img.encodeJpg(image));

    final outputPath = '${tempDir.path}/exif_card.png';
    final result = await ExifCardGenerator.generate(
      photoPath: inputPath,
      outputPath: outputPath,
      exif: const ExifInfo(
        cameraModel: 'HarmonyOS Phone',
        focalLength: '5.4mm',
        fNumber: 'f/1.8',
        iso: 'ISO 100',
        shutterSpeed: '1/200s',
        timestamp: '2026-07-25 11:20',
        sceneName: '人像',
        template: '人像模板 A',
      ),
    );

    expect(result, equals(outputPath));
    expect(await File(outputPath).exists(), isTrue);

    // 额外校验：输出是有效 PNG，且尺寸为 1080x1620
    final bytes = await File(outputPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, equals(1080));
    expect(frame.image.height, equals(1620));
    codec.dispose();
  });
}
