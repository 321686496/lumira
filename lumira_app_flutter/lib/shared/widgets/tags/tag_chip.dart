import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../effects/breathing_tap.dart';

/// 标签 chip 的语义类型。
///
/// 不同 [kind] 使用不同的颜色/图标语言，但均随当前 UI 风格 × 主题自适应：
/// - [TagChipKind.plain]：用户自定义 / 普通标签
/// - [TagChipKind.system]：模板自带的系统标签（用特殊视觉标识，**不含「系统」文本**）
/// - [TagChipKind.golden]：场景推荐标签
enum TagChipKind { plain, system, golden }

/// 风格自适应的标签 chip（模板详情 / 场景详情 / 统一标签区块复用）。
///
/// 颜色、边框、圆角、透明度一律从 `appThemeProvider` 派生，随设置切换而变化，
/// 不硬编码任何皮肤色。装饰对齐 `NeuCard` 的 4 风格分支：
/// - neumorphic：实心表面 + 细描边（chip 位于卡片/画布上，不做双向浮雕外阴影）
/// - flat：表面色 + 细边框
/// - glass：半透明白玻璃底 + 白色细边
/// - female：不透明暖色微渐变 + 柔和品牌投影
///
/// 可交互时（[onTap] / [onDeleted]）提供「呼吸」按压反馈。
class TagChip extends ConsumerWidget {
  const TagChip({
    super.key,
    required this.label,
    this.kind = TagChipKind.plain,
    this.selected = false,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final TagChipKind kind;

  /// 选中态（标签选择器中的已选项）。
  final bool selected;

  /// 点击整个 chip。
  final VoidCallback? onTap;

  /// 提供删除（右侧关闭按钮）。
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appThemeProvider);
    final tokens = app.tokens;

    Widget chip = _buildBody(app, tokens);

    // 可交互 → 呼吸按压反馈（女性不同缩放）
    if (onTap != null || onDeleted != null) {
      final scale = app.style == UIStyle.female ? 0.96 : 0.98;
      chip = BreathingTap(
        onTap: () {
          if (onDeleted != null && onTap == null) {
            onDeleted!();
          } else {
            onTap?.call();
          }
        },
        pressedScale: scale,
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildBody(AppThemeData app, ThemeTokens tokens) {
    final radius = BorderRadius.circular(9999);
    final textColor = selected ? tokens.textInverse : _textColorOf(app);
    final fontSize = 12.0;

    // 选中态统一品牌实底
    BoxDecoration deco;
    if (selected) {
      deco = BoxDecoration(
        color: tokens.brand,
        borderRadius: radius,
        border: Border.all(color: tokens.brand, width: 1),
      );
    } else {
      deco = _kindDecoration(app, tokens, radius);
    }

    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 系统标签用星形图标标识（区别于普通标签，不含「系统」文本）
        if (kind == TagChipKind.system) ...[
          Icon(Icons.auto_awesome, size: 12, color: textColor),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: textColor,
          ),
        ),
        if (onDeleted != null) ...[
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onDeleted,
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.close, size: 13, color: textColor),
          ),
        ],
      ],
    );

    final content = Container(
      padding: EdgeInsets.only(
        left: kind == TagChipKind.system ? 8 : 10,
        right: onDeleted != null ? 4 : 10,
        top: 4,
        bottom: 4,
      ),
      decoration: deco,
      child: inner,
    );

    // 女性风格：柔和品牌投影（非玻璃高光）
    if (app.style == UIStyle.female && !selected) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.12),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: content,
      );
    }
    return content;
  }

  BoxDecoration _kindDecoration(
      AppThemeData app, ThemeTokens tokens, BorderRadius radius) {
    switch (kind) {
      case TagChipKind.system:
        // 系统标签：品牌色系强调（区别于普通标签的表面色）
        if (app.style == UIStyle.female) {
          return BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandSubtle,
                Color.lerp(tokens.brandLight, tokens.surface, 0.4)!,
              ],
            ),
            border: Border.all(
                color: tokens.brand.withOpacity(0.25), width: 0.5),
          );
        }
        return BoxDecoration(
          color: tokens.brandSubtle,
          borderRadius: radius,
          border: Border.all(
              color: tokens.brand.withOpacity(0.28), width: 0.5),
        );
      case TagChipKind.golden:
        if (app.style == UIStyle.female) {
          return BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandSubtle,
                Color.lerp(tokens.brandLight, tokens.surface, 0.5)!,
              ],
            ),
            border: Border.all(
                color: tokens.brand.withOpacity(0.18), width: 0.5),
          );
        }
        return BoxDecoration(
          color: tokens.brand.withOpacity(0.15),
          borderRadius: radius,
          border: Border.all(
              color: tokens.brand.withOpacity(0.20), width: 0.5),
        );
      case TagChipKind.plain:
        if (app.style == UIStyle.glass) {
          return BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.6), width: 0.8),
          );
        }
        if (app.style == UIStyle.female) {
          return BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surface,
                Color.lerp(tokens.brandSubtle, tokens.surface, 0.6)!,
              ],
            ),
            border: Border.all(color: tokens.divider, width: 0.5),
          );
        }
        return BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: radius,
          border: Border.all(color: tokens.divider, width: 0.5),
        );
    }
  }

  Color _textColorOf(AppThemeData app) {
    final tokens = app.tokens;
    switch (kind) {
      case TagChipKind.plain:
        return tokens.textPrimary;
      case TagChipKind.system:
        return tokens.brandText;
      case TagChipKind.golden:
        return tokens.brandDeep;
    }
  }
}