import 'package:flutter/foundation.dart';

/// ===== 积分充值配置 =====
///
/// 充值渠道按平台分流（App Store 上架整改）：
/// - iOS：走 App Store 内购（消耗型积分包），商品 id 见 [RechargeTier.iosProductId]。
///   审核要求数字内容必须通过 IAP 购买，故 iOS 不再使用客服充值。
/// - Android / OHOS：仍为人工客服处理（复制微信号添加客服，核实后手动发放，
///   流水来源 admin_grant）。本轮整改**不改动**这两个平台。
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

  /// iOS App Store 消耗型商品 id（需在 App Store Connect 按此命名创建商品）
  final String iosProductId;

  const RechargeTier({
    required this.amount,
    required this.basePoints,
    required this.bonusPoints,
    required this.iosProductId,
  });

  /// 到账合计积分
  int get totalPoints => basePoints + bonusPoints;

  /// 赠送占比（如 10.0 表示比基础多送 10%），用于展示「多充多送」力度
  double get bonusRatePercent =>
      basePoints == 0 ? 0 : bonusPoints * 100 / basePoints;
}

/// 充值档位表（1 元 = 100 积分为基础价，档位越高赠送比例越高）
///
/// iosProductId 命名规则：com.rh.lumira.points.<到账积分>
const List<RechargeTier> kRechargeTiers = [
  RechargeTier(
    amount: 6,
    basePoints: 600,
    bonusPoints: 0,
    iosProductId: 'com.rh.lumira.points.600',
  ),
  RechargeTier(
    amount: 30,
    basePoints: 3000,
    bonusPoints: 300,
    iosProductId: 'com.rh.lumira.points.3300',
  ),
  RechargeTier(
    amount: 68,
    basePoints: 6800,
    bonusPoints: 1000,
    iosProductId: 'com.rh.lumira.points.7800',
  ),
  RechargeTier(
    amount: 128,
    basePoints: 12800,
    bonusPoints: 2500,
    iosProductId: 'com.rh.lumira.points.15300',
  ),
  RechargeTier(
    amount: 328,
    basePoints: 32800,
    bonusPoints: 10000,
    iosProductId: 'com.rh.lumira.points.42800',
  ),
];

/// 将 赠送占比 格式化为如「+10%」「+30%」的展示文案
String rechargeBonusLabel(RechargeTier tier) {
  if (tier.bonusPoints <= 0) return '';
  final rate = tier.bonusRatePercent.round();
  return '+$rate%';
}