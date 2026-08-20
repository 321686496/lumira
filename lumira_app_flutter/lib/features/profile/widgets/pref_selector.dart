import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 偏好选项中文文案（与后端白名单 key 一致，全部为小写 snake_case）
class PrefOptions {
  PrefOptions._();

  static const Map<String, String> gender = {
    'male': '男', 'female': '女', 'prefer_not': '不方便透露',
  };

  static const Map<String, String> skillLevel = {
    'beginner': '新手', 'intermediate': '进阶',
    'advanced': '高级', 'pro': '专业',
  };

  static const Map<String, String> shootFrequency = {
    'rarely': '偶尔', 'monthly': '每月', 'weekly': '每周', 'daily': '每天',
  };

  static const Map<String, String> favoriteCategories = {
    'portrait': '人像', 'landscape': '风光', 'food': '美食', 'street': '街拍',
    'night': '夜景', 'macro': '微距', 'still-life': '静物',
  };

  static const Map<String, String> painPoints = {
    'composition': '构图困难', 'lighting': '光线处理', 'posing': '摆姿不自然',
    'camera_settings': '参数设置', 'post_processing': '后期修图',
    'no_subject': '找不到拍摄对象', 'no_time': '没时间拍',
  };

  static const Map<String, String> expectations = {
    'learn_photo': '学摄影', 'inspiration': '找灵感', 'better_composition': '提升构图',
    'master_camera': '玩转相机', 'share_works': '分享作品', 'record_life': '记录生活',
  };

  static const Map<String, String> commonScenes = {
    'indoor_home': '家中', 'cafe': '咖啡馆', 'outdoor_park': '户外公园',
    'street': '街头', 'travel': '旅行', 'office': '办公室', 'studio': '影棚',
  };
}

/// 单选偏好块：展示中文 label，选中高亮（品牌色描边/填充），点击回调。
class PrefSingleSelector extends StatelessWidget {
  const PrefSingleSelector({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.tokens,
  });

  final String title;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.textTertiary,
            letterSpacing: 0.04 * 13,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in options.entries)
              _PrefPill(
                label: entry.value,
                selected: entry.key == value,
                tokens: tokens,
                onTap: () => onChanged(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// 多选偏好块：状态由父组件持有，选中集合传入 selected，onToggle 切换。
class PrefMultiSelector extends StatelessWidget {
  const PrefMultiSelector({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.tokens,
  });

  final String title;
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.textTertiary,
            letterSpacing: 0.04 * 13,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in options.entries)
              _PrefPill(
                label: entry.value,
                selected: selected.contains(entry.key),
                tokens: tokens,
                onTap: () => onToggle(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// 单个偏好胶囊（pill）：沿问卷选项风格，选中用 brand 描边 + brandText，
/// 未选中用 canvas 底 + divider 描边 + textSecondary 文字。
class _PrefPill extends StatelessWidget {
  const _PrefPill({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSubtle : tokens.canvas,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? tokens.brand : tokens.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}