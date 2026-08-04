import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 如画应用统一 Dialog 容器与展示函数
///
/// 替代 Material 的 `showDialog` + `AlertDialog`，颜色与形态随 8 主题 × 4 风格变化。
///
/// 视觉规格来源：spec §3.2 Phase 2
/// - 圆角 = `appTheme.popupRadius / 2`（rpx → dp）
/// - 4 风格分支由 `LumiraThemeResolver.containerVisual()` 统一解析
/// - glass 风格额外应用 backdrop blur（sigma = containerVisual.backdropBlurSigma）
/// - 自动避开状态栏与底部安全区（`SafeArea` 包裹）
///
/// 用法：
/// ```dart
/// // 1. 自定义内容
/// final result = await showLumiraDialog<int>(
///   context: context,
///   builder: (ctx) => Column(
///     mainAxisSize: MainAxisSize.min,
///     children: [
///       Text('标题'),
///       LumiraButton(variant: ButtonVariant.primary, onPressed: () => Navigator.pop(ctx, 1), child: Text('确定')),
///     ],
///   ),
/// );
///
/// // 2. 预设 AlertDialog 形态
/// await LumiraAlertDialog.show(
///   context: context,
///   title: Text('提示'),
///   content: Text('确定删除？'),
///   actions: [TextButton(onPressed: () {}, child: Text('取消'))],
/// );
/// ```
Future<T?> showLumiraDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      return SafeArea(
        child: Center(
          child: LumiraDialogContainer(
            child: Builder(builder: builder),
          ),
        ),
      );
    },
  );
}

/// Lumira Dialog 容器
///
/// 4 风格分支渲染：
/// - neumorphic：surface 背景 + shadowFloat 阴影
/// - flat：surface 背景 + divider 边框
/// - glass：白透明 0.55 背景 + backdrop blur 25 + 白透明边框 + 顶部高光渐变
/// - female：surface 背景 + brandSubtle→透明 渐变叠加 + 白透明 hairline + brand 阴影
///
/// 容器自带横向 24dp 外边距（保证小屏不贴边）；内部默认 padding 24dp，可由 [padding] 覆盖。
class LumiraDialogContainer extends ConsumerWidget {
  const LumiraDialogContainer({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;

  /// 内边距，默认 `EdgeInsets.all(24)`
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final radius = appTheme.popupRadius / 2;
    final visual = LumiraThemeResolver.containerVisual(
      tokens: tokens,
      style: style,
      radiusDp: radius,
    );
    final effectivePadding = padding ?? const EdgeInsets.all(24);

    // glass 风格需要 BackdropFilter，使用 Stack 结构让 blur 在背景层、内容在顶层
    if (visual.backdropBlurSigma > 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: visual.shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: visual.backdropBlurSigma,
                    sigmaY: visual.backdropBlurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: visual.background,
                      gradient: visual.glassOverlay,
                      border: visual.border,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: effectivePadding,
                child: child,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(radius),
        border: visual.border,
        boxShadow: visual.shadows,
        gradient: visual.glassOverlay,
      ),
      child: child,
    );
  }
}

/// 预设的 Lumira 警告对话框
///
/// 提供标准 `title` + `content` + `actions` 结构，颜色随主题变化。
///
/// - 标题：`Theme.of(context).textTheme.titleMedium` 加粗，颜色 = textPrimary
/// - 正文：`Theme.of(context).textTheme.bodyMedium`，颜色 = textSecondary
/// - actions：横向排列，右对齐，间距 8
///
/// 用法：
/// ```dart
/// await LumiraAlertDialog.show(
///   context: context,
///   title: Text('提示'),
///   content: Text('确定删除？'),
///   actions: [
///     LumiraButton(variant: ButtonVariant.ghost, onPressed: () => Navigator.pop(context), child: Text('取消')),
///     LumiraButton(variant: ButtonVariant.primary, onPressed: () => Navigator.pop(context, true), child: Text('删除')),
///   ],
/// );
/// ```
class LumiraAlertDialog extends ConsumerWidget {
  const LumiraAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  /// 便捷展示方法，内部调用 [showLumiraDialog]
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<Widget> actions = const [],
    bool barrierDismissible = true,
  }) {
    return showLumiraDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => LumiraAlertDialog(
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = (textTheme.titleMedium ??
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))
        .copyWith(
      fontWeight: FontWeight.bold,
      color: tokens.textPrimary,
    );
    final contentStyle = (textTheme.bodyMedium ??
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400))
        .copyWith(color: tokens.textSecondary);

    final children = <Widget>[];
    if (title != null) {
      children.add(
        DefaultTextStyle.merge(
          style: titleStyle,
          textAlign: TextAlign.start,
          child: title!,
        ),
      );
    }
    if (content != null) {
      children.add(
        DefaultTextStyle.merge(
          style: contentStyle,
          textAlign: TextAlign.start,
          child: content!,
        ),
      );
    }
    if (actions.isNotEmpty) {
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    );
  }
}
