import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/gallery_mock_data.dart';
import '../data/gallery_models.dart';

/// 画册统计页
///
/// 展示用户的拍摄数据统计：
/// - 总照片数（大数字卡片）
/// - 近 7 天拍摄趋势（柱状图）
/// - 每日平均照片数
/// - 拍摄分类排行榜（横向条形图）
/// - 最活跃拍摄时段分布
class GalleryStatsPage extends ConsumerStatefulWidget {
  const GalleryStatsPage({super.key});

  @override
  ConsumerState<GalleryStatsPage> createState() => _GalleryStatsPageState();
}

class _GalleryStatsPageState extends ConsumerState<GalleryStatsPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final daoAsync = ref.watch(galleryDaoProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '拍摄统计',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: daoAsync.when(
          loading: () => Center(child: LumiraProgress.circular()),
          error: (e, _) => Center(
            child: Text('加载失败：$e',
                style: TextStyle(color: tokens.textSecondary)),
          ),
          data: (dao) => _StatsContent(tokens: tokens, dao: dao),
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
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.gallery);
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

class _StatsContent extends StatefulWidget {
  const _StatsContent({required this.tokens, required this.dao});
  final ThemeTokens tokens;
  final GalleryDao dao;

  @override
  State<_StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends State<_StatsContent> {
  List<GalleryItemRecord> _photos = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final photos = await widget.dao.getAll();
      if (mounted) {
        setState(() {
          _photos = photos;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    if (!_loaded) {
      return Center(child: LumiraProgress.circular());
    }

    // 如果真实数据为空，使用 mock 数据展示统计效果
    final useMock = _photos.isEmpty;
    final stats = useMock
        ? GalleryMockData.stats
        : _computeStats(_photos);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (useMock)
          FadeUp(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: tokens.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前展示示例数据，拍摄照片后将显示真实统计',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.brandText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 1. 总照片数大卡片
        FadeUp(
          child: _TotalCountCard(
            tokens: tokens,
            total: stats.totalCount,
            thisWeek: stats.thisWeekCount,
            avgPerDay: stats.avgPerDay,
          ),
        ),
        const SizedBox(height: 16),
        // 2. 近 7 天趋势柱状图
        FadeUp(
          delay: const Duration(milliseconds: 80),
          child: _TrendChartCard(
            tokens: tokens,
            dailyCounts: stats.dailyCounts,
          ),
        ),
        const SizedBox(height: 16),
        // 3. 拍摄分类排行榜
        FadeUp(
          delay: const Duration(milliseconds: 160),
          child: _CategoryRankCard(
            tokens: tokens,
            ranks: stats.categoryRanks,
          ),
        ),
        const SizedBox(height: 16),
        // 4. 拍摄时段分布
        FadeUp(
          delay: const Duration(milliseconds: 240),
          child: _TimeOfDayCard(
            tokens: tokens,
            distribution: stats.timeOfDayDistribution,
          ),
        ),
      ],
    );
  }

  /// 从真实照片数据计算统计
  GalleryStats _computeStats(List<GalleryItemRecord> photos) {
    final now = DateTime.now();

    // 近 7 天每日计数
    final dailyCounts = <int>[0, 0, 0, 0, 0, 0, 0];
    for (final p in photos) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.createdAt);
      final diff = now.difference(dt).inDays;
      if (diff >= 0 && diff < 7) {
        dailyCounts[6 - diff] = dailyCounts[6 - diff] + 1;
      }
    }

    // 本周总数
    final thisWeekCount = dailyCounts.fold<int>(0, (s, c) => s + c);

    // 每日平均（基于所有照片的天数范围）
    final avgPerDay = photos.isEmpty
        ? 0.0
        : (photos.length / 7).roundToDouble();

    // 分类排行（基于 sceneId）
    final sceneCounts = <String, int>{};
    for (final p in photos) {
      final key = p.sceneId ?? 'uncategorized';
      sceneCounts[key] = (sceneCounts[key] ?? 0) + 1;
    }
    final ranks = sceneCounts.entries
        .map((e) => CategoryRank(
              label: _sceneLabel(e.key),
              count: e.value,
              percent: photos.isNotEmpty ? e.value / photos.length : 0.0,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // 时段分布
    final timeBuckets = <int>[0, 0, 0, 0]; // 上午/下午/傍晚/夜晚
    for (final p in photos) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.createdAt);
      final hour = dt.hour;
      if (hour >= 6 && hour < 12) {
        timeBuckets[0]++;
      } else if (hour >= 12 && hour < 17) {
        timeBuckets[1]++;
      } else if (hour >= 17 && hour < 20) {
        timeBuckets[2]++;
      } else {
        timeBuckets[3]++;
      }
    }
    final total = timeBuckets.fold<int>(0, (s, c) => s + c);
    final distribution = [
      TimeSlot(label: '上午', icon: Icons.wb_sunny_outlined, count: timeBuckets[0], percent: total > 0 ? timeBuckets[0] / total : 0),
      TimeSlot(label: '下午', icon: Icons.wb_cloudy_outlined, count: timeBuckets[1], percent: total > 0 ? timeBuckets[1] / total : 0),
      TimeSlot(label: '傍晚', icon: Icons.wb_twilight_outlined, count: timeBuckets[2], percent: total > 0 ? timeBuckets[2] / total : 0),
      TimeSlot(label: '夜晚', icon: Icons.nights_stay_outlined, count: timeBuckets[3], percent: total > 0 ? timeBuckets[3] / total : 0),
    ];

    return GalleryStats(
      totalCount: photos.length,
      thisWeekCount: thisWeekCount,
      avgPerDay: avgPerDay,
      dailyCounts: dailyCounts,
      categoryRanks: ranks,
      timeOfDayDistribution: distribution,
    );
  }

  String _sceneLabel(String sceneId) {
    if (sceneId == 'uncategorized') return '未分类';
    // 简单返回 sceneId 作为标签（真实场景下可查询场景名称）
    return sceneId;
  }
}

/// 总照片数卡片
class _TotalCountCard extends StatelessWidget {
  const _TotalCountCard({
    required this.tokens,
    required this.total,
    required this.thisWeek,
    required this.avgPerDay,
  });

  final ThemeTokens tokens;
  final int total;
  final int thisWeek;
  final double avgPerDay;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 22, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '我的拍摄',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 总数大字
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: tokens.brand,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '张照片',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 子指标
          Row(
            children: [
              _SubMetric(
                tokens: tokens,
                label: '本周拍摄',
                value: '$thisWeek 张',
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(width: 20),
              _SubMetric(
                tokens: tokens,
                label: '日均拍摄',
                value: '${avgPerDay.toStringAsFixed(1)} 张',
                icon: Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubMetric extends StatelessWidget {
  const _SubMetric({
    required this.tokens,
    required this.label,
    required this.value,
    required this.icon,
  });

  final ThemeTokens tokens;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 近 7 天趋势柱状图
class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({
    required this.tokens,
    required this.dailyCounts,
  });

  final ThemeTokens tokens;
  final List<int> dailyCounts; // 长度 7，索引 0 = 6天前

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final maxCount = dailyCounts.reduce((a, b) => a > b ? a : b).clamp(1, 999);

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '近 7 天拍摄趋势',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 柱状图
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _BarColumn(
                      tokens: tokens,
                      label: _weekdays[i],
                      count: dailyCounts[i],
                      maxCount: maxCount,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.tokens,
    required this.label,
    required this.count,
    required this.maxCount,
  });

  final ThemeTokens tokens;
  final String label;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final heightRatio = maxCount > 0 ? count / maxCount : 0.0;
    final isToday = label == _TrendChartCard._weekdays.last;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 数值
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tokens.brand,
              ),
            ),
          ),
        // 柱子
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 0.6,
              heightFactor: heightRatio.clamp(0.02, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isToday
                        ? [tokens.brand, tokens.brandDeep]
                        : [tokens.brandLight, tokens.brand.withOpacity(0.5)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isToday ? tokens.brand : tokens.textTertiary,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 拍摄分类排行榜
class _CategoryRankCard extends StatelessWidget {
  const _CategoryRankCard({
    required this.tokens,
    required this.ranks,
  });

  final ThemeTokens tokens;
  final List<CategoryRank> ranks;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_outlined, size: 20, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '拍摄分类排行',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ranks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '暂无分类数据',
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                ),
              ),
            )
          else
            for (var i = 0; i < ranks.length; i++) ...[
              _RankRow(
                tokens: tokens,
                rank: ranks[i],
                index: i,
              ),
              if (i < ranks.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.tokens,
    required this.rank,
    required this.index,
  });

  final ThemeTokens tokens;
  final CategoryRank rank;
  final int index;

  @override
  Widget build(BuildContext context) {
    final medalColors = [tokens.brand, const Color(0xFF9C9690), const Color(0xFFB8976A)];
    final medalColor = index < 3 ? medalColors[index] : tokens.textTertiary;

    return Row(
      children: [
        // 排名
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: medalColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: medalColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 标签
        Expanded(
          flex: 2,
          child: Text(
            rank.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ),
        // 进度条
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.12)),
                  FractionallySizedBox(
                    widthFactor: rank.percent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 数量
        SizedBox(
          width: 36,
          child: Text(
            '${rank.count}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 拍摄时段分布
class _TimeOfDayCard extends StatelessWidget {
  const _TimeOfDayCard({
    required this.tokens,
    required this.distribution,
  });

  final ThemeTokens tokens;
  final List<TimeSlot> distribution;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 20, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '拍摄时段分布',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < distribution.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TimeSlotCell(
                    tokens: tokens,
                    slot: distribution[i],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeSlotCell extends StatelessWidget {
  const _TimeSlotCell({required this.tokens, required this.slot});
  final ThemeTokens tokens;
  final TimeSlot slot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 圆形进度
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: slot.percent,
                strokeWidth: 4,
                backgroundColor: tokens.brandSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
              ),
              Icon(slot.icon, size: 16, color: tokens.brand),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slot.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${(slot.percent * 100).round()}%',
          style: TextStyle(
            fontSize: 10,
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }
}
