import 'home_mock_data.dart';

/// 运营位展示条件
enum OperationCondition {
  /// 老用户 & 未绑定过邀请码 → 邀请
  nonNewUserNotInvited,

  /// 有积分余额 → 引导去积分中心
  pointsReady,

  /// 存在未解锁付费模板 → 模板上新/解锁
  hasLockedTemplate,
}

/// 运营位条件所需的用户状态快照（由 Provider 汇聚远端数据后注入推荐服务）。
///
/// 各字段 null 表示「拉取失败/未知」，对应条件一律不成立（fail-safe 不出运营位，
/// slot 0 让位给个性化推荐）。
class OperationUserInputs {
  const OperationUserInputs({
    this.hasBoundInviter,
    this.pointsBalance,
    this.hasLockedTemplate,
  });

  /// 是否已绑定过邀请码（GET /invite/stats → myInviter != null）
  final bool? hasBoundInviter;

  /// 积分余额（GET /points/balance → balance）
  final int? pointsBalance;

  /// 是否存在未解锁付费模板（GET /templates/prices + /templates/owned）
  final bool? hasLockedTemplate;
}

/// 首页运营 Banner 条目：指向真实功能，条件满足才参与 slot 0。
/// 未来接入后台下发时，仅需把配置源从本地静态 swap 成远端拉取，
/// 渲染层与埋点层无需改动。
class OperationBanner {
  const OperationBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.route,
    required this.condition,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 如「邀请有礼」「积分乐园」「上新」
  final String tag;

  /// 真实路由：/invite、/points/wallet、/templates/unlock
  final String route;

  /// 展示条件
  final OperationCondition condition;
}

/// 运营条目目录（顺序即优先级，满足者最多取 1 条置于 slot 0）
const List<OperationBanner> kOperationBanners = [
  OperationBanner(
    id: 'op_invite',
    title: '邀请好友 · 双方各+30分',
    subtitle: '绑定邀请码完成首拍，双方各得 30 积分',
    tag: '邀请有礼',
    route: '/invite',
    condition: OperationCondition.nonNewUserNotInvited,
  ),
  OperationBanner(
    id: 'op_points',
    title: '积分当钱花 · 解锁模板',
    subtitle: '拍摄攒积分，攒够就兑换心仪模板',
    tag: '积分乐园',
    route: '/points/wallet',
    condition: OperationCondition.pointsReady,
  ),
  OperationBanner(
    id: 'op_unlock',
    title: '尊享上新 · 一键解锁',
    subtitle: '用积分或邀请奖励，解锁付费模板',
    tag: '上新',
    route: '/templates/unlock',
    condition: OperationCondition.hasLockedTemplate,
  ),
];

/// 单条件是否满足（null 视为不满足）
bool _isConditionSatisfied(
  OperationCondition condition,
  bool isNewUser,
  OperationUserInputs inputs,
) {
  switch (condition) {
    case OperationCondition.nonNewUserNotInvited:
      return !isNewUser && inputs.hasBoundInviter == false;
    case OperationCondition.pointsReady:
      return (inputs.pointsBalance ?? 0) > 0;
    case OperationCondition.hasLockedTemplate:
      return inputs.hasLockedTemplate == true;
  }
}

/// 按目录顺序取第一条满足条件的运营条目；无则返回 null（slot 0 让位个性化）。
OperationBanner? matchOperationBanner({
  required bool isNewUser,
  OperationUserInputs inputs = const OperationUserInputs(),
}) {
  for (final banner in kOperationBanners) {
    if (_isConditionSatisfied(banner.condition, isNewUser, inputs)) {
      return banner;
    }
  }
  return null;
}

/// 运营条目转首页 Banner 项（type=operation，无封面 → 品牌渐变背景）
HomeBannerItem operationBannerToItem(OperationBanner banner) {
  return HomeBannerItem(
    id: banner.id,
    title: banner.title,
    subtitle: banner.subtitle,
    imageSeed: 'banner-op-${banner.id}',
    tag: banner.tag,
    route: banner.route,
    type: BannerType.operation,
    bannerId: banner.id,
  );
}
