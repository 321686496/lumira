import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/challenge_providers.dart';
import '../data/challenge_models.dart';

class AchievementWallCard extends ConsumerWidget {
  const AchievementWallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final asyncAchievements = ref.watch(challengeAchievementsProvider);

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: asyncAchievements.when(
        loading: () => SizedBox(height: 200, child: Center(child: LumiraProgress.circular())),
        error: (e, _) => SizedBox(height: 200, child: Center(child: Text('加载失败', style: TextStyle(color: tokens.textSecondary)))),
        data: (achievements) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('挑战成就', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showDetail(context, achievement, tokens),
                    child: _AchievementBadge(
                        achievement: achievement, tokens: tokens),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// 点击成就弹出详情，展示图标、描述与完成情况
  void _showDetail(
      BuildContext context, ChallengeAchievement achievement, ThemeTokens tokens) {
    final percent = (achievement.progress * 100).clamp(0, 100).round();
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 成就图标
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: achievement.unlocked
                        ? tokens.brandSubtle
                        : tokens.canvasDeep,
                    border: achievement.unlocked
                        ? Border.all(color: tokens.brand, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    achievement.unlocked
                        ? achievement.icon
                        : Icons.lock_outline,
                    size: 32,
                    color: achievement.unlocked
                        ? tokens.brand
                        : tokens.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 标题
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // 描述
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              // 解锁状态胶囊
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: achievement.unlocked
                        ? tokens.successSubtle
                        : tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    achievement.unlocked ? '已解锁' : '未解锁',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: achievement.unlocked
                          ? tokens.success
                          : tokens.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 解锁进度
              Row(
                children: [
                  Expanded(
                    child: LumiraProgress.linear(
                      value: achievement.progress.clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final ChallengeAchievement achievement;
  final ThemeTokens tokens;

  const _AchievementBadge({required this.achievement, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: achievement.unlocked ? tokens.brandSubtle : tokens.canvasDeep,
            shape: BoxShape.circle,
            border: achievement.unlocked ? Border.all(color: tokens.brand, width: 1.5) : null,
          ),
          child: Icon(
            achievement.unlocked ? achievement.icon : Icons.lock_outline,
            size: 22,
            color: achievement.unlocked ? tokens.brand : tokens.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          achievement.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: achievement.unlocked ? tokens.textPrimary : tokens.textTertiary,
          ),
        ),
      ],
    );
  }
}
