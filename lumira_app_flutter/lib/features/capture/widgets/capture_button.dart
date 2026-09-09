import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../data/capture_state.dart';

/// 拍摄按钮（底部中央圆形）
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 130-145
/// - 外环: 80dp 直径，边框 4dp
/// - 内圆: 60dp 直径，实心
/// - 按下: 内圆缩小到 50dp
/// - 颜色：immersive=白色；theme=当前主题文字主色（浅画布上深色快门，高对比）
class CaptureButton extends ConsumerStatefulWidget {
  const CaptureButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  ConsumerState<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends ConsumerState<CaptureButton>
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
    final tokens = ref.watch(themeTokensProvider);
    final isThemed =
        ref.watch(CaptureState.captureAppearanceProvider) ==
            CaptureAppearance.theme;
    final shutterColor = isThemed ? tokens.textPrimary : Colors.white;
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
          border: Border.all(color: shutterColor, width: 4),
        ),
        alignment: Alignment.center,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shutterColor,
            ),
          ),
        ),
      ),
    );
  }
}
