import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../templates/data/templates_mock_data.dart';
import '../../templates/widgets/template_cover_image.dart';
import '../data/home_providers.dart';
import '../data/inspiration_models.dart';

/// 今日灵感卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 17-37 + style line 326-425
/// - 40rpx→20dp 边距
/// - 40rpx→20dp 圆角（hero-card border-radius 40rpx）
/// - padding 56rpx×48rpx → 28dp×24dp
/// - 背景：linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%)
/// - hero-deco：280rpx→140dp 圆形 brand 10% 透明度装饰
class HeroCard extends ConsumerStatefulWidget {
  const HeroCard({super.key, required this.onCapture});

  final VoidCallback onCapture;

  @override
  ConsumerState<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends ConsumerState<HeroCard> {
  // 刷新间隔：1 分钟。
  // homeInspirationProvider 是 FutureProvider，首次构建后结果被 Riverpod 缓存，日期/时段/天气不再更新。
  // 通过定时 invalidate 让其每次都用 DateTime.now() 重新构建，保持实时。
  // 后端 /weather 已做 30 分钟缓存，频繁重算不会重复打上游天气源。
  static const Duration _refreshInterval = Duration(minutes: 1);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      // invalidate 触发重算；配合 skipLoadingOnReload 刷新时保留旧数据，不闪 loading。
      ref.invalidate(homeInspirationProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;
    final isGlass = appTheme.style == UIStyle.glass;
    final inspirationAsync = ref.watch(homeInspirationProvider);

    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20, // 40rpx → 20dp
      ),
      child: Container(
        // Forced fix(半圆被内边距剪裁): 把 padding 移出 Container（下放到 _buildContent 的内容层）。
        // 这样装饰半圆（Positioned top/right: -30）相对于整个卡片 padding box 定位，
        // 与 uni-app .hero-deco 一致；由卡片圆角 clipBehavior: antiAlias 裁出角上弧线，
        // 而不被内容盒内边距硬裁。
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // 40rpx → 20dp
          // neumorphic 风格：使用 surface 纯色 + 双向凸起阴影替代硬编码渐变背景
          // 其他风格：保留原渐变效果
          // glass 风格：半透明磨砂 + 细白描边 + 柔和投影
          color: isNeumorphic
              ? tokens.surface
              : (isGlass ? ThemeTokens.glassFill(tokens) : null),
          gradient: isNeumorphic || isGlass
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFDF6EC),
                    Color(0xFFF5E6CC),
                  ],
                ),
          border: isGlass
              ? Border.all(color: ThemeTokens.glassBorder(tokens), width: 1)
              : null,
          boxShadow: isNeumorphic
              ? tokens.shadowConvex
              : (isGlass
                  ? const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        offset: Offset(0, 6),
                        blurRadius: 20,
                      ),
                    ]
                  : null),
        ),
        child: inspirationAsync.when(
          // skipLoadingOnReload：定时 invalidate 触发的重载沿用旧数据，避免每分钟闪 loading 骨架。
          loading: () => _buildContent(tokens, appTheme.style, HeroInspiration.fallback, dim: true),
          error: (_, __) => _buildContent(tokens, appTheme.style, HeroInspiration.fallback),
          data: (inspiration) => _buildContent(tokens, appTheme.style, inspiration),
          skipLoadingOnReload: true,
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeTokens tokens,
    UIStyle style,
    HeroInspiration inspiration, {
    bool dim = false,
  }) {
    final isNeumorphic = style == UIStyle.neumorphic;
    return Stack(
      // Clip.none：允许装饰半圆溢出到卡片边缘（由外层 Container antiAlias 做圆角裁剪）
      clipBehavior: Clip.none,
      children: [
        // hero-deco 装饰圆
        Positioned(
          top: -30, // -60rpx → -30dp
          right: -30,
          child: Container(
            width: 140, // 280rpx → 140dp
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.brand.withOpacity(0.10),
            ),
          ),
        ),
        // 内容层（内边距在此下放，自卡片 padding box 内偏移）
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24, // 48rpx → 24dp
            vertical: 28, // 56rpx → 28dp
          ),
          child: Opacity(
            opacity: dim ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日期
                if (inspiration.dateText.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14, // 28rpx → 14dp
                        color: tokens.brand,
                      ),
                      const SizedBox(width: 6), // 12rpx → 6dp
                      Flexible(
                        child: Text(
                          inspiration.dateText,
                          style: TextStyle(
                            fontSize: 12, // 24rpx → 12dp
                            color: tokens.textTertiary,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10), // 20rpx → 10dp
                // 标题
                Text(
                  inspiration.title,
                  style: TextStyle(
                    fontSize: 22, // 44rpx → 22dp
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.01 * 22,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8), // 16rpx → 8dp
                // 描述
                Text(
                  inspiration.description,
                  style: TextStyle(
                    fontSize: 13, // 26rpx → 13dp
                    color: tokens.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16), // 32rpx → 16dp，模板卡片与上方文字间隙
                // 推荐模板卡（有推荐时嵌入灵感卡内部，点击直接套用进入拍摄）
                if (inspiration.recommendedTemplateId.isNotEmpty) ...[
                  Builder(
                    builder: (context) => _recommendCard(
                      tokens: tokens,
                      style: style,
                      inspiration: inspiration,
                      onTap: () => GoRouter.of(context).push(RouteNames.build(
                        RouteNames.capture,
                        {RouteNames.paramTemplateId: inspiration.recommendedTemplateId},
                      )),
                    ),
                  ),
                  const SizedBox(height: 20), // 40rpx → 20dp
                ],
                // CTA 按钮（有推荐模板时，点击直接套用模板进入拍摄）
                Builder(builder: (context) {
                  final hasRec = inspiration.recommendedTemplateId.isNotEmpty;
                  return GestureDetector(
                    onTap: () {
                      if (hasRec) {
                        GoRouter.of(context).push(RouteNames.build(
                          RouteNames.capture,
                          {RouteNames.paramTemplateId: inspiration.recommendedTemplateId},
                        ));
                      } else {
                        widget.onCapture();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24, // 48rpx → 24dp
                        vertical: 12, // 24rpx → 12dp
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
                        // neumorphic 风格：使用 brand 纯色 + 双向阴影，避免渐变发光感
                        // 其他风格：保留 brand→brandDeep 渐变
                        color: isNeumorphic ? tokens.brand : null,
                        gradient: isNeumorphic
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  tokens.brand,
                                  tokens.brandDeep,
                                ],
                              ),
                        boxShadow:
                            isNeumorphic ? tokens.shadowConvex : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 16, // 32rpx → 16dp
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8), // 16rpx → 8dp
                          Text(
                            hasRec ? '套用模板拍摄' : '开始拍摄',
                            style: const TextStyle(
                              fontSize: 15, // 30rpx → 15dp
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // 天气行（weatherText 为空时隐藏）
                if (inspiration.weatherText.isNotEmpty) ...[
                  const SizedBox(height: 16), // 32rpx → 16dp
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 14, // 28rpx → 14dp
                        color: tokens.brand,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          inspiration.weatherText,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textTertiary,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 今日灵感卡内嵌的推荐模板卡（横向紧凑：左封面缩略图 + 右名称/分类）
  Widget _recommendCard({
    required ThemeTokens tokens,
    required UIStyle style,
    required HeroInspiration inspiration,
    required VoidCallback onTap,
  }) {
    final isNeu = style == UIStyle.neumorphic;
    final isFlat = style == UIStyle.flat;
    final category = inspiration.recommendedTemplateCategory;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isNeu ? tokens.shadowConvex : null,
          border: isFlat ? Border.all(color: tokens.divider, width: 1) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72, // 144rpx → 72dp 紧凑缩略图
              height: 96, // 192rpx → 96dp（3:4），与文字列撑起卡片高度
              child: TemplateCoverImage(
                cover: inspiration.recommendedTemplateCover,
                coverData: inspiration.recommendedTemplateCoverData,
                fit: BoxFit.cover,
                fallback: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [tokens.brandSubtle, tokens.brand.withOpacity(0.4)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 22,
                      color: tokens.brandDeep.withOpacity(0.6),
                    ),
                  ),
                ),
                errorFallback: Container(
                  color: tokens.surfaceAlt,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: tokens.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日推荐',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: tokens.brand,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inspiration.recommendedTemplateName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        TemplatesMockData.categoryLabel(category),
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
