import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/image_cache.dart';

/// 统一图片加载组件（全链路）。
///
/// 对四种图片来源做统一处理，并统一按「实际渲染尺寸 × DPR」降采样（cacheWidth），
/// 避免网格/卡片处按原图全尺寸解码导致加载慢、内存高：
///
/// - `assets/*` 开头 → 打包资源（[Image.asset] + 降采样）
/// - `data:` 开头   → base64 data URL（字节级缓存，避免每次重建反复解码 + 降采样）
/// - `http` 开头    → 网络 URL（复用 [CachedNetworkImage]：磁盘缓存 + 降采样）
/// - 其它           → 本地文件路径（[Image.file] + 降采样）
///
/// 兼容模板编辑等需要强制 asset 的场景：可显式传 [asset]。来源识别失败或为空走
/// [placeholder]/[errorWidget]。
class LumiraImage extends StatelessWidget {
  const LumiraImage(
    this.src, {
    super.key,
    this.asset,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.placeholder,
    this.errorWidget,
  });

  /// 任意图片来源：asset 路径 / data URL / http URL / 本地文件路径。
  final String src;

  /// 显式指定为打包 asset（覆盖 [src] 的来源自动识别，用于模板编辑等场景）。
  final String? asset;

  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// 加载/解码中的占位 widget（当前网络路径渲染占位；asset/file/base64 无异步加载态）。
  final Widget? placeholder;

  /// 加载失败的占位 widget。
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    // 显式 asset 优先
    final explicitAsset = asset;
    final s = src;
    if (explicitAsset != null && explicitAsset.isNotEmpty) {
      return _buildWithDownsample(
        context,
        (cw, ch) => Image.asset(
          explicitAsset,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cw,
          cacheHeight: ch,
          errorBuilder: (c, e, st) => errorWidget ?? _defaultError(c),
        ),
      );
    }

    if (s.isEmpty) {
      return placeholder ?? errorWidget ?? const SizedBox.shrink();
    }

    // 网络 URL → 复用 CachedNetworkImage（自带磁盘缓存 + 降采样）
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return CachedNetworkImage(
        url: s,
        fit: fit,
        width: width,
        height: height,
        borderRadius: borderRadius == BorderRadius.zero ? null : borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }

    // base64 data URL → 字节级缓存 + 降采样
    if (s.startsWith('data:')) {
      final bytes = _decodeDataUrl(s);
      if (bytes == null) {
        return errorWidget ?? _defaultError(null);
      }
      return _buildWithDownsample(
        context,
        (cw, ch) => Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cw,
          cacheHeight: ch,
          errorBuilder: (c, e, st) => errorWidget ?? _defaultError(c),
        ),
      );
    }

    if (s.startsWith('assets/')) {
      return _buildWithDownsample(
        context,
        (cw, ch) => Image.asset(
          s,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cw,
          cacheHeight: ch,
          errorBuilder: (c, e, st) => errorWidget ?? _defaultError(c),
        ),
      );
    }

    // 本地文件路径
    return _buildWithDownsample(
      context,
      (cw, ch) => Image.file(
        File(s),
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cw,
        cacheHeight: ch,
        errorBuilder: (c, e, st) => errorWidget ?? _defaultError(c),
      ),
    );
  }

  /// 外层用 LayoutBuilder 测算渲染尺寸，按「较大边长 × DPR」算出一个解码目标，
  /// 只传一维，另一维由引擎按原图宽高比推导（避免拉伸变形）。
  Widget _buildWithDownsample(
    BuildContext context,
    ImageBuilder builder,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final mw = constraints.maxWidth;
        final mh = constraints.maxHeight;
        final wPx = (mw.isFinite && mw > 0) ? (mw * dpr).round() : null;
        final hPx = (mh.isFinite && mh > 0) ? (mh * dpr).round() : null;

        int? cw = wPx;
        int? ch = hPx;
        if (cw != null && ch != null) {
          if (cw >= ch) {
            ch = null;
          } else {
            cw = null;
          }
        }

        Widget img = builder(
          cw?.clamp(1, 4096),
          ch?.clamp(1, 4096),
        );

        final radius = borderRadius;
        if (radius != null && radius != BorderRadius.zero) {
          img = ClipRRect(borderRadius: radius, child: img);
        }
        return img;
      },
    );
  }

  // ---- base64 字节级缓存（解决每次 rebuild 反复解码）----
  static const int _maxDataBytes = 8 * 1024 * 1024;
  static final Map<String, Uint8List> _dataCache = {};
  static final List<String> _dataOrder = [];

  static Uint8List? _decodeDataUrl(String data) {
    final cached = _dataCache[data];
    if (cached != null) return cached;

    Uint8List bytes;
    try {
      final commaIdx = data.indexOf(',');
      final raw = (commaIdx >= 0 && data.startsWith('data:'))
          ? data.substring(commaIdx + 1)
          : data;
      bytes = base64Decode(raw);
    } catch (_) {
      return null;
    }

    // 小块才进内存缓存；超大 base64 不做缓存，避免常驻内存。
    if (bytes.length <= _maxDataBytes) {
      _dataCache[data] = bytes;
      _dataOrder.add(data);
      while (_dataOrder.length > 32) {
        final oldest = _dataOrder.removeAt(0);
        _dataCache.remove(oldest);
      }
    }
    return bytes;
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

/// 图片构建函数签名：接收解码目标边长（可能为 null），返回图片 widget。
typedef ImageBuilder =
    Widget Function(int? cacheWidth, int? cacheHeight);