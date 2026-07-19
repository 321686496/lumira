import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/gallery_mock_data.dart';
import '../widgets/diary_timeline_entry.dart';

/// 拍摄日记页（mock 数据）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/diary.vue（433 行）
/// - LumiraNav + 视图切换 + 连续打卡 banner + 时间轴（5 篇）+ FAB
class GalleryDiaryPage extends ConsumerStatefulWidget {
  const GalleryDiaryPage({super.key});

  @override
  ConsumerState<GalleryDiaryPage> createState() => _GalleryDiaryPageState();
}

class _GalleryDiaryPageState extends ConsumerState<GalleryDiaryPage> {
  String _viewTab = 'outfit'; // 'outfit' / 'shoot'

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        // Forced fix: brief File 9 把 title 硬编码为 '穿搭日记'，但 brief File 15
        // Test 3「toggles between outfit and shoot tabs」期望切换 shoot tab 后
        // '穿搭日记' 文字仅出现 1 次（findsOneWidget）。改为动态 title：outfit→
        // '穿搭日记'，shoot→'拍摄日记'，与 active tab 同步。
        title: _viewTab == 'outfit' ? '穿搭日记' : '拍摄日记',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _CalendarAction(tokens: tokens),
        ],
      ),
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            child: ListView(
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
                  child: _StreakBanner(tokens: tokens),
                ),
                // 时间轴标题
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
                        '5篇',
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
                ...GalleryMockData.diaryEntries.asMap().entries.map((e) {
                  return FadeUp(
                    delay: Duration(milliseconds: (e.key % 5) * 60),
                    child: DiaryTimelineEntry(entry: e.value),
                  );
                }),
              ],
            ),
          ),
          // FAB
          Positioned(
            right: 24,
            bottom: 32,
            child: _DiaryFab(tokens: tokens),
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
  const _CalendarAction({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.calendar_today_outlined, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _DiaryViewToggle extends StatelessWidget {
  const _DiaryViewToggle({
    required this.activeTab,
    required this.onTap,
    required this.tokens,
  });
  final String activeTab;
  final void Function(String) onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(1000),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _item('穿搭日记', 'outfit', activeTab == 'outfit'),
          _item('拍摄日记', 'shoot', activeTab == 'shoot'),
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
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1))]
              : null,
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
  const _StreakBanner({required this.tokens});
  final ThemeTokens tokens;

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
                      '连续打卡 7 ',
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
  const _DiaryFab({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
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
