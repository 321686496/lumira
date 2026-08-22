import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 如画应用统一 BottomSheet 展示函数
///
/// 替代 Material 的 `showModalBottomSheet`，容器颜色与形态随 8 主题 × 4 风格变化。
///
/// 视觉规格来源：spec §3.2 Phase 2
/// - 顶部圆角 = `appTheme.popupRadius / 2`（仅顶部两个角）
/// - 顶部 12dp padding 后是 40×4dp 拖柄（圆角 2，颜色 brandLight，居中）
/// - 4 风格分支由 `LumiraThemeResolver.containerVisual()` 统一解析
/// - glass 风格额外应用 BackdropFilter blur 20
/// - `isScrollControlled: true` 时底部加安全区 padding（适配全屏高度的滚动内容）
///
/// 用法：
/// ```dart
/// final result = await showLumiraBottomSheet<int>(
///   context: context,
///   isScrollControlled: true,
///   builder: (ctx) => ListView(
///     children: [
///       ListTile(title: Text('选项 1'), onTap: () => Navigator.pop(ctx, 1)),
///     ],
///   ),
/// );
/// ```
Future<T?> showLumiraBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    builder: (sheetContext) {
      return LumiraBottomSheetContainer(
        isScrollControlled: isScrollControlled,
        child: Builder(builder: builder),
      );
    },
  );
}

/// Lumira BottomSheet 容器
///
/// 4 风格分支渲染：
/// - neumorphic：surface 背景 + shadowFloat 阴影
/// - flat：surface 背景 + divider 顶部边框
/// - glass：白透明 0.55 背景 + backdrop blur 20 + 白透明边框 + 顶部高光渐变
/// - female：surface 背景 + brandSubtle→透明 渐变叠加 + 白透明 hairline + brand 阴影
class LumiraBottomSheetContainer extends ConsumerWidget {
  const LumiraBottomSheetContainer({
    super.key,
    required this.child,
    this.isScrollControlled = false,
    this.padding,
  });

  final Widget child;

  /// 透传 [showModalBottomSheet.isScrollControlled]，
  /// 为 true 时底部加 `MediaQuery.padding.bottom` 安全区
  final bool isScrollControlled;

  /// 内容区内边距（拖柄下方的 padding），默认 `EdgeInsets.all(20)`
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final effectivePadding = padding ?? const EdgeInsets.all(20);
    final onlyTopRadius = BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );

    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部拖柄：避开状态栏安全区 + 12dp 上 padding + 40×4 拖柄 + 16dp 下 padding
        Padding(
          padding: EdgeInsets.only(
            top: (isScrollControlled ? MediaQuery.of(context).padding.top : 0) + 12,
            bottom: 16,
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.brandLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Flexible(
          child: Padding(
            padding: effectivePadding,
            child: child,
          ),
        ),
        // isScrollControlled 透传：底部加安全区
        if (isScrollControlled) SizedBox(height: bottomPadding),
      ],
    );

    // glass 风格使用 BackdropFilter + Stack 结构
    if (style == UIStyle.glass) {
      return ClipRRect(
        borderRadius: onlyTopRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: visual.background,
              gradient: visual.glassOverlay,
              border: visual.border,
              borderRadius: onlyTopRadius,
              boxShadow: visual.shadows,
            ),
            child: body,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: visual.background,
        gradient: visual.glassOverlay,
        border: visual.border,
        borderRadius: onlyTopRadius,
        boxShadow: visual.shadows,
      ),
      child: body,
    );
  }
}
