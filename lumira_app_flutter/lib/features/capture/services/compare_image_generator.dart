import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 生成"原图 vs 滤镜后"对比图（横向并排 + 文字标签）
class CompareImageGenerator {
  CompareImageGenerator._();

  /// 生成对比图，返回 outputPath。
  ///
  /// [originalPath] 原图（无滤镜）
  /// [filteredPath] 滤镜后的图
  /// [outputPath] 输出 PNG 路径
  static Future<String> generate({
    required String originalPath,
    required String filteredPath,
    required String outputPath,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 解码两张图
      final originalBytes = await File(originalPath).readAsBytes();
      final filteredBytes = await File(filteredPath).readAsBytes();
      final origCodec = await ui.instantiateImageCodec(originalBytes);
      final origFrame = await origCodec.getNextFrame();
      final origImage = origFrame.image;
      origCodec.dispose();

      final filtCodec = await ui.instantiateImageCodec(filteredBytes);
      final filtFrame = await filtCodec.getNextFrame();
      final filtImage = filtFrame.image;
      filtCodec.dispose();

      // 2. 统一高度（取较小值，避免放大）
      final targetH = origImage.height < filtImage.height
          ? origImage.height
          : filtImage.height;
      final origW = (origImage.width * targetH / origImage.height).round();
      final filtW = (filtImage.width * targetH / filtImage.height).round();
      const padding = 20;
      const labelH = 40;
      final totalW = origW + filtW + padding * 3;
      final totalH = targetH + labelH + padding * 2;

      // 3. 绘制到 canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, totalW.toDouble(), totalH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF1C1A17),
      );

      // 原图
      canvas.drawImageRect(
        origImage,
        ui.Rect.fromLTWH(0, 0, origImage.width.toDouble(),
            origImage.height.toDouble()),
        ui.Rect.fromLTWH(
            padding.toDouble(),
            (labelH + padding).toDouble(),
            origW.toDouble(),
            targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );

      // 滤镜后
      canvas.drawImageRect(
        filtImage,
        ui.Rect.fromLTWH(0, 0, filtImage.width.toDouble(),
            filtImage.height.toDouble()),
        ui.Rect.fromLTWH(
            (padding * 2 + origW).toDouble(),
            (labelH + padding).toDouble(),
            filtW.toDouble(),
            targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );

      // 标签
      final tp = TextPainter(textDirection: ui.TextDirection.ltr);
      tp.text = const TextSpan(
        text: '原图',
        style: TextStyle(
            color: ui.Color(0xFFC9A96E),
            fontSize: 24,
            fontWeight: ui.FontWeight.w600),
      );
      tp.layout();
      tp.paint(canvas, ui.Offset(padding.toDouble(), 8));
      tp.text = const TextSpan(
        text: '滤镜后',
        style: TextStyle(
            color: ui.Color(0xFFC9A96E),
            fontSize: 24,
            fontWeight: ui.FontWeight.w600),
      );
      tp.layout();
      tp.paint(
          canvas, ui.Offset((padding * 2 + origW).toDouble(), 8));

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(totalW, totalH);
      picture.dispose();
      origImage.dispose();
      filtImage.dispose();

      // 4. 编码 PNG 并保存
      final pngBytes = await resultImage.toByteData(
          format: ui.ImageByteFormat.png);
      if (pngBytes == null) {
        throw StateError('toByteData(png) 返回 null');
      }
      await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
      resultImage.dispose();

      debugPrint('[compare] 生成对比图: ${sw.elapsedMilliseconds}ms');
      return outputPath;
    } catch (e, st) {
      debugPrint('[compare] 失败: $e\n$st');
      rethrow;
    }
  }
}
