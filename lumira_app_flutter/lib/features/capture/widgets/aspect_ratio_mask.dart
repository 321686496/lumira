import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_state.dart';

/// 取景器比例遮罩
///
/// 当用户选择非全屏比例时（如 4:3、1:1、3:4），
/// 在取景器上下（或左右）显示半透明黑色遮罩，
/// 让用户直观看到最终照片的裁剪区域。
///
/// 全屏模式下不显示遮罩（照片与取景器完全一致）。
class AspectRatioMask extends ConsumerWidget {
  const AspectRatioMask({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = ref.watch(CaptureState.aspectRatioProvider);

    // 全屏模式：不显示遮罩
    if (ratio == 'fullscreen') return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final isPortrait = size.height >= size.width;
    final screenW = size.width;
    final screenH = size.height;

    // 计算目标比例
    double targetRatio;
    switch (ratio) {
      case '4:3':
        targetRatio = isPortrait ? 3.0 / 4.0 : 4.0 / 3.0;
        break;
      case '1:1':
        targetRatio = 1.0;
        break;
      case '3:4':
        targetRatio = 3.0 / 4.0;
        break;
      default:
        return const SizedBox.shrink();
    }

    // 计算可见区域：在屏幕内居中显示目标比例的矩形
    final screenRatio = screenW / screenH;
    double visibleW, visibleH;
    if (screenRatio > targetRatio) {
      // 屏幕比目标更宽 → 按高度适配，左右留黑
      visibleH = screenH;
      visibleW = visibleH * targetRatio;
    } else {
      // 屏幕比目标更高 → 按宽度适配，上下留黑
      visibleW = screenW;
      visibleH = visibleW / targetRatio;
    }

    // 如果可见区域几乎等于屏幕，不显示遮罩
    if ((visibleW - screenW).abs() < 1 && (visibleH - screenH).abs() < 1) {
      return const SizedBox.shrink();
    }

    final leftBand = (screenW - visibleW) / 2.0;
    final topBand = (screenH - visibleH) / 2.0;

    return IgnorePointer(
      child: Stack(
        children: [
          // 左遮罩
          if (leftBand > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: leftBand,
              child: Container(color: Colors.black.withOpacity(0.65)),
            ),
          // 右遮罩
          if (leftBand > 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: leftBand,
              child: Container(color: Colors.black.withOpacity(0.65)),
            ),
          // 上遮罩
          if (topBand > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: topBand,
              child: Container(color: Colors.black.withOpacity(0.65)),
            ),
          // 下遮罩
          if (topBand > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: topBand,
              child: Container(color: Colors.black.withOpacity(0.65)),
            ),
          // 可见区域边框（白色细线）
          Positioned(
            left: leftBand,
            top: topBand,
            width: visibleW,
            height: visibleH,
            child: Container(
              decoration: BorderBoxDecoration.box,
            ),
          ),
        ],
      ),
    );
  }
}

/// 边框装饰辅助
class BorderBoxDecoration {
  static final box = BoxDecoration(
    border: Border.all(
      color: Colors.white.withOpacity(0.3),
      width: 0.5,
    ),
  );
}
