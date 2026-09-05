import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 设备持握显示方向：竖屏 or 横屏（并给出横屏时内容要旋转到正向的 90° 圈数）。
///
/// 用于横屏拍摄时：把悬浮可折叠的「模板信息卡」等元素旋转到与持机方向一致的可读角度。
/// 定义：
/// - [portrait]：true=竖持，false=横持。
/// - [quarterTurns]：相对竖屏，元素需**顺时针**旋转的 90° 圈数（仅 0/1/3）。
///   - 0：竖持，无需旋转。
///   - 1：横持且手机「顶部朝右」（即顺时针 90°，landscapeRight）→ 内容顺时针转 90°。
///   - 3：横持且手机「顶部朝左」（landscapeLeft）→ 内容逆时针转 90°（= 顺时针 270°）。
class HoldOrientation {
  const HoldOrientation({required this.portrait, required this.quarterTurns});

  final bool portrait;

  /// 横屏时元素要顺时针旋转的 90° 圈数（0/1/3）。
  final int quarterTurns;

  bool get isLandscape => !portrait;
}

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

  /// 判定手机此刻是竖持(true)还是横持(false)，并给出横屏时内容旋转到正向的圈数。
  ///
  /// 用于拍摄方向、比例切换与横屏悬浮卡旋转。**不依赖 Flutter 窗口是否已旋转**：
  /// OHOS 引擎在窗口旋转时不一定把方向同步给 MediaQuery，导致横屏持机时 MediaQuery
  /// 恒报竖屏、成片恒为竖图。这里直接读加速度计判断"手机拿横了没、哪边朝下"，
  /// 与 iPhone 原相机一致。
  ///
  /// 判定规则（[x,y,z] 为 m/s²，重力≈9.8）：
  /// - 竖持时重力主轴在屏幕 y 轴、横持时在 x 轴 → |y|>=|x| 判竖持、|x|>|y| 判横持。
  /// - 横屏再按 [x] 正负分辨左右：x>0（重力沿 +x，手机右缘朝下）→ landscapeRight，
  ///   内容顺时针转 90°（[HoldOrientation.quarterTurns]=1）；x<0 → landscapeLeft，
  ///   内容逆时针转 90°（quarterTurns=3）。
  /// - 手机平放（重力几乎全沿 z 轴，|x|、|y| 都小）时无左右方向感，维持上次判定。
  static Stream<HoldOrientation> holdOrientationStream() =>
      _rawStream().transform(_holdOrientationTransformer());

  static StreamTransformer<List<double>, HoldOrientation>
      _holdOrientationTransformer() {
    HoldOrientation? last;
    return StreamTransformer.fromHandlers(
      handleData: (List<double> a, EventSink<HoldOrientation> sink) {
        // 坐标系（2026-09-05 按官方文档核实）：OHOS @ohos.sensor 加速度计与
        // Android/iOS 一致 —— X 轴沿屏幕短边（宽，右为正）、Y 轴沿屏幕长边（高，
        // 上为正）、Z 轴垂直屏幕向外。因此竖持时 |y|≈9.8、|x|≈0，
        // `portrait = |y| >= |x|` 即为正确判定，**不要做任何 x/y 对调**：
        // 此前误加的 OHOS 轴对调曾把竖持判成横持（isPortrait=false），
        // 导致成片被旋 270°、拍照回退慢速 Dart 管线（4991ms）。
        // （与同文件 _smoothingTransformer 供水平仪的未对调轴约定保持一致。）
        final x = a[0].abs();
        final y = a[1].abs();
        final z = a[2].abs();
        // 平放或接近平放：重力沿 z 轴，无竖/横持方向感 → 维持上次判定。
        if (z >= 1.0 && x < 2.0 && y < 2.0) {
          if (last != null) sink.add(last!);
          return;
        }
        final portrait = y >= x;
        var quarterTurns = 0;
        if (!portrait) {
          // 横屏：按 [a0] 正负分辨左右。如果真机观感旋转方向相反，把 1/3 对调即可。
          quarterTurns = a[0] > 0 ? 1 : 3;
        }
        // 首帧诊断：打印原始轴值，用于真机/新机型核对轴约定（竖持时应见 |a1|≈9.8）。
        if (last == null) {
          final fmt = (double v) => v.toStringAsFixed(2);
          debugPrint('[level] accel(raw)=${fmt(a[0])},${fmt(a[1])},${fmt(a[2])} '
              '=> portrait=$portrait');
        }
        final orientation =
            HoldOrientation(portrait: portrait, quarterTurns: quarterTurns);
        last = orientation;
        sink.add(orientation);
      },
      handleError: (Object e, StackTrace st, EventSink<HoldOrientation> sink) {
        if (last != null) sink.add(last!);
        sink.close();
      },
      handleDone: (EventSink<HoldOrientation> sink) => sink.close(),
    );
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
