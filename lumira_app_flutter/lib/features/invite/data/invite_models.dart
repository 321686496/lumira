import 'package:flutter/foundation.dart';

import '../../rewards/data/rewards_models.dart';

/// 邀请激活渠道
enum InviteChannel {
  direct,
  shareCard,
  qrcode,
}

extension InviteChannelExt on InviteChannel {
  String toJson() {
    switch (this) {
      case InviteChannel.direct:
        return 'direct';
      case InviteChannel.shareCard:
        return 'share_card';
      case InviteChannel.qrcode:
        return 'qrcode';
    }
  }

  static InviteChannel? fromJson(String? s) {
    switch (s) {
      case 'direct':
        return InviteChannel.direct;
      case 'share_card':
        return InviteChannel.shareCard;
      case 'qrcode':
        return InviteChannel.qrcode;
      default:
        return null;
    }
  }
}

/// POST /invite/activate 请求体
@immutable
class ActivateInviteRequest {
  final String inviteCode;
  final InviteChannel? channel;

  const ActivateInviteRequest({required this.inviteCode, this.channel});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'inviteCode': inviteCode};
    if (channel != null) m['channel'] = channel!.toJson();
    return m;
  }
}

/// 激活后奖励元组
@immutable
class ActivateRewards {
  final int tier;
  final List<RewardItem> items;

  const ActivateRewards({required this.tier, required this.items});

  factory ActivateRewards.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['items'] as List<dynamic>;
    return ActivateRewards(
      tier: j['tier'] as int,
      items: itemsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// POST /invite/activate 响应体
@immutable
class ActivateInviteResponse {
  final String inviterDeviceId;
  final int? tierReached;
  final ActivateRewards? rewards;

  const ActivateInviteResponse({
    required this.inviterDeviceId,
    this.tierReached,
    this.rewards,
  });

  factory ActivateInviteResponse.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as Map<String, dynamic>?;
    return ActivateInviteResponse(
      inviterDeviceId: j['inviterDeviceId'] as String,
      tierReached: j['tierReached'] as int?,
      rewards: rewardsRaw == null ? null : ActivateRewards.fromJson(rewardsRaw),
    );
  }
}

/// 下一档邀请奖励
@immutable
class NextInviteTier {
  final int tier;
  final int requiredInvites;
  final List<RewardItem> rewards;

  const NextInviteTier({
    required this.tier,
    required this.requiredInvites,
    required this.rewards,
  });

  factory NextInviteTier.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as List<dynamic>;
    return NextInviteTier(
      tier: j['tier'] as int,
      requiredInvites: j['requiredInvites'] as int,
      rewards: rewardsRaw.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// GET /invite/stats 响应体
@immutable
class InviteStats {
  final int totalInvites;
  final int currentTier;
  final NextInviteTier? nextTier;
  final List<UnlockedReward> unlockedRewards;
  final String? myInviteCode;
  final List<InviteTierEntry> tiers;
  final List<Invitee> invitees;

  const InviteStats({
    required this.totalInvites,
    required this.currentTier,
    this.nextTier,
    required this.unlockedRewards,
    this.myInviteCode,
    this.tiers = const [],
    this.invitees = const [],
  });

  factory InviteStats.fromJson(Map<String, dynamic> j) {
    final nextTierRaw = j['nextTier'] as Map<String, dynamic>?;
    final unlockedRaw = j['unlockedRewards'] as List<dynamic>? ?? const [];
    final tiersRaw = j['tiers'] as List<dynamic>? ?? const [];
    final inviteesRaw = j['invitees'] as List<dynamic>? ?? const [];
    return InviteStats(
      totalInvites: j['totalInvites'] as int,
      currentTier: j['currentTier'] as int,
      nextTier: nextTierRaw == null ? null : NextInviteTier.fromJson(nextTierRaw),
      unlockedRewards:
          unlockedRaw.map((e) => UnlockedReward.fromJson(e as Map<String, dynamic>)).toList(),
      myInviteCode: j['myInviteCode'] as String?,
      tiers: tiersRaw.map((e) => InviteTierEntry.fromJson(e as Map<String, dynamic>)).toList(),
      invitees: inviteesRaw.map((e) => Invitee.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalInvites': totalInvites,
        'currentTier': currentTier,
        'nextTier': nextTier == null
            ? null
            : {
                'tier': nextTier!.tier,
                'requiredInvites': nextTier!.requiredInvites,
                'rewards': nextTier!.rewards.map((r) => r.toJson()).toList(),
              },
        'unlockedRewards': unlockedRewards.map((r) => r.toJson()).toList(),
        'myInviteCode': myInviteCode,
        'tiers': tiers.map((t) => t.toJson()).toList(),
        'invitees': invitees.map((i) => i.toJson()).toList(),
      };
}

/// POST /invite/generate 响应体
@immutable
class InviteCode {
  final String code;

  const InviteCode({required this.code});

  factory InviteCode.fromJson(Map<String, dynamic> j) {
    return InviteCode(code: j['inviteCode'] as String);
  }
}

/// 单档奖励阶梯（stats.tiers 动态数据）
@immutable
class InviteTierEntry {
  final int tier;
  final int requiredInvites;
  final List<RewardItem> rewards;
  final bool done;
  final bool locked;

  const InviteTierEntry({
    required this.tier,
    required this.requiredInvites,
    required this.rewards,
    required this.done,
    required this.locked,
  });

  factory InviteTierEntry.fromJson(Map<String, dynamic> j) => InviteTierEntry(
        tier: j['tier'] as int,
        requiredInvites: j['requiredInvites'] as int,
        rewards: (j['rewards'] as List<dynamic>)
            .map((e) => RewardItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        done: j['done'] as bool? ?? false,
        locked: j['locked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'tier': tier,
        'requiredInvites': requiredInvites,
        'rewards': rewards.map((r) => r.toJson()).toList(),
        'done': done,
        'locked': locked,
      };
}

/// 被邀请人记录（stats.invitees）
@immutable
class Invitee {
  final String inviteeDeviceId;
  final String channel;
  final int activatedAt;

  const Invitee({
    required this.inviteeDeviceId,
    required this.channel,
    required this.activatedAt,
  });

  factory Invitee.fromJson(Map<String, dynamic> j) => Invitee(
        inviteeDeviceId: j['inviteeDeviceId'] as String,
        channel: j['channel'] as String? ?? 'direct',
        activatedAt: j['activatedAt'] as int,
      );

  Map<String, dynamic> toJson() => {
        'inviteeDeviceId': inviteeDeviceId,
        'channel': channel,
        'activatedAt': activatedAt,
      };
}
