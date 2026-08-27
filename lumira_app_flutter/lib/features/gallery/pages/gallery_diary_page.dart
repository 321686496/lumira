import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/data/capture_preview_mock_data.dart';
import '../providers/gallery_diary_providers.dart';
import '../widgets/diary_timeline_entry.dart';
import 'gallery_detail_page.dart';

/// 拍摄日记页（接入 GalleryDao）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/diary.vue（433 行）
/// - LumiraNav + 视图切换 + 连续拍摄 banner + 时间轴 + FAB
/// - 数据：通过 diaryEntriesProvider 异步读取近 50 张照片并按天分组
class GalleryDiaryPage extends ConsumerStatefulWidget {
  const GalleryDiaryPage({super.key});

  @override
  ConsumerState<GalleryDiaryPage> createState() => _GalleryDiaryPageState();
}

class _GalleryDiaryPageState extends ConsumerState<GalleryDiaryPage> {
  /// 已选心情集合（多选；空集表示「全部」）
  Set<String> _selectedMoods = {};

  /// 当前筛选的日期（null 表示未筛选 / 「全部」）
  DateTime? _pickedDate;
  final ScrollController _scrollController = ScrollController();

  /// 每个日期 entry 的 GlobalKey，用于日期跳转（Scrollable.ensureVisible）
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 点击照片进入详情页。传入该天（entry 内）的全部照片 ID 作为左右滑动范围，
  /// 保证详情页内左右滑动跟随拍摄日记的照片列表而非整个相册。
  void _navigateToPhoto(List<String> scopeIds, String photoId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryDetailPage(photoId: photoId, scopeIds: scopeIds),
      ),
    );
  }

  /// 时间轴「查看更多」→ 当日照片页（传该天具体日期）
  void _navigateToDay(DateTime day) {
    final dateStr =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.galleryDiaryDay, {
        RouteNames.paramDate: dateStr,
      }),
    );
  }

  Future<void> _pickDate() async {
    final entries = ref
        .read(diaryEntriesProvider(
            DiaryFilter(tab: kDiaryTabShoot, moods: _selectedMoods)))
        .valueOrNull;

    // 有照片的日期集合 → 日期选择器打点标记
    final markedDates =
        (entries ?? []).map((e) => e.day).toSet();

    final picked = await showLumiraDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      markedDates: markedDates,
    );
    if (picked == null || !mounted) return;

    if (entries == null || entries.isEmpty) {
      LumiraToast.show(context, '暂无照片数据', duration: const Duration(milliseconds: 1200));
      return;
    }

    final targetLabel = DateFormat('M月d日').format(picked);
    final index = entries.indexWhere((e) => e.date == targetLabel);
    if (index < 0) {
      LumiraToast.show(
        context,
        '该日期没有照片',
        duration: const Duration(milliseconds: 1200),
      );
      return;
    }

    // 记录当前筛选取向的日期，按钮上回显「M月d日」
    setState(() => _pickedDate = picked);

    // 通过 GlobalKey 定位目标 entry 并滚动到可视区（entry 高度不固定，不能用估算偏移）
    final key = _entryKeys[targetLabel];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  Future<void> _onPhotoLongPress(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('删除', style: TextStyle(color: ref.read(themeTokensProvider).danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final dao = await ref.read(galleryDaoProvider.future);
    await dao.delete(photoId);
    ref.invalidate(
        diaryEntriesProvider(DiaryFilter(tab: kDiaryTabShoot, moods: _selectedMoods)));
    ref.invalidate(diaryStreakProvider);
    ref.invalidate(diaryTotalCountProvider);
    if (mounted) {
      LumiraToast.show(context, '已删除', duration: const Duration(milliseconds: 1200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final entriesAsync = ref.watch(
        diaryEntriesProvider(DiaryFilter(tab: kDiaryTabShoot, moods: _selectedMoods)));
    final streak = ref.watch(diaryStreakProvider).valueOrNull ?? 0;
    final monthStats = ref.watch(diaryMonthlyStatsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '拍摄日记',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _CalendarAction(
            tokens: tokens,
            pickedDate: _pickedDate,
            onTap: _pickDate,
            onClear: _pickedDate == null
                ? null
                : () {
                    setState(() => _pickedDate = null);
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
          ),
        ],
      ),
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            child: entriesAsync.when(
              loading: () => Center(child: LumiraProgress.circular()),
              error: (e, _) => Center(
                child: Text(
                  '加载失败：$e',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
              data: (entries) => ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // 心情筛选（多选，与标题栏保持间隔）
                  FadeUp(
                    delay: const Duration(milliseconds: 50),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: _MoodFilterRow(
                        selectedMoods: _selectedMoods,
                        onToggle: (mood, active) => setState(() {
                          if (active) {
                            _selectedMoods = {..._selectedMoods, mood};
                          } else {
                            _selectedMoods = {..._selectedMoods}..remove(mood);
                          }
                        }),
                        tokens: tokens,
                      ),
                    ),
                  ),
                  // 连续打卡 banner（本月进度 + 里程碑徽章）
                  FadeUp(
                    delay: const Duration(milliseconds: 100),
                    child: _StreakBanner(
                      tokens: tokens,
                      streak: streak,
                      monthStats: monthStats,
                    ),
                  ),
                  // 月度聚合条
                  if (monthStats != null)
                    FadeUp(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: '本月照片',
                                value: '${monthStats.thisMonthPhotos}',
                                tokens: tokens,
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: '打卡天数',
                                value: '${monthStats.thisMonthDays}',
                                tokens: tokens,
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: '最常心情',
                                value: monthStats.mostCommonMood ?? '-',
                                tokens: tokens,
                              ),
                            ),
                            Expanded(
                              child: _MiniStat(
                                label: '常去场景',
                                value: monthStats.mostCommonScene ?? '-',
                                tokens: tokens,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 时间轴标题
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: _EmptyState(tokens: tokens),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '时间轴',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            '${entries.length}篇',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                              fontFamily: 'Courier New',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 时间轴 entries
                    ...entries.asMap().entries.map((e) {
                      _entryKeys[e.value.date] = _entryKeys[e.value.date] ?? GlobalKey();
                      return FadeUp(
                        delay: Duration(milliseconds: (e.key % 5) * 60),
                        child: DiaryTimelineEntry(
                          key: _entryKeys[e.value.date],
                          entry: e.value,
                          onPhotoTap: (id) => _navigateToPhoto(
                            e.value.photos.map((p) => p.id).toList(),
                            id,
                          ),
                          onPhotoLongPress: _onPhotoLongPress,
                          onViewMore: _navigateToDay,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          // FAB
          Positioned(
            right: 24,
            bottom: 32,
            child: _DiaryFab(
              tokens: tokens,
              onTap: () => GoRouter.of(context).push(RouteNames.capture),
            ),
          ),
        ],
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
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 18, color: tokens.textPrimary),
      ),
    );
  }
}

class _CalendarAction extends StatelessWidget {
  const _CalendarAction({
    required this.tokens,
    required this.onTap,
    required this.pickedDate,
    this.onClear,
  });
  final ThemeTokens tokens;
  final VoidCallback onTap;

  /// 当前筛选日期（null 表示未筛选，显示「全部」）
  final DateTime? pickedDate;

  /// 长按清除筛选（非 null 时生效），用于回到「全部」
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilter = pickedDate != null;
    final label = hasFilter ? DateFormat('M月d日').format(pickedDate!) : '全部';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onClear,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasFilter ? tokens.brandSubtle : tokens.surface,
          borderRadius: BorderRadius.circular(1000),
          border: Border.all(
            color: hasFilter ? tokens.brand.withOpacity(0.6) : tokens.divider,
            width: 1,
          ),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: hasFilter ? tokens.brand : tokens.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasFilter ? tokens.brand : tokens.textPrimary,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.close,
                size: 12,
                color: tokens.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 心情筛选行：横向滑动，支持多选（点击选中/再次点击取消）
class _MoodFilterRow extends StatelessWidget {
  const _MoodFilterRow({
    required this.selectedMoods,
    required this.onToggle,
    required this.tokens,
  });

  final Set<String> selectedMoods;
  final void Function(String mood, bool active) onToggle;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const moods = CapturePreviewMockData.moods;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mood = moods[index];
          final active = selectedMoods.contains(mood.name);
          return GestureDetector(
            onTap: () => onToggle(mood.name, !active),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? tokens.brand : tokens.surface,
                borderRadius: BorderRadius.circular(1000),
                border: Border.all(
                  color: active ? tokens.brand : tokens.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mood.icon,
                      size: 14,
                      color: active ? tokens.textInverse : tokens.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    mood.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? tokens.textInverse : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({
    required this.tokens,
    required this.streak,
    required this.monthStats,
  });
  final ThemeTokens tokens;
  final int streak;
  final DiaryMonthlyStats? monthStats;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime.now().day;
    final progress = monthStats?.thisMonthDays ?? 0;
    final ratio = daysInMonth > 0 ? (progress / daysInMonth).clamp(0.0, 1.0) : 0.0;

    // 里程碑徽章：7/14/30 天
    String? badgeLabel;
    if (streak >= 30) {
      badgeLabel = '月度达人';
    } else if (streak >= 14) {
      badgeLabel = '坚持达人';
    } else if (streak >= 7) {
      badgeLabel = '周更达人';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.brandSubtle, tokens.brandLight.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月打卡 $progress/$daysInMonth 天',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              if (badgeLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, size: 14, color: tokens.textInverse),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textInverse,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 本月进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: tokens.brand.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            streak > 0
                ? badgeLabel != null
                    ? '已连续拍摄 $streak 天，已获得「$badgeLabel」徽章'
                    : '已连续拍摄 $streak 天，距离「周更达人」还差 ${7 - streak} 天'
                : '今天开始拍摄，记录你的拍摄轨迹',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 月度聚合小格：数值 + 标签
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.tokens});
  final String label;
  final String value;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return LumiraSurface(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      radius: 10,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.brand,
                  fontFamily: 'Courier New',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: tokens.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryFab extends StatelessWidget {
  const _DiaryFab({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: tokens.brand,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '还没有照片，去拍一张吧',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textTertiary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -0.8),
              radius: 1.2,
              colors: [
                tokens.brandSubtle.withOpacity(0.35),
                tokens.canvas.withOpacity(0),
              ],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}
