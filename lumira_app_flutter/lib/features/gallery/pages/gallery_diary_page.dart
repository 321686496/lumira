import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../providers/gallery_diary_providers.dart';
import '../widgets/diary_timeline_entry.dart';

/// 拍摄日记页（接入 GalleryDao）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/diary.vue（433 行）
/// - LumiraNav + 视图切换 + 连续打卡 banner + 时间轴 + FAB
/// - 数据：通过 diaryEntriesProvider 异步读取近 50 张照片并按天分组
class GalleryDiaryPage extends ConsumerStatefulWidget {
  const GalleryDiaryPage({super.key});

  @override
  ConsumerState<GalleryDiaryPage> createState() => _GalleryDiaryPageState();
}

class _GalleryDiaryPageState extends ConsumerState<GalleryDiaryPage> {
  String _viewTab = kDiaryTabOutfit; // 'outfit' / 'shoot'
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToPhoto(String photoId) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.galleryDetail,
        {RouteNames.paramPhotoId: photoId},
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showLumiraDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;

    final entries = ref.read(diaryEntriesProvider(_viewTab)).valueOrNull;
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

    // 估算滚动位置：顶部 view toggle (~60) + streak banner (~90) + 时间轴标题 (~50) + index 个 entry (~120 each)
    final offset = 60 + 90 + 50 + index * 120.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
    ref.invalidate(diaryEntriesProvider(_viewTab));
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
    final entriesAsync = ref.watch(diaryEntriesProvider(_viewTab));
    final streak = ref.watch(diaryStreakProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        // title 与 active tab 同步：outfit→'穿搭日记'，shoot→'拍摄日记'
        title: _viewTab == kDiaryTabOutfit ? '穿搭日记' : '拍摄日记',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _CalendarAction(tokens: tokens, onTap: _pickDate),
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
                  // 视图切换
                  FadeUp(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: _DiaryViewToggle(
                        activeTab: _viewTab,
                        onTap: (t) => setState(() => _viewTab = t),
                        tokens: tokens,
                      ),
                    ),
                  ),
                  // 连续打卡 banner
                  FadeUp(
                    delay: const Duration(milliseconds: 100),
                    child: _StreakBanner(tokens: tokens, streak: streak),
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
                      return FadeUp(
                        delay: Duration(milliseconds: (e.key % 5) * 60),
                        child: DiaryTimelineEntry(
                          key: ValueKey('diary_${e.value.date}'),
                          entry: e.value,
                          onPhotoTap: _navigateToPhoto,
                          onPhotoLongPress: _onPhotoLongPress,
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
  const _CalendarAction({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.calendar_today_outlined, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _DiaryViewToggle extends ConsumerWidget {
  const _DiaryViewToggle({
    required this.activeTab,
    required this.onTap,
    required this.tokens,
  });
  final String activeTab;
  final void Function(String) onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;

    return Container(
      decoration: BoxDecoration(
        color: isNeu ? tokens.surface : tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(1000),
        boxShadow: isNeu ? tokens.shadowConcaveSubtle : null,
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item('穿搭日记', kDiaryTabOutfit, activeTab == kDiaryTabOutfit),
          _item('拍摄日记', kDiaryTabShoot, activeTab == kDiaryTabShoot),
        ],
      ),
    );
  }

  Widget _item(String label, String key, bool active) {
    return GestureDetector(
      onTap: () => onTap(key),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.canvas : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
          boxShadow: active ? tokens.shadowConvexSubtle : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? tokens.textPrimary : tokens.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.tokens, required this.streak});
  final ThemeTokens tokens;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.brandSubtle, tokens.brandLight.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '连续打卡 $streak ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Icon(Icons.local_fire_department_outlined, size: 18, color: tokens.brand),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '继续保持，解锁「周更达人」徽章',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.local_fire_department, size: 36, color: tokens.brand),
        ],
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
