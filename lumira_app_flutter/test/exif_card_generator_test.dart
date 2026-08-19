import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/exif_card_generator.dart';

Future<String> _createTestPhoto(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFE04040), // 纯红照片
  );
  final img = await recorder.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  final dir = await Directory.systemTemp.createTemp('exif_src');
  final path = '${dir.path}/photo.png';
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  return path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生成 1080x1620 海报且竖图照片铺满无左右留白', () async {
    final photoPath = await _createTestPhoto(100, 200); // 竖图（旧实现左右留白大）
    final outDir = await Directory.systemTemp.createTemp('exif_out');
    final outPath = '${outDir.path}/card.png';

    await ExifCardGenerator.generate(
      photoPath: photoPath,
      outputPath: outPath,
      exif: const ExifInfo(
        cameraModel: 'HUAWEI P50',
        focalLength: '35mm',
        fNumber: 'f/1.8',
        iso: 'ISO 200',
        shutterSpeed: '1/200s',
        timestamp: '2026-08-19 10:00',
        sceneName: '人像',
        template: '经典人像',
      ),
    );

    final bytes = await File(outPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    try {
      expect(img.width, 1080);
      expect(img.height, 1620);

      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = data!.buffer.asUint8List();
      ui.Color px(int x, int y) {
        final i = (y * img.width + x) * 4;
        return ui.Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
      }

      // 照片区：中间 + 左边缘 都应是照片红色（铺满，无白边）
      final mid = px(540, 600);
      expect(mid.red, greaterThan(200));
      expect(mid.green, lessThan(100));
      expect(mid.blue, lessThan(100));

      final leftEdge = px(2, 600);
      expect(leftEdge.red, greaterThan(200));
      expect(leftEdge.green, lessThan(100));
      expect(leftEdge.blue, lessThan(100));

      // 标题区背景：深色（0xFF1C1A17）
      final topBg = px(2, 20);
      expect(topBg.red, lessThan(80));
    } finally {
      img.dispose();
      codec.dispose();
    }
  });
}
