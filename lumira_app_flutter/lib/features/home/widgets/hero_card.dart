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
    // 定时器改为在 didChangeDependencies 里按 TickerMode 启停（见下），
    // 避免 keep-alive 的首页在非激活时仍每分钟重建灵感卡。
  }

  /// 跟随 TickerMode：首页 Tab 非激活时暂停 1 分钟刷新定时器，激活时恢复，
  /// 避免后台持续 rebuild 占帧。数据在回到首页时自动重新拉取。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.of(context);
    if (enabled && _timer == null) {
      _timer = Timer.periodic(_refreshInterval, (_) {
        if (!mounted) return;
        // invalidate 触发重算；配合 skipLoadingOnReload 刷新时保留旧数据，不闪 loading。
        ref.invalidate(homeInspirationProvider);
      });
    } else if (!enabled && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
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

    // 底部间距交由调用方统一控制（同 QuickActions），此处只保留左右边距，
    // 使今日灵感卡上下留白由单一数值决定、且天然对称。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.surface,
                    tokens.surfaceAlt,
                  ],
                ),
          border: isGlass
              ? Border.all(color: ThemeTokens.glassBorder(tokens), width: 1)
              : null,
          boxShadow: isNeumorphic
              ? tokens.shadowConvex
              : (isGlass ? tokens.shadowFloat : null),
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
        // 内容层（压缩：垂直 padding 28 → 16，水平 24 → 20）
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Opacity(
            opacity: dim ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  inspiration.title,
                  style: TextStyle(
                    fontSize: 20, // 40rpx → 20dp（略减以配合压缩）
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.01 * 20,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                // 日期：完整显示（原与天气挤在一行导致双双省略，现各自独占一行）
                Text(
                  inspiration.dateText,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                // 天气：完整显示，可换行；无天气数据时整行隐藏
                if (inspiration.weatherText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          inspiration.weatherText,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                // 描述：完整显示（原 maxLines:1 截断，现按内容自动换行）
                Text(
                  inspiration.description,
                  style: TextStyle(
                    fontSize: 13, // 26rpx → 13dp
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12), // 模板卡片与上方文字间隙（压缩后减小）
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
                  const SizedBox(height: 12), // 40rpx → 20dp（压缩后减小）
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
                        horizontal: 20, // 40rpx → 20dp（压缩后减小）
                        vertical: 10, // 20rpx → 10dp
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
          // 叠在灵感卡内的子卡保持扁平：不挂外阴影（避免照片/纯色底上的光晕感）
          border: isFlat ? Border.all(color: tokens.divider, width: 1) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56, // 压缩后缩略图
              height: 72, // 3:4，与文字列撑起卡片高度
              child: TemplateCoverImage(
                cover: inspiration.recommendedTemplateCover,
                coverData: inspiration.recommendedTemplateCoverData,
                fit: BoxFit.cover,
                thumbWidth: 480,
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
