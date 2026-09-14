import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/preview_beauty_shader.dart';
import 'package:lumira_app_flutter/features/capture/widgets/detail_effects_layer.dart';

Future<ui.Image> _decodeImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<ui.Image> _paint(DetailEffectsPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Size(64, 64));
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  picture.dispose();
  return image;
}

void main() {
  testWidgets('detail shader changes pixels', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('detail_shader_paint');
    final source = img.Image(width: 64, height: 64);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x < 32 ? 80 : 200, 120, 90);
      }
    }
    final path =
        '${tempDir.path}${Platform.pathSeparator}source.png';
    File(path).writeAsBytesSync(img.encodePng(source));
    final image = (await tester.runAsync(() => _decodeImage(path)))!;
    final noise = await tester.runAsync(loadGrainNoiseTile);
    final program = await tester.runAsync(
      () => loadFragmentProgramFromCandidates(const [
        'assets/shaders/edit_detail_effects.frag',
        'shaders/edit_detail_effects.frag',
      ]),
    );
    expect(program, isNotNull);
    expect(noise, isNotNull);

    final basePainter = DetailEffectsPainter(
      image: image,
      noise: noise!,
      effects: const DetailEffectsParams(),
      program: program!,
    );
    final sharpenPainter = DetailEffectsPainter(
      image: image,
      noise: noise,
      effects: const DetailEffectsParams(sharpen: 100),
      program: program,
    );
    final base = (await tester.runAsync(() => _paint(basePainter)))!;
    final sharpened = (await tester.runAsync(() => _paint(sharpenPainter)))!;
    final baseBytes = await tester.runAsync(() => base.toByteData());
    final sharpenBytes = await tester.runAsync(() => sharpened.toByteData());
    expect(sharpenBytes, isNot(equals(baseBytes)));
    image.dispose();
    base.dispose();
    sharpened.dispose();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });
}
