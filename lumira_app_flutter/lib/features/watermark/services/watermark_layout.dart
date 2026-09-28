import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show FontStyle, FontWeight, TextAlign;

import '../models/watermark_template.dart';

/// 水印画框几何：输出画布 / 照片区域 / 白板基准三块矩形。
///
/// 成片渲染（[WatermarkRenderer]）、管理页缩略图（`WatermarkPreview`）、
/// 编辑页预览三处**共用**本类，是画框几何的唯一真源；消费方不得再另行推导
/// 画布尺寸或基准矩形，否则会出现「同日期的水印在缩略图/编辑器/成片各不相同」。
class WatermarkLayout {
  const WatermarkLayout({
    required this.cardRect,
    required this.photoRect,
    required this.plateRect,
    required this.padLeft,
    required this.padTop,
    required this.padRight,
    required this.padBottom,
  });

  /// 元素 fontSize / letterSpacing 相对值换算的参考宽度。
  static const double referenceWidth = 400.0;

  /// 整个输出画布。
  final ui.Rect cardRect;

  /// 照片区域（画布坐标系）。
  final ui.Rect photoRect;

  /// `space == frame` 元素的基准矩形：拍立得有白板时为**整卡宽**的底部白板，
  /// 其余情况回退为 [photoRect]（调用方无需判空）。
  final ui.Rect plateRect;

  final double padLeft;
  final double padTop;
  final double padRight;
  final double padBottom;

  factory WatermarkLayout.compute({
    required double photoW,
    required double photoH,
    required WatermarkFrame frame,
  }) {
    double padLeft = 0, padRight = 0, padTop = 0, padBottom = 0;
    if (frame.type == WatermarkFrameType.polaroid) {
      padLeft = frame.borderLeft * photoW;
      padRight = frame.borderRight * photoW;
      padTop = frame.borderTop * photoW;
      padBottom = frame.borderBottom * photoW +
          (frame.bottomPlate ? frame.bottomRatio * photoH : 0);
    }
    final cardRect = ui.Rect.fromLTWH(
        0, 0, photoW + padLeft + padRight, photoH + padTop + padBottom);
    final photoRect = ui.Rect.fromLTWH(padLeft, padTop, photoW, photoH);
    // 白板左边界取 0（整卡宽）：若取 padLeft，`x: 0.5` 的白板内元素会被整体
    // 右移 padLeft，拍立得日期永远不居中。
    final plateRect =
        (frame.type == WatermarkFrameType.polaroid && frame.bottomPlate)
            ? ui.Rect.fromLTWH(0, photoRect.bottom, cardRect.width, padBottom)
            : photoRect;
    return WatermarkLayout(
      cardRect: cardRect,
      photoRect: photoRect,
      plateRect: plateRect,
      padLeft: padLeft,
      padTop: padTop,
      padRight: padRight,
      padBottom: padBottom,
    );
  }

  /// 元素坐标系基准矩形：`frame` → 白板，其余 → 照片。
  ui.Rect baseFor(WatermarkElementSpace space) =>
      space == WatermarkElementSpace.frame ? plateRect : photoRect;

  int get outputWidth => cardRect.width.round();
  int get outputHeight => cardRect.height.round();
}

/// 单个元素的绝对量换算（字号 / 字距 / 颜色 / 阴影 / 字形）。
///
/// [baseWidth] 为该元素基准矩形的宽度（对应 [WatermarkLayout.baseFor]）。
class WatermarkElementMetrics {
  const WatermarkElementMetrics({
    required this.fontSize,
    required this.letterSpacing,
    required this.color,
    required this.shadows,
    required this.fontWeight,
    required this.fontStyle,
    required this.fontFamily,
  });

  final double fontSize;
  final double letterSpacing;
  final ui.Color color;
  final List<ui.Shadow> shadows;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final String? fontFamily;

  factory WatermarkElementMetrics.of(WatermarkElement e, double baseWidth) {
    final fontSize = e.fontSize * baseWidth;
    // 阴影随尺寸等比缩放：参考宽度归一化系数。
    final k = baseWidth / WatermarkLayout.referenceWidth;
    final shadows = <ui.Shadow>[];
    final shadowColor = watermarkColorWithOpacity(e.shadowColor, e.opacity);
    if (shadowColor.alpha > 0) {
      // 柔光晕：上下限按 k 缩放，避免成片上（3000px 级）半径被 8px 上限吞掉。
      if (e.shadowBlur > 0) {
        final blur = (fontSize * e.shadowBlur).clamp(0.5 * k, 8.0 * k);
        shadows.add(ui.Shadow(
          color: watermarkColorWithOpacity(shadowColor, 0.75),
          blurRadius: blur.toDouble(),
          offset: ui.Offset(blur * 0.4, blur * 0.4),
        ));
      }
    }
    return WatermarkElementMetrics(
      fontSize: fontSize,
      letterSpacing: e.letterSpacing * (baseWidth / WatermarkLayout.referenceWidth),
      color: watermarkColorWithOpacity(e.color, e.opacity),
      shadows: shadows,
      fontWeight: e.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: e.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: e.fontFamily.isEmpty ? null : e.fontFamily,
    );
  }
}

/// 文字锚点与偏移：`translate(anchorX, anchorY)` → `rotate` → `translate(offsetX, offsetY)`
/// 后绘制文字即为最终位置，三处消费方共用同一套换算。
class WatermarkTextPlacement {
  const WatermarkTextPlacement({
    required this.anchorX,
    required this.anchorY,
    required this.offsetX,
    required this.offsetY,
  });

