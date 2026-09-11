import 'package:flutter/foundation.dart';

/// ===== 积分充值配置 =====
/// 充值由人工客服处理（不接入支付 SDK）：用户复制微信号添加客服，
/// 发送账号ID与所选档位，客服核实后手动发放积分（流水来源为 admin_grant）。
///
/// 上线前请替换为真实客服微信号。
const String kRechargeWechat = 'h15575801283';

/// 单档充值档位
@immutable
class RechargeTier {
  /// 充值金额（元）
  final int amount;

  /// 基础积分（1 元 = 100 积分）
  final int basePoints;

  /// 赠送积分（多充多送）
  final int bonusPoints;

  const RechargeTier({
    required this.amount,
    required this.basePoints,
    required this.bonusPoints,
  });

  /// 到账合计积分
  int get totalPoints => basePoints + bonusPoints;

  /// 赠送占比（如 10.0 表示比基础多送 10%），用于展示「多充多送」力度
  double get bonusRatePercent =>
      basePoints == 0 ? 0 : bonusPoints * 100 / basePoints;
}

/// 充值档位表（1 元 = 100 积分为基础价，档位越高赠送比例越高）
const List<RechargeTier> kRechargeTiers = [
  RechargeTier(amount: 6, basePoints: 600, bonusPoints: 0),
  RechargeTier(amount: 30, basePoints: 3000, bonusPoints: 300),
  RechargeTier(amount: 68, basePoints: 6800, bonusPoints: 1000),
  RechargeTier(amount: 128, basePoints: 12800, bonusPoints: 2500),
  RechargeTier(amount: 328, basePoints: 32800, bonusPoints: 10000),
];

/// 将 赠送占比 格式化为如「+10%」「+30%」的展示文案
String rechargeBonusLabel(RechargeTier tier) {
  if (tier.bonusPoints <= 0) return '';
  final rate = tier.bonusRatePercent.round();
  return '+$rate%';
}
