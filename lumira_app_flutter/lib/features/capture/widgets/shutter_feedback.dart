import 'package:flutter/material.dart';

/// 屏幕白闪 overlay，模拟机械快门。80ms 闪现。
class ShutterFeedback extends StatefulWidget {
  const ShutterFeedback({super.key, required this.trigger});
  final int trigger; // 递增触发，每次变化播放一次

  @override
  State<ShutterFeedback> createState() => _ShutterFeedbackState();
}

class _ShutterFeedbackState extends State<ShutterFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ShutterFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          if (_controller.value == 0) return const SizedBox.shrink();
          return Container(
            color: Colors.white.withOpacity((1 - _controller.value) * 0.8),
          );
        },
      ),
    );
  }
}
