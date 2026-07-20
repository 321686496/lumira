import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 玻璃拟态风格的页面背景装饰
///
/// Forced fix: 之前 glass 风格页面背景是纯色 canvas，BackdropFilter.blur 模糊纯色
/// 没有视觉效果，导致用户看不出毛玻璃效果。
///
/// 解决方案：在 glass 风格时，给页面背景叠加多个彩色径向斑点（brand/brandLight/brandSubtle），
/// 让 BackdropFilter 能 blur 这些色彩，形成真正的毛玻璃视觉。
///
/// 非 glass 风格时返回 SizedBox.shrink()，不影响其他风格渲染。
///
/// 视觉规格来源：iOS Control Center / Apple Vision Pro 玻璃质感
class GlassBackground extends ConsumerWidget {
  const GlassBackground({super.key, this.variant = GlassBackgroundVariant.standard});

  /// 背景变体（不同页面用不同斑点布局避免重复感）
  final GlassBackgroundVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);

    // 非 glass 风格不渲染
    if (appTheme.style != UIStyle.glass) {
      return const SizedBox.shrink();
    }

    final tokens = appTheme.tokens;
    return _buildColoredBlobs(tokens);
  }

  Widget _buildColoredBlobs(ThemeTokens tokens) {
    switch (variant) {
      case GlassBackgroundVariant.standard:
        return Stack(
          children: [
            // 底色 canvas
            ColoredBox(color: tokens.canvas),
            // 主斑点 1：左上 brand
            Positioned(
              top: -80,
              left: -60,
              child: _Blob(
                size: 280,
                color: tokens.brand.withOpacity(0.38),
              ),
            ),
            // 斑点 2：右上 brandLight
            Positioned(
              top: 60,
              right: -80,
              child: _Blob(
                size: 240,
                color: tokens.brandLight.withOpacity(0.32),
              ),
            ),
            // 斑点 3：中部左 brandSubtle
            Positioned(
              top: 320,
              left: -40,
              child: _Blob(
                size: 220,
                color: tokens.brandSubtle.withOpacity(0.65),
              ),
            ),
            // 斑点 4：中下右 brand
            Positioned(
              bottom: 120,
              right: -60,
              child: _Blob(
                size: 260,
                color: tokens.brand.withOpacity(0.28),
              ),
            ),
            // 斑点 5：底部中 brandLight
            Positioned(
              bottom: -80,
              left: 80,
              child: _Blob(
                size: 300,
                color: tokens.brandLight.withOpacity(0.30),
              ),
            ),
          ],
        );
      case GlassBackgroundVariant.profile:
        // profile 页：右上重，左下轻
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -60,
              right: -40,
              child: _Blob(
                size: 300,
                color: tokens.brand.withOpacity(0.40),
              ),
            ),
            Positioned(
              top: 200,
              left: -80,
              child: _Blob(
                size: 260,
                color: tokens.brandSubtle.withOpacity(0.70),
              ),
            ),
            Positioned(
              bottom: 100,
              right: -60,
              child: _Blob(
                size: 240,
                color: tokens.brandLight.withOpacity(0.35),
              ),
            ),
            Positioned(
              bottom: -100,
              left: 60,
              child: _Blob(
                size: 280,
                color: tokens.brand.withOpacity(0.25),
              ),
            ),
          ],
        );
      case GlassBackgroundVariant.templates:
        // templates 页：网格背景，斑点分散
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -40,
              left: 80,
              child: _Blob(
                size: 260,
                color: tokens.brand.withOpacity(0.32),
              ),
            ),
            Positioned(
              top: 280,
              right: -80,
              child: _Blob(
                size: 280,
                color: tokens.brandLight.withOpacity(0.30),
              ),
            ),
            Positioned(
              bottom: 200,
              left: -40,
              child: _Blob(
                size: 240,
                color: tokens.brandSubtle.withOpacity(0.60),
              ),
            ),
            Positioned(
              bottom: -80,
              right: 100,
              child: _Blob(
                size: 300,
                color: tokens.brand.withOpacity(0.22),
              ),
            ),
          ],
        );
      case GlassBackgroundVariant.challenge:
        // challenge 页：左上+右下对角
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -60,
              left: -60,
              child: _Blob(
                size: 320,
                color: tokens.brand.withOpacity(0.36),
              ),
            ),
            Positioned(
              top: 180,
              right: -80,
              child: _Blob(
                size: 240,
                color: tokens.brandLight.withOpacity(0.34),
              ),
            ),
            Positioned(
              bottom: 60,
              left: -40,
              child: _Blob(
                size: 260,
                color: tokens.brandSubtle.withOpacity(0.65),
              ),
            ),
            Positioned(
              bottom: -100,
              right: 60,
              child: _Blob(
                size: 280,
                color: tokens.brand.withOpacity(0.24),
              ),
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

/// 彩色斑点（径向渐变圆）
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.5,
            colors: [color, color.withOpacity(0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
