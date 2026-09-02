import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../data/points_models.dart';

/// 单条积分流水行
///
/// 钱包页「积分流水」预览与「积分明细」全量页共用同一视觉组件，
/// 保证两处样式一致。
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

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tx.delta >= 0 ? tokens.successSubtle : tokens.dangerSubtle,
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
                  style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
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
    );
  }
}