import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 如画应用统一列表项组件
///
/// 替换原生 ListTile，提供 4 风格分支渲染的点击反馈。
/// 视觉规格来源：spec §3.5 LumiraListTile
///
/// - 默认 padding：horizontal 20，vertical 12（dense 时 vertical 8）
/// - 4 风格差异：仅 splashColor 不同
///   - neumorphic / flat：tokens.brandSubtle
///   - glass：白透明 0.2
///   - female：brandSubtle 0.3
/// - disabled 时整体 opacity 0.4
/// - 文字颜色：title = tokens.textPrimary，subtitle = tokens.textSecondary
class LumiraListTile extends ConsumerStatefulWidget {
  const LumiraListTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dense = false,
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;

  @override
  ConsumerState<LumiraListTile> createState() => _LumiraListTileState();
}

class _LumiraListTileState extends ConsumerState<LumiraListTile> {
  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final splashColor = LumiraThemeResolver.listTileSplashColor(tokens, style);

    final isInteractive = widget.enabled && widget.onTap != null;
    final verticalPadding = widget.dense ? 8.0 : 12.0;

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  child: widget.title,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    child: widget.subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 12),
            widget.trailing!,
          ],
        ],
      ),
    );

    // 点击反馈：Material + InkWell，splashColor 由 4 风格解析
    if (isInteractive) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          splashColor: splashColor,
          highlightColor: splashColor.withOpacity(0.5),
          child: content,
        ),
      );
    }

    // disabled 时整体 opacity 0.4
    if (!widget.enabled) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return content;
  }
}
