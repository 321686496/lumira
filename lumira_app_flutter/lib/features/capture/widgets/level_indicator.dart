import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';

/// 水平仪指示器：在取景器底部显示一条水平线和气泡。
/// 通过 `levelEnabledProvider` 控制显隐，`levelAngleProvider` 控制气泡位置。
///
/// 注意：本 widget 使用 `Positioned`，必须放在 `Stack` 内部。
class LevelIndicator extends ConsumerWidget {
  const LevelIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(CaptureState.levelEnabledProvider);
    final angle = ref.watch(CaptureState.levelAngleProvider);
    if (!enabled) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: CustomPaint(
          size: const Size(120, 24),
          painter: _LevelPainter(angle: angle),
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  final double angle;
  _LevelPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      trackPaint,
    );
    // 气泡位置：angle 越大越向右偏移
    final bubbleX = center.dx + angle * 2;
    canvas.drawCircle(
      Offset(bubbleX.clamp(10.0, size.width - 10), center.dy),
      4,
      Paint()..color = Colors.amber,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy),
      3,
      Paint()..color = Colors.white38,
    );
  }

  @override
  bool shouldRepaint(_LevelPainter old) => old.angle != angle;
}
