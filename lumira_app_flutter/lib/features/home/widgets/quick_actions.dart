import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 快捷入口配置
class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.circleColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color circleColor;
  final Color iconColor;
  final VoidCallback onTap;
}

/// 快捷入口行
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 40-65 + style line 428-481
/// - 96rpx→48dp 圆形 + 44rpx→22dp 图标
/// - quick-circle-gold: brand-subtle bg + brand icon
/// - quick-circle-green: success-subtle bg + success icon
/// - quick-circle-red: danger-subtle bg + danger icon
class QuickActions extends ConsumerWidget {
  const QuickActions({
    super.key,
    required this.onCapture,
    required this.onTemplates,
    required this.onInspiration,
    required this.onGallery,
  });

  final VoidCallback onCapture;
  final VoidCallback onTemplates;
  final VoidCallback onInspiration;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;

    // neumorphic 风格下：圆形按钮背景统一改为 surface（保留原图标颜色 brand/success/danger）
    // 其他风格：保留原 brandSubtle/successSubtle/dangerSubtle 半透明背景
    final circleBg = isNeumorphic ? tokens.surface : null;

    final actions = [
      _QuickAction(
        icon: Icons.camera_alt_outlined,
        label: '拍摄',
        circleColor: circleBg ?? tokens.brandSubtle,
        iconColor: tokens.brand,
        onTap: onCapture,
      ),
      _QuickAction(
        icon: Icons.menu_book_outlined,
        label: '发现',
        circleColor: circleBg ?? tokens.successSubtle,
        iconColor: tokens.success,
        onTap: onTemplates,
      ),
      _QuickAction(
        icon: Icons.auto_awesome_outlined,
        label: '灵感',
        circleColor: circleBg ?? tokens.brandSubtle,
        iconColor: tokens.brand,
        onTap: onInspiration,
      ),
      _QuickAction(
        icon: Icons.photo_library_outlined,
        label: '相册',
        circleColor: circleBg ?? tokens.dangerSubtle,
        iconColor: tokens.danger,
        onTap: onGallery,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24, // 48rpx → 24dp
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions
            .map((action) => _QuickItem(
                  action: action,
                  tokens: tokens,
                  isNeumorphic: isNeumorphic,
                ))
            .toList(),
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.action,
    required this.tokens,
    this.isNeumorphic = false,
  });

  final _QuickAction action;
  final ThemeTokens tokens;

  /// 是否为 neumorphic 风格（影响圆形按钮阴影渲染）
  final bool isNeumorphic;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, // 96rpx → 48dp
            height: 48,
            decoration: BoxDecoration(
              color: action.circleColor,
              shape: BoxShape.circle,
              // neumorphic 风格：添加轻量凸起阴影
              // 其他风格：无阴影
              boxShadow: isNeumorphic
                  ? tokens.shadowConvexSubtle
                  : null,
            ),
            child: Icon(
              action.icon,
              size: 22, // 44rpx → 22dp
              color: action.iconColor,
            ),
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          Text(
            action.label,
            style: TextStyle(
              fontSize: 12, // 24rpx → 12dp
              color: tokens.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
