import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/image_cache.dart';

/// 模板封面图统一渲染组件。
///
/// 解决：自定义模板的封面图以 base64 data URL 形式存储在 `coverData` 字段，
/// 内置模板的封面图以 assets 路径存储在 `cover` 字段，远程模板可能用 http URL。
/// 之前各页面分别用 `Image.network('picsum.photos/seed/...')` 渲染，导致
/// 自定义模板封面不显示。
///
/// 本组件按优先级渲染：
/// 1. [coverData] 非空 → `Image.memory(base64Decode(...))`（自定义模板 base64 data URL）
/// 2. [cover] 以 `assets/` 开头 → `Image.asset(cover)`（内置模板资产路径）
/// 3. [cover] 以 `http` 开头 → `Image.network(cover)`（远程模板 URL）
/// 4. [cover] 以 `data:` 开头 → 解析 base64 后 `Image.memory`
/// 5. 兜底 → [fallback] 或默认占位图标
class TemplateCoverImage extends StatelessWidget {
  const TemplateCoverImage({
    super.key,
    this.cover,
    this.coverData,
    this.fit = BoxFit.cover,
    this.fallback,
    this.errorFallback,
  });

  /// 内置模板 assets 路径或远程模板 http URL（可能为空字符串）
  final String? cover;

  /// 自定义模板 base64 data URL（如 `data:image/jpeg;base64,xxx`）
  final String? coverData;

  /// 图片 fit 模式
  final BoxFit fit;

  /// 无任何封面数据时的占位 widget
  final Widget? fallback;

  /// 图片加载/解码失败时的占位 widget
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    // 1. coverData 优先（自定义模板 base64）
    if (coverData != null && coverData!.isNotEmpty) {
      return _buildFromDataUrl(coverData!);
    }

    // 2. cover 字段
    if (cover != null && cover!.isNotEmpty) {
      // 2a. data: URL
      if (cover!.startsWith('data:')) {
        return _buildFromDataUrl(cover!);
      }
      // 2b. assets 路径
      if (cover!.startsWith('assets/')) {
        return Image.asset(
          cover!,
          fit: fit,
          frameBuilder: _fadeInFrameBuilder,
          errorBuilder: (_, __, ___) =>
              errorFallback ?? _defaultError(context),
        );
      }
      // 2c. http(s) URL → 走统一缓存组件（磁盘缓存 + 按需降采样）
      if (cover!.startsWith('http')) {
        return CachedNetworkImage(
          url: cover!,
          fit: fit,
          errorWidget: errorFallback ?? _defaultError(context),
        );
      }
    }

    // 3. 兜底
    return fallback ?? _defaultEmpty(context);
  }

  /// 图片解码完成前显示淡入（避免跳变）。
  static Widget _fadeInFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: child,
    );
  }

  Widget _buildFromDataUrl(String dataUrl) {
    try {
      final bytes = _decodeBase64DataUrl(dataUrl);
      return Image.memory(
        bytes,
        fit: fit,
        frameBuilder: _fadeInFrameBuilder,
        errorBuilder: (_, __, ___) =>
            errorFallback ?? _defaultError(null),
      );
    } catch (_) {
      return errorFallback ?? _defaultError(null);
    }
  }

  /// 解析 data URL 中的 base64 数据。
  /// 支持 `data:image/jpeg;base64,xxx` 和纯 base64 字符串。
  static Uint8List _decodeBase64DataUrl(String data) {
    String raw = data;
    final commaIdx = data.indexOf(',');
    if (commaIdx >= 0 && data.startsWith('data:')) {
      raw = data.substring(commaIdx + 1);
    }
    return base64Decode(raw);
  }

  Widget _defaultEmpty(BuildContext? context) {
    return Builder(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          color: theme.colorScheme.surfaceVariant,
          child: Icon(
            Icons.photo_outlined,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            size: 32,
          ),
        );
      },
    );
  }

  Widget _defaultError(BuildContext? context) {
    return Builder(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          color: theme.colorScheme.surfaceVariant,
          child: Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            size: 32,
          ),
        );
      },
    );
  }
}
