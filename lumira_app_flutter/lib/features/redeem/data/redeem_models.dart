import 'package:flutter/foundation.dart';

import '../../rewards/data/rewards_models.dart';

/// POST /redeem/code 请求体
@immutable
class RedeemCodeRequest {
  final String code;

  const RedeemCodeRequest({required this.code});

  Map<String, dynamic> toJson() => {'code': code};
}

/// POST /redeem/code 响应体
@immutable
class RedeemCodeResponse {
  final int batchId;
  final String campaignName;
  final int rewardTier;
  final List<RewardItem> rewardItems;

  const RedeemCodeResponse({
    required this.batchId,
    required this.campaignName,
    required this.rewardTier,
    required this.rewardItems,
  });

  factory RedeemCodeResponse.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['rewardItems'] as List<dynamic>;
    return RedeemCodeResponse(
      batchId: j['batchId'] as int,
      campaignName: j['campaignName'] as String,
      rewardTier: j['rewardTier'] as int,
      rewardItems: itemsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
