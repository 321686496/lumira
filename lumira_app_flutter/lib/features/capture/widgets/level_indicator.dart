import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../services/level_sensor_service.dart';

/// 水平仪指示器：在取景器底部显示一条水平线和气泡。
/// 通过 `levelEnabledProvider` 控制显隐，气泡位置由
/// `levelSensorProvider`（加速度传感器 + EMA 滤波）驱动。
///
/// 注意：本 widget 使用 `Positioned`，必须放在 `Stack` 内部。
class LevelIndicator extends ConsumerWidget {
  const LevelIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(CaptureState.levelEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    // 传感器不可用 / 出错时 reading.available=false，角度归 0（气泡回中、不变绿）
    final reading = ref.watch(CaptureState.levelSensorProvider).maybeWhen(
          data: (r) => r,
          orElse: () => LevelReading.unavailable,
        );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: CustomPaint(
          size: const Size(120, 24),
          painter: _LevelPainter(
            angle: reading.available ? reading.angleDeg : 0,
            isLevel: reading.available && reading.angleDeg.abs() < levelDegThreshold,
          ),
        ),
      ),
    );
  }
}

/// 判定「水平」的角度阈值（度）：气泡在此范围内变为绿色。
const double levelDegThreshold = 0.8;

class _LevelPainter extends CustomPainter {
  final double angle;
  final bool isLevel;

  /// 角度→像素系数：±10° 映射到 ±(轨长/2 - 10)。
  static const double _pxPerDeg = 5.0;

  static const Color _trackColor = Colors.white24;
  static const Color _bubbleColor = Colors.amber;
  static const Color _bubbleLevelColor = Color(0xFF69F0AE); // 绿色（水平时）
  static const Color _centerDotColor = Colors.white38;

  _LevelPainter({required this.angle, required this.isLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = _trackColor
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      trackPaint,
    );
    // 气泡位置：角度越大越向右偏移（先 clamp ±10° 防止出轨）
    final clamped = angle.clamp(-10.0, 10.0);
    final bubbleX = (center.dx + clamped * _pxPerDeg)
        .clamp(10.0, size.width - 10);
    canvas.drawCircle(
      Offset(bubbleX, center.dy),
      isLevel ? 5 : 4,
      Paint()
        ..color = isLevel ? _bubbleLevelColor : _bubbleColor
        ..style = PaintingStyle.fill,
    );
    // 中心基准点：水平时变绿
    canvas.drawCircle(
      Offset(center.dx, center.dy),
      3,
      Paint()..color = isLevel ? _bubbleLevelColor : _centerDotColor,
    );
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.angle != angle || old.isLevel != isLevel;
}
