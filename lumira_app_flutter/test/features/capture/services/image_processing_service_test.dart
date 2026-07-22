// test/features/capture/services/image_processing_service_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/image_processing_service.dart';

void main() {
  /// 创建一张纯色测试图像（width × height，填充指定 RGBA 像素值）。
  Future<ui.Image> createSolidColorImage({
    required int width,
    required int height,
    required int argb32, // 0xAARRGGBB
  }) async {
    final byteData = ByteData(width * height * 4);
    final rgba = byteData.buffer.asUint32List();
    // ImageDescriptor.raw with rgba8888 expects RGBA byte order.
    // Convert ARGB32 → RGBA (R,G,B,A byte order).
    final a = (argb32 >> 24) & 0xFF;
    final r = (argb32 >> 16) & 0xFF;
    final g = (argb32 >> 8) & 0xFF;
    final b = argb32 & 0xFF;
    final rgbaPixel = (b << 24) | (g << 16) | (r << 8) | a; // little-endian RGBA
    for (int i = 0; i < rgba.length; i++) {
      rgba[i] = rgbaPixel;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      byteData.buffer.asUint8List(),
    );
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    buffer.dispose();
    return frame.image;
  }

  /// 创建两段灰度测试图像（左半 [leftVal]、右半 [rightVal]），用于锐化/清晰度测试。
  /// 使用中间灰度（如 64/192）避免锐化过冲被 0/255 裁剪掉。
  Future<ui.Image> createHalfHalfImage({
    required int width,
    required int height,
    int leftVal = 64,
    int rightVal = 192,
  }) async {
    final bytes = ByteData(width * height * 4);
    final rgba = bytes.buffer.asUint8List();
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final v = x < width ~/ 2 ? leftVal : rightVal;
        rgba[i] = v;     // R
        rgba[i + 1] = v; // G
        rgba[i + 2] = v; // B
        rgba[i + 3] = 255;             // A
      }
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    buffer.dispose();
    return frame.image;
  }

  /// 读取 ui.Image 的 RGBA 像素数据。
  Future<Uint8List> readRgba(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  group('ImageProcessingService.process', () {
    test('returns image with same dimensions for default params', () async {
      final input = await createSolidColorImage(
        width: 4,
        height: 4,
        argb32: 0xFFFF0000, // opaque red
      );
      final params = PostProcess(color: PostProcessColor());

      final result = await ImageProcessingService.process(
        input: input,
        params: params,
      );

      expect(result.width, 4);
      expect(result.height, 4);
      input.dispose();
      result.dispose();
    });

    test('applies color adjustments without crashing', () async {
      final input = await createSolidColorImage(
        width: 8,
        height: 8,
        argb32: 0xFF808080, // mid gray
      );
      final params = PostProcess(
        color: PostProcessColor(
          brightness: 10,
          contrast: 15,
          saturation: -20,
          temperature: 8,
          tint: -5,
          highlights: -10,
          shadows: 5,
          clarity: 12,
          vibrance: 8,
          brilliance: 6,
        ),
        sharpen: 25,
      );

      final result = await ImageProcessingService.process(
        input: input,
        params: params,
      );

      expect(result.width, 8);
      expect(result.height, 8);
      input.dispose();
      result.dispose();
    });

    test('falls back to ColorMatrix when gpu_image LUT unavailable', () async {
      // LutProcessor.apply3DLut uses composeLutMatrix + ColorFilter as fallback
      // (gpu_image 1.0.0 doesn't support 3D LUT on HarmonyOS).
      // The service calls apply3DLut which returns a processed image;
      // subsequent ColorMatrix excludes LUT to avoid double-application.
      final input = await createSolidColorImage(
        width: 6,
        height: 6,
        argb32: 0xFF336699, // blue-gray
      );
      final params = PostProcess(
        color: PostProcessColor(),
        lut: 'cinematic',
      );

      final result = await ImageProcessingService.process(
        input: input,
        params: params,
      );

      expect(result.width, 6);
      expect(result.height, 6);
      input.dispose();
      result.dispose();
    });

    test('applies vignette overlay without crashing', () async {
      final input = await createSolidColorImage(
        width: 10,
        height: 10,
        argb32: 0xFFFFFFFF, // white
      );
      final params = PostProcess(
        color: PostProcessColor(),
        vignette: 60,
      );

      final result = await ImageProcessingService.process(
        input: input,
        params: params,
      );

      expect(result.width, 10);
      expect(result.height, 10);
      input.dispose();
      result.dispose();
    });

    test('systemFilter + lut compose together without crashing', () async {
      final input = await createSolidColorImage(
        width: 5,
        height: 5,
        argb32: 0xFFAA5500,
      );
      final params = PostProcess(
        color: PostProcessColor(contrast: 5),
        systemFilter: 'vivid_warm',
        lut: 'vintage',
        vignette: 20,
        grain: 15,
        sharpen: 10,
      );

      final result = await ImageProcessingService.process(
        input: input,
        params: params,
      );

      expect(result.width, 5);
      expect(result.height, 5);
      input.dispose();
      result.dispose();
    });

    test('sharpening actually modifies edge pixels', () async {
      // Build a 12×12 image with a sharp vertical edge at column 6.
      final input = await createHalfHalfImage(width: 12, height: 12);
      final baselineParams = PostProcess(color: PostProcessColor());
      final sharpenedParams = PostProcess(
        color: PostProcessColor(),
        sharpen: 80,
      );

      final baseline = await ImageProcessingService.process(
        input: input,
        params: baselineParams,
      );
      final sharpened = await ImageProcessingService.process(
        input: input,
        params: sharpenedParams,
      );

      final baselinePixels = await readRgba(baseline);
      final sharpenedPixels = await readRgba(sharpened);

      int diffCount = 0;
      for (int i = 0; i < baselinePixels.length; i += 4) {
        final dR = (baselinePixels[i] - sharpenedPixels[i]).abs();
        final dG = (baselinePixels[i + 1] - sharpenedPixels[i + 1]).abs();
        final dB = (baselinePixels[i + 2] - sharpenedPixels[i + 2]).abs();
        if (dR + dG + dB > 15) diffCount++;
      }
      expect(diffCount, greaterThan(0),
          reason: 'Sharpening should modify pixels near edges');

      input.dispose();
      baseline.dispose();
      sharpened.dispose();
    });

    test('grain adds noise to a solid-color image', () async {
      final input = await createSolidColorImage(
        width: 16,
        height: 16,
        argb32: 0xFF808080, // mid gray
      );
      final baselineParams = PostProcess(color: PostProcessColor());
      final grainParams = PostProcess(
        color: PostProcessColor(),
        grain: 60,
      );

      final baseline = await ImageProcessingService.process(
        input: input,
        params: baselineParams,
      );
      final grainy = await ImageProcessingService.process(
        input: input,
        params: grainParams,
      );

      final baselinePixels = await readRgba(baseline);
      final grainyPixels = await readRgba(grainy);

      int diffCount = 0;
      for (int i = 0; i < baselinePixels.length; i += 4) {
        final dR = (baselinePixels[i] - grainyPixels[i]).abs();
        final dG = (baselinePixels[i + 1] - grainyPixels[i + 1]).abs();
        final dB = (baselinePixels[i + 2] - grainyPixels[i + 2]).abs();
        if (dR + dG + dB > 6) diffCount++;
      }
      expect(diffCount, greaterThan(0),
          reason: 'Grain should add noise to a flat color');

      input.dispose();
      baseline.dispose();
      grainy.dispose();
    });

    test('clarity modifies pixels near edges', () async {
      final input = await createHalfHalfImage(width: 16, height: 16);
      final baselineParams = PostProcess(color: PostProcessColor());
      final clarityParams = PostProcess(
        color: PostProcessColor(clarity: 60),
      );

      final baseline = await ImageProcessingService.process(
        input: input,
        params: baselineParams,
      );
      final clarified = await ImageProcessingService.process(
        input: input,
        params: clarityParams,
      );

      final baselinePixels = await readRgba(baseline);
      final clarifiedPixels = await readRgba(clarified);

      int diffCount = 0;
      for (int i = 0; i < baselinePixels.length; i += 4) {
        final dR = (baselinePixels[i] - clarifiedPixels[i]).abs();
        final dG = (baselinePixels[i + 1] - clarifiedPixels[i + 1]).abs();
        final dB = (baselinePixels[i + 2] - clarifiedPixels[i + 2]).abs();
        if (dR + dG + dB > 15) diffCount++;
      }
      expect(diffCount, greaterThan(0),
          reason: 'Clarity should modify pixels near edges');

      input.dispose();
      baseline.dispose();
      clarified.dispose();
    });

    test('per-pixel effects compose with vignette without crashing', () async {
      final input = await createHalfHalfImage(width: 24, height: 24);
      final params = PostProcess(
        color: PostProcessColor(clarity: 30),
        sharpen: 40,
        grain: 25,
        vignette: 35,
      );

      final result = await ImageProcessingService.process(
        input: input,
        params: params,
      );

      expect(result.width, 24);
      expect(result.height, 24);
      input.dispose();
      result.dispose();
    });
  });
}
