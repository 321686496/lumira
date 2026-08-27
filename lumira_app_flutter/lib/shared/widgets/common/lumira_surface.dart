import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../lumira/_internal/lumira_theme_resolver.dart';

/// 通用卡片/内容块表面组件
///
/// 替代「硬编码成新拟态」的散落 Container：通过 [LumiraThemeResolver.cardVisual]
/// 统一按当前 4 种 UI 风格（neumorphic/flat/glass/female）渲染背景、描边、阴影，
/// 保证所有页面的通用卡片观感一致并随设置实时变化。
///
/// 典型用途：空态提示卡、信息卡、统计卡、分隔内容块。若内容本身是照片/渐变
/// 海报或叠在照片上的浮层，则不适用（应保留原语义）。
class LumiraSurface extends ConsumerWidget {
  const LumiraSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.emphasize = false,
    this.color,
    this.clip = false,
  });

  /// 内容
  final Widget child;

  /// 内容区内边距
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 圆角（dp）。默认 14dp。
  final double? radius;

  /// true 用强浮雕新拟态阴影（shadowConvex），false 用轻量（shadowConvexSubtle）
  final bool emphasize;

  /// 覆盖背景色（仅在需要自定义时使用；为 null 走风格默认）
  final Color? color;

  /// 是否裁剪内容到圆角内（子组件可能溢出时用）
  final bool clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    final visual = LumiraThemeResolver.cardVisual(
      tokens: tokens,
      style: appTheme.style,
      radiusDp: radius ?? 14,
      emphasize: emphasize,
    );

    Widget surface = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? visual.background,
        borderRadius: BorderRadius.circular(radius ?? 14),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: child,
    );

    // glass/female 的柔和玻璃渐变叠加层
    if (visual.glassOverlay != null) {
      surface = Stack(
        children: [
          surface,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius ?? 14),
                  gradient: visual.glassOverlay,
                ),
              ),
            ),
          ),
        ],
      );
      if (margin != null) {
        surface = Padding(padding: margin!, child: surface);
      }
    }

    return surface;
  }
}