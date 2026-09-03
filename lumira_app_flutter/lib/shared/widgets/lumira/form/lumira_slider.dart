import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 全局滑块
///
/// 视觉规格来源：spec §3.3 LumiraSlider
/// 自定义实现（不用原生 Slider，便于 4 风格化）
/// - track：高 `sliderTrackHeight`，背景 `tokens.divider`，active 段 `tokens.brand`
/// - thumb：直径 20，颜色 `tokens.brand`，4 风格阴影/边框/渐变
/// - 拖动时 thumb 放大 1.1 倍
class LumiraSlider extends ConsumerStatefulWidget {
  const LumiraSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.label,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final String? label;

  @override
  ConsumerState<LumiraSlider> createState() => _LumiraSliderState();
}

class _LumiraSliderState extends ConsumerState<LumiraSlider> {
  static const double _thumbSize = 20.0;
  static const double _trackVerticalPadding = 12.0;
  bool _dragging = false;

  void _updateValue(double dx, double trackWidth) {
    final double effectiveWidth = trackWidth - _thumbSize;
    if (effectiveWidth <= 0) return;
    final double clampedDx = (dx - _thumbSize / 2).clamp(0.0, effectiveWidth);
    final double ratio = clampedDx / effectiveWidth;
    double newValue = widget.min + ratio * (widget.max - widget.min);
    if (widget.divisions != null) {
      final double step = (widget.max - widget.min) / widget.divisions!;
      newValue = (newValue / step).round() * step;
    }
    newValue = newValue.clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final trackHeight = appTheme.sliderTrackHeight;
    const double sliderHeight = _thumbSize + _trackVerticalPadding * 2;

    final double valueRange = (widget.max - widget.min);
    final double ratio = valueRange > 0
        ? ((widget.value - widget.min) / valueRange).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      label: widget.label,
      slider: true,
      value: '${widget.value}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double trackWidth = constraints.maxWidth;
          final double thumbX = ratio * (trackWidth - _thumbSize);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _updateValue(details.localPosition.dx, trackWidth),
            onHorizontalDragStart: (details) {
              setState(() => _dragging = true);
              _updateValue(details.localPosition.dx, trackWidth);
            },
            onHorizontalDragUpdate: (details) =>
                _updateValue(details.localPosition.dx, trackWidth),
            onHorizontalDragEnd: (_) => setState(() => _dragging = false),
            child: SizedBox(
              height: sliderHeight,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 背景轨道
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (sliderHeight - trackHeight) / 2,
                    child: Container(
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: appTheme.style == UIStyle.neumorphic
                            ? null
                            : tokens.divider,
                        borderRadius:
                            BorderRadius.circular(trackHeight / 2),
                        // 新拟态：轨道为「凹陷凹槽」（recessedGradient），模拟滑入
                        gradient: appTheme.style == UIStyle.neumorphic
                            ? ThemeTokens.recessedGradient(tokens, depth: 0.18)
                            : null,
                      ),
                    ),
                  ),
                  // Active 段轨道（从左侧到 thumb 中心）
                  Positioned(
                    left: 0,
                    width: thumbX + _thumbSize / 2,
                    top: (sliderHeight - trackHeight) / 2,
                    child: Container(
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: tokens.brand,
                        borderRadius:
                            BorderRadius.circular(trackHeight / 2),
                      ),
                    ),
                  ),
                  // Thumb
                  Positioned(
                    left: thumbX,
                    top: (sliderHeight - _thumbSize) / 2,
                    child: _buildThumb(appTheme, tokens),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 按 4 风格分支构建 thumb
  Widget _buildThumb(AppThemeData appTheme, ThemeTokens tokens) {
    final double scale = _dragging ? 1.1 : 1.0;
    final Widget thumb;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        // brand + shadowConvexSubtle
        thumb = Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: tokens.brand,
            shape: BoxShape.circle,
            boxShadow: tokens.shadowConvexSubtle,
          ),
        );
        break;
      case UIStyle.flat:
        // brand 圆点，无阴影
        thumb = Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: tokens.brand,
            shape: BoxShape.circle,
          ),
        );
        break;
      case UIStyle.glass:
        // 白透明 0.8 + brand 边框
        thumb = Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: tokens.brand, width: 1.5),
          ),
        );
        break;
      case UIStyle.female:
        // brandLight 渐变
        thumb = Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandLight,
                tokens.brand,
              ],
            ),
          ),
        );
        break;
    }
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: thumb,
    );
  }
}
