import 'package:flutter/foundation.dart';

/// GET /points/balance 响应体
@immutable
class PointsBalance {
  final String deviceId;
  final int balance;
  final int totalEarned;
  final int totalSpent;

  /// 免费解锁付费模板次数（邀请里程碑奖励，兑换时扣减，不耗积分）
  final int freeUnlockCount;

  const PointsBalance({
    required this.deviceId,
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    required this.freeUnlockCount,
  });

  factory PointsBalance.fromJson(Map<String, dynamic> j) => PointsBalance(
        deviceId: j['deviceId'] as String? ?? '',
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        totalEarned: (j['totalEarned'] as num?)?.toInt() ?? 0,
        totalSpent: (j['totalSpent'] as num?)?.toInt() ?? 0,
        freeUnlockCount: (j['freeUnlockCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'balance': balance,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
        'freeUnlockCount': freeUnlockCount,
      };
}

/// 积分流水类型
///
/// 后端契约：'earn' | 'spend'，由后端 type 字段决定。
/// 兼容兜底：未知值按 delta 正负推断。
enum PointTxType { earn, spend, unknown }

PointTxType _parseTxType(dynamic v, int delta) {
  if (v is String) {
    if (v == 'earn') return PointTxType.earn;
    if (v == 'spend') return PointTxType.spend;
  }
  if (delta > 0) return PointTxType.earn;
  if (delta < 0) return PointTxType.spend;
  return PointTxType.unknown;
}

/// GET /points/transactions 单条记录
@immutable
class PointTransaction {
  final String id;
  final String deviceId;
  final int delta;
  final PointTxType type;

  /// 原始流水来源（后端 type 字段，如 sign_in/invite/challenge/exchange_template/
  /// level_reward/free_unlock/free_unlock_spend/redeem_code 等），用于展示中文来源
  final String source;
  final String? refId;
  final int createdAt;

  const PointTransaction({
    required this.id,
    required this.deviceId,
    required this.delta,
    required this.type,
    required this.source,
    this.refId,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> j) {
    final delta = (j['delta'] as num?)?.toInt() ?? 0;
    final source = j['type']?.toString() ?? '';
    return PointTransaction(
      id: j['id']?.toString() ?? '',
      deviceId: j['deviceId'] as String? ?? '',
      delta: delta,
      type: _parseTxType(j['type'], delta),
      source: source,
      refId: j['refId'] as String?,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'delta': delta,
        'type': type == PointTxType.earn
            ? 'earn'
            : type == PointTxType.spend
                ? 'spend'
                : 'unknown',
        'source': source,
        if (refId != null) 'refId': refId,
        'createdAt': createdAt,
      };
}

/// 流水来源 → 中文标签（钱包页展示）
String pointSourceLabel(String source) {
  switch (source) {
    case 'sign_in':
      return '每日签到';
    case 'shoot_daily':
      return '每日首拍';
    case 'challenge':
      return '完成挑战';
    case 'share':
      return '每日分享';
    case 'invite':
      return '邀请奖励';
    case 'redeem_code':
      return '兑换码奖励';
    case 'exchange_template':
      return '模板解锁';
    case 'level_reward':
      return '升级奖励';
    case 'free_unlock':
      return '获得免费解锁';
    case 'free_unlock_spend':
      return '免费解锁消耗';
    case 'ad':
      return '广告奖励';
    case 'admin_grant':
      return '后台发放';
    default:
      return '积分变动';
  }
}

/// GET /points/transactions 响应体
@immutable
class PointsTransactions {
  final List<PointTransaction> transactions;
  final int total;

  const PointsTransactions({
    required this.transactions,
    required this.total,
  });

  factory PointsTransactions.fromJson(Map<String, dynamic> j) {
    final list = j['transactions'] as List<dynamic>? ?? const [];
    return PointsTransactions(
      transactions: list
        .map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
        .toList(),
      total: (j['total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'total': total,
      };
}

/// POST /templates/exchange 响应体
@immutable
class TemplateExchangeResult {
  final bool success;
  final String templateId;
  final int spentCredits;
  final int balance;

  /// 免费解锁次数支付后的剩余次数（payBy=free_unlock 时有值）
  final int? freeUnlockLeft;

  /// 本次支付方式：'points' | 'free_unlock'
  final String payBy;

  const TemplateExchangeResult({
    required this.success,
    required this.templateId,
    required this.spentCredits,
    required this.balance,
    this.freeUnlockLeft,
    this.payBy = 'points',
  });

  factory TemplateExchangeResult.fromJson(Map<String, dynamic> j) =>
      TemplateExchangeResult(
        success: j['success'] as bool? ?? false,
        templateId: j['templateId'] as String? ?? '',
        spentCredits: (j['spentCredits'] as num?)?.toInt() ?? 0,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        freeUnlockLeft: (j['freeUnlockLeft'] as num?)?.toInt(),
        payBy: j['payBy'] as String? ?? 'points',
      );
}

/// POST /points/earn 响应体
///
/// 事件型积分领取（每日首次拍摄 / 完成挑战）：
/// - [granted] = 本次是否发放积分（false = 该事件当天/该挑战已领过）
/// - [delta]   = 本次获得的积分数（未发放时为 0）
/// - [balance] = 领取后的积分余额
@immutable
class PointEarnResult {
  final bool granted;
  final int delta;
  final int balance;

  const PointEarnResult({
    required this.granted,
    required this.delta,
    required this.balance,
  });

  factory PointEarnResult.fromJson(Map<String, dynamic> j) => PointEarnResult(
        granted: j['granted'] as bool? ?? false,
        delta: (j['delta'] as num?)?.toInt() ?? 0,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
      );
}
