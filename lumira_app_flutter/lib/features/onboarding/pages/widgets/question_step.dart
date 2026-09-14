import 'package:flutter/material.dart';

import '../../../../core/theme/theme_tokens.dart';
import '../../data/questionnaire_data.dart';

/// 单个「大类下的二级风格」分组（供 [QuestionType.hierarchical] 渲染）
class StyleSection {
  final String title;
  final List<QuestionOption> options;
  const StyleSection(this.title, this.options);
}

/// 单题步骤通用骨架
///
/// 渲染题目标题 + 选项列表；选项选中态用 brandSubtle 背景 + brand 边框。
/// 单选/多选的差异由 [onToggle] 调用方控制。
/// [styleSections] 仅在 [QuestionType.hierarchical] 时启用：按大类分组展示二级风格。
class QuestionStep extends StatelessWidget {
  final QuestionDef question;
  final Set<String> selectedKeys;
  final void Function(String key) onToggle;
  final ThemeTokens tokens;
  final List<StyleSection>? styleSections;

  const QuestionStep({
    super.key,
    required this.question,
    required this.selectedKeys,
    required this.onToggle,
    required this.tokens,
    this.styleSections,
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
          const SizedBox(height: 24),
          if (question.type == QuestionType.hierarchical)
            _buildHierarchical(tokens)
          else
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

  /// 分级选择：按大类分区，每区为一行风格 chip（多选）。
  Widget _buildHierarchical(ThemeTokens tokens) {
    final sections = styleSections;
    if (sections == null || sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '先在上一步勾选你爱拍的大类，风格选项会随之出现',
          style: TextStyle(fontSize: 13, color: tokens.textTertiary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections) ...[
          Text(
            section.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in section.options) _buildStyleChip(opt, tokens),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildStyleChip(QuestionOption opt, ThemeTokens tokens) {
    final isSelected = selectedKeys.contains(opt.key);
    return GestureDetector(
      onTap: () => onToggle(opt.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tokens.brandSubtle : tokens.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? tokens.brand : tokens.divider,
            width: 1.2,
          ),
        ),
        child: Text(
          opt.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? tokens.brand : tokens.textPrimary,
          ),
        ),
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
