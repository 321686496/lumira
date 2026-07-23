import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/challenge_models.dart';

/// 3 张卡牌翻面选 1 的动画组件
///
/// 装饰美术：全部由 Flutter CustomPainter 即时绘制（无需外部资源），
/// 包含：莫兰迪渐变背景、烫金边框、四角卷草纹饰、中央光圈徽章、星光点缀。
class DailyFlipCard extends ConsumerStatefulWidget {
  final List<ChallengePoolItem> candidates;
  final void Function(ChallengePoolItem selected) onSelected;

  const DailyFlipCard({
    super.key,
    required this.candidates,
    required this.onSelected,
  });

  @override
  ConsumerState<DailyFlipCard> createState() => _DailyFlipCardState();
}

class _DailyFlipCardState extends ConsumerState<DailyFlipCard>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _flipController;
  late AnimationController _fadeController;
  late Animation<double> _flipAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onCardTap(int index) {
    if (_selectedIndex != null) return;
    setState(() => _selectedIndex = index);
    _flipController.forward();
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      widget.onSelected(widget.candidates[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    if (_selectedIndex != null) {
      // 翻牌后：显示选中的卡牌
      return Column(
        children: [
          // 未选中的 2 张淡出
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                if (i != _selectedIndex)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _CardBack(
                          tokens: tokens,
                          size: 80,
                          shimmerAnimation: _shimmerAnimation,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          // 选中的卡牌翻转
          AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * math.pi;
              final showFront = _flipAnimation.value > 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(angle),
                child: showFront
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: _CardFront(
                          item: widget.candidates[_selectedIndex!],
                          tokens: tokens,
                          shimmerAnimation: _shimmerAnimation,
                        ),
                      )
                    : _CardBack(
                        tokens: tokens,
                        size: 200,
                        shimmerAnimation: _shimmerAnimation,
                      ),
              );
            },
          ),
        ],
      );
    }

    // 翻牌前：3 张背面朝上的卡牌
    // 修复 Row overflow：3*120=360 > 容器 333，缩小到 95 避免溢出
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < 3; i++)
          GestureDetector(
            onTap: () => _onCardTap(i),
            child: _CardBack(
              tokens: tokens,
              size: 95,
              index: i,
              shimmerAnimation: _shimmerAnimation,
            ),
          ),
      ],
    );
  }
}

/// 卡牌背面：莫兰迪渐变 + 烫金边框 + 四角卷草 + 中央光圈徽章
class _CardBack extends StatelessWidget {
  final ThemeTokens tokens;
  final double size;
  final int? index;
  final Animation<double> shimmerAnimation;

