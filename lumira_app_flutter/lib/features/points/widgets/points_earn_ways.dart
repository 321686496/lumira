import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_tokens.dart';

/// 单条积分获取途径数据
///
/// [route] 非空时该行整行可点击并跳转到对应页面（如「客服充值」进入充值说明页）。
@immutable
class PointsEarnWay {
  final IconData icon;
  final String title;
  final String desc;
  final String? route;

  const PointsEarnWay(this.icon, this.title, this.desc, {this.route});
}

/// 全局积分获取途径列表（钱包页「获取积分」卡片与积分不足弹窗共用同一来源）
const List<PointsEarnWay> pointsEarnWays = [
  PointsEarnWay(
    Icons.calendar_today_outlined,
    '每日签到',
    '+4 积分/天，连签 7 天额外 +14（每日首拍自动完成）',
  ),
  PointsEarnWay(Icons.share_outlined, '每日分享', '+2 积分/天'),
  PointsEarnWay(Icons.emoji_events_outlined, '完成挑战', '+5 积分/次，每日上限 3 次'),
  PointsEarnWay(Icons.card_giftcard, '邀请好友', '双方各得 +30，每日上限 3 次'),
  PointsEarnWay(Icons.trending_up, '等级升级', '每级发放，档位递增'),
  PointsEarnWay(
    Icons.headset_mic_outlined,
    '客服充值',
    '联系客服充值，多充多送',
    route: RouteNames.pointsRecharge,
  ),
];

/// 获取积分途径列表
///
/// - [dense]：弹窗等紧凑场景传 true，缩小行距并去掉分隔线
/// - [stacked]：弹窗等窄空间传 true，标题与说明上下排布（避免长文案右侧挤压换行）
class PointsEarnWaysList extends StatelessWidget {
  const PointsEarnWaysList({
    super.key,
    required this.tokens,
    this.dense = false,
    this.stacked = false,
  });

  final ThemeTokens tokens;
  final bool dense;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < pointsEarnWays.length; i++) ...[
          if (!dense && i > 0) Divider(height: 1, color: tokens.divider),
          Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
            child: stacked
                ? _StackedRow(tokens: tokens, way: pointsEarnWays[i])
                : _SplitRow(tokens: tokens, way: pointsEarnWays[i]),
          ),
        ],
      ],
    );
  }
}

/// 图标 + 标题（左）、说明（右）水平排布，钱包页卡片使用
class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.tokens, required this.way});
  final ThemeTokens tokens;
  final PointsEarnWay way;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(way.icon, size: 16, color: tokens.brand),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            way.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            way.desc,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
        ),
        if (way.route != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14, color: tokens.textTertiary),
        ],
      ],
    );
    if (way.route == null) return content;
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(way.route!),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// 图标 + 标题一行、说明换行缩进，弹窗等窄空间使用
class _StackedRow extends StatelessWidget {
  const _StackedRow({required this.tokens, required this.way});
  final ThemeTokens tokens;
  final PointsEarnWay way;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(way.icon, size: 15, color: tokens.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                way.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                way.desc,
                style: TextStyle(fontSize: 11, color: tokens.textTertiary),
              ),
            ],
          ),
        ),
        if (way.route != null)
          Icon(Icons.chevron_right, size: 14, color: tokens.textTertiary),
      ],
    );
    if (way.route == null) return content;
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(way.route!),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
