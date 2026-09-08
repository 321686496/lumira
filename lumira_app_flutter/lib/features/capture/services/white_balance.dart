import 'package:camerawesome/camerawesome_plugin.dart' as ca;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/photo_template.dart' show WbResidual;

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

/// iOS 硬件白平衡「残差」会话状态（见 [WbResidual]）。
///
/// 极值色温下 iOS 硬件增益被软封顶（规避传感器饱和导致镜头渐晕校正失效
/// ——取景器局部冷/暖色丢失），封顶削减的比值由此 provider 记录，经
/// [CaptureState.effectivePostProcessProvider] 注入 composePostProcessMatrix
/// 补足，取景器与成片同源一致。仅 iOS + 手动白平衡时非 null。
final wbResidualSessionProvider = StateProvider<WbResidual?>((ref) => null);

/// 下发白平衡到传感器后，从 iOS 拉取硬件「残差」刷新会话状态。
///
/// 必须在 `CameraService.setWhiteBalance` 之后调用：两者走同一 platform
/// channel（FIFO），iOS 端残差读取必然在增益锁定之后执行，读到的是本次
/// 设置的目标/实际增益比。auto / 非 iOS / 读取失败时置 null（无软件补足）。
Future<void> refreshWbResidual(WidgetRef ref) async {
  try {
    final map = await ca.CamerawesomePlugin.getWbResidual();
    final residual = WbResidual.fromPlatformMap(map);
    ref.read(wbResidualSessionProvider.notifier).state =
        (residual == null || residual.isIdentity) ? null : residual;
  } catch (e) {
    debugPrint('[wb] getWbResidual failed: $e');
  }
}