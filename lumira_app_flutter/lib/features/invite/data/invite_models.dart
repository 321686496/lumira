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

/// 激活后里程碑奖励元组（邀请人达成阶梯）
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
///
/// 自「成就条件」机制起：绑定成功仅建立待达成(pending)关系，`rewards/tierReached`
/// 为空；`condition` 说明达成条件，`achievableRewards` 为达成后可得奖励列表。
@immutable
class ActivateInviteResponse {
  final String inviterDeviceId;

  /// 'pending'（新机制，绑定后待成片）| 'success'（兼容）
  final String status;

  final int? tierReached;
  final ActivateRewards? rewards;

  /// 达成条件文案（如「完成首次拍照/成片后双方各得30积分」）
  final String? condition;

  /// 达成后可得奖励（被邀请人视角）列表
  final List<RewardItem> achievableRewards;

  const ActivateInviteResponse({
    required this.inviterDeviceId,
    this.status = 'pending',
    this.tierReached,
    this.rewards,
    this.condition,
    this.achievableRewards = const [],
  });

  factory ActivateInviteResponse.fromJson(Map<String, dynamic> j) {
    final rewardsRaw = j['rewards'] as Map<String, dynamic>?;
    final achievableRaw = j['achievableRewards'] as List<dynamic>? ?? const [];
    return ActivateInviteResponse(
      inviterDeviceId: j['inviterDeviceId'] as String,
      status: j['status'] as String? ?? 'pending',
      tierReached: j['tierReached'] as int?,
      rewards: rewardsRaw == null ? null : ActivateRewards.fromJson(rewardsRaw),
      condition: j['condition'] as String?,
      achievableRewards: achievableRaw
          .map((e) => RewardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// POST /invite/complete 响应体（新用户首次成片后结算）
///
/// - `status`：'success'（已达成本次）| 'none'（未绑定邀请码）
/// - `alreadyAchieved`：true 表示此前已达成（幂等重放，不再重复发奖）
/// - `myRewards`：被邀请人本次实际获得的奖励明细
@immutable
class CompleteInviteResponse {
  final String status;
  final bool alreadyAchieved;
  final int? achievedAt;
  final String? inviterDeviceId;
  final List<RewardItem> myRewards;
  final ActivateRewards? rewards;

  const CompleteInviteResponse({
    required this.status,
    this.alreadyAchieved = false,
    this.achievedAt,
    this.inviterDeviceId,
    this.myRewards = const [],
    this.rewards,
  });

  bool get isNone => status == 'none';
  bool get succeeded => status == 'success';

  factory CompleteInviteResponse.fromJson(Map<String, dynamic> j) {
    final myRaw = j['myRewards'] as List<dynamic>? ?? const [];
    final rewardsRaw = j['rewards'] as Map<String, dynamic>?;
    return CompleteInviteResponse(
      status: j['status'] as String? ?? 'none',
      alreadyAchieved: j['alreadyAchieved'] as bool? ?? false,
      achievedAt: j['achievedAt'] as int?,
      inviterDeviceId: j['inviterDeviceId'] as String?,
      myRewards: myRaw
          .map((e) => RewardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
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

/// 我的绑定信息（我被谁邀请）
///
/// 见后端 stats.myInviter。status 为 'pending'（待达成）/ 'success'（已成立）。
@immutable
class InviteBinding {
  final String inviterDeviceId;
  final String? inviteCode;
  final String channel;
  final int activatedAt;
  final String status;
  final int? achievedAt;

  const InviteBinding({
    required this.inviterDeviceId,
    this.inviteCode,
    this.channel = 'direct',
    required this.activatedAt,
    this.status = 'pending',
    this.achievedAt,
  });

  bool get achieved => status == 'success';

  factory InviteBinding.fromJson(Map<String, dynamic> j) => InviteBinding(
        inviterDeviceId: j['inviterDeviceId'] as String,
        inviteCode: j['inviteCode'] as String?,
        channel: j['channel'] as String? ?? 'direct',
        activatedAt: j['activatedAt'] as int,
        status: j['status'] as String? ?? 'pending',
        achievedAt: j['achievedAt'] as int?,
      );
}

/// GET /invite/stats 响应体
@immutable
class InviteStats {
  final int totalInvites;

  /// 待达成（已绑定但新用户尚未首次成片）数量
  final int pendingInvites;

  final int currentTier;
  final NextInviteTier? nextTier;
  final List<UnlockedReward> unlockedRewards;
  final String? myInviteCode;
  final List<InviteTierEntry> tiers;
  final List<Invitee> invitees;

  /// 我的绑定信息（我被谁邀请），未绑定为 null
  final InviteBinding? myInviter;

  /// 达成条件说明文案
  final String? condition;

  /// 免费解锁付费模板次数（邀请里程碑累计奖励）
  final int freeUnlockCount;

  /// 今日已达成邀请次数
  final int todayInviteCount;

  /// 今日还可领即时积分的达成次数（= 每日上限 3 - 今日已达成）
  final int dailyInvitePointsLeft;

  const InviteStats({
    required this.totalInvites,
    this.pendingInvites = 0,
    required this.currentTier,
    this.nextTier,
    required this.unlockedRewards,
    this.myInviteCode,
    this.tiers = const [],
    this.invitees = const [],
    this.myInviter,
    this.condition,
    this.freeUnlockCount = 0,
    this.todayInviteCount = 0,
    this.dailyInvitePointsLeft = 0,
  });

  factory InviteStats.fromJson(Map<String, dynamic> j) {
    final nextTierRaw = j['nextTier'] as Map<String, dynamic>?;
    final unlockedRaw = j['unlockedRewards'] as List<dynamic>? ?? const [];
    final tiersRaw = j['tiers'] as List<dynamic>? ?? const [];
    final inviteesRaw = j['invitees'] as List<dynamic>? ?? const [];
    final myInviterRaw = j['myInviter'] as Map<String, dynamic>?;
    return InviteStats(
      totalInvites: j['totalInvites'] as int,
      pendingInvites: (j['pendingInvites'] as num?)?.toInt() ?? 0,
      currentTier: j['currentTier'] as int,
      nextTier: nextTierRaw == null ? null : NextInviteTier.fromJson(nextTierRaw),
      unlockedRewards:
          unlockedRaw.map((e) => UnlockedReward.fromJson(e as Map<String, dynamic>)).toList(),
      myInviteCode: j['myInviteCode'] as String?,
      tiers: tiersRaw.map((e) => InviteTierEntry.fromJson(e as Map<String, dynamic>)).toList(),
      invitees: inviteesRaw.map((e) => Invitee.fromJson(e as Map<String, dynamic>)).toList(),
      myInviter: myInviterRaw == null ? null : InviteBinding.fromJson(myInviterRaw),
      condition: j['condition'] as String?,
      freeUnlockCount: (j['freeUnlockCount'] as num?)?.toInt() ?? 0,
      todayInviteCount: (j['todayInviteCount'] as num?)?.toInt() ?? 0,
      dailyInvitePointsLeft: (j['dailyInvitePointsLeft'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalInvites': totalInvites,
        'pendingInvites': pendingInvites,
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
        'myInviter': myInviter == null
            ? null
            : {
                'inviterDeviceId': myInviter!.inviterDeviceId,
                'inviteCode': myInviter!.inviteCode,
                'channel': myInviter!.channel,
                'activatedAt': myInviter!.activatedAt,
                'status': myInviter!.status,
                'achievedAt': myInviter!.achievedAt,
              },
        'condition': condition,
        'freeUnlockCount': freeUnlockCount,
        'todayInviteCount': todayInviteCount,
        'dailyInvitePointsLeft': dailyInvitePointsLeft,
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
///
/// `status`：'pending'（待达成，新用户尚未首次成片）/ 'success'（已成立）
@immutable
class Invitee {
  final String inviteeDeviceId;
  final String channel;
  final int activatedAt;
  final String status;
  final int? achievedAt;

  const Invitee({
    required this.inviteeDeviceId,
    required this.channel,
    required this.activatedAt,
    this.status = 'pending',
    this.achievedAt,
  });

  bool get achieved => status == 'success';

  factory Invitee.fromJson(Map<String, dynamic> j) => Invitee(
        inviteeDeviceId: j['inviteeDeviceId'] as String,
        channel: j['channel'] as String? ?? 'direct',
        activatedAt: j['activatedAt'] as int,
        status: j['status'] as String? ?? 'pending',
        achievedAt: j['achievedAt'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'inviteeDeviceId': inviteeDeviceId,
        'channel': channel,
        'activatedAt': activatedAt,
        'status': status,
        'achievedAt': achievedAt,
      };
}