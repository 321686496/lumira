import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/home_mock_data.dart';

/// 最近拍摄卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 166-187 + style line 698-803
/// - 28rpx→14dp 圆角
/// - 图片 aspect ratio 3:4 (padding-bottom 133.33%)
/// - 标签左上：white 90% + blur 8px + brand 文字
/// - 收藏右下：isFavorite 时显示实心心形
/// - 再拍一次：右上角小按钮（onRetake 非空时显示）
/// - 下方文字：作品名 + 相对拍摄时间
class RecentShotCard extends ConsumerWidget {
  const RecentShotCard({
    super.key,
    required this.recent,
    required this.onTap,
    this.onRetake,
  });

  final RecentShot recent;
  final VoidCallback onTap;

  /// "再拍一次"回调；为 null 时隐藏右上角复用按钮
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;
    final isGlass = appTheme.style == UIStyle.glass;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          // Forced fix(玻璃): 玻璃风格用半透明品牌玻璃面 + 细白描边 + 柔和投影，
          // 让背后 GlassBackground 光晕透出形成玻璃卡；其余风格保持不变。
          color: isGlass
              ? ThemeTokens.glassFill(tokens)
              : (isNeumorphic ? tokens.surface : tokens.canvas),
          borderRadius: BorderRadius.circular(14),
          border: isGlass
              ? Border.all(color: ThemeTokens.glassBorder(tokens), width: 1)
              : (isNeumorphic
                  ? null
                  : Border.all(color: tokens.divider, width: 1)),
          boxShadow: isGlass
              ? const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    offset: Offset(0, 6),
                    blurRadius: 20,
                  ),
                ]
              : (isNeumorphic ? tokens.shadowConvex : null),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(tokens),
                    // 分类标签（左上）
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildCategoryChip(tokens, isGlass, recent),
                    ),
                    // 再拍一次（右上角）
                    if (onRetake != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onRetake,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(1000),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.replay,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '再拍',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 收藏状态（右下角）
                    if (recent.isFavorite)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x991A1A1A),
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 10,
                                color: tokens.danger,
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                '已收藏',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 文字区
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13, // 26rpx → 13dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 11,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _relativeTime(recent.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textTertiary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类标签（叠在封面图上的浮层角标）。
  ///
  /// 性能(Forced fix): 之前非新拟态在照片上叠「白 0.9 + BackdropFilter blur 8」的角标，
  /// 每张可见卡片的 BackdropFilter 在滚动时每帧都要重新采样/模糊其背后的照片，
  /// 多张卡片叠加后是 OHOS 首页滚动掉帧的主要成本之一。
  /// 按「叠图表面」规范改为：非玻璃风格一律用半透明 surface + 细边（不做模糊、不做玻璃），
  /// 仅玻璃风格保留毛玻璃角标（模糊属该风格设计语言）。视觉与原实现高度一致。
  Widget _buildCategoryChip(
    ThemeTokens tokens,
    bool isGlass,
    RecentShot recent,
  ) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          recent.icon,
          size: 10, // 20rpx → 10dp
          color: tokens.brand,
        ),
        const SizedBox(width: 3),
        Text(
          recent.category,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.brand,
            height: 1.2,
          ),
        ),
      ],
    );

    if (!isGlass) {
      final visual = LumiraThemeResolver.overlayOnImageVisual(
        tokens: tokens,
        radiusDp: 12,
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(1000),
          border: visual.border,
          boxShadow: visual.shadows,
        ),
        child: label,
      );
    }

    // 玻璃风格：保留毛玻璃角标（模糊属于玻璃风格设计语言）
    return ClipRRect(
      borderRadius: BorderRadius.circular(1000),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: Colors.white.withOpacity(0.9),
          child: label,
        ),
      ),
    );
  }

  /// 相对拍摄时间：今天 HH:mm / 昨天 / N 天前
  String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(t.year, t.month, t.day);
    final dayDiff = today.difference(thatDay).inDays;

    if (dayDiff <= 0) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '今天 $hh:$mm';
    }
    if (dayDiff == 1) return '昨天';
    if (dayDiff < 7) return '$dayDiff 天前';
    return '${t.month}月${t.day}日';
  }

  /// 按优先级渲染真实照片：filePath > dataUrl > originalPath > picsum 占位
  Widget _buildImage(ThemeTokens tokens) {
    // 1. filePath：本地文件
    final filePath = recent.imageFilePath;
    if (filePath != null && filePath.isNotEmpty) {
      return LumiraImage(
        filePath,
        fit: BoxFit.cover,
        errorWidget: _fallbackImage(tokens),
      );
    }

    // 2. dataUrl：base64 内联（兼容旧数据）→ LumiraImage 自动降采样 + base64 字节级缓存
    final dataUrl = recent.imageDataUrl;
    if (dataUrl != null && dataUrl.isNotEmpty) {
      return LumiraImage(
        dataUrl,
        fit: BoxFit.cover,
        errorWidget: _fallbackImage(tokens),
      );
    }

    // 3. originalPath：原始文件路径
    final originalPath = recent.imageOriginalPath;
    if (originalPath != null && originalPath.isNotEmpty) {
      return LumiraImage(
        originalPath,
        fit: BoxFit.cover,
        errorWidget: _fallbackImage(tokens),
      );
    }

    // 4. picsum 占位（网络，保留原 CachedNetworkImage）
    return CachedNetworkImage(
      url: 'https://picsum.photos/seed/${recent.imageSeed}/400/600',
      fit: BoxFit.cover,
      errorWidget: _fallbackImage(tokens),
    );
  }

  Widget _fallbackImage(ThemeTokens tokens) {
    return Container(
      color: tokens.surfaceAlt,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: tokens.textTertiary,
      ),
    );
  }
}