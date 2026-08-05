import 'package:flutter/material.dart';

import '../../../../core/theme/theme_tokens.dart';
import '../../data/questionnaire_data.dart';

/// 单题步骤通用骨架
///
/// 渲染题目标题 + 选项列表；选项选中态用 brandSubtle 背景 + brand 边框。
/// 单选/多选的差异由 [onToggle] 调用方控制。
class QuestionStep extends StatelessWidget {
  final QuestionDef question;
  final Set<String> selectedKeys;
  final void Function(String key) onToggle;
  final ThemeTokens tokens;

  const QuestionStep({
    super.key,
    required this.question,
    required this.selectedKeys,
    required this.onToggle,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.3,
            ),
          ),
          if (question.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              question.subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 28),
          ...question.options.map((opt) {
            final isSelected = selectedKeys.contains(opt.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onToggle(opt.key),
                behavior: HitTestBehavior.opaque,
                child: _OptionCard(
                  label: opt.label,
                  selected: isSelected,
                  tokens: tokens,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeTokens tokens;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: selected ? tokens.brandSubtle : tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? tokens.brand : tokens.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? tokens.brand : tokens.textPrimary,
              ),
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle,
              size: 20,
              color: tokens.brand,
            ),
        ],
      ),
    );
  }
}
