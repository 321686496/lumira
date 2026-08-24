import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import 'package:go_router/go_router.dart';

/// 账号相关页统一「说明引导卡片」。
///
/// 顶部展示本功能用途 + 分步使用教程 + 可选安全提示，让用户清楚「这是干嘛的、怎么用」。
/// 全部使用 themeTokens 派生，随主题/风格变化，无硬编码色。
class AccountGuideCard extends ConsumerWidget {
  const AccountGuideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.steps,
    this.tip,
  });

  final IconData icon;
  final String title;
  final String description;

  /// 分步使用教程（每项渲染为带序号的说明行）
  final List<String>? steps;

  /// 安全/注意事项提示（渲染在最下方，可换行）
  final String? tip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: tokens.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    if (steps != null && steps!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (var i = 0; i < steps!.length; i++) _StepRow(index: i + 1, text: steps![i], tokens: tokens),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(fontSize: 13, height: 1.5, color: tokens.textSecondary),
            ),
          ],
          if (tip != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: tokens.brand),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tip!,
                    style: TextStyle(fontSize: 12, height: 1.5, color: tokens.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text, required this.tokens});
  final int index;
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.brandText),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.4, color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 账号相关页统一样式对比脚本返回按钮（与其它详情页保持一致）
class AccountBackButton extends StatelessWidget {
  const AccountBackButton({super.key, required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}