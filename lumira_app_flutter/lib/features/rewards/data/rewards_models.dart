import 'package:flutter/foundation.dart';

/// 奖励类型
///
/// 后端契约：'template' | 'template_pack' | 'achievement' | 'points' | 'unlock_count'
enum RewardType {
  template,
  templatePack,
  achievement,
  points,
  unlockCount,
}

extension RewardTypeExt on RewardType {
  String toJson() {
    switch (this) {
      case RewardType.template:
        return 'template';
      case RewardType.templatePack:
        return 'template_pack';
      case RewardType.achievement:
        return 'achievement';
      case RewardType.points:
        return 'points';
      case RewardType.unlockCount:
        return 'unlock_count';
    }
  }

  static RewardType fromJson(String s) {
    switch (s) {
      case 'template':
        return RewardType.template;
      case 'template_pack':
        return RewardType.templatePack;
      case 'achievement':
        return RewardType.achievement;
      case 'points':
        return RewardType.points;
      case 'unlock_count':
        return RewardType.unlockCount;
      default:
        return RewardType.template;
    }
  }
}

/// 奖励来源
enum RewardSource {
  invite,
  redemption,
}

extension RewardSourceExt on RewardSource {
  String toJson() {
    switch (this) {
      case RewardSource.invite:
        return 'invite';
      case RewardSource.redemption:
        return 'redemption';
    }
  }

  static RewardSource fromJson(String s) {
    switch (s) {
      case 'invite':
        return RewardSource.invite;
      case 'redemption':
        return RewardSource.redemption;
      default:
        return RewardSource.invite;
    }
  }
}

/// 解锁/领取状态
enum UnlockStatus {
  unlocked,
  claimed,
}

extension UnlockStatusExt on UnlockStatus {
  String toJson() {
    switch (this) {
      case UnlockStatus.unlocked:
        return 'unlocked';
      case UnlockStatus.claimed:
        return 'claimed';
    }
  }

  static UnlockStatus fromJson(String s) {
    switch (s) {
      case 'unlocked':
        return UnlockStatus.unlocked;
      case 'claimed':
        return UnlockStatus.claimed;
      default:
        return UnlockStatus.unlocked;
    }
  }
}

/// 单个奖励项
@immutable
class RewardItem {
  final RewardType type;
  final String id;
  final String label;

  /// 数值型奖励的数量（points 为积分值、unlock_count 为解锁次数）
  final int value;

  const RewardItem({
    required this.type,
    this.id = '',
    this.label = '',
    this.value = 0,
  });

  factory RewardItem.fromJson(Map<String, dynamic> j) => RewardItem(
        type: RewardTypeExt.fromJson(j['type'] as String? ?? ''),
        id: j['id'] as String? ?? '',
        label: j['label'] as String? ?? '',
        value: (j['value'] as num?)?.toInt() ?? 0,
      );

  /// 用户可见文案（points/unlock_count 由 value 拼装，achievement 用 label）
  String get displayLabel {
    switch (type) {
      case RewardType.points:
        return '+$value 积分';
      case RewardType.unlockCount:
        return '免费解锁 ×$value';
      case RewardType.achievement:
        return label.isEmpty ? '成就' : label;
      case RewardType.template:
      case RewardType.templatePack:
        return label.isEmpty ? id : label;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        if (id.isNotEmpty) 'id': id,
        if (label.isNotEmpty) 'label': label,
        if (value > 0) 'value': value,
      };
}

/// 已解锁的奖励（包含一项或多项 RewardItem）
@immutable
class UnlockedReward {
  final int id;
  final int tier;
  final RewardSource source;
  final String? sourceDetail;
  final UnlockStatus status;
  final List<RewardItem> rewardItems;
  final int unlockedAt;
  final int? claimedAt;

  const UnlockedReward({
    required this.id,
    required this.tier,
    required this.source,
    this.sourceDetail,
    required this.status,
    required this.rewardItems,
    required this.unlockedAt,
    this.claimedAt,
  });

  factory UnlockedReward.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['rewardItems'] as List<dynamic>;
    return UnlockedReward(
      id: j['id'] as int,
      tier: j['tier'] as int,
      source: RewardSourceExt.fromJson(j['source'] as String),
      sourceDetail: j['sourceDetail'] as String?,
      status: UnlockStatusExt.fromJson(j['status'] as String),
      rewardItems: itemsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
      unlockedAt: j['unlockedAt'] as int,
      claimedAt: j['claimedAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier,
        'source': source.toJson(),
        'sourceDetail': sourceDetail,
        'status': status.toJson(),
        'rewardItems': rewardItems.map((r) => r.toJson()).toList(),
        'unlockedAt': unlockedAt,
        'claimedAt': claimedAt,
      };
}

/// GET /rewards 响应体
@immutable
class RewardsList {
  final List<UnlockedReward> rewards;

  const RewardsList({required this.rewards});

  factory RewardsList.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as List<dynamic>;
    return RewardsList(
      rewards: rewardsRaw.map((e) => UnlockedReward.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'rewards': rewards.map((r) => r.toJson()).toList(),
      };
}

/// POST /rewards/:id/claim 响应体
@immutable
class ClaimResult {
  final bool success;

  const ClaimResult({required this.success});

  factory ClaimResult.fromJson(Map<String, dynamic> j) {
    return ClaimResult(success: j['success'] as bool);
  }
}
