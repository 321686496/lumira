import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../data/checkin_categories.dart';

/// 评分星行（rating 0 不渲染）
class CheckinRatingStars extends StatelessWidget {
  const CheckinRatingStars({
    super.key,
    required this.rating,
    required this.tokens,
    this.size = 12,
  });

  final int rating;
  final ThemeTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: filled ? tokens.brand : tokens.textTertiary,
        );
      }),
    );
  }
}

/// 分类标签（彩色 pill）
class CheckinCategoryTag extends StatelessWidget {
  const CheckinCategoryTag({
    super.key,
    required this.category,
    required this.tokens,
  });

  final CheckinCategory category;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: category.iconBgColor,
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 11, color: category.iconColor),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: TextStyle(
              fontSize: 11,
              color: category.iconColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 打卡日期展示：7 天内相对时间，否则 "M月D日"
String formatCheckinDate(int millis) {
  final rel = formatRelativeTime(millis);
  return rel.isNotEmpty ? rel : formatDateOnly(millis);
}

/// 照片统一渲染：dataUrl / filePath / http；为空或加载失败显示占位
class CheckinPhotoImage extends StatelessWidget {
  const CheckinPhotoImage({
    super.key,
    required this.url,
    required this.tokens,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String? url;
  final ThemeTokens tokens;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return _fallback();
    }
    final Widget image = u.startsWith('http')
        ? CachedNetworkImage(
            url: u,
            fit: fit,
            width: width,
            height: height,
            errorWidget: _fallback(),
          )
        : Image.file(
            File(u),
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, __, ___) => _fallback(),
          );
    if (borderRadius == null) return image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius!),
      child: image,
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: tokens.surfaceAlt,
      child: Icon(Icons.broken_image_outlined, size: 20, color: tokens.textTertiary),
    );
  }
}
