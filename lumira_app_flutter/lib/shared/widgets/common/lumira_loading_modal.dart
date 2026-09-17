import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../lumira/feedback/lumira_progress.dart';

/// 全局加载模态。
///
/// 点击「生成 / 加载」类操作时弹出，阻塞交互，任务完成后自动关闭并返回结果。
/// 视觉随 8 主题色 × 4 套 UI 风格自适应，贴合 App 品牌调性：
/// - neumorphic：纯色画布 + tokens.shadowConvex 双向浮雕
/// - flat      ：细边框 + 无阴影
/// - glass     ：半透明毛玻璃（BackdropFilter）+ 玻璃描边
/// - female    ：多渐变 + brand 柔和阴影
///
/// 用法：
/// ```dart
/// final result = await showLumiraLoading(
///   context,
///   message: '正在生成…',
///   task: () async { ... return data; },
/// );
/// ```
/// 若 [task] 抛异常，模态自动关闭并向上抛出该异常。
Future<T?> showLumiraLoading<T>(
  BuildContext context, {
  required Future<T> Function() task,
  String message = '正在生成…',
}) async {
  final result = Completer<T>();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) => _LoadingModalDialog<T>(
      message: message,
      task: task,
      onResult: result,
    ),
  );
  return result.isCompleted ? result.future : null;
}

/// 加载模态对话框：挂载后启动 [task]，完成/失败时关闭自身并把结果交给 [onResult]。
class _LoadingModalDialog<T> extends StatefulWidget {
  const _LoadingModalDialog({
    required this.message,
    required this.task,
    required this.onResult,
  });

  final String message;
  final Future<T> Function() task;
  final Completer<T> onResult;

  @override
  State<_LoadingModalDialog<T>> createState() => _LoadingModalDialogState<T>();
}

class _LoadingModalDialogState<T> extends State<_LoadingModalDialog<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
    _run();
  }

  Future<void> _run() async {
    T? value;
    Object? error;
    StackTrace? st;
    try {
      value = await widget.task();
    } catch (e, s) {
      error = e;
      st = s;
    }
    if (!mounted) return;
    if (error != null) {
      widget.onResult.completeError(error, st!);
    } else {
      widget.onResult.complete(value as T);
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: _LoadingModalCard(message: widget.message),
        ),
      ),
    );
  }
}

/// 加载模态卡片本体：按 4 风格 × 8 主题自适应。
class _LoadingModalCard extends ConsumerWidget {
  const _LoadingModalCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    // popupRadius 为 rpx 原值，按约定 /2 转 dp。
    final radius = appTheme.popupRadius / 2;

    final inside = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LumiraProgress.circular(strokeWidth: 3, size: 40),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );

    // glass：半透明毛玻璃卡片（该风格自己的玻璃）。
    final Widget card;
    switch (style) {
      case UIStyle.glass:
        card = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 150,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
              decoration: BoxDecoration(
                color: ThemeTokens.glassFill(tokens),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: ThemeTokens.glassBorder(tokens),
                  width: 1,
                ),
                boxShadow: appTheme.cardShadow,
              ),
              child: inside,
            ),
          ),
        );
        break;
      case UIStyle.neumorphic:
        // 叠加在模态上的卡片，去掉凸起外阴影（避免在 message 文字下方形成暖色细影，
        // 且模态内无需浮雕取向），改用细描边定义表面。
        card = Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.divider, width: 1),
          ),
          child: inside,
        );
        break;
      case UIStyle.female:
        card = Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandSubtle,
                tokens.surface,
                Color.lerp(tokens.brandLight, tokens.surface, 0.6)!,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: appTheme.cardShadow,
          ),
          child: inside,
        );
        break;
      case UIStyle.flat:
        card = Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.divider, width: 1),
          ),
          child: inside,
        );
        break;
    }

    return Center(child: card);
  }
}