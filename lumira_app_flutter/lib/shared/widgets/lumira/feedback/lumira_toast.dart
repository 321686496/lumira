import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';

/// Lumira 自定义 Toast 组件（主题感知版）
///
/// 替代 Flutter 自带的 SnackBar，颜色随 8 主题 × 4 风格变化。
///
/// 视觉规格（spec §3.1）：
/// - 深色主题（ink，canvas.computeLuminance() < 0.5）：背景 `tokens.canvasDeep` + brand 装饰条
/// - 浅色主题：背景 `tokens.canvas` 90% 透明 + brand 装饰条
/// - 文字：深色用 `tokens.textInverse`，浅色用 `tokens.textPrimary`（更深的 brandText）
/// - 行动按钮：`brandSubtle` 背景 + `brandText` 文字
/// - 圆角：12px，柔和阴影
/// - 动画：从顶部滑入 + 淡入；消失时淡出 + 上滑
///
/// API 与原 LumiraToast 完全兼容：
/// ```dart
/// LumiraToast.show(context, '已保存到相册');
/// LumiraToast.show(context, '生成失败', action: ToastAction(label: '重试', onTap: () {}));
/// ```
///
/// 主题读取：LumiraToast 是静态方法，不能用 ConsumerWidget。在 `_LumiraToastView` 内部
/// 通过 `ProviderScope.containerOf(context, listen: false).read(appThemeProvider)` 获取主题。
/// 由于 toast 显示时间短（默认 2s），使用 read 而非 listen 即可。
class LumiraToast {
  LumiraToast._();

  /// 显示 Toast
  ///
  /// [message] 主消息
  /// [action] 可选行动按钮（如"重试"、"查看"）
  /// [duration] 显示时长，默认 2 秒
  /// [position] 显示位置，默认顶部
  static void show(
    BuildContext context,
    String message, {
    ToastAction? action,
    Duration duration = const Duration(seconds: 2),
    ToastPosition position = ToastPosition.top,
  }) {
    showWithOverlay(
      Overlay.of(context, rootOverlay: true),
      message,
      action: action,
      duration: duration,
      position: position,
    );
  }

  /// 通过 [OverlayState] 直接显示 Toast。
  ///
  /// 用于无页面 context 的全局回调（如分享降级）：此时不能调用
  /// `Overlay.of(navigatorKey.currentContext!)`——Navigator 自身的 context
  /// 位于它创建的 Overlay 之上，向上查找会抛 "No Overlay widget found"。
  /// 应通过 `NavigatorState.overlay` 拿到 OverlayState 后调用本方法。
  static void showWithOverlay(
    OverlayState overlay,
    String message, {
    ToastAction? action,
    Duration duration = const Duration(seconds: 2),
    ToastPosition position = ToastPosition.top,
  }) {
    late OverlayEntry entry;
    late _LumiraToastController controller;

    controller = _LumiraToastController(
      onRemove: () {
        controller._dispose();
        if (entry.mounted) entry.remove();
      },
    );

    entry = OverlayEntry(
      builder: (ctx) => _LumiraToastView(
        message: message,
        action: action,
        position: position,
        duration: duration,
        controller: controller,
      ),
    );

    overlay.insert(entry);
    controller._show();
  }
}

/// Toast 行动按钮配置
class ToastAction {
  const ToastAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

/// Toast 显示位置
enum ToastPosition { top, bottom }

// ── 内部实现 ──

class _LumiraToastController {
  _LumiraToastController({required this.onRemove});

  final VoidCallback onRemove;

  final ValueNotifier<double> _opacity = ValueNotifier(0.0);
  final ValueNotifier<Offset> _offset = ValueNotifier(const Offset(0, -0.15));

  bool _removed = false;

  // 可取消的退出动画定时器，避免 widget 销毁后仍有 pending timer（测试环境会抛
  // `!timersPending` 断言失败；生产环境也会泄漏）
  Timer? _dismissTimer;

  void _show() {
    // 触发入场动画
    Future.microtask(() {
      _opacity.value = 1.0;
      _offset.value = Offset.zero;
    });
  }

  void dismiss() {
    if (_removed) return;
    _removed = true;
    _opacity.value = 0.0;
    _offset.value = const Offset(0, -0.15);
    // 等动画结束后移除（可取消，dispose 中会取消以避免 pending timer）
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 220), onRemove);
  }

  void _dispose() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _opacity.dispose();
    _offset.dispose();
  }
}

class _LumiraToastView extends StatefulWidget {
  const _LumiraToastView({
    required this.message,
    required this.position,
    required this.duration,
    required this.controller,
    this.action,
  });

  final String message;
  final ToastAction? action;
  final ToastPosition position;
  final Duration duration;
  final _LumiraToastController controller;

  @override
  State<_LumiraToastView> createState() => _LumiraToastViewState();
}

class _LumiraToastViewState extends State<_LumiraToastView> {
  // 自动消失定时器（可取消，避免 widget 销毁后仍有 pending timer）
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    // 延时自动消失
    _autoDismissTimer = Timer(widget.duration, () {
      if (mounted) widget.controller.dismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Positioned(
      top: widget.position == ToastPosition.top ? topPadding + 16 : null,
      bottom: widget.position == ToastPosition.bottom ? bottomPadding + 24 : null,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              widget.controller._opacity,
              widget.controller._offset,
            ]),
            builder: (ctx, _) {
              return Opacity(
                opacity: widget.controller._opacity.value,
                child: FractionalTranslation(
                  translation: widget.controller._offset.value,
                  child: _ToastCard(
                    message: widget.message,
                    action: widget.action,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, this.action});

  final String message;
  final ToastAction? action;

  @override
  Widget build(BuildContext context) {
    // 通过 Riverpod 容器读取当前主题（静态方法无法用 ConsumerWidget）
    final appTheme = ProviderScope.containerOf(context, listen: false)
        .read(appThemeProvider);
    final tokens = appTheme.tokens;
    final isDark = tokens.canvas.computeLuminance() < 0.5;

    // 深色主题：canvasDeep；浅色主题：canvas 90% 透明
    final Color backgroundColor = isDark
        ? tokens.canvasDeep
        : tokens.canvas.withOpacity(0.9);
    // 深色主题：textInverse；浅色主题：textPrimary（更深的 brandText 提升对比）
    final Color textColor = isDark ? tokens.textInverse : tokens.textPrimary;
    final Color brandBarColor = tokens.brand;
    final Color brandBorderColor = tokens.brand.withOpacity(0.35);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // brand 色装饰边框
          color: brandBorderColor,
          width: 0.75,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧 brand 色装饰条
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: brandBarColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // 主消息
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: textColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // 可选行动按钮
          if (action != null) ...[
            const SizedBox(width: 12),
            _ToastActionButton(action: action!),
          ],
        ],
      ),
    );
  }
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({required this.action});

  final ToastAction action;

  @override
  Widget build(BuildContext context) {
    final appTheme = ProviderScope.containerOf(context, listen: false)
        .read(appThemeProvider);
    final tokens = appTheme.tokens;

    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          // 行动按钮：brandSubtle 背景 + brandText 文字
          color: tokens.brandSubtle,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          action.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tokens.brandText,
          ),
        ),
      ),
    );
  }
}
