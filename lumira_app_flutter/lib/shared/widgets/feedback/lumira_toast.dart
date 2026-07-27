import 'dart:async';

import 'package:flutter/material.dart';

/// Lumira 自定义 Toast 组件
///
/// 替代 Flutter 自带的 SnackBar，与项目深色 + 金色品牌主题高度匹配。
///
/// 视觉规格：
/// - 背景：深色半透明（#1C1A17 90%），与拍摄/预览页一致
/// - 文字：暖白色（#FAF7F2）
/// - 强调色：品牌金（#C9A96E），用于行动按钮和左侧装饰条
/// - 圆角：12px
/// - 阴影：柔和投影，营造浮层感
/// - 动画：从顶部滑入 + 淡入；消失时淡出 + 上滑
///
/// 用法：
/// ```dart
/// LumiraToast.show(context, '已保存到相册');
/// LumiraToast.show(context, '生成失败', action: ToastAction(label: '重试', onTap: () {}));
/// ```
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
    final overlay = Overlay.of(context, rootOverlay: true);
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // 深色半透明背景，与拍摄/预览页一致
        color: const Color(0xE61C1A17),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // 金色左侧装饰条通过 BorderDirectional 实现
          color: const Color(0xFFC9A96E).withOpacity(0.35),
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
          // 左侧金色装饰条
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // 主消息
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFFFAF7F2),
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
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A96E).withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          action.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD4B57A),
          ),
        ),
      ),
    );
  }
}
