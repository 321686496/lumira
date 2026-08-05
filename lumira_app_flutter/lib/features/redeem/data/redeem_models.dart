import 'package:flutter/foundation.dart';

/// POST /redeem 请求体
@immutable
class RedeemCodeRequest {
  final String code;

  const RedeemCodeRequest({required this.code});

  Map<String, dynamic> toJson() => {'code': code};
}

/// POST /redeem 响应体（积分体系）
@immutable
class RedeemCodeResponse {
  final int batchId;
  final String campaignName;
  /// 本次兑换发放的积分数
  final int rewardPoints;
  /// 兑换后当前积分余额
  final int balance;

  const RedeemCodeResponse({
    required this.batchId,
    required this.campaignName,
    required this.rewardPoints,
    required this.balance,
  });

  factory RedeemCodeResponse.fromJson(Map<String, dynamic> j) {
    return RedeemCodeResponse(
      batchId: j['batchId'] as int,
      campaignName: j['campaignName'] as String,
      rewardPoints: (j['rewardPoints'] as num?)?.toInt() ?? 0,
      balance: (j['balance'] as num?)?.toInt() ?? 0,
    );
  }
}
