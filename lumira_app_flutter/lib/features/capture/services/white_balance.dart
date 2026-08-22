/// 白平衡模式。
///
/// 与相机原生通道约定一致，`name` 直接作为 `CamerawesomePlugin.setWhiteBalance(mode, k)` 的 mode 参数。
enum WhiteBalanceMode { auto, daylight, cloudy, fluorescent, incandescent }

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