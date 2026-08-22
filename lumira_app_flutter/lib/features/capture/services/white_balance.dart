import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 白平衡模式。
///
/// 与相机原生通道约定一致，`name` 直接作为 `CamerawesomePlugin.setWhiteBalance(mode, k)` 的 mode 参数。
enum WhiteBalanceMode { auto, daylight, cloudy, fluorescent, incandescent }

/// 把模板/设置里的预设模式字符串（'auto'/'daylight'/'cloudy'/'fluorescent'/'incandescent'）
/// 映射为 [WhiteBalanceMode]。未知值回退到 [WhiteBalanceMode.auto]。
WhiteBalanceMode whiteBalanceModeFromString(String value) {
  return WhiteBalanceMode.values.firstWhere(
    (m) => m.name == value,
    orElse: () => WhiteBalanceMode.auto,
  );
}

/// 传感器级白平衡设置（跨三端共享模型）。
class WhiteBalanceSettings {
  const WhiteBalanceSettings({
    this.mode = WhiteBalanceMode.auto,
    this.temperatureK,
  });

  final WhiteBalanceMode mode;

  /// 色温（开尔文），取值 3000..8000，仅非 auto 模式生效，auto 时为 null。
  final int? temperatureK;

  bool get isAuto => mode == WhiteBalanceMode.auto;

  WhiteBalanceSettings copyWith({
    WhiteBalanceMode? mode,
    int? temperatureK,
  }) {
    return WhiteBalanceSettings(
      mode: mode ?? this.mode,
      temperatureK: temperatureK ?? this.temperatureK,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WhiteBalanceSettings &&
        other.mode == mode &&
        other.temperatureK == temperatureK;
  }

  @override
  int get hashCode => Object.hash(mode, temperatureK);

  @override
  String toString() =>
      'WhiteBalanceSettings(mode: $mode, temperatureK: $temperatureK)';
}

/// 白平衡会话状态（实时调节取景器，**不写入模板 CameraParams**）。
///
/// 放在顶层 riverpod provider 而非本地 StatefulWidget：TabBarView 切换 Tab 会
/// dispose/重建非当前页 child，本地 state 会丢失；provider 保证切换或模板变更
/// 后白平衡选择得以保留并同步到传感器。
final whiteBalanceSessionProvider =
    StateProvider<WhiteBalanceSettings>((ref) => const WhiteBalanceSettings());