  const _CardBack({
    required this.tokens,
    required this.size,
    required this.shimmerAnimation,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, _) {
        return Container(
          width: size,
          height: size * 1.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tokens.brandDeep.withOpacity(0.32),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 莫兰迪深色渐变背景
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.brandDeep,
                      _darken(tokens.brandDeep, 0.18),
                      _darken(tokens.brandDeep, 0.32),
                    ],
                  ),
                ),
              ),
              // 2. 中央径向光晕（呼应"光圈"主题）
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.7,
                    colors: [
                      tokens.brand.withOpacity(0.45),
                      tokens.brand.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              // 3. 烫金边框 + 四角卷草
              CustomPaint(
                painter: _OrnamentalBorderPainter(
                  gold: _gold(tokens),
                  goldSubtle: _gold(tokens).withOpacity(0.55),
                ),
              ),
              // 4. 流光扫描（shimmer）
              _ShimmerOverlay(
                animation: shimmerAnimation,
                gold: _gold(tokens),
              ),
              // 5. 中央徽章
              Center(
                child: _ApertureEmblem(
                  tokens: tokens,
                  gold: _gold(tokens),
                  size: size * 0.42,
                ),
              ),
              // 6. 顶部 wordmark
              Positioned(
                top: size * 0.08,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'LUMIRA',
                    style: TextStyle(
                      fontSize: size * 0.085,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                      color: _gold(tokens).withOpacity(0.85),
                    ),
                  ),
                ),
              ),
              // 7. 底部"点击翻开"
              Positioned(
                bottom: size * 0.1,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShortDivider(gold: _gold(tokens).withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text(
                      '点击翻开',
                      style: TextStyle(
                        fontSize: size * 0.085,
                        fontWeight: FontWeight.w500,
                        color: _gold(tokens).withOpacity(0.92),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ShortDivider(gold: _gold(tokens).withOpacity(0.6)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _gold(ThemeTokens t) {
    // 莫兰迪烫金：低饱和暖金
    return const Color(0xFFD4B584);
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

class _ShortDivider extends StatelessWidget {
  const _ShortDivider({required this.gold});
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withOpacity(0), gold, gold.withOpacity(0)],
        ),
      ),
    );
  }
}

/// 中央光圈徽章：相机光圈造型 + 放射线 + 中心宝石
class _ApertureEmblem extends StatelessWidget {
  const _ApertureEmblem({
    required this.tokens,
    required this.gold,
    required this.size,
  });

  final ThemeTokens tokens;
  final Color gold;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外圈光晕
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: gold.withOpacity(0.35), width: 1),
            ),
          ),
          // 放射线（6 道）
          CustomPaint(
            size: Size(size, size),
            painter: _RaysPainter(gold: gold.withOpacity(0.5), rays: 12),
          ),
          // 中圈
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  gold.withOpacity(0.32),
                  gold.withOpacity(0.08),
                ],
              ),
              border: Border.all(color: gold.withOpacity(0.85), width: 1.2),
            ),
          ),
          // 光圈叶片（6 叶）
          CustomPaint(
            size: Size(size * 0.55, size * 0.55),
            painter: _ApertureBladesPainter(gold: gold),
          ),
          // 中心宝石点
          Container(
            width: size * 0.12,
            height: size * 0.12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  gold,
                  gold.withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: gold.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡牌正面：分类渐变 + 烫金框 + 星光 XP 徽章
class _CardFront extends StatelessWidget {
  final ChallengePoolItem item;
  final ThemeTokens tokens;
  final Animation<double> shimmerAnimation;

  const _CardFront({
    required this.item,
    required this.tokens,
    required this.shimmerAnimation,
  });

  /// 分类对应的渐变配色（莫兰迪）
  List<Color> _categoryGradient(String category) {
    switch (category) {
      case ChallengeCategory.portrait:
        return [const Color(0xFFE8B4B8), const Color(0xFFC97B84)];
      case ChallengeCategory.landscape:
        return [const Color(0xFF8FA06A), const Color(0xFF5A7A48)];
      case ChallengeCategory.food:
        return [const Color(0xFFD4A574), const Color(0xFFB8860B)];
      case ChallengeCategory.street:
        return [const Color(0xFF7A8088), const Color(0xFF3F4754)];
      case ChallengeCategory.night:
        return [const Color(0xFF5B6CB5), const Color(0xFF2D3561)];
      case ChallengeCategory.macro:
        return [const Color(0xFF7BA87B), const Color(0xFF4A7C59)];
      case ChallengeCategory.stillLife:
        return [const Color(0xFFC9A96E), const Color(0xFF8B7355)];
      default:
        return [tokens.brand, tokens.brandDeep];
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case ChallengeCategory.portrait:
        return Icons.person_outline;
      case ChallengeCategory.landscape:
        return Icons.landscape_outlined;
      case ChallengeCategory.food:
        return Icons.restaurant_outlined;
      case ChallengeCategory.street:
        return Icons.location_city_outlined;
      case ChallengeCategory.night:
        return Icons.nights_stay_outlined;
      case ChallengeCategory.macro:
        return Icons.zoom_in_outlined;
      case ChallengeCategory.stillLife:
        return Icons.collections_outlined;
      default:
        return Icons.camera_alt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _categoryGradient(item.category);
    final gold = const Color(0xFFD4B584);
    final icon = _categoryIcon(item.category);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 卡片底
          Container(
            color: tokens.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部分类渐变带
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.22),
                        ),
                        child: Icon(icon, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ChallengeCategory.label(item.category),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'DAILY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // 主体内容
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    children: [
                      // 装饰引号
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.format_quote_rounded,
                              size: 16, color: gold.withOpacity(0.6)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 挑战标题
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          height: 1.4,
                          fontFamily: 'Noto Serif SC',
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 装饰分隔线
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    gold.withOpacity(0),
                                    gold.withOpacity(0.5),
                                    gold.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: gold.withOpacity(0.7),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    gold.withOpacity(0),
                                    gold.withOpacity(0.5),
                                    gold.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 描述
                      Text(
                        item.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // XP 徽章
                      _XpBadge(
                        xp: item.rewardXP,
                        gold: gold,
                        shimmerAnimation: shimmerAnimation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 烫金边框
          CustomPaint(
            painter: _FrontBorderPainter(gold: gold.withOpacity(0.7)),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

/// XP 徽章：金色渐变 + 星光 + 流光
class _XpBadge extends StatelessWidget {
  const _XpBadge({
    required this.xp,
    required this.gold,
    required this.shimmerAnimation,
  });

  final int xp;
  final Color gold;
  final Animation<double> shimmerAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gold.withOpacity(0.95),
                _lighten(gold, 0.1),
                gold.withOpacity(0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: gold.withOpacity(0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 星光图标
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 16, color: Colors.white),
                  // 流光扫过
                  if (shimmerAnimation.value > 0 &&
                      shimmerAnimation.value < 1)
                    Transform.translate(
                      offset: Offset(
                        (shimmerAnimation.value - 0.5) * 16,
                        0,
                      ),
                      child: Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.8),
                              Colors.white.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                '+$xp XP',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// 流光扫描覆盖层
class _ShimmerOverlay extends StatelessWidget {
  const _ShimmerOverlay({required this.animation, required this.gold});
  final Animation<double> animation;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        // 只在 0~1 区间显示流光
        if (t < 0 || t > 1) return const SizedBox.shrink();
        return Positioned.fill(
          child: CustomPaint(
            painter: _ShimmerPainter(progress: t, gold: gold),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress, required this.gold});
  final double progress;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    // 斜向流光带
    final width = size.width;
    final height = size.height;
    final bandWidth = width * 0.35;
    final x = progress * (width + bandWidth) - bandWidth;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          gold.withOpacity(0),
          gold.withOpacity(0.18),
          gold.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x + bandWidth, 0)
      ..lineTo(x + bandWidth - height * 0.3, height)
      ..lineTo(x - height * 0.3, height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 烫金边框 + 四角卷草纹饰
class _OrnamentalBorderPainter extends CustomPainter {
  _OrnamentalBorderPainter({required this.gold, required this.goldSubtle});
  final Color gold;
  final Color goldSubtle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = 16.0;

    // 外边框（细金线）
    final outer = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      Radius.circular(r - 1),
    );
    canvas.drawRRect(outerRect, outer);

    // 内边框（更细的虚线感）
    final inner = Paint()
      ..color = goldSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, w - 16, h - 16),
      Radius.circular(r - 6),
    );
    canvas.drawRRect(innerRect, inner);

    // 四角卷草纹饰
    final cornerPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final cornerSize = 18.0;
    // 左上
    canvas.save();
    canvas.translate(8, 8);
    _drawCornerFlourish(canvas, cornerSize, cornerPaint);
    canvas.restore();
    // 右上
    canvas.save();
    canvas.translate(w - 8, 8);
    canvas.scale(-1, 1);
    _drawCornerFlourish(canvas, cornerSize, cornerPaint);
    canvas.restore();
    // 左下
    canvas.save();
    canvas.translate(8, h - 8);
    canvas.scale(1, -1);
    _drawCornerFlourish(canvas, cornerSize, cornerPaint);
    canvas.restore();
    // 右下
    canvas.save();
    canvas.translate(w - 8, h - 8);
    canvas.scale(-1, -1);
    _drawCornerFlourish(canvas, cornerSize, cornerPaint);
    canvas.restore();

    // 四边中点小菱形装饰
    final dotPaint = Paint()..color = gold.withOpacity(0.7);
    final dotSize = 3.0;
    _drawDiamond(canvas, Offset(w / 2, 4), dotSize, dotPaint);
    _drawDiamond(canvas, Offset(w / 2, h - 4), dotSize, dotPaint);
    _drawDiamond(canvas, Offset(4, h / 2), dotSize, dotPaint);
    _drawDiamond(canvas, Offset(w - 4, h / 2), dotSize, dotPaint);
  }

  void _drawCornerFlourish(Canvas canvas, double s, Paint paint) {
    final path = Path();
    // 主弧线
    path.moveTo(0, s);
    path.quadraticBezierTo(0, 0, s, 0);
    // 内卷草
    path.moveTo(s * 0.45, 0);
    path.quadraticBezierTo(s * 0.45, s * 0.3, s * 0.75, s * 0.3);
    path.quadraticBezierTo(s * 0.95, s * 0.3, s * 0.95, s * 0.1);
    // 外卷草
    path.moveTo(0, s * 0.45);
    path.quadraticBezierTo(s * 0.3, s * 0.45, s * 0.3, s * 0.75);
    path.quadraticBezierTo(s * 0.3, s * 0.95, s * 0.1, s * 0.95);
    canvas.drawPath(path, paint);
    // 端点小圆
    canvas.drawCircle(Offset(s * 0.95, s * 0.1), 1.2, paint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(s * 0.1, s * 0.95), 1.2, paint);
    paint.style = PaintingStyle.stroke;
  }

  void _drawDiamond(Canvas canvas, Offset center, double s, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..lineTo(center.dx + s, center.dy)
      ..lineTo(center.dx, center.dy + s)
      ..lineTo(center.dx - s, center.dy)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _OrnamentalBorderPainter oldDelegate) =>
      oldDelegate.gold != gold;
}

/// 正面卡牌的简单烫金边框
class _FrontBorderPainter extends CustomPainter {
  _FrontBorderPainter({required this.gold});
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = 18.0;

    final paint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, w - 4, h - 4),
      Radius.circular(r - 2),
    );
    canvas.drawRRect(rect, paint);

    // 四角小装饰点
    final dotPaint = Paint()..color = gold.withOpacity(0.85);
    final dotSize = 2.5;
    final inset = 10.0;
    _drawDot(canvas, Offset(inset, inset), dotSize, dotPaint);
    _drawDot(canvas, Offset(w - inset, inset), dotSize, dotPaint);
    _drawDot(canvas, Offset(inset, h - inset), dotSize, dotPaint);
    _drawDot(canvas, Offset(w - inset, h - inset), dotSize, dotPaint);
  }

  void _drawDot(Canvas canvas, Offset center, double s, Paint paint) {
    canvas.drawCircle(center, s, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _FrontBorderPainter oldDelegate) =>
      oldDelegate.gold != gold;
}

/// 放射线（光圈外圈）
class _RaysPainter extends CustomPainter {
  _RaysPainter({required this.gold, required this.rays});
  final Color gold;
  final int rays;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final inner = size.width * 0.32;
    final outer = size.width * 0.48;
    final paint = Paint()
      ..color = gold
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * math.pi * 2;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + dx * inner, center.dy + dy * inner),
        Offset(center.dx + dx * outer, center.dy + dy * outer),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) =>
      oldDelegate.gold != gold;
}

/// 光圈叶片（6 叶形成相机光圈造型）
class _ApertureBladesPainter extends CustomPainter {
  _ApertureBladesPainter({required this.gold});
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..color = gold.withOpacity(0.55)
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round;

    final bladeCount = 6;
    for (var i = 0; i < bladeCount; i++) {
      final a0 = (i / bladeCount) * math.pi * 2;
      final a1 = ((i + 1) / bladeCount) * math.pi * 2;
      // 每片叶片偏移一点，形成光圈错位感
      final offset = 0.18;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a0 - offset) * r,
          center.dy + math.sin(a0 - offset) * r,
        )
        ..arcToPoint(
          Offset(
            center.dx + math.cos(a1 + offset) * r,
            center.dy + math.sin(a1 + offset) * r,
          ),
          radius: Radius.circular(r * 0.3),
          clockwise: true,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    // 中心六边形
    final hexPaint = Paint()
      ..color = gold.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final hexPath = Path();
    final hexR = r * 0.42;
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2 - math.pi / 2;
      final x = center.dx + math.cos(a) * hexR;
      final y = center.dy + math.sin(a) * hexR;
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();
    canvas.drawPath(hexPath, hexPaint);
  }

  @override
  bool shouldRepaint(covariant _ApertureBladesPainter oldDelegate) =>
      oldDelegate.gold != gold;
}
