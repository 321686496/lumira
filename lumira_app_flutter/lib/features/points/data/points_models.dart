import 'package:flutter/foundation.dart';

/// GET /points/balance 响应体
@immutable
class PointsBalance {
  final String deviceId;
  final int balance;
  final int totalEarned;
  final int totalSpent;

  const PointsBalance({
    required this.deviceId,
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
  });

  factory PointsBalance.fromJson(Map<String, dynamic> j) => PointsBalance(
        deviceId: j['deviceId'] as String? ?? '',
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        totalEarned: (j['totalEarned'] as num?)?.toInt() ?? 0,
        totalSpent: (j['totalSpent'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'balance': balance,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
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
  final String? refId;
  final int createdAt;

  const PointTransaction({
    required this.id,
    required this.deviceId,
    required this.delta,
    required this.type,
    this.refId,
    required this.createdAt,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> j) {
    final delta = (j['delta'] as num?)?.toInt() ?? 0;
    return PointTransaction(
      id: j['id']?.toString() ?? '',
      deviceId: j['deviceId'] as String? ?? '',
      delta: delta,
      type: _parseTxType(j['type'], delta),
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
        if (refId != null) 'refId': refId,
        'createdAt': createdAt,
      };
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

  const TemplateExchangeResult({
    required this.success,
    required this.templateId,
    required this.spentCredits,
    required this.balance,
  });

  factory TemplateExchangeResult.fromJson(Map<String, dynamic> j) =>
      TemplateExchangeResult(
        success: j['success'] as bool? ?? false,
        templateId: j['templateId'] as String? ?? '',
        spentCredits: (j['spentCredits'] as num?)?.toInt() ?? 0,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
      );
}
