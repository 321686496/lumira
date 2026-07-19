import 'package:flutter/material.dart';

/// 构图叠图组件
///
/// 视觉规格来源：lumira-app/src/components/CompositionOverlay.vue
/// 7 种 overlay 类型：rule_of_thirds / golden_ratio / diagonal / grid / leading_lines / center / none
/// 用 CustomPainter 绘制，AspectRatio 由父组件控制
class CompositionOverlay extends StatelessWidget {
  const CompositionOverlay({
    super.key,
    required this.overlayType,
    required this.opacity,
    this.color,
  });

  /// 'rule_of_thirds' / 'golden_ratio' / 'diagonal' / 'grid' / 'leading_lines' / 'center' / 'none'
  final String overlayType;

  /// 0.0 ~ 1.0
  final double opacity;

  /// 默认白色
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CompositionPainter(
          overlayType: overlayType,
          opacity: opacity,
          color: color ?? Colors.white,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CompositionPainter extends CustomPainter {
  _CompositionPainter({
    required this.overlayType,
    required this.opacity,
    required this.color,
  });

  final String overlayType;
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayType == 'none') return;
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    switch (overlayType) {
      case 'rule_of_thirds':
        _drawThirdsLines(canvas, paint, w, h, ratios: [1.0 / 3, 2.0 / 3]);
        _drawIntersectionDots(canvas, paint, w, h, ratiosX: [1.0 / 3, 2.0 / 3], ratiosY: [1.0 / 3, 2.0 / 3]);
        break;
      case 'golden_ratio':
        // 黄金分割比 0.382 / 0.618
        _drawThirdsLines(canvas, paint, w, h, ratios: [0.382, 0.618]);
        _drawIntersectionDots(canvas, paint, w, h, ratiosX: [0.382, 0.618], ratiosY: [0.382, 0.618]);
        break;
      case 'diagonal':
        _drawDiagonals(canvas, paint, w, h);
        break;
      case 'grid':
        // 与 rule_of_thirds 视觉相同但无交叉点强调
        _drawThirdsLines(canvas, paint, w, h, ratios: [1.0 / 3, 2.0 / 3]);
        break;
      case 'leading_lines':
        _drawLeadingLines(canvas, paint, w, h);
        break;
      case 'center':
        _drawCenterCross(canvas, paint, w, h);
        break;
    }
  }

  void _drawThirdsLines(
    Canvas canvas,
    Paint paint,
    double w,
    double h, {
    required List<double> ratios,
  }) {
    // 水平线
    for (final r in ratios) {
      final y = h * r;
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
    // 垂直线
    for (final r in ratios) {
      final x = w * r;
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
    }
  }

  void _drawIntersectionDots(
    Canvas canvas,
    Paint paint,
    double w,
    double h, {
    required List<double> ratiosX,
    required List<double> ratiosY,
  }) {
    final dotPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    const radius = 4.0;
    for (final rx in ratiosX) {
      for (final ry in ratiosY) {
        canvas.drawCircle(Offset(w * rx, h * ry), radius, dotPaint);
      }
    }
  }

  void _drawDiagonals(Canvas canvas, Paint paint, double w, double h) {
    // 左上 → 右下
    canvas.drawLine(const Offset(0, 0), Offset(w, h), paint);
    // 右上 → 左下
    canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
  }

  void _drawLeadingLines(Canvas canvas, Paint paint, double w, double h) {
    // 从画面 4 个角向中心延伸的引导线（汇聚线）
    final cx = w / 2;
    final cy = h / 2;
    canvas.drawLine(const Offset(0, 0), Offset(cx, cy), paint);
    canvas.drawLine(Offset(w, 0), Offset(cx, cy), paint);
    canvas.drawLine(Offset(0, h), Offset(cx, cy), paint);
    canvas.drawLine(Offset(w, h), Offset(cx, cy), paint);
  }

  void _drawCenterCross(Canvas canvas, Paint paint, double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    // 中心十字线
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), paint);
    canvas.drawLine(Offset(0, cy), Offset(w, cy), paint);
    // 中心小方框（约 1/8 边长的正方形）
    const boxFactor = 0.06;
    final half = (w < h ? w : h) * boxFactor;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: half * 2, height: half * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CompositionPainter oldDelegate) {
    return oldDelegate.overlayType != overlayType ||
        oldDelegate.opacity != opacity ||
        oldDelegate.color != color;
  }
}
