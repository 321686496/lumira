import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/profile/data/growth_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_growth_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/growth_providers.dart';

void main() {
  testWidgets(
      'tapping share on unlocked achievement opens PosterGenerator sheet',
      (tester) async {
    final unlockedAchievements = <AchievementRecord>[
      const AchievementRecord(
        id: 'ach_first_photo',
        name: '初次拍摄',
        description: '完成第一次拍摄',
        iconKey: 'camera',
        unlocked: true,
        unlockedAt: 1700000000000,
      ),
      const AchievementRecord(
        id: 'ach_streak_7',
        name: '连续7天',
        description: '连续打卡 7 天',
        iconKey: 'flame',
        unlocked: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthAchievementsProvider.overrideWith(
            (ref) async => unlockedAchievements,
          ),
          growthLevelProvider.overrideWith(
            (ref) async => GrowthSummary(
              level: 3,
              currentXp: 1200,
              xpToNextLevel: 300,
              levelName: '进阶',
            ),
          ),
          growthTrajectoryProvider.overrideWith((ref) async => const []),
          growthHeatmapProvider.overrideWith((ref) async => const {}),
        ],
        child: const MaterialApp(home: ProfileGrowthPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 验证已解锁成就上有分享按钮
    final shareIcons = find.byIcon(Icons.ios_share_outlined);
    expect(shareIcons, findsOneWidget);

    // 点击分享按钮
    await tester.tap(shareIcons);
    await tester.pumpAndSettle();

    // 验证 PosterGenerator 底部 Sheet 出现
    expect(find.text('导出海报'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
