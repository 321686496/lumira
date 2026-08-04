import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 进度指示器组件
///
/// 替代 Material 的 `CircularProgressIndicator` / `LinearProgressIndicator`，
/// 颜色随 8 主题 × 4 风格变化。
///
/// 提供 3 种工厂构造：
/// - [LumiraProgress.circular]：圆形旋转进度（indeterminate）
/// - [LumiraProgress.linear]：线性进度条（determinate 或 indeterminate）
/// - [LumiraProgress.dot]：3 个 brand 色圆点呼吸动画（替代部分 circular 场景）
///
/// 4 风格分支（spec §3.1）：
/// - neumorphic / flat：brand 色主体
/// - glass：circular 加白色透明背景圆环
/// - female：用 brandLight 渐变（linear 用 brandLight）
class LumiraProgress extends ConsumerWidget {
  const LumiraProgress._(
    this._type, {
    super.key,
    this.strokeWidth = 2.0,
    this.size = 24.0,
    this.value,
    this.minHeight = 4.0,
  });

  /// 圆形旋转进度（indeterminate）
  ///
  /// [strokeWidth] 描边宽度，默认 2.0
  /// [size] 直径，默认 24.0
  factory LumiraProgress.circular({
    Key? key,
    double strokeWidth = 2.0,
    double size = 24.0,
  }) {
    return LumiraProgress._(
      _ProgressType.circular,
      key: key,
      strokeWidth: strokeWidth,
      size: size,
    );
  }

  /// 线性进度条
  ///
  /// [value] 进度值 0.0~1.0，为 null 时为 indeterminate 模式
  /// [minHeight] 最小高度，默认 4.0
  factory LumiraProgress.linear({
    Key? key,
    double? value,
    double minHeight = 4.0,
  }) {
    return LumiraProgress._(
      _ProgressType.linear,
      key: key,
      value: value,
      minHeight: minHeight,
    );
  }

  /// 3 圆点呼吸进度（indeterminate）
  ///
  /// [size] 单个圆点直径，默认 8.0
  factory LumiraProgress.dot({
    Key? key,
    double size = 8.0,
  }) {
    return LumiraProgress._(
      _ProgressType.dot,
      key: key,
      size: size,
    );
  }

  final _ProgressType _type;
  final double strokeWidth;
  final double size;
  final double? value;
  final double minHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;

    switch (_type) {
      case _ProgressType.circular:
        return _CircularProgress(
          tokens: tokens,
          style: style,
          strokeWidth: strokeWidth,
          size: size,
        );
      case _ProgressType.linear:
        return _LinearProgress(
          tokens: tokens,
          style: style,
          value: value,
          minHeight: minHeight,
        );
      case _ProgressType.dot:
        return _DotProgress(
          tokens: tokens,
          dotSize: size,
        );
    }
  }
}

enum _ProgressType { circular, linear, dot }

// ── 圆形进度 ──

class _CircularProgress extends StatefulWidget {
  const _CircularProgress({
    required this.tokens,
    required this.style,
    required this.strokeWidth,
    required this.size,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final double strokeWidth;
  final double size;

  @override
  State<_CircularProgress> createState() => _CircularProgressState();
}

class _CircularProgressState extends State<_CircularProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (ctx, _) {
          return CustomPaint(
            painter: _CircularProgressPainter(
              progress: _controller.value,
              tokens: widget.tokens,
              style: widget.style,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.tokens,
    required this.style,
    required this.strokeWidth,
  });

  final double progress;
  final ThemeTokens tokens;
  final UIStyle style;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const sweepAngle = 2 * math.pi * 0.75; // 270° 弧

    // 背景圆环（glass: 白透明；female: brandSubtle 透明；其他: 无）
    if (style == UIStyle.glass) {
      final bgPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, bgPaint);
    } else if (style == UIStyle.female) {
      final bgPaint = Paint()
        ..color = tokens.brandSubtle.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, bgPaint);
    }

    // 进度弧（旋转）
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (style == UIStyle.female) {
      // female: brand → brandLight 渐变
      progressPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tokens.brand, tokens.brandLight],
      ).createShader(rect);
    } else {
      progressPaint.color = tokens.brand;
    }

    final startAngle = -math.pi / 2 + 2 * math.pi * progress; // 从顶部开始旋转
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.tokens != tokens ||
      oldDelegate.style != style ||
      oldDelegate.strokeWidth != strokeWidth;
}

// ── 线性进度 ──

class _LinearProgress extends StatefulWidget {
  const _LinearProgress({
    required this.tokens,
    required this.style,
    required this.value,
    required this.minHeight,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final double? value;
  final double minHeight;

  @override
  State<_LinearProgress> createState() => _LinearProgressState();
}

class _LinearProgressState extends State<_LinearProgress>
    with SingleTickerProviderStateMixin {
  // indeterminate 模式下驱动位移动画
  AnimationController? _indeterminateController;

  @override
  void initState() {
    super.initState();
    if (widget.value == null) {
      _indeterminateController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _indeterminateController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final style = widget.style;

    final Color trackColor = tokens.divider;
    final Gradient? progressGradient = style == UIStyle.female
        ? LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [tokens.brand, tokens.brandLight],
          )
        : null;
    final Color progressColor = tokens.brand;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.minHeight / 2),
      child: SizedBox(
        height: widget.minHeight,
        child: Stack(
          children: [
            // 轨道
            Positioned.fill(
              child: ColoredBox(color: trackColor),
            ),
            // 进度
            if (widget.value != null)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.value!.clamp(0.0, 1.0),
                  child: progressGradient != null
                      ? DecoratedBox(
                          decoration: BoxDecoration(gradient: progressGradient),
                        )
                      : ColoredBox(color: progressColor),
                ),
              )
            else if (_indeterminateController != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _indeterminateController!,
                  builder: (ctx, _) {
                    // 在轨道上从左到右循环移动一个 40% 宽度的进度块
                    final t = _indeterminateController!.value;
                    const blockWidth = 0.4;
                    // leftFraction 从 -blockWidth → 1.0，块从左侧滑入、右侧滑出
                    final leftFraction = t * (1 + blockWidth) - blockWidth;
                    final block = progressGradient != null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: progressGradient,
                            ),
                          )
                        : ColoredBox(color: progressColor);
                    return LayoutBuilder(
                      builder: (ctx, constraints) {
                        final width = constraints.maxWidth;
                        return Stack(
                          children: [
                            Positioned(
                              left: leftFraction * width,
                              top: 0,
                              bottom: 0,
                              width: width * blockWidth,
                              child: block,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 三圆点呼吸进度 ──

class _DotProgress extends StatefulWidget {
  const _DotProgress({required this.tokens, required this.dotSize});

  final ThemeTokens tokens;
  final double dotSize;

  @override
  State<_DotProgress> createState() => _DotProgressState();
}

class _DotProgressState extends State<_DotProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = widget.tokens.brand;
    // 3 个圆点，呼吸间隔 200ms（相对于 1200ms 周期 = 1/6）
    const stagger = 1 / 6;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (ctx, _) {
            // 每个圆点的相位偏移 i * stagger
            final phase = (_controller.value - i * stagger) % 1.0;
            // 用正弦计算呼吸缩放（0.5 → 1.0 → 0.5）
            final scale = 0.5 + 0.5 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
            final opacity = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi));
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: i == 0 || i == 2 ? 0 : widget.dotSize * 0.5,
              ),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: brandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
