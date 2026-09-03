import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../templates/data/remote_templates_providers.dart';
import '../data/points_models.dart';

/// 单条积分流水行
///
/// 钱包页「积分流水」预览与「积分明细」全量页共用同一视觉组件，
/// 保证两处样式一致。整行可点击 → 弹出流水详情（底部弹层）。
class PointTransactionTile extends StatelessWidget {
  const PointTransactionTile({
    super.key,
    required this.tokens,
    required this.tx,
  });

  final ThemeTokens tokens;
  final PointTransaction tx;

  String get _typeLabel => pointSourceLabel(tx.source);

  String get _deltaText {
    final v = tx.delta;
    return v > 0 ? '+$v' : '$v';
  }

  Color get _deltaColor {
    if (tx.delta > 0) return tokens.success;
    if (tx.delta < 0) return tokens.danger;
    return tokens.textSecondary;
  }

  /// 是否为「解锁付费模板」类流水（积分解锁 / 免费解锁扣次），refId 即模板 id
  bool get _isTemplateSpend =>
      (tx.source == 'exchange_template' ||
          tx.source == 'free_unlock_spend') &&
      tx.refId != null &&
      tx.refId!.isNotEmpty;

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showPointTransactionDetail(context, tx),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tx.delta >= 0
                    ? tokens.successSubtle
                    : tokens.dangerSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                tx.delta >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                size: 16,
                color: tx.delta >= 0 ? tokens.success : tokens.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(tx.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: tokens.textTertiary),
                  ),
                  // 支出流水：标明「花在哪」（无需解析模板，静态说明；模板实体详见详情弹层）
                  if (_isTemplateSpend) ...[
                    const SizedBox(height: 2),
                    Text(
                      '用于解锁付费模板 ›',
                      style: TextStyle(
                          fontSize: 11, color: tokens.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: tokens.textTertiary),
            const SizedBox(width: 4),
            Text(
              _deltaText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _deltaColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出某条积分的流水详情（底部弹层）
///
/// 展示该笔流水的完整信息：来源 / 获取·花费 / 时间 / 流水编号；
/// 若是「解锁付费模板」类支出，内嵌该模板卡片，点击卡片跳转模板详情页。
Future<void> showPointTransactionDetail(
  BuildContext context,
  PointTransaction tx,
) {
  return showLumiraBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PointTransactionDetailSheet(tx: tx),
  );
}

/// 流水详情弹层内容
class PointTransactionDetailSheet extends ConsumerWidget {
  const PointTransactionDetailSheet({super.key, required this.tx});

  final PointTransaction tx;

  bool get _isTemplateSpend =>
      (tx.source == 'exchange_template' ||
          tx.source == 'free_unlock_spend') &&
      tx.refId != null &&
      tx.refId!.isNotEmpty;

  String get _detailText {
    switch (tx.source) {
      case 'exchange_template':
        return '使用积分解锁付费模板';
      case 'free_unlock_spend':
        return '消耗 1 次免费解锁，用于解锁付费模板';
      case 'sign_in':
        return '每日签到自动获得积分，连签奖励更多';
      case 'shoot_daily':
        return '每日首次拍摄照片获得积分';
      case 'challenge':
        return '完成每日挑战任务获得积分';
      case 'share':
        return '每日分享作品获得积分';
      case 'invite':
        return '邀请好友获得积分奖励';
      case 'redeem_code':
        return '兑换兑换码获得积分奖励';
      case 'level_reward':
        return '达成新等级获得升级奖励';
      case 'free_unlock':
        return '邀请里程碑达成，获得免费解锁次数';
      case 'ad':
        return '观看广告获得积分';
      default:
        return '积分变动记录';
    }
  }

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final isEarn = tx.delta > 0;
    final deltaColor =
        tx.delta > 0 ? tokens.success : tx.delta < 0 ? tokens.danger : tokens.textSecondary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：来源 + 变动金额 + 正文说明
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEarn ? tokens.successSubtle : tokens.dangerSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEarn ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 22,
                  color: isEarn ? tokens.success : tokens.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pointSourceLabel(tx.source),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detailText,
                      style: TextStyle(
                          fontSize: 13, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                tx.delta > 0 ? '+${tx.delta}' : '${tx.delta}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 信息明细
          _InfoRow(tokens: tokens, label: '时间', value: _formatTime(tx.createdAt)),
          const SizedBox(height: 10),
          _InfoRow(
            tokens: tokens,
            label: '类型',
            value: tx.delta > 0
                ? '获取'
                : tx.delta < 0
                    ? '花费'
                    : '额度变动',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            tokens: tokens,
            label: '来源',
            value: tx.source,
            valueColor: tokens.textTertiary,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            tokens: tokens,
            label: '流水编号',
            value: tx.id,
            valueColor: tokens.textTertiary,
          ),
          // 解锁付费模板：内嵌模板卡片
          if (_isTemplateSpend) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: tokens.divider),
            const SizedBox(height: 16),
            Text(
              tx.source == 'exchange_template' ? '用于解锁模板' : '消耗免费解锁模板',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _SpentTemplateCard(templateId: tx.refId!),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.tokens,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final ThemeTokens tokens;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: tokens.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 支出对应的付费模板卡片（点击跳转模板详情页）
class _SpentTemplateCard extends ConsumerWidget {
  const _SpentTemplateCard({required this.templateId});

  final String templateId;

  void _openTemplate(BuildContext context) {
    Navigator.of(context).pop();
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesDetail, templateId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final detailAsync = ref.watch(templateDetailProvider(templateId));

    return NeuCard(
      overlayOnImage: false,
      padding: const EdgeInsets.all(12),
      child: detailAsync.when(
        loading: () => Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 12,
                    color: tokens.surfaceAlt,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    color: tokens.surfaceAlt,
                  ),
                ],
              ),
            ),
          ],
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: tokens.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '模板详情加载失败',
                style: TextStyle(
                    fontSize: 13, color: tokens.textSecondary),
              ),
            ),
          ],
        ),
        data: (detail) {
          if (detail == null) {
            return Row(
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 20, color: tokens.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '该模板已下架或不存在',
                    style: TextStyle(
                        fontSize: 13, color: tokens.textSecondary),
                  ),
                ),
              ],
            );
          }
          return InkWell(
            onTap: () => _openTemplate(context),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: detail.cover != null
                      ? Image.network(
                          detail.cover!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _PlaceholderImage(
                              tokens: tokens),
                        )
                      : _PlaceholderImage(tokens: tokens),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail.price > 0 ? '付费模板 · ${detail.price} 积分' : '免费模板',
                        style: TextStyle(
                            fontSize: 12, color: tokens.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '查看',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tokens.brand,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: tokens.brand),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 模板封面占位图（无封面 / 加载失败时显示）
class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: tokens.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 20, color: tokens.textTertiary),
    );
  }
}