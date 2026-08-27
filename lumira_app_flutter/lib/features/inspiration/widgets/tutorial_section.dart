import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../data/inspiration_providers.dart';
import '../data/tutorial_models.dart';

/// 拍摄小课堂：横滑小教程卡片区（取代原"拍得更好"推系统课）
class TutorialSection extends ConsumerWidget {
  const TutorialSection({
    super.key,
    required this.onTutorialTap,
    required this.onAcademyTap,
  });

  final void Function(ShootingTutorial) onTutorialTap;
  final VoidCallback onAcademyTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(tutorialPicksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Text(
              '拍摄小课堂',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAcademyTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '系统性学习 → 美学院',
                style: TextStyle(fontSize: 12, color: tokens.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: async.when(
            loading: () => _placeholder(tokens),
            error: (_, __) => _placeholder(tokens),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => TutorialCard(
                tutorial: list[index],
                onTap: () => onTutorialTap(list[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ThemeTokens tokens) {
    return Center(
      child: Text(
        '小课堂加载中',
        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
      ),
    );
  }
}

/// 单张教程小卡（封面 + 标题 + 时长 + 已读勾）
class TutorialCard extends ConsumerWidget {
  const TutorialCard({super.key, required this.tutorial, required this.onTap});

  final ShootingTutorial tutorial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 150,
        child: LumiraSurface(
          radius: 14,
          emphasize: true,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 90,
                width: double.infinity,
                child: Image.asset(
                  tutorial.coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.photo_outlined,
                        size: 24, color: tokens.textTertiary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tutorial.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tutorial.readMinutes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: tokens.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    _ReadBadge(tutorialId: tutorial.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 已读勾（异步读 tutorial_reads）
class _ReadBadge extends ConsumerWidget {
  const _ReadBadge({required this.tutorialId});
  final String tutorialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(tutorialReadIdsProvider);
    final isRead = async.maybeWhen(
          data: (ids) => ids.contains(tutorialId),
          orElse: () => false,
        );
    if (!isRead) return const SizedBox.shrink();
    return Icon(Icons.check_circle, size: 14, color: tokens.brand);
  }
}