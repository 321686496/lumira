import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/home_mock_data.dart';
import '../providers/banner_recommendation_provider.dart';

/// 首页 Banner 轮播
///
/// 展示与用户相关的推荐信息：模板与场景搭配、拍摄灵感、新模板等。
/// 自动轮播 5 秒一切，支持手动滑动，点击跳转对应路由。
///
/// 数据源：[bannerRecommendationProvider] 基于用户真实拍摄历史生成 5 条 banner。
/// - loading 态：占位卡（surfaceAlt 色 Container）
/// - error 态：fallback 到 [HomeMockData.banners] 第 1 条（保证不空白）
/// - data 态：真实推荐数据
class HomeBanner extends ConsumerStatefulWidget {
  const HomeBanner({super.key});

  @override
  ConsumerState<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends ConsumerState<HomeBanner> {
  final PageController _controller = PageController();
  int _current = 0;
  Timer? _timer;
  int _lastBannerCount = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// banner 数量变化时重启定时器（避免越界 / 旧索引残留）
  void _ensureTimer(int count) {
    if (count == _lastBannerCount) return;
    _lastBannerCount = count;
    _timer?.cancel();
    _timer = null;
    if (count > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        if (_current >= count) _current = 0;
        final next = (_current + 1) % count;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final asyncBanners = ref.watch(bannerRecommendationProvider);

    return asyncBanners.when(
      loading: () => _LoadingPlaceholder(tokens: tokens),
      error: (_, __) {
        // fallback 到 mock 数据第 1 条，保证不空白
        final banners = <HomeBannerItem>[HomeMockData.banners.first];
        _ensureTimer(banners.length);
        return _buildCarousel(banners, tokens);
      },
      data: (banners) {
        final list =
            banners.isEmpty ? <HomeBannerItem>[HomeMockData.banners.first] : banners;
        _ensureTimer(list.length);
        return _buildCarousel(list, tokens);
      },
    );
  }

  Widget _buildCarousel(List<HomeBannerItem> banners, ThemeTokens tokens) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: banners.length,
            itemBuilder: (_, index) {
              final banner = banners[index];
              return _BannerCard(
                banner: banner,
                tokens: tokens,
                onTap: () => GoRouter.of(context).push(banner.route),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < banners.length; i++)
              Container(
                width: i == _current ? 16 : 6,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == _current
                      ? tokens.brand
                      : tokens.brand.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Loading 占位卡（surfaceAlt 色容器，宽屏 280x140 风格）
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++)
              Container(
                width: i == 0 ? 16 : 6,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: tokens.brand.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.tokens, required this.onTap});
  final HomeBannerItem banner;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: tokens.brandDeep.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景渐变
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.brandDeep,
                    tokens.brand,
                    tokens.brandLight,
                  ],
                ),
              ),
            ),
            // 装饰圆
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -10,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      banner.tag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    banner.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.01 * 18,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 右侧箭头
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
