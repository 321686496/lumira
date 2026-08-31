import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../../shared/widgets/common/glass_surface.dart';
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
          // 限制最大宽度，避免大屏/平板上弹窗内容被拉得过宽、影响阅读
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // TextField / Button 等 Material 组件需要 Material ancestor；
            // LumiraDialogContainer 是纯 Container（DecoratedBox），这里补一层透明 Material
            child: Material(
              type: MaterialType.transparency,
              child: LumiraDialogContainer(
                child: Builder(builder: builder),
              ),
            ),
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

    // glass 风格使用共享 GlassSurface（半透明主题色磨砂 + 高光 + 内描边）
    if (style == UIStyle.glass) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: visual.shadows,
        ),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(radius),
          padding: effectivePadding,
          child: child,
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
/// - 标题：17dp 半粗（w600）+ 1.35 行高，颜色 = textPrimary
/// - 正文：14dp 常规 + 1.5 行高，颜色 = textSecondary
/// - actions：横向排列，右对齐，间距 8
/// - 间距层级：标题→正文 12dp，正文/标题→按钮区 20dp
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

    // 标题/正文采用显式 dp 字号（不依赖 textTheme：主题 textTheme 的
    // bodyMedium 为 rpx 原值，直接使用会出现「正文比标题大」的问题），
    // 字号与全局组件保持一致（按钮 14 / 列表标题 16）。
    final titleStyle = const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ).copyWith(color: tokens.textPrimary);
    final contentStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ).copyWith(color: tokens.textSecondary);

    final hasTitle = title != null;
    final hasContent = content != null;
    final hasActions = actions.isNotEmpty;

    final children = <Widget>[];
    if (hasTitle) {
      children.add(
        DefaultTextStyle.merge(
          style: titleStyle,
          textAlign: TextAlign.start,
          child: title!,
        ),
      );
    }
    if (hasContent) {
      children.add(
        Padding(
          // 有标题时正文下方留 12dp，单独弹正文时不额外留白
          padding: EdgeInsets.only(top: hasTitle ? 12 : 0),
          child: DefaultTextStyle.merge(
            style: contentStyle,
            textAlign: TextAlign.start,
            child: content!,
          ),
        ),
      );
    }
    if (hasActions) {
      children.add(
        Padding(
          // 按钮区与正文/标题保持 20dp 间距
          padding: EdgeInsets.only(top: (hasTitle || hasContent) ? 20 : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
