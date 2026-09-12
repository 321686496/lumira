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
/// 远端下发（`operationBannerFromJson`）或本地静态目录皆可构造。
class OperationBanner {
  const OperationBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.route,
    required this.condition,
    this.imageUrl,
    this.focusX = 0.5,
    this.focusY = 0.5,
    this.focusZoom = 1.0,
    this.templateId,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 如「邀请有礼」「积分乐园」「上新」
  final String tag;

  /// 真实路由：/invite、/points/wallet、/templates/unlock、/templates/detail
  final String route;

  /// 展示条件
  final OperationCondition condition;

  /// 运营配图 URL（可空）：非空时 App 卡片右侧 40% 区域 contain 完整显示，
  /// 为空回退品牌渐变背景（与旧行为兼容）
  final String? imageUrl;

  /// 背景图水平焦点（0 = 左，1 = 右）
  final double focusX;

  /// 背景图垂直焦点（0 = 上，1 = 下）
  final double focusY;

  /// 背景图缩放倍数（1–3）
  final double focusZoom;

  /// 目标模板 id（仅 route=/templates/detail 时有值）：用于拼模板详情页跳转
  final String? templateId;
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

/// 运营位路由白名单（与后端 OPERATION_BANNER_ROUTES 一致）。
/// 远端下发数据 route 不在名单内时整条丢弃（fail-safe，防旧版 App 跳转崩溃）。
const List<String> kOperationBannerRoutes = [
  '/invite',
  '/points/wallet',
  '/templates/unlock',
  '/templates/detail',
];

/// 后端下发条目 → 运营位模型；字段缺失/route 越白名单/condition 无法识别 → null（丢弃）。
/// imageUrl 可选：非 String 或空串视为无配图（回退品牌渐变背景）。
double _clampDouble(Object? value, double min, double max, double fallback) {
  if (value is! num) return fallback;
  return value.toDouble().clamp(min, max);
}

OperationBanner? operationBannerFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final title = json['title'];
  final subtitle = json['subtitle'];
  final tag = json['tag'];
  final route = json['route'];
  if (id is! String || title is! String || subtitle is! String || tag is! String || route is! String) {
    return null;
  }
  if (!kOperationBannerRoutes.contains(route)) return null;
  OperationCondition? condition;
  for (final c in OperationCondition.values) {
    if (c.name == json['condition']) condition = c;
  }
  if (condition == null) return null;
  final rawImage = json['imageUrl'];
  final imageUrl = rawImage is String && rawImage.isNotEmpty ? rawImage : null;
  // 目标模板 id：route=/templates/detail 时必须携带非空值，否则 fail-safe 丢弃
  final rawTemplateId = json['templateId'];
  final templateId = rawTemplateId is String && rawTemplateId.isNotEmpty
      ? rawTemplateId
      : null;
  if (route == '/templates/detail' && templateId == null) return null;
  final focusX = _clampDouble(json['focusX'], 0, 1, 0.5);
  final focusY = _clampDouble(json['focusY'], 0, 1, 0.5);
  final focusZoom = _clampDouble(json['focusZoom'], 1, 3, 1.0);
  return OperationBanner(
    id: id, title: title, subtitle: subtitle, tag: tag,
    route: route, condition: condition, imageUrl: imageUrl,
    focusX: focusX,
    focusY: focusY,
    focusZoom: focusZoom,
    templateId: templateId,
  );
}

/// 按目录顺序取第一条满足条件的运营条目；无则返回 null（slot 0 让位个性化）。
///
/// [banners] 为运营条目目录（默认静态 [kOperationBanners]；远端拉取成功后
/// 注入后台下发列表，空列表为合法状态=后台全部停用，不出运营位）。
OperationBanner? matchOperationBanner({
  required bool isNewUser,
  List<OperationBanner> banners = kOperationBanners,
  OperationUserInputs inputs = const OperationUserInputs(),
}) {
  for (final banner in banners) {
    if (_isConditionSatisfied(banner.condition, isNewUser, inputs)) {
      return banner;
    }
  }
  return null;
}

/// 运营条目转首页 Banner 项（type=operation）。配图经 [HomeBannerItem.cover]
/// 传递：非空时卡片右侧 40% 区域 contain 完整显示，空时品牌渐变背景。
HomeBannerItem operationBannerToItem(OperationBanner banner) {
  // route=/templates/detail 且携带目标模板 id 时，拼出模板详情页完整跳转路由
  final route = (banner.route == '/templates/detail' && banner.templateId != null)
      ? '/templates/detail?templateId=${banner.templateId}'
      : banner.route;
  return HomeBannerItem(
    id: banner.id,
    title: banner.title,
    subtitle: banner.subtitle,
    imageSeed: 'banner-op-${banner.id}',
    tag: banner.tag,
    route: route,
    cover: banner.imageUrl,
    focusX: banner.focusX,
    focusY: banner.focusY,
    focusZoom: banner.focusZoom,
    type: BannerType.operation,
    bannerId: banner.id,
  );
}
