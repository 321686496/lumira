import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/challenge_models.dart';

/// 3 张卡牌翻面选 1 的动画组件
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
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _fadeController.dispose();
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
                        child: _CardBack(tokens: tokens, size: 80),
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
                        ),
                      )
                    : _CardBack(tokens: tokens, size: 200),
              );
            },
          ),
        ],
      );
    }

    // 翻牌前：3 张背面朝上的卡牌
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < 3; i++)
          GestureDetector(
            onTap: () => _onCardTap(i),
            child: _CardBack(tokens: tokens, size: 120, index: i),
          ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  final ThemeTokens tokens;
  final double size;
  final int? index;

  const _CardBack({required this.tokens, required this.size, this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.4,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: tokens.shadowConvex,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.help_outline,
            size: size * 0.3,
            color: tokens.brand,
          ),
          const SizedBox(height: 8),
          Text(
            '点击翻开',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final ChallengePoolItem item;
  final ThemeTokens tokens;

  const _CardFront({required this.item, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 分类标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ChallengeCategory.label(item.category),
              style: TextStyle(fontSize: 12, color: tokens.brandText),
            ),
          ),
          const SizedBox(height: 16),
          // 挑战标题
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // 描述
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          const SizedBox(height: 16),
          // 奖励 XP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_outlined, size: 18, color: tokens.brand),
              const SizedBox(width: 4),
              Text(
                '+${item.rewardXP} XP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.brand,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
