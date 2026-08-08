import 'package:flutter/foundation.dart';

/// 兑换的模板信息
@immutable
class RewardTemplateInfo {
  final String templateId;
  final String templateName;

  const RewardTemplateInfo({
    required this.templateId,
    required this.templateName,
  });

  factory RewardTemplateInfo.fromJson(Map<String, dynamic> j) {
    return RewardTemplateInfo(
      templateId: j['templateId'] as String,
      templateName: j['templateName'] as String,
    );
  }
}

/// POST /redeem 请求体
@immutable
class RedeemCodeRequest {
  final String code;

  const RedeemCodeRequest({required this.code});

  Map<String, dynamic> toJson() => {'code': code};
}

/// POST /redeem 响应体
@immutable
class RedeemCodeResponse {
  final int batchId;
  final String campaignName;
  final int rewardPoints;
  final int balance;
  final List<RewardTemplateInfo> rewardTemplates;

  const RedeemCodeResponse({
    required this.batchId,
    required this.campaignName,
    required this.rewardPoints,
    required this.balance,
    required this.rewardTemplates,
  });

  factory RedeemCodeResponse.fromJson(Map<String, dynamic> j) {
    final templatesRaw = (j['rewardTemplates'] as List<dynamic>?) ?? [];
    return RedeemCodeResponse(
      batchId: j['batchId'] as int,
      campaignName: j['campaignName'] as String,
      rewardPoints: (j['rewardPoints'] as num?)?.toInt() ?? 0,
      balance: (j['balance'] as num?)?.toInt() ?? 0,
      rewardTemplates: templatesRaw
          .map((e) => RewardTemplateInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}