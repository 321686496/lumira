import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 玻璃拟态风格的页面背景装饰
///
/// 视觉规格来源：iOS Control Center / Apple Vision Pro 玻璃质感。
///
/// Forced fix(明显可辨): 之前背景光斑透明度仅 0.2~0.4，透过半透明玻璃再衰减，
/// 背后几乎看不到色彩，导致用户在真机上看不出玻璃效果。
/// 现将光斑饱和度提升到 0.5~0.7、尺寸更大、扩散更柔和（当作环境光晕），
/// 让「玻璃背后有一层被柔化的彩色」一眼可辨。
///
/// 非 glass 风格时返回 SizedBox.shrink()，不影响其他风格渲染。
class GlassBackground extends ConsumerWidget {
  const GlassBackground({super.key, this.variant = GlassBackgroundVariant.standard});

  /// 背景变体（不同页面用不同光斑布局避免重复感）
  final GlassBackgroundVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);

    // 非 glass 风格不渲染
    if (appTheme.style != UIStyle.glass) {
      return const SizedBox.shrink();
    }

    final tokens = appTheme.tokens;
    return Stack(
      children: [
        // 基座：全屏品牌色柔和渐变（画布→品牌光晕→画布），
        // 让半透明玻璃在任何位置都能透出色彩（不只依赖离散光斑）
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.brandLight.withOpacity(0.34),
                  tokens.canvas.withOpacity(0.0),
                  tokens.brand.withOpacity(0.30),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(child: _buildColoredBlobs(tokens)),
      ],
    );
  }

  Widget _buildColoredBlobs(ThemeTokens tokens) {
    switch (variant) {
      case GlassBackgroundVariant.standard:
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            // 主光晕 1：左上 brand（最浓，穿过玻璃也清晰）
            Positioned(
              top: -90,
              left: -70,
              child: _Blob(size: 340, opacity: 0.72, color: tokens.brand),
            ),
            // 光晕 2：右上 brandLight
            Positioned(
              top: 50,
              right: -90,
              child: _Blob(size: 300, opacity: 0.58, color: tokens.brandLight),
            ),
            // 光晕 3：中部左 brandSubtle（让中部卡片也有色彩可透）
            Positioned(
              top: 340,
              left: -60,
              child: _Blob(size: 300, opacity: 0.72, color: tokens.brandSubtle),
            ),
            // 光晕 4：中下右 brand
            Positioned(
              bottom: 130,
              right: -70,
              child: _Blob(size: 320, opacity: 0.55, color: tokens.brand),
            ),
            // 光晕 5：底部中 brandLight
            Positioned(
              bottom: -70,
              left: 70,
              child: _Blob(size: 360, opacity: 0.52, color: tokens.brandLight),
            ),
            // 光晕 6：中屏右 brandLight（远离主光晕，均衡分布）
            Positioned(
              top: 200,
              right: 40,
              child: _Blob(size: 220, opacity: 0.46, color: tokens.brandLight),
            ),
          ],
        );
      case GlassBackgroundVariant.profile:
        // profile 页：右上重，左下轻
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -70,
              right: -50,
              child: _Blob(size: 360, opacity: 0.70, color: tokens.brand),
            ),
            Positioned(
              top: 210,
              left: -90,
              child: _Blob(size: 320, opacity: 0.72, color: tokens.brandSubtle),
            ),
            Positioned(
              bottom: 90,
              right: -70,
              child: _Blob(size: 300, opacity: 0.58, color: tokens.brandLight),
            ),
            Positioned(
              bottom: -110,
              left: 60,
              child: _Blob(size: 340, opacity: 0.52, color: tokens.brand),
            ),
          ],
        );
      case GlassBackgroundVariant.templates:
        // templates 页：光斑网格分散
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -50,
              left: 70,
              child: _Blob(size: 320, opacity: 0.55, color: tokens.brand),
            ),
            Positioned(
              top: 290,
              right: -90,
              child: _Blob(size: 340, opacity: 0.55, color: tokens.brandLight),
            ),
            Positioned(
              bottom: 210,
              left: -50,
              child: _Blob(size: 300, opacity: 0.62, color: tokens.brandSubtle),
            ),
            Positioned(
              bottom: -90,
              right: 90,
              child: _Blob(size: 360, opacity: 0.50, color: tokens.brand),
            ),
          ],
        );
      case GlassBackgroundVariant.challenge:
        // challenge 页：左上+右下对角
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -70,
              left: -70,
              child: _Blob(size: 380, opacity: 0.62, color: tokens.brand),
            ),
            Positioned(
              top: 190,
              right: -90,
              child: _Blob(size: 300, opacity: 0.58, color: tokens.brandLight),
            ),
            Positioned(
              bottom: 60,
              left: -50,
              child: _Blob(size: 320, opacity: 0.66, color: tokens.brandSubtle),
            ),
            Positioned(
              bottom: -110,
              right: 60,
              child: _Blob(size: 340, opacity: 0.52, color: tokens.brand),
            ),
          ],
        );
    }
  }
}

/// 背景变体
enum GlassBackgroundVariant {
  /// 标准变体（默认，适合大多数页面）
  standard,

  /// profile 页变体（右上重）
  profile,

  /// templates 页变体（网格分散）
  templates,

  /// challenge 页变体（对角分布）
  challenge,
}

/// 柔和环境光晕（超大径向渐变圆，边界完全融入背景）
class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.opacity,
    required this.color,
  });

  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = color.withOpacity(opacity);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(0.0, 0.0),
            radius: 0.85,
            colors: [base, base.withOpacity(opacity * 0.5), base.withOpacity(0)],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}