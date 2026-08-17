import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';

/// 挑战规则说明卡
class ChallengeRulesCard extends ConsumerWidget {
  const ChallengeRulesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '挑战规则',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _RuleItem(
            number: '1',
            text: '每天进入挑战页会随机翻出 3 道选题，选一道开始拍摄',
            tokens: tokens,
          ),
          const SizedBox(height: 8),
          _RuleItem(
            number: '2',
            text: '完成挑战可获得对应 XP，连续拍摄 7/15 天解锁额外成就',
            tokens: tokens,
          ),
          const SizedBox(height: 8),
          _RuleItem(
            number: '3',
            text: 'XP 累计提升等级，等级越高解锁更多拍摄套件',
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String number;
  final String text;
  final ThemeTokens tokens;

  const _RuleItem({
    required this.number,
    required this.text,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: tokens.brand,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
