import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../templates/widgets/template_cover_image.dart';
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
  /// 无限轮播使用的虚拟倍数（PageView itemCount = count*_kRepeat，
  /// 初始页取中间值，保证前后都能无限滑动而不越界）。
  static const int _kRepeat = 10000;

  PageController? _controller;
  int _current = 0;
  Timer? _timer;
  int _bannerCount = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Tab 非激活时（MainTabsPage 用 TickerMode 静音整页）自动暂停轮播定时器，
  /// 避免 keep-alive 后台继续驱动轮播动画占帧；恢复激活时按需重启。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.of(context);
    if (enabled) {
      if (_controller != null && _timer == null) {
        _restartTimer(_bannerCount);
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// banner 数量变化时重建控制器（居中初始化以实现无限滑动），并（重）启自动轮播。
  void _initController(int count) {
    if (_controller != null && count == _bannerCount) return;
    _bannerCount = count;
    final old = _controller;
    _current = (count * _kRepeat) ~/ 2;
    _controller = count > 0
        ? PageController(initialPage: _current)
        : null;
    old?.dispose();
    _restartTimer(count);
  }

  /// 取消并重新启动自动轮播定时器（count<=1 不轮播）。
  void _restartTimer(int count) {
    _timer?.cancel();
    _timer = null;
    if (count <= 1) return;
    if (!TickerMode.of(context)) return; // Tab 非激活时不启动
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final c = _controller;
      if (c == null || !c.hasClients || !mounted) return;
      // 已滚出可视区时不自动轮播（省掉不可见的离屏重绘）
      if (!_isInViewport()) return;
      // 无限模式：始终向后滑一页即可无缝循环
      c.animateToPage(
        _current + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  /// 判断 banner 是否处于「外层滚动容器（首页 ListView）」的可视区内。
  /// 穿透 banner 自身的 PageView，取最外层真实滚动位置计算；任何不确定都 fail-open。
  bool _isInViewport() {
    try {
      final box = context.findRenderObject();
      if (box == null || box is! RenderBox) return true;
      // banner 自身 PageView 永远"可视"；取最外层滚动容器（首页 ListView）判定。
      ScrollableState? s = context.findAncestorStateOfType<ScrollableState>();
      ScrollPosition? outer;
      while (s != null) {
        outer = s.position;
        s = s.context.findAncestorStateOfType<ScrollableState>();
      }
      if (outer == null) return true;
      final viewport = outer.context.storageContext
          .findAncestorRenderObjectOfType<RenderAbstractViewport>();
      if (viewport == null) return true;
      final reveal = viewport.getOffsetToReveal(box, 0.0);
      final top = reveal.offset;
      final bottom = top + box.size.height;
      final vp = outer.pixels;
      final vh = outer.viewportDimension;
      return bottom >= vp && top <= vp + vh;
    } catch (_) {
      return true;
    }
  }

  /// 用户手动拖动开始 → 重置自动轮播计时（避免刚滑动完立刻被自动切走）。
  bool _onManualScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _restartTimer(_bannerCount);
    }
    return false;
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
        _initController(banners.length);
        return _buildCarousel(banners, tokens);
      },
      data: (banners) {
        final list =
            banners.isEmpty ? <HomeBannerItem>[HomeMockData.banners.first] : banners;
        _initController(list.length);
        return _buildCarousel(list, tokens);
      },
    );
  }

  Widget _buildCarousel(List<HomeBannerItem> banners, ThemeTokens tokens) {
    if (banners.isEmpty) return const SizedBox.shrink();
    final count = banners.length;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onManualScroll,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _current = i),
              // 无限模式：足够大的虚拟 itemCount，index%count 映射到真实 banner
              itemCount: count * _kRepeat,
              itemBuilder: (_, index) {
                final banner = banners[index % count];
                return _BannerCard(
                  banner: banner,
                  tokens: tokens,
                  onTap: () => GoRouter.of(context).push(banner.route),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < count; i++)
              Container(
                width: i == (_current % count) ? 16 : 6,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == (_current % count)
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

/// Loading 占位卡（surface 色容器 + 新拟态凸起阴影）
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
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: tokens.shadowConvexSubtle,
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
    final hasCover = banner.hasCover;
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
            // 背景：模板类 banner 用封面图，其他用品牌渐变
            if (hasCover) ...[
              TemplateCoverImage(
                cover: banner.cover,
                coverData: banner.coverData,
                fit: BoxFit.cover,
                fallback: _buildGradientBackground(),
              ),
              // 暗色渐变遮罩，保证文字可读性
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
            ] else
              _buildGradientBackground(),
            // 装饰圆（仅渐变背景显示）
            if (!hasCover) ...[
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
            ],
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
                    maxLines: 2,
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

  /// 品牌渐变背景（无封面图时使用）
  Widget _buildGradientBackground() {
    return Container(
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
    );
  }
}
