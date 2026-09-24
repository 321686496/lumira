import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';

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

/// 偏好组标题：标签在左、可选的操作提示在右（如「可多选」）。
///
/// 字号/字重/颜色统一走 [textSecondary]，与页面级节标题（textPrimary / 16）
/// 拉开一级，避免「节标题」与「字段标签」同级导致层级塌陷。
class PrefGroupTitle extends StatelessWidget {
  const PrefGroupTitle({
    super.key,
    required this.title,
    required this.tokens,
    this.hint,
  });

  final String title;
  final ThemeTokens tokens;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// 单选偏好块：展示中文 label，选中高亮，点击回调。
class PrefSingleSelector extends StatelessWidget {
  const PrefSingleSelector({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.tokens,
    this.hint,
  });

  final String title;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final ThemeTokens tokens;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrefGroupTitle(title: title, hint: hint, tokens: tokens),
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
    this.hint,
  });

  final String title;
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final ThemeTokens tokens;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrefGroupTitle(title: title, hint: hint, tokens: tokens),
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

/// 单个偏好胶囊：视觉随设置里的 4 种 UI 风格联动。
///
/// - neumorphic：未选中 = surface 凸起浮雕；选中 = 同色 surface 凹陷内影（不填充主色）
/// - flat：未选中 = surfaceAlt + divider 细边；选中 = brandSubtle + brand 描边
/// - glass：未选中 = 半透明 surface + 灯光细边；选中 = 品牌色半透明 + 品牌描边
/// - female：未选中 = 纸面微渐变 + 品牌 hairline；选中 = 品牌渐变 + 柔和品牌投影
class _PrefPill extends ConsumerWidget {
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

  static const double _radius = 999;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(uiStyleProvider);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? tokens.brandText : tokens.textSecondary,
        ),
      ),
    );

    Widget pill;
    if (style == UIStyle.neumorphic) {
      // 新拟态：未选中凸起、选中凹陷；两者同为 surface 底色，只用明暗和字色
      // 表达选中，不填充主色（纯色画布上的同色浮雕才是这套风格的本体）。
      pill = selected
          ? RecessedSurface(
              tokens: tokens,
              borderRadius: _radius,
              depth: 0.55,
              rimFraction: 0.5,
              child: content,
            )
          : Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(_radius),
                boxShadow: tokens.shadowConvexSubtle,
              ),
              child: content,
            );
    } else {
      pill = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: _decoration(style),
        child: content,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }

  BoxDecoration _decoration(UIStyle style) {
    switch (style) {
      case UIStyle.neumorphic:
        // 不应到达（新拟态走 RecessedSurface / 凸起容器）。
        return BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(_radius),
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: selected ? tokens.brandSubtle : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: selected ? tokens.brand : tokens.divider,
            width: selected ? 1.5 : 1,
          ),
        );
      case UIStyle.glass:
        return BoxDecoration(
          color: selected
              ? tokens.brandSubtle.withOpacity(0.85)
              : tokens.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: selected
                ? tokens.brand.withOpacity(0.7)
                : ThemeTokens.glassBorder(tokens),
            width: selected ? 1.5 : 1,
          ),
        );
      case UIStyle.female:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [tokens.brandSubtle, tokens.brandLight.withOpacity(0.45)]
                : [tokens.surface, tokens.brandSubtle.withOpacity(0.45)],
          ),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: selected ? tokens.brand : tokens.brand.withOpacity(0.18),
            width: selected ? 1.2 : 0.8,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tokens.brand.withOpacity(0.22),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ]
              : null,
        );
    }
  }
}