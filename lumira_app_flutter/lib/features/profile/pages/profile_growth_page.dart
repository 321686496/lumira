import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';

/// 成长中心页
///
/// 视觉规格来源：lumira-app/src/pages/profile/growth.vue（375 行）
/// 4 个 section：
/// 1. LevelCard（等级 + 经验进度 + 三列 meta）
/// 2. AchievementCard（6 项成就墙）
/// 3. TrajectoryCard（4 项成长轨迹时间线）
/// 4. CalendarCard（112 格热力图 + 图例）
class ProfileGrowthPage extends ConsumerWidget {
  const ProfileGrowthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '成长中心',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeUp(child: _LevelCard(user: ProfileMockData.userProfile, tokens: tokens)),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: _AchievementCard(tokens: tokens),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 200),
                  child: _TrajectoryCard(tokens: tokens),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 300),
                  child: _CalendarCard(tokens: tokens),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.user, required this.tokens});
  final UserProfile user;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        children: [
          Text(
            'LEVEL',
            style: TextStyle(
              fontFamily: 'Courier New',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.brandText,
              letterSpacing: 0.08 * 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.level}',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.levelName,
            style: TextStyle(
              fontSize: 15,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: user.xpPercent / 100.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 三列 meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatThousands(user.currentXp)} XP',
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '还差 ${formatThousands(user.xpRemaining)} XP 升级',
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 11,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${formatThousands(user.maxXp)} XP',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = ProfileMockData.achievements.where((a) => !a.locked).length;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '成就',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount / ${ProfileMockData.achievements.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: ProfileMockData.achievements.map((a) => _AchievementCell(item: a, tokens: tokens)).toList(),
          ),
        ],
      ),
    );
  }
}

class _AchievementCell extends StatelessWidget {
  const _AchievementCell({required this.item, required this.tokens});
  final Achievement item;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 36, // 72rpx → 36dp
            color: item.locked ? tokens.textTertiary : tokens.textPrimary,
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: TextStyle(
              fontSize: 11, // 22rpx → 11dp
              color: item.locked ? tokens.textTertiary : tokens.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (item.locked) {
      return Opacity(opacity: 0.5, child: cell);
    }
    return cell;
  }
}

class _TrajectoryCard extends StatelessWidget {
  const _TrajectoryCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '成长轨迹',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < ProfileMockData.trajectory.length; i++)
                _TrajectoryRow(
                  entry: ProfileMockData.trajectory[i],
                  isLast: i == ProfileMockData.trajectory.length - 1,
                  tokens: tokens,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrajectoryRow extends StatelessWidget {
  const _TrajectoryRow({required this.entry, required this.isLast, required this.tokens});
  final TrajectoryEntry entry;
  final bool isLast;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间线左侧：圆点 + 连接线
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tokens.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.canvas, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.brand.withOpacity(0.4),
                      blurRadius: 0,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 36, // ~48dp height
                  color: tokens.divider,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.date,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier New',
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.tokens});
  final ThemeTokens tokens;

  /// 热力图色块颜色（硬编码，与 uni-app 一致）
  Color _heatColor(int level) {
    switch (level) {
      case 0:
        return tokens.divider;
      case 1:
        return const Color(0xFFC9A96E).withOpacity(0.2);
      case 2:
        return const Color(0xFFC9A96E).withOpacity(0.4);
      case 3:
        return const Color(0xFFC9A96E).withOpacity(0.6);
      case 4:
        return tokens.brand;
      default:
        return tokens.divider;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '拍摄日历',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '本月 ${ProfileMockData.monthlyPhotos} 张',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 360, // minWidth 360
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: ProfileMockData.heatmap.length,
                itemBuilder: (context, i) {
                  return Container(
                    key: ValueKey('heatmap_cell_$i'),
                    decoration: BoxDecoration(
                      color: _heatColor(ProfileMockData.heatmap[i]),
                      borderRadius: BorderRadius.circular(2), // 4rpx → 2dp
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '少',
                style: TextStyle(fontSize: 11, color: tokens.textTertiary),
              ),
              const SizedBox(width: 4),
              for (final level in const [0, 1, 2, 3, 4]) ...[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: _heatColor(level),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '多',
                style: TextStyle(fontSize: 11, color: tokens.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
