import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/images/adaptive_photo_grid.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';
import '../widgets/fragment_poster_generator.dart';

/// 碎片收集详情页
///
/// 展示各分类碎片的收集进度、获取方式与集齐奖励。
/// 每个碎片卡片下方展示构成该碎片的图片（九宫格/四宫格），
/// 可生成海报分享。
class ProfileFragmentDetailPage extends ConsumerStatefulWidget {
  const ProfileFragmentDetailPage({super.key});

  @override
  ConsumerState<ProfileFragmentDetailPage> createState() =>
      _ProfileFragmentDetailPageState();
}

class _ProfileFragmentDetailPageState
    extends ConsumerState<ProfileFragmentDetailPage> {
  /// 为每个碎片卡片维护一个 posterKey
  final Map<int, GlobalKey> _posterKeys = {};

  GlobalKey _keyFor(int index) =>
      _posterKeys.putIfAbsent(index, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final fragments = ProfileMockData.fragments;
    final collected = fragments.fold<int>(0, (s, f) => s + f.current);
    final total = fragments.fold<int>(0, (s, f) => s + f.max);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '碎片收集',
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeUp(child: _SummaryCard(
                  tokens: tokens,
                  collected: collected,
                  total: total,
                )),
                const SizedBox(height: 20),
                ...fragments.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeUp(
                      delay: Duration(milliseconds: 80 * (entry.key + 1)),
                      child: _FragmentDetailCard(
                        tokens: tokens,
                        item: entry.value,
                        posterKey: _keyFor(entry.key),
                        onSharePoster: () {
                          FragmentPosterGenerator.showPoster(
                            context,
                            tokens: tokens,
                            fragment: entry.value,
                            posterKey: _keyFor(entry.key),
                          );
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                FadeUp(
                  delay: Duration(milliseconds: 80 * (fragments.length + 1)),
                  child: _RewardCard(tokens: tokens, allDone: collected >= total),
                ),
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

/// 顶部汇总卡片
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.tokens, required this.collected, required this.total});
  final ThemeTokens tokens;
  final int collected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (collected / total * 100).round() : 0;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension, size: 22, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '碎片图鉴',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已收集 $collected / $total',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: tokens.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: percent / 100.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [tokens.brand, tokens.brandLight]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '完成不同分类的拍摄挑战即可收集碎片，集齐全部碎片可解锁专属奖励。',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 单个碎片详情卡
class _FragmentDetailCard extends StatelessWidget {
  const _FragmentDetailCard({
    required this.tokens,
    required this.item,
    required this.posterKey,
    required this.onSharePoster,
  });
  final ThemeTokens tokens;
  final FragmentItem item;
  final GlobalKey posterKey;
  final VoidCallback onSharePoster;

  String get _howToEarn {
    switch (item.name) {
      case '人像':
        return '使用人像分类模板完成拍摄，每次获得 1 枚碎片';
      case '风光':
        return '使用风光分类模板完成拍摄，每次获得 1 枚碎片';
      case '美食':
        return '使用美食分类模板完成拍摄，每次获得 1 枚碎片';
      case '街拍':
        return '使用街拍分类模板完成拍摄，每次获得 1 枚碎片';
      default:
        return '完成对应分类拍摄挑战即可获得碎片';
    }
  }

  void _showFullGrid(BuildContext context, List<String> urls) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('全部图片')),
        body: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: urls.length,
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(urls[i], fit: BoxFit.cover),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final done = item.current >= item.max;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done
                      ? tokens.brand.withOpacity(0.15)
                      : tokens.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  done ? Icons.check_circle : item.icon,
                  size: 18,
                  color: done ? tokens.success : tokens.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '${item.current}/${item.max}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: done ? tokens.success : tokens.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _howToEarn,
            style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: item.percent / 100.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: done
                              ? [tokens.success, tokens.success]
                              : [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 构成此碎片的图片（九宫格/四宫格）
          if (item.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 14, color: tokens.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '构成碎片的照片',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AdaptivePhotoGrid(
              urls: item.photoUrls,
              onTapOverflow: () => _showFullGrid(context, item.photoUrls),
            ),
            const SizedBox(height: 12),
            // 分享海报按钮
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onSharePoster,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.brandSubtle,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share_outlined,
                          size: 14, color: tokens.brand),
                      const SizedBox(width: 4),
                      Text(
                        '生成海报',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 集齐奖励卡
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.tokens, required this.allDone});
  final ThemeTokens tokens;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, size: 20, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '集齐奖励',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            allDone
                ? '恭喜你已集齐全部碎片！专属称号「光影收藏家」已解锁。'
                : '集齐全部碎片后可解锁专属称号「光影收藏家」及 200 XP 奖励。',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
