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
      // gpu_image 1.0.0 does not support 3D LUT; LutProcessor.apply3DLut throws
      // UnimplementedError. The service must catch it and apply the LUT via
      // composeLutMatrix (baked into fromPostProcess).
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
  });
}
