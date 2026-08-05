import 'package:flutter/material.dart';

import '../../../../core/theme/theme_tokens.dart';

/// 问卷顶部进度条
class QuestionnaireProgress extends StatelessWidget {
  final int current;
  final int total;
  final ThemeTokens tokens;

  const QuestionnaireProgress({
    super.key,
    required this.current,
    required this.total,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current + 1) / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: tokens.divider,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${current + 1}/$total',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
