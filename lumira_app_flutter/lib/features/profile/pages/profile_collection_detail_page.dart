import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_content_mock_data.dart';

/// 精选集详情页
///
/// 视觉规格来源：lumira-app/src/pages/profile/collection-detail.vue（191 行）
/// 3 个 section：
/// 1. GridWrap（9 张照片 3 列网格）
/// 2. StatsSection（3 列统计：9 张照片 / 7.9 平均评分 / 7/1 创建日）
/// 3. ExportSection（导出九宫格拼图按钮 + 提示）
class ProfileCollectionDetailPage extends ConsumerWidget {
  const ProfileCollectionDetailPage({super.key, this.collectionId});

  final String? collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我最爱的九张',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _EditButton(tokens: tokens),
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
                _StatsSection(tokens: tokens),
                _ExportSection(tokens: tokens),
                _Hint(tokens: tokens),
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

class _EditButton extends StatelessWidget {
  const _EditButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('编辑精选集'),
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
            '编辑',
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
    const photos = ProfileContentMockData.photos;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), // 48rpx/40rpx/0 → 24/20/0
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 8, // 16rpx → 8dp
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
        children: [
          for (var i = 0; i < photos.length; i++)
            FadeUp(
              delay: Duration(milliseconds: i * 80),
              child: _PhotoCell(item: photos[i], tokens: tokens),
            ),
        ],
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.item, required this.tokens});
  final PhotoItem item;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
      child: Image.network(
        item.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: tokens.surfaceAlt,
          child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.tokens});
  final ThemeTokens tokens;

  Widget _statItem(String num, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 24, // 48rpx → 24dp
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11, // 22rpx → 11dp
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28, // 56rpx → 28dp
      color: tokens.divider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0), // 48rpx/40rpx/0 → 24/20/0
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16), // 32rpx → 16dp
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('9', '张照片'),
            _divider(),
            _statItem('7.9', '平均评分'),
            _divider(),
            _statItem('7/1', '创建日'),
          ],
        ),
      ),
    );
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), // 48rpx/48rpx/0 → 24/24/0
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('导出九宫格拼图'),
                duration: Duration(milliseconds: 1000),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // 48rpx/28rpx → 24/14dp
            decoration: BoxDecoration(
              color: tokens.textPrimary,
              borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              // 硬编码颜色，与 uni-app 一致 (#FAF7F2)
              children: const [
                Icon(
                  Icons.send_outlined, // ph-paper-plane-tilt
                  size: 18,
                  color: Color(0xFFFAF7F2),
                ),
                SizedBox(width: 8),
                Text(
                  '导出九宫格拼图',
                  style: TextStyle(
                    fontSize: 15, // 30rpx → 15dp
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFAF7F2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0), // 48rpx/32rpx/0 → 24/16/0
      child: Center(
        child: Text(
          '导出的拼图可直接分享到社交媒体',
          style: TextStyle(
            fontSize: 11, // 22rpx → 11dp
            color: tokens.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
