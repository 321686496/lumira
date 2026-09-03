import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 新拟态「凹陷表面」的可复用组件。
///
/// 复现 CSS `box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px
/// var(--shadow-lt)` 的内凹观感：**上/左内边缘压暗、下/右内边缘泛白高光、中部平坦**
/// （内凹的"地板"）。凹陷应是沿四条边各画一条渐变（明暗只集中在边缘），而非把整块
/// 表面扫成一个斜向渐变——那样上边远离角落的部分会没有阴影、中心也无法保持平整。
///
/// 之所以不用 `BoxShadow(blurStyle: BlurStyle.inner)`：本 SDK 实测把 inner 阴影当外
/// 阴影画（视觉仍是凸起），故改用边缘渐变叠加。做法：一个裁成圆角的 base 平底
/// + 四条贴边的渐变带（上/左 = 暗→surface，下/右 = surface→亮），四角自然成为
/// 「左上最暗、右下最亮」。所有颜色仍派生自当前主题、随 8 主题 × 4 风格自适应。
///
/// [depth] 控制明暗强度（越大越明显）；[rimFraction] 控制边缘带占短边的比例
/// （沟槽/轨道用较小值，芯片/按钮用较大值）。
class RecessedSurface extends StatelessWidget {
  const RecessedSurface({
    super.key,
    required this.tokens,
    required this.child,
    this.borderRadius = 16,
    this.depth = 0.7,
    this.rimFraction = 0.30,
    this.color,
    this.brimGap = 0,
  });

  final ThemeTokens tokens;

  /// 承载在凹陷表面之上的实际内容，同时也是尺寸来源（按非定位子组件计算）。
  final Widget child;

  final double borderRadius;

  /// 明暗强度 0~1。
  final double depth;

  /// 每条边缘渐变带占短边（min 宽/高）的比例。
  final double rimFraction;

  /// 覆盖默认 surface 的底色（一般不用传，跟随主题）。
  final Color? color;

  /// 底部/右侧亮条相对下边/右边再往里收的偏移，用于避免纯亮到边显得过爆，默认 0。
  final double brimGap;

  @override
  Widget build(BuildContext context) {
    final surface = color ?? tokens.surface;
    final sd = Color.lerp(surface, tokens.shadowConcave.first.color, depth)!;
    final hl = Color.lerp(surface, tokens.shadowConcave[1].color, depth)!;

    return LayoutBuilder(
      builder: (context, cons) {
        final short = math.min(cons.maxWidth, cons.maxHeight);
        final rim = short * rimFraction;

        Widget band({required Widget child}) => Positioned.fill(child: child);

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Stack(
            // 渐变带在下、内容在上，避免盖住文字/图标。
            children: [
              // 上 · 内边缘暗
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: rim,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [sd, surface],
                    ),
                  ),
                ),
              ),
              // 左 · 内边缘暗
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: rim,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [sd, surface],
                    ),
                  ),
                ),
              ),
              // 下 · 内边缘亮
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: math.max(0, rim - brimGap),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [hl, surface],
                    ),
                  ),
                ),
              ),
              // 右 · 内边缘亮
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: math.max(0, rim - brimGap),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [hl, surface],
                    ),
                  ),
                ),
              ),
              band(child: child),
            ],
          ),
        );
      },
    );
  }
}