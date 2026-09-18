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

/// OHOS 前置摄像头预设白平衡的「软件色彩补偿」（R/G/B 对角增益，返回 null 表示不补偿）。
///
/// 根因：OHOS 前置摄像头对各预设档位的 ISP 预设增益渲染与后置不同——
/// `setWhiteBalanceMode` 实际生效但画面仍偏色（前置尤其偏红）；前置 MANUAL
/// 色温不可用（`getWhiteBalanceRange` 返回 undefined，全部回退预设模式），
/// 唯一可行方案是软件矩阵修正。补偿与 [wbResidualSessionProvider] 同机制：
/// 由 `CaptureState.effectivePostProcessProvider` 按「OHOS + 前置 + 非 auto」
/// 注入 `PostProcess.frontWbCompensation`，作用于取景器 FX 矩阵与成片矩阵
/// 同层（最内层对角增益，两处同源一致）。
///
/// 当前各档位统一按「抵消前置偏红」起步（R×0.90 / B×1.10，约抵消 10% 偏红）；
/// 真机逐档位实测后若各档偏色程度不同，再在下方 switch 分档位微调。
WbResidual? ohosFrontWhiteBalanceCompensation(WhiteBalanceMode mode) {
  switch (mode) {
    case WhiteBalanceMode.auto:
      // auto 不修正（用户未反馈 auto 偏色）
      return null;
    case WhiteBalanceMode.daylight:
    case WhiteBalanceMode.cloudy:
    case WhiteBalanceMode.fluorescent:
    case WhiteBalanceMode.incandescent:
      // TEMP-DIAG: 强补偿用于真机验证管线是否真正应用矩阵（R×0.5/B×2.0）。
      return const WbResidual(r: 0.5, g: 1.0, b: 2.0);
  }
}