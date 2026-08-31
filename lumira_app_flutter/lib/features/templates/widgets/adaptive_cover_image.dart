import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'template_cover_image.dart';

/// 模板封面默认展示比例（加载中/未知比例兜底，≈ 3:4）。
const double kDefaultCoverRatio = 3 / 4;

/// 封面展示比例下限：9:16(0.5625) 等长屏钳到 0.65，高度温和削减约 13%。
const double kMinCoverRatio = 0.65;

/// 封面展示比例上限：超宽全景（>2:1）钳到 2.0，裁左右。
const double kMaxCoverRatio = 2.0;

/// 将图片真实宽高比钳制到 [kMinCoverRatio, kMaxCoverRatio]。
///
/// 区间内的比例完全展示；超出区间的（9:16 长屏 / 超宽全景）用 cover 裁切多余方向。
double clampCoverRatio(double realRatio) =>
    realRatio.clamp(kMinCoverRatio, kMaxCoverRatio);

/// 构造封面 ImageProvider（四种来源统一路由，与 LumiraImage 内部路由保持一致）：
/// 1. [coverData] 非空 → base64 → [MemoryImage]
/// 2. [cover] 以 `data:` 开头 → base64 → [MemoryImage]
/// 3. [cover] 以 `assets/` 开头 → [AssetImage]
/// 4. [cover] 以 `http(s)` 开头 → [NetworkImage]
/// 5. 其它 → 本地文件 [FileImage]
/// 无任何有效来源时返回 null。
ImageProvider? buildCoverProvider(String? cover, String? coverData) {
  final cd = coverData;
  if (cd != null && cd.isNotEmpty) {
    final bytes = _decodeBase64Bytes(cd);
    if (bytes != null) return MemoryImage(bytes);
  }
  final c = cover;
  if (c == null || c.isEmpty) return null;
  if (c.startsWith('data:')) {
    final bytes = _decodeBase64Bytes(c);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  if (c.startsWith('assets/')) return AssetImage(c);
  if (c.startsWith('http://') || c.startsWith('https://')) {
    return NetworkImage(c);
  }
  return FileImage(File(c));
}

Uint8List? _decodeBase64Bytes(String data) {
  try {
    final commaIdx = data.indexOf(',');
    final raw = (commaIdx >= 0 && data.startsWith('data:'))
        ? data.substring(commaIdx + 1)
        : data;
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

/// 自适应封面组件：按封面真实比例定高，宽度 100%，比例钳制在
/// [kMinCoverRatio, kMaxCoverRatio]（9:16 温和削减 / 超宽裁切）。
///
/// - 通过 `ImageStream.resolve` 取真实宽高（先例：gallery/photo_crop_layer.dart）。
/// - 渲染仍委托 [TemplateCoverImage]（走 LumiraImage 字节缓存 + 降采样），
///   本组件只负责外层比例与尺寸。
/// - [overlay] 作为封面 Stack 内的叠加子组件（免费/积分/已拍等角标）。
class AdaptiveCoverImage extends StatefulWidget {
  const AdaptiveCoverImage({
    super.key,
    this.cover,
    this.coverData,
    this.fit = BoxFit.cover,
    this.fallback,
    this.errorFallback,
    this.overlay = const <Widget>[],
  });

  final String? cover;
  final String? coverData;
  final BoxFit fit;
  final Widget? fallback;
  final Widget? errorFallback;
  final List<Widget> overlay;

  @override
  State<AdaptiveCoverImage> createState() => _AdaptiveCoverImageState();
}

class _AdaptiveCoverImageState extends State<AdaptiveCoverImage> {
  /// 图片真实宽高比（width / height）；null 表示尚未解析（用默认比例）。
  double? _realAspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AdaptiveCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover ||
        oldWidget.coverData != widget.coverData) {
      _realAspect = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    final s = _stream;
    final l = _listener;
    if (s != null && l != null) {
      s.removeListener(l);
    }
    _stream = null;
    _listener = null;
    super.dispose();
  }

  void _resolve() {
    final s = _stream;
    final l = _listener;
    if (s != null && l != null) {
      s.removeListener(l);
    }
    _stream = null;
    _listener = null;

    final provider = buildCoverProvider(widget.cover, widget.coverData);
    if (provider == null) return;

    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        final w = info.image.width;
        final h = info.image.height;
        if (w > 0 && h > 0) {
          setState(() => _realAspect = w / h);
        }
      },
      onError: (_, __) {
        // 解析失败：保持默认比例，画面由 TemplateCoverImage 的 errorFallback 兜底。
        if (mounted && _realAspect != null) {
          setState(() => _realAspect = null);
        }
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    final provider = buildCoverProvider(widget.cover, widget.coverData);
    if (provider == null) {
      // 无封面（空 cover + 无 coverData）时仍要展示 overlay（免费/积分/已拍等角标），
      // 否则空封面模板会丢失价格/已拍徽标，与有封面卡片不一致。
      // 用默认比例定高（与"有封面"路径一致），避免 Stack 在无界高度约束下崩 layout。
      final fb = widget.fallback ?? const SizedBox.shrink();
      if (widget.overlay.isEmpty) return fb;
      return AspectRatio(
        aspectRatio: kDefaultCoverRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [fb, ...widget.overlay],
        ),
      );
    }
    final real = _realAspect;
    final ratio = (real == null) ? kDefaultCoverRatio : clampCoverRatio(real);
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TemplateCoverImage(
            cover: widget.cover,
            coverData: widget.coverData,
            fit: widget.fit,
            fallback: widget.fallback,
            errorFallback: widget.errorFallback,
          ),
          ...widget.overlay,
        ],
      ),
    );
  }
}
