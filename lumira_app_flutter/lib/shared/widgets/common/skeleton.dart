// lib/shared/widgets/common/skeleton.dart
//
// 通用骨架屏组件：
// - SkeletonShimmer：流光扫描容器（只作用在内部的占位块上，不影响卡片背景）
// - SkeletonBox：圆角占位块
//
// 用法：把「卡片背景」放在 SkeletonShimmer 之外，只把占位内容包进 SkeletonShimmer。
// 因为 ShaderMask 的 srcATop 会把子树内所有不透明像素染成流光色，
// 若卡片背景也包在里面，整张卡会被刷成一片色、看不出占位形状。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';

/// 骨架屏流光扫描容器
///
/// 在 child 的绘制区域内做一条斜向高光往复扫描，表达"正在加载"。
/// 亮/暗主题分别取色：底色 surfaceAlt，高光向白色插值（暗主题插值更少，避免刺眼）。
///
/// 注意：child 内部必须是「透明底 + 占位块」结构，卡片背景请放在本组件外层，
/// 否则背景也会一起被流光染色。
class SkeletonShimmer extends ConsumerStatefulWidget {
  const SkeletonShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  final Widget child;

  /// 单次扫描时长
  final Duration duration;

  /// 关闭后直接渲染 child（用于测试/降低动效场景）
  final bool enabled;

  @override
  ConsumerState<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends ConsumerState<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SkeletonShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final tokens = ref.watch(appThemeProvider).tokens;
    final base = tokens.surfaceAlt;
    final isDark = tokens.canvas.computeLuminance() < 0.5;
    final highlight = Color.lerp(base, Colors.white, isDark ? 0.12 : 0.55)!;

    return AnimatedBuilder(
      animation: _controller,
      // child 与动画无关，单独构建避免每帧重建子树
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          // srcATop：只在 child 不透明的像素上绘制流光，保留圆角与间隙
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            // 扫描窗口宽度固定（1.2 倍），随 t 从左侧移出到右侧移出
            begin: Alignment(-1.2 + 2.4 * t, -0.5),
            end: Alignment(0.0 + 2.4 * t, 0.5),
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// 骨架屏占位块（圆角矩形）
///
/// 默认颜色取当前主题 surfaceAlt；被 SkeletonShimmer 包裹时颜色由流光接管。
class SkeletonBox extends ConsumerWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.borderRadius,
    this.color,
  });

  final double? width;
  final double? height;

  /// 四角统一圆角（未传 borderRadius 时生效）
  final double radius;

  /// 自定义圆角（例如只圆上方两角）
  final BorderRadius? borderRadius;

  /// 占位色（默认 tokens.surfaceAlt）
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? tokens.surfaceAlt,
          borderRadius: borderRadius ?? BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
