import 'dart:math';
import 'package:flutter/material.dart';

/// 圆形进度环（CustomPainter）
class AcademyProgressRing extends StatelessWidget {
  const AcademyProgressRing({
    super.key,
    required this.progress, // 0.0 - 1.0
    required this.size,
    this.strokeWidth = 6,
    this.ringColor,
    this.backgroundColor,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? ringColor;
  final Color? backgroundColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              ringColor: ringColor ?? const Color(0xFFC9A96E),
              backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.12),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color ringColor;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.ringColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景环
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // 进度弧
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // 从顶部开始
        2 * pi * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      ringColor != oldDelegate.ringColor ||
      backgroundColor != oldDelegate.backgroundColor;
}
