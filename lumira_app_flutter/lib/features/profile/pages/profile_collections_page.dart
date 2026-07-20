import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_content_mock_data.dart';

/// 我的精选集页
///
/// 视觉规格来源：lumira-app/src/pages/profile/collections.vue（188 行）
/// 2 个 section：
/// 1. GridWrap（4 个 CollectionCard 2 列网格）
/// 2. TipSection（精选集功能提示卡）
class ProfileCollectionsPage extends ConsumerWidget {
  const ProfileCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的精选集',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _CreateButton(tokens: tokens),
        ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GridWrap(tokens: tokens),
                _TipSection(tokens: tokens),
                const SizedBox(height: 24),
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
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.profile);
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

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('新建精选集'),
            duration: Duration(milliseconds: 1000),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // 24rpx/12rpx → 12/6dp
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Center(
          child: Text(
            '+ 新建',
            style: TextStyle(
              fontSize: 14, // 28rpx → 14dp
              fontWeight: FontWeight.w500,
              color: tokens.textInverse,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridWrap extends StatelessWidget {
  const _GridWrap({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const collections = ProfileContentMockData.collections;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), // 48rpx/40rpx/0 → 24/20/0
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16, // 32rpx → 16dp
        mainAxisSpacing: 16,
        // Forced fix: 原 0.79 导致 33px 溢出。
        // _CollectionCard 文字区 = 14*1.4+2+11+26 = 58.6dp
        // 设 w=154: 0.70 → h=220dp，图 Expanded 占 220-58.6 = 161.4dp ✓
        childAspectRatio: 0.70,
        children: [
          for (var i = 0; i < collections.length; i++)
            FadeUp(
              delay: Duration(milliseconds: i * 80),
              child: _CollectionCard(item: collections[i], tokens: tokens),
            ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.item, required this.tokens});
  final CollectionItem item;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.profileCollectionDetail),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
          boxShadow: tokens.shadowConvexSubtle,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover with count badge
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      item.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: tokens.surfaceAlt,
                        child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // 16rpx/6rpx → 8/3dp
                      decoration: BoxDecoration(
                        // 硬编码颜色，与 uni-app 一致 (rgba(0,0,0,0.7))
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        '${item.count}张',
                        style: const TextStyle(
                          fontSize: 10, // 20rpx → 10dp
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), // 28rpx/24rpx/28rpx → 14/12/14dp
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '更新于 ${item.updated}',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipSection extends StatelessWidget {
  const _TipSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0), // 48rpx/64rpx/0 → 24/32/0
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), // 40rpx/32rpx → 20/16dp
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.divider, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 24, // 48rpx → 24dp
              color: tokens.brand,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '精选集功能',
                    style: TextStyle(
                      fontSize: 13, // 26rpx → 13dp
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '将喜欢的照片整理成集，一键导出九宫格拼图',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
