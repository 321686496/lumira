import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/usage_dao.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../templates/widgets/template_cover_image.dart';
import '../../usage/usage_providers.dart';
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

class _HomeBannerState extends ConsumerState<HomeBanner>
    with WidgetsBindingObserver {
  /// 无限轮播使用的虚拟倍数（PageView itemCount = count*_kRepeat，
  /// 初始页取中间值，保证前后都能无限滑动而不越界）。
  static const int _kRepeat = 10000;

  /// Banner 配置刷新间隔（运营后台改配置后，App 最迟 60s 内跟进；
  /// 后端 Redis 缓存写后即时失效，客户端 TTL 仅作防抖）
  static const Duration _kRefreshTtl = Duration(seconds: 60);

  /// 上次拉取 Banner 配置的时间（会话级；null = 尚未拉取）
  static DateTime? _lastFetchedAt;

  PageController? _controller;
  int _current = 0;
  Timer? _timer;
  int _bannerCount = 0;

  /// 会话内已上报曝光的 bannerId（去重：自动轮播/来回滑动不重复计曝光）
  final Set<String> _exposedBannerIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// App 回前台 → 按 TTL 静默刷新 Banner 配置（后台运营改动同步进 App）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _maybeRefreshBanners();
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
      // 切回首页 Tab 时也按 TTL 刷新（覆盖不经过前后台切换的场景）
      _maybeRefreshBanners();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// 距上次拉取超过 TTL 才 invalidate；重载期间保留旧数据不闪 loading
  /// （provider 为非 autoDispose FutureProvider，invalidate 后 ref.watch 的
  ///  .when(skipLoadingOnReload) 会继续展示旧列表直到新数据到达）。
  void _maybeRefreshBanners() {
    final last = _lastFetchedAt;
    final now = DateTime.now();
    if (last == null) {
      // 冷启动：初始拉取已由首次 watch 触发，仅记录时间戳，不重复拉取
      _lastFetchedAt = now;
      return;
    }
    if (now.difference(last) < _kRefreshTtl) return;
    _lastFetchedAt = now;
    ref.invalidate(bannerRecommendationProvider);
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

  /// Banner 埋点：曝光/点击写入本地 usage_events 队列
  /// （失败静默降级，不影响 Banner 渲染与跳转；启动时由 usageSyncService 统一上报）
  void _recordBannerEvent(String bannerId, UsageEventType event) {
    ref
        .read(usageEventRecorderProvider.future)
        .then((recorder) =>
            recorder.recordBanner(bannerId: bannerId, event: event))
        .catchError((_) {});
  }

  /// 曝光埋点：banner 成为当前页时上报一次（按 trackingId 会话内去重）
  void _reportExpose(List<HomeBannerItem> banners, int realIndex) {
    if (realIndex < 0 || realIndex >= banners.length) return;
    final banner = banners[realIndex];
    if (!_exposedBannerIds.add(banner.trackingId)) return;
    _recordBannerEvent(banner.trackingId, UsageEventType.bannerExpose);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final asyncBanners = ref.watch(bannerRecommendationProvider);

    return asyncBanners.when(
      // 刷新（invalidate）期间保留旧数据继续展示，不闪 loading 占位
      skipLoadingOnReload: true,
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
    // 首屏曝光：首帧渲染后上报当前页（仅当轮播处于外层可视区）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isInViewport()) _reportExpose(banners, _current % count);
    });
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onManualScroll,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) {
                setState(() => _current = i);
                _reportExpose(banners, i % count);
              },
              // 无限模式：足够大的虚拟 itemCount，index%count 映射到真实 banner
              itemCount: count * _kRepeat,
              itemBuilder: (_, index) {
                final banner = banners[index % count];
                return _BannerCard(
                  banner: banner,
                  tokens: tokens,
                  onTap: () {
                    // 点击埋点：失败静默，不阻断跳转
                    _recordBannerEvent(
                        banner.trackingId, UsageEventType.bannerClick);
                    GoRouter.of(context).push(banner.route);
                  },
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
    // 运营位配图：右侧 40% 区域 contain 完整显示（不裁切），底层同图模糊填充；
    // 模板类封面仍走全幅 cover + 暗色遮罩
    final opImage = banner.type == BannerType.operation && hasCover;
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
            if (opImage) ...[
              // 运营位配图：渐变打底 + 左文右图（3:2 分栏）
              _buildGradientBackground(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildTextColumn(),
                    ),
                  ),
                  Expanded(flex: 2, child: _buildOperationImage()),
                ],
              ),
            ] else if (hasCover) ...[
              // 模板类封面：全幅 cover + 暗色遮罩保证文字可读
              TemplateCoverImage(
                cover: banner.cover,
                coverData: banner.coverData,
                fit: BoxFit.cover,
                fallback: _buildGradientBackground(),
              ),
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTextColumn(),
              ),
            ] else ...[
              _buildGradientBackground(),
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTextColumn(),
              ),
            ],
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

  /// 文案列（角标胶囊 + 主标题 + 副标题），垂直居中
  Widget _buildTextColumn() {
    return Column(
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
    );
  }

  /// 运营配图区（卡片右侧 40%）：
  /// 底层同图 cover + 模糊铺底（填充 contain 两侧留白），上层 contain 完整显示不裁切
  Widget _buildOperationImage() {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Transform.scale(
              scale: 1.3,
              child: TemplateCoverImage(
                cover: banner.cover,
                coverData: banner.coverData,
                fit: BoxFit.cover,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
          TemplateCoverImage(
            cover: banner.cover,
            coverData: banner.coverData,
            fit: BoxFit.contain,
            fallback: const SizedBox.shrink(),
          ),
        ],
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
