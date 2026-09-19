import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../templates/data/templates_providers.dart';
import '../../templates/widgets/recommendation_card.dart';
import '../data/home_providers.dart';

/// 首页「最近使用模板」横向流。
/// 无拍摄历史时降级为「为你备选模板」，并与发现页推荐栏取数错开。
class RecentTemplateStrip extends ConsumerWidget {
  const RecentTemplateStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final asyncTemplates = ref.watch(homeRecentTemplateStripProvider);
    final usageCounts =
        ref.watch(templateUsageCountsProvider).valueOrNull ?? const <String, int>{};

    return asyncTemplates.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (templates) {
        if (templates.length <= 3) return const SizedBox.shrink();
        final hasHistory = templates.any(
          (template) => (usageCounts[template.id] ?? 0) > 0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部不再自带 20dp：外层已由首页 slivers 提供 28dp 间距，
            // 这里再叠加会让今日灵感卡下方实得 48dp、与上方 28dp 不对称。
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Text(
                    hasHistory ? '最近使用模板' : '为你备选模板',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    child: Text(
                      hasHistory ? '再拍一次' : '快速开拍',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tokens.brand,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 248,
              child: ListView.separated(
                clipBehavior: Clip.none, // 放行卡片四周浮雕阴影，避免下侧阴影被「场景推荐」区裁切遮挡
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final template = templates[index];
                  return RepaintBoundary(
                    child: RecommendationCard(
                      recommendation: templateRecordToRecommendation(template),
                      usageCount: usageCounts[template.id] ?? 0,
                      onTap: () => GoRouter.of(context).push(
                        RouteNames.build(
                          RouteNames.capture,
                          {RouteNames.paramTemplateId: template.id},
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
