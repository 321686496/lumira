import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../data/remote_template_dto.dart';
import 'ambience_label.dart';

/// 氛围标签组（季节 / 天气 / 时段）——按类别用不同图标 + 色调区分，避免视觉混淆。
///
/// 三类标签刻意使用不同的视觉语言，让用户一眼分辨数据含义：
/// - **季节**：绿色系（success）+ 植物图标
/// - **天气**：品牌色（brand）+ 天气图标
/// - **时段**：中性（surfaceAlt + textSecondary）+ 时钟图标
///
/// 均取自 [ThemeTokens]，跟随当前 UI 风格 / 主题切换。
class AmbienceBadges extends StatelessWidget {
  const AmbienceBadges({
    super.key,
    required this.ambience,
    required this.tokens,
    this.maxItems,
  });

  /// 季节/天气/时段元数据；为 null 时整体不渲染。
  final RemoteTemplateAmbienceDto? ambience;
  final ThemeTokens tokens;
  /// 最多展示的标签数（卡片等紧凑场景用，null 表示展示全部）。
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final a = ambience;
    if (a == null) return const SizedBox.shrink();

    final chips = <Widget>[
      for (final s in AmbienceLabel.seasonLabels(a.seasons))
        _chip(
          Icons.eco,
          s,
          tokens.successSubtle,
          tokens.success,
        ),
      for (final w in AmbienceLabel.weatherLabels(a.weathers))
        _chip(
          Icons.wb_cloudy,
          w,
          tokens.brandSubtle,
          tokens.brand,
        ),
      for (final t in AmbienceLabel.timeToneLabels(a.timeTones))
        _chip(
          Icons.schedule,
          t,
          tokens.surfaceAlt,
          tokens.textSecondary,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    final shown =
        maxItems != null ? chips.take(maxItems!).toList() : chips;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: shown,
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: fg),
          ),
        ],
      ),
    );
  }
}