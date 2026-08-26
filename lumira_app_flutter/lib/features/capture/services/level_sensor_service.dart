import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 水平仪读数。
class LevelReading {
  const LevelReading({required this.angleDeg, required this.available});

  /// 平放判定阈值（m/s²）：|x|、|y| 均小于该值时，重力基本沿 z 轴
  /// （手机平放），左右倾斜无定义，降级为 [LevelReading.unavailable]（气泡回中）。
  static const double _flatThreshold = 1.0;

  /// 从原始加速度数据（m/s²）构造读数。
  /// 手机平放（重力沿 z 轴）时无法判定左右倾斜，返回不可用读数。
  factory LevelReading.fromAccel(double x, double y) {
    if (x.abs() < _flatThreshold && y.abs() < _flatThreshold) {
      return LevelReading.unavailable;
    }
    return LevelReading(
      angleDeg: LevelSensorService.angleFromAccel(x, y),
      available: true,
    );
  }

  /// 传感器不可用 / 出错时的降级读数（气泡回中）。
  static const LevelReading unavailable =
      LevelReading(angleDeg: 0, available: false);

  /// 倾斜角（度），0 = 水平。正值 = 手机右倾（气泡右移），负值 = 左倾。
  final double angleDeg;

  /// 传感器是否可用。false 时 UI 应让气泡回中。
  final bool available;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelReading &&
          runtimeType == other.runtimeType &&
          angleDeg == other.angleDeg &&
          available == other.available;

  @override
  int get hashCode => angleDeg.hashCode ^ available.hashCode;

  @override
  String toString() =>
      'LevelReading(angleDeg: $angleDeg, available: $available)';
}

/// 水平仪传感器服务：按平台分发加速度数据，经 EMA 低通滤波后输出 [LevelReading] 流。
///
/// - 非鸿蒙（Android/iOS 等）：sensors_plus 4.0.2 的加速度计流
/// - 鸿蒙（OHOS）：自研 EventChannel `lumira/level_sensor`（[x, y, z]，m/s²），
///   由原生插件 [LumiraSensorPlugin] 订阅 @ohos.sensor 加速度计并推送
/// - 无传感器 / 出错：发出 [LevelReading.unavailable] 后结束，气泡回中、不崩溃
class LevelSensorService {
  LevelSensorService._();

  /// 鸿蒙自研 EventChannel 通道名。
  static const String ohosChannelName = 'lumira/level_sensor';
  static const EventChannel _ohosChannel = EventChannel(ohosChannelName);

  /// 是否运行在鸿蒙平台（沿用 FilePickerService 的平台分发模式）。
  static bool get isOhos => !kIsWeb && Platform.operatingSystem == 'ohos';

  /// EMA 低通滤波系数（α≈0.25：新数据权重 25%，平滑抖动）。
  static const double _alpha = 0.25;

  /// 水平仪传感器数据流（已滤波 + 角度换算）。
  static Stream<LevelReading> stream() =>
      _rawStream().transform(_smoothingTransformer());

  /// 一阶低通滤波（EMA）：`α * raw + (1 - α) * prev`。
  static double emaSmooth(double raw, double prev, [double alpha = _alpha]) =>
      alpha * raw + (1 - alpha) * prev;

  /// 竖持手机左右倾斜角（roll，绕取景轴向），0 = 水平。
  ///
  /// 使用 `atan2(x, -y)`：手机竖直时重力在屏幕坐标系中 y≈-g（向下），取 -y
  /// 使水平时为 0，且手机右倾（x 为正）时角度为正（气泡右移）。
  /// 若真机观感方向相反，可整体取负号调整。
  static double angleFromAccel(double x, double y) =>
      math.atan2(x, -y) * 180 / math.pi;

  /// 气泡偏移角度裁剪：限制在 ±[maxDeg]，避免气泡超出水平轨。
  static double clampAngle(double angle, [double maxDeg = 10.0]) =>
      angle.clamp(-maxDeg, maxDeg);

  /// 原始加速度流（[x, y, z]，m/s²）。
  static Stream<List<double>> _rawStream() {
    if (isOhos) {
      return _ohosChannel.receiveBroadcastStream().map(_parseOhosEvent);
    }
    return Sensors().accelerometerEventStream().map((e) {
      return <double>[e.x, e.y, e.z];
    });
  }

  static List<double> _parseOhosEvent(Object? event) {
    final list = event as List;
    final x = (list[0] as num).toDouble();
    final y = (list[1] as num).toDouble();
    final z = (list[2] as num).toDouble();
    return <double>[x, y, z];
  }

  /// 状态化变换器：对 x/y 原始值做 EMA 平滑后计算角度。
  /// 上游出错 / 无传感器时降级为 [LevelReading.unavailable] 并结束。
  static StreamTransformer<List<double>, LevelReading>
      _smoothingTransformer() {
    var smoothX = 0.0;
    var smoothY = 0.0;
    var initialized = false;
    return StreamTransformer.fromHandlers(
      handleData: (List<double> accel, EventSink<LevelReading> sink) {
        final x = accel[0];
        final y = accel[1];
        if (!initialized) {
          smoothX = x;
          smoothY = y;
          initialized = true;
        } else {
          smoothX = emaSmooth(x, smoothX);
          smoothY = emaSmooth(y, smoothY);
        }
        sink.add(LevelReading.fromAccel(smoothX, smoothY));
      },
      handleError: (Object e, StackTrace st, EventSink<LevelReading> sink) {
        debugPrint('[level] sensor stream error, degrading: $e');
        sink.add(LevelReading.unavailable);
        sink.close();
      },
      handleDone: (EventSink<LevelReading> sink) => sink.close(),
    );
  }
}