  final double anchorX;
  final double anchorY;
  final double offsetX;
  final double offsetY;

  factory WatermarkTextPlacement.compute({
    required WatermarkElement element,
    required ui.Rect base,
    required double textWidth,
    required double textHeight,
  }) {
    final anchorX = element.x * base.width + base.left;
    final anchorY = element.y * base.height + base.top;
    double offsetX;
    switch (element.textAlign) {
      case TextAlign.right:
        offsetX = -textWidth;
        break;
      case TextAlign.center:
        offsetX = -textWidth / 2;
        break;
      case TextAlign.left:
      case TextAlign.justify:
      default:
        offsetX = 0.0;
    }
    return WatermarkTextPlacement(
      anchorX: anchorX,
      anchorY: anchorY,
      offsetX: offsetX,
      // 锚点视为文本行顶偏上，使视觉位置贴合画布上的落点。
      offsetY: -textHeight * 0.85,
    );
  }
}

/// 缩略图 / 编辑器预览的画布映射：把 [WatermarkLayout] 的卡片坐标系等比缩放后
/// 居中铺进给定显示尺寸，供组件定位照片与画笔绘制（两边共用同一映射）。
class WatermarkPreviewGeometry {
  const WatermarkPreviewGeometry({
    required this.layout,
    required this.scale,
    required this.origin,
  });

  /// 预览用的参考照片逻辑尺寸（竖构图 3:4）。
  static const double referencePhotoW = 300.0;
  static const double referencePhotoH = 400.0;

  final WatermarkLayout layout;
  final double scale;

  /// 卡片居中后的显示偏移。
  final ui.Offset origin;

  factory WatermarkPreviewGeometry.fit({
    required ui.Size size,
    required WatermarkFrame frame,
  }) {
    final layout = WatermarkLayout.compute(
      photoW: referencePhotoW,
      photoH: referencePhotoH,
      frame: frame,
    );
    final scale = math.min(
      size.width / layout.cardRect.width,
      size.height / layout.cardRect.height,
    );
    final origin = ui.Offset(
      (size.width - layout.cardRect.width * scale) / 2,
      (size.height - layout.cardRect.height * scale) / 2,
    );
    return WatermarkPreviewGeometry(
      layout: layout,
      scale: scale,
      origin: origin,
    );
  }

  /// 卡片坐标系矩形 → 显示坐标系矩形。
  ui.Rect displayRect(ui.Rect r) => ui.Rect.fromLTWH(
        r.left * scale + origin.dx,
        r.top * scale + origin.dy,
        r.width * scale,
        r.height * scale,
      );

  /// 元素基准矩形（显示坐标系）。
  ui.Rect baseFor(WatermarkElementSpace space) =>
      displayRect(layout.baseFor(space));
}

/// 拍立得白卡填充 shader：`frame.color` → `frame.gradientEndColor`，方向由
/// [WatermarkFrame.gradientDirection] 决定（仅 `borderFill == gradient` 有意义）。
///
/// 成片渲染与缩略图预览共用，避免两处各写一份方向映射。
ui.Shader watermarkFrameGradientShader(WatermarkFrame frame, ui.Rect rect) {
  final c = rect.center;
  ui.Offset begin;
  ui.Offset end;
  switch (frame.gradientDirection) {
    case WatermarkGradientDirection.bottomToTop:
      begin = ui.Offset(c.dx, rect.bottom);
      end = ui.Offset(c.dx, rect.top);
      break;
    case WatermarkGradientDirection.leftToRight:
      begin = ui.Offset(rect.left, c.dy);
      end = ui.Offset(rect.right, c.dy);
      break;
    case WatermarkGradientDirection.rightToLeft:
      begin = ui.Offset(rect.right, c.dy);
      end = ui.Offset(rect.left, c.dy);
      break;
    case WatermarkGradientDirection.topLeftToBottomRight:
      begin = rect.topLeft;
      end = rect.bottomRight;
      break;
    case WatermarkGradientDirection.bottomLeftToTopRight:
      begin = rect.bottomLeft;
      end = rect.topRight;
      break;
    case WatermarkGradientDirection.topToBottom:
    default:
      begin = ui.Offset(c.dx, rect.top);
      end = ui.Offset(c.dx, rect.bottom);
      break;
  }
  return ui.Gradient.linear(
    begin,
    end,
    [frame.color, frame.gradientEndColor],
  );
}

/// 水印日期格式化：`yyyy.MM.dd`（零填充）。
String formatWatermarkDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y.$m.$day';
}

/// 从拍摄产物文件名的 `capture_<毫秒>` 前缀解析拍摄时间，失败返回 null
/// （调用方把 null 交给渲染器，由其回退当天）。
///
/// App 产物命名形如 `capture_1727000000000.jpg` /
/// `capture_1727000000000_final_wm.jpg`，首个 10 位以上数字即快门时间。
/// 相比再解一次 JPEG 读 EXIF（App 自身编码的 JPEG 不写 EXIF DateTime），
/// 文件名解析零开销且更可靠。
DateTime? watermarkCaptureDateFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final match = RegExp(r'capture_(\d{10,})').firstMatch(path);
  if (match == null) return null;
  final millis = int.tryParse(match.group(1)!);
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

/// 将 [color] 的 alpha 乘以 [opacity]（0.0~1.0）后返回。
ui.Color watermarkColorWithOpacity(ui.Color color, double opacity) {
  if (opacity >= 1.0) return color;
  final clamped = opacity.clamp(0.0, 1.0);
  return ui.Color.fromARGB(
    (color.alpha * clamped).round(),
    color.red,
    color.green,
    color.blue,
  );
}