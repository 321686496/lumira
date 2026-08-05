import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 挑战完成 XP 动画奖励页
///
/// 闭环最后一环：拍摄保存 → 此页 → 返回挑战页
/// - 入场动画：金色徽章 scale + rotate + 粒子爆裂
/// - XP 计数动画：0 → rewardXp（数字滚动）
/// - 行动按钮：再拍一张 / 完成挑战
class ChallengeCompletePage extends ConsumerStatefulWidget {
  const ChallengeCompletePage({
    super.key,
    required this.challengeId,
    required this.rewardXp,
    required this.challengeTitle,
  });

  final String challengeId;
  final int rewardXp;
  final String challengeTitle;

  @override
  ConsumerState<ChallengeCompletePage> createState() =>
      _ChallengeCompletePageState();
}

class _ChallengeCompletePageState extends ConsumerState<ChallengeCompletePage>
    with TickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final AnimationController _xpController;
  late final AnimationController _particleController;

  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeRotate;
  late final Animation<double> _badgeOpacity;
  late final Animation<int> _xpCount;
  late final Animation<double> _particleProgress;

  @override
  void initState() {
    super.initState();

    // 徽章入场：scale 0→1.1→1 + rotate -0.5→0 + opacity 0→1
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_badgeController);
    _badgeRotate = Tween<double>(begin: -0.5, end: 0.0)
        .animate(CurvedAnimation(
            parent: _badgeController, curve: Curves.easeOutBack));
    _badgeOpacity = CurvedAnimation(
        parent: _badgeController, curve: const Interval(0.0, 0.3, curve: Curves.easeIn));

    // XP 计数动画：0 → rewardXp（900ms）
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _xpCount = IntTween(begin: 0, end: widget.rewardXp)
        .animate(CurvedAnimation(
            parent: _xpController, curve: Curves.easeOutCubic));

    // 粒子爆裂动画
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _particleProgress = CurvedAnimation(
        parent: _particleController, curve: Curves.easeOutQuad);

    // 启动动画序列
    _badgeController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _xpController.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _particleController.forward();
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    _xpController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _goChallenge() {
    // 清栈返回挑战主页
    GoRouter.of(context).go(RouteNames.challenge);
  }

  void _goCaptureAgain() {
    // 再次进入拍摄页（保留 challengeId 以便再次回写）
    // 注意：DB 中今日挑战已 done，再拍不会重复加 XP（_completeChallenge 会再次更新状态但已为 done）
    GoRouter.of(context).go(
      '${RouteNames.capture}'
      '?${RouteNames.paramChallengeId}=${Uri.encodeComponent(widget.challengeId)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);
    final isNeumorphic = style == UIStyle.neumorphic;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          // 1. 背景：径向金色光晕
          Positioned.fill(
            child: CustomPaint(
              painter: _RadialGlowPainter(
                color: tokens.brand.withOpacity(0.10),
              ),
            ),
          ),
          // 2. 粒子层
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (_, __) {
                  if (_particleController.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    painter: _ParticlePainter(
                      progress: _particleProgress.value,
                      color: tokens.brand,
                    ),
                  );
                },
              ),
            ),
          ),
          // 3. 主体内容
          SafeArea(
            child: Column(
              children: [
                LumiraNav(
                  title: '挑战完成',
                  transparent: true,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _goChallenge,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 徽章
                        AnimatedBuilder(
                          animation: _badgeController,
                          builder: (_, __) {
                            return Opacity(
                              opacity: _badgeOpacity.value,
                              child: Transform.rotate(
                                angle: _badgeRotate.value,
                                child: Transform.scale(
                                  scale: _badgeScale.value,
                                  child: _Badge(
                                    tokens: tokens,
                                    isNeumorphic: isNeumorphic,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        // 标题 + 描述
                        FadeUp(
                          delay: const Duration(milliseconds: 500),
                          child: Column(
                            children: [
                              Text(
                                '挑战完成！',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.challengeTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: tokens.textSecondary,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // XP 计数
                        FadeUp(
                          delay: const Duration(milliseconds: 700),
                          child: _XpCounter(
                            animation: _xpCount,
                            rewardXp: widget.rewardXp,
                            tokens: tokens,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // 行动按钮
                        FadeUp(
                          delay: const Duration(milliseconds: 900),
                          child: Row(
                            children: [
                              Expanded(
                                child: LumiraButton(
                                  variant: ButtonVariant.secondary,
                                  onPressed: _goCaptureAgain,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.camera_alt_outlined),
                                      SizedBox(width: 8),
                                      Text('再拍一张'),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LumiraButton(
                                  variant: ButtonVariant.primary,
                                  onPressed: _goChallenge,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle_outline),
                                      SizedBox(width: 8),
                                      Text('完成'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 金色徽章：圆形 + check 图标 + 双层光晕
class _Badge extends StatelessWidget {
  const _Badge({required this.tokens, required this.isNeumorphic});

  final ThemeTokens tokens;
  final bool isNeumorphic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.brand.withOpacity(0.95),
            tokens.brandDeep,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.brand.withOpacity(0.35),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: tokens.brand.withOpacity(0.20),
            offset: const Offset(0, 0),
            blurRadius: 48,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外环装饰
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
          ),
          // check 图标
          Icon(
            Icons.check,
            size: 56,
            color: Colors.white,
            shadows: [
              Shadow(
                color: tokens.brandDeep.withOpacity(0.5),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// XP 计数显示：大字号 + 进度条
class _XpCounter extends StatelessWidget {
  const _XpCounter({
    required this.animation,
    required this.rewardXp,
    required this.tokens,
  });

  final Animation<int> animation;
  final int rewardXp;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (_, __) {
                return Text(
                  '+${animation.value}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: tokens.brand,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              'XP',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: tokens.brandText,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '经验值已发放',
          style: TextStyle(
            fontSize: 13,
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// 径向金色光晕背景
class _RadialGlowPainter extends CustomPainter {
  _RadialGlowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = size.width * 0.7;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          color,
          color.withOpacity(0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialGlowPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 粒子爆裂效果：12 个粒子从中心向外扩散
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;
    final center = Offset(size.width / 2, size.height * 0.4);
    const particleCount = 14;
    final maxRadius = size.width * 0.35;
    final radius = maxRadius * progress;
    // 粒子大小随进度衰减
    final particleSize = (1 - progress) * 6 + 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      // 距离越远的粒子透明度越低
      final opacity = (1 - progress) * 0.9;
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(dx, dy), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
