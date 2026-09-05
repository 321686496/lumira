import 'package:flutter/material.dart';

/// 圆角矩形 + 「上/左亮、下/右暗」内斜边描边的品牌 CTA 表面。
///
/// Flutter 的 `BoxDecoration` 禁止 `BorderRadius` 与非均匀 `Border`（各边颜色不同）
/// 同时使用（断言：A borderRadius can only be given for a uniform Border），
/// 因此用 CustomPainter 手动绘制内斜边：把圆角矩形描边沿左右边中点切成
/// 「上+左」与「下+右」两条半路径，分别以 [bevelLight]/[bevelDark] 描边，
/// 兼容任意圆角。按压态由调用方交换两色实现斜边反转。
class BevelRoundedSurface extends StatelessWidget {
  const BevelRoundedSurface({
    super.key,
    required this.fill,
    required this.bevelLight,
    required this.bevelDark,
    required this.borderRadius,
    this.strokeWidth = 1.5,
    required this.child,
  });

  /// 表面填充色（如品牌色）
  final Color fill;

  /// 内斜边亮色（常态上/左）
  final Color bevelLight;

  /// 内斜边暗色（常态下/右）
  final Color bevelDark;

  /// 圆角半径
  final double borderRadius;

  /// 斜边线宽
  final double strokeWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BevelBorderPainter(
        fill: fill,
        light: bevelLight,
        dark: bevelDark,
        radius: borderRadius,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _BevelBorderPainter extends CustomPainter {
  _BevelBorderPainter({
    required this.fill,
    required this.light,
    required this.dark,
    required this.radius,
    required this.strokeWidth,
  });

  final Color fill;
  final Color light;
  final Color dark;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = radius.clamp(0.0, size.shortestSide / 2).toDouble();
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // 1) 表面填充
    canvas.drawRRect(rrect, Paint()..color = fill);

    // 2) 内斜边：沿左右边中点把描边切成两半，
    //    上+左半圈（含上边、左上/右上圆角）用亮色，下+右半圈用暗色。
    final x0 = rect.left, y0 = rect.top, x1 = rect.right, y1 = rect.bottom;
    final midY = y0 + size.height / 2;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    if (r <= 0) {
      // 直角矩形：两条折线即可
      final lightPath = Path()
        ..moveTo(x0, midY)
        ..lineTo(x0, y0)
        ..lineTo(x1, y0)
        ..lineTo(x1, midY);
      final darkPath = Path()
        ..moveTo(x1, midY)
        ..lineTo(x1, y1)
        ..lineTo(x0, y1)
        ..lineTo(x0, midY);
      stroke.color = light;
      canvas.drawPath(lightPath, stroke);
      stroke.color = dark;
      canvas.drawPath(darkPath, stroke);
      return;
    }

    // 上+左半圈：左中点 → 左上圆角 → 上边 → 右上圆角 → 右中点（顺时针）
    final topLeftHalf = Path()
      ..moveTo(x0, midY)
      ..lineTo(x0, y0 + r)
      ..arcToPoint(Offset(x0 + r, y0), radius: Radius.circular(r))
      ..lineTo(x1 - r, y0)
      ..arcToPoint(Offset(x1, y0 + r), radius: Radius.circular(r))
      ..lineTo(x1, midY);

    // 下+右半圈：右中点 → 右下圆角 → 下边 → 左下圆角 → 左中点（顺时针）
    final bottomRightHalf = Path()
      ..moveTo(x1, midY)
      ..lineTo(x1, y1 - r)
      ..arcToPoint(Offset(x1 - r, y1), radius: Radius.circular(r))
      ..lineTo(x0 + r, y1)
      ..arcToPoint(Offset(x0, y1 - r), radius: Radius.circular(r))
      ..lineTo(x0, midY);

    stroke.color = light;
    canvas.drawPath(topLeftHalf, stroke);
    stroke.color = dark;
    canvas.drawPath(bottomRightHalf, stroke);
  }

  @override
  bool shouldRepaint(_BevelBorderPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.light != light ||
        oldDelegate.dark != dark ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}