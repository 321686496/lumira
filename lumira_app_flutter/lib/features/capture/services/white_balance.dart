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
    this.manualK = false,
  });

  final WhiteBalanceMode mode;

  /// 色温（开尔文），取值 3000..8000，仅非 auto 模式生效，auto 时为 null。
  final int? temperatureK;

  /// 是否为「手动拖动色温滑块」产生的连续色温。
  ///
  /// OHOS 原生据此决定路径：true=MANUAL 连续色温（setWhiteBalance，仅后置支持，
  /// 前置 HDI 未实现手动色温接口）；false=预设模式（setWhiteBalanceMode，前后置均支持）。
  /// 预设 pill 点击联动滑块时为 false（temperatureK 仅用于 UI 滑块跟随）。
  final bool manualK;

  bool get isAuto => mode == WhiteBalanceMode.auto;

  WhiteBalanceSettings copyWith({
    WhiteBalanceMode? mode,
    int? temperatureK,
    bool? manualK,
  }) {
    return WhiteBalanceSettings(
      mode: mode ?? this.mode,
      temperatureK: temperatureK ?? this.temperatureK,
      manualK: manualK ?? this.manualK,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WhiteBalanceSettings &&
        other.mode == mode &&
        other.temperatureK == temperatureK &&
        other.manualK == manualK;
  }

  @override
  int get hashCode => Object.hash(mode, temperatureK, manualK);

  @override
  String toString() =>
      'WhiteBalanceSettings(mode: $mode, temperatureK: $temperatureK, manualK: $manualK)';
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

/// OHOS 前置摄像头白平衡档位的「软件色温模拟」（R/G/B 对角增益，返回 null 表示不注入）。
///
/// 【学醒图路线（2026-09-19）】前置 ISP 预设增益表偏红（真机实测非 auto 档
/// R 通道高 30~40%），原生档位不可信，故原生侧前置固定 AUTO（传感器级 AWB，
/// 实测中性 R/G≈0.988）；档位视觉改由本矩阵在最内层模拟——基于后置（正常）
/// 各档位相对 AUTO 的实测偏移（室内灯光场景截图中心区 RGB 均值）标定，
/// 方向与系统相机一致（阴天偏暖、荧光偏冷青、白炽最冷蓝）：
///
/// | 档位         | 后置相对 AUTO 偏移 (R,B) | 模拟系数 (R,B)  |
/// | ------------ | ----------------------- | -------------- |
/// | daylight     | ×0.899 / ×1.019         | ×0.90 / ×1.02  |
/// | cloudy       | ×0.960 / ×0.851         | ×0.96 / ×0.85  |
/// | fluorescent  | ×0.910 / ×1.406         | ×0.91 / ×1.35  |
/// | incandescent | ×0.264 / ×1.512(过冲)   | ×0.75 / ×1.25(收敛) |
///
/// auto 档不注入（原生 AUTO 已中性）。仅 OHOS 前置 + 非 auto 生效（调用方
/// [CaptureState.effectivePostProcessProvider] 判断；后置走原生档位，不注入）。
/// 单场景单采样局限，需真机逐档验证微调。
WbResidual? ohosFrontWhiteBalanceCompensation(WhiteBalanceMode mode) {
  switch (mode) {
    case WhiteBalanceMode.daylight:
      return const WbResidual(r: 0.90, g: 1.0, b: 1.02);
    case WhiteBalanceMode.cloudy:
      return const WbResidual(r: 0.96, g: 1.0, b: 0.85);
    case WhiteBalanceMode.fluorescent:
      return const WbResidual(r: 0.91, g: 1.0, b: 1.35);
    case WhiteBalanceMode.incandescent:
      // 后置实测相对偏移 R×0.264/B×1.512 是冷光下切白炽档的过冲表现，直接照搬
      // 会让肤色发蓝；收敛后仍保持全档位最冷蓝的方向。
      return const WbResidual(r: 0.75, g: 1.0, b: 1.25);
    case WhiteBalanceMode.auto:
      return null;
  }
}