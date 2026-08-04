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
                  return _AchievementBadge(achievement: achievement, tokens: tokens);
                },
              ),
            ],
          );
        },
      ),
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
