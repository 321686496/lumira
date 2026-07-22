import 'package:flutter/material.dart';

/// 拍摄按钮（底部中央圆形）
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 130-145
/// - 外环: 80dp 直径，白色边框 4dp
/// - 内圆: 60dp 直径，白色实心
/// - 按下: 内圆缩小到 50dp
class CaptureButton extends StatefulWidget {
  const CaptureButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.83).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _pressing = true;
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        if (_pressing) {
          widget.onTap();
        }
        _pressing = false;
      },
      onTapCancel: () {
        _controller.reverse();
        _pressing = false;
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